#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
#
# Fermata for Linux (x86_64): self-extracting installer.
#
# tool/package_linux.sh turns this file into dist/setup.sh: it fills in the
# version and payload checksum below, inlines lib/common.sh, and appends a
# gzip-compressed tar archive (the release bundle, desktop entry, AppStream
# metadata, icons and uninstall.sh). The payload is the last PAYLOAD_SIZE
# bytes of the file and is verified against PAYLOAD_SHA256 before use.
#
# Run ./setup.sh --help for usage. Documentation: docs/INSTALL.md.

# Re-exec under bash when started as `sh setup.sh` (POSIX sh syntax only here).
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "Fermata setup needs bash 4 or newer (found ${BASH_VERSION})." >&2
  exit 1
fi
set -euo pipefail

FERMATA_VERSION="@FERMATA_VERSION@"
PAYLOAD_SHA256="@PAYLOAD_SHA256@"
PAYLOAD_SIZE="@PAYLOAD_SIZE@"

# >>> inline lib/common.sh >>>
# shellcheck source=lib/common.sh
. "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/lib/common.sh"
# <<< inline lib/common.sh <<<

SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"

usage() {
  cat <<EOF
Fermata ${FERMATA_VERSION} installer for Linux (x86_64)

Usage: ./setup.sh [options]

Without options, installs Fermata for the current user (no root needed):
  ~/.local/lib/fermata/<version>/   the application (+ "current" symlink)
  ~/.local/bin/fermata              launcher symlink
  ~/.local/share/applications/      desktop entry ($APP_ID.desktop)
  ~/.local/share/icons/hicolor/     icons
  ~/.local/share/metainfo/          AppStream metadata
Installing a newer setup.sh over an existing installation upgrades it in
place; your library, settings and sign-ins are kept.

Options:
  --system           Install for all users: /opt/fermata, /usr/local/bin and
                     /usr/share. Uses sudo for the copy steps only.
  --uninstall        Remove Fermata (only what this installer installed; your
                     data is kept). Combine with --system for a system-wide
                     installation.
  --purge            With --uninstall: also delete your Fermata data (library
                     database, settings, cache, autostart entry, stored
                     sign-ins) after asking for confirmation.
  --check            Only check that the runtime libraries are present.
  --extract DIR      Extract the portable application to DIR and exit
                     (run DIR/fermata; nothing is installed).
  --no-deps          Skip the runtime library check.
  -y, --yes          Answer yes to all questions (non-interactive).
  --version          Print the version and exit.
  -h, --help         Show this help.

Exit codes:
  0 success   1 error   2 usage error   3 corrupt installer (checksum)
  4 missing runtime libraries (--check, or install refused)
  5 not installed (--uninstall)   6 cancelled by the user

Environment:
  NO_COLOR=1                       Disable colored output.
  FERMATA_SETUP_FAKE_MISSING=LIBS  Testing: treat these sonames as missing,
                                   e.g. "libmpv.so.2 libsecret-1.so.0".
  FERMATA_SETUP_OS_RELEASE=FILE    Testing: read this file instead of
                                   /etc/os-release.
EOF
}

# --- Options --------------------------------------------------------------------
MODE="install"
SYSTEM=0
PURGE=0
CHECK_DEPS=1
EXTRACT_DIR=""

parse_args() {
  while (($#)); do
    case "$1" in
      --system) SYSTEM=1 ;;
      --uninstall) MODE="uninstall" ;;
      --purge) PURGE=1; MODE="uninstall" ;;
      --check) MODE="check" ;;
      --extract)
        [[ $# -ge 2 && -n "$2" ]] || die "--extract needs a directory" "$EXIT_USAGE"
        MODE="extract"; EXTRACT_DIR="$2"; shift ;;
      --extract=*) MODE="extract"; EXTRACT_DIR="${1#*=}"
        [[ -n "$EXTRACT_DIR" ]] || die "--extract needs a directory" "$EXIT_USAGE" ;;
      --no-deps) CHECK_DEPS=0 ;;
      -y|--yes) ASSUME_YES=1 ;;
      --no-color) FERMATA_SETUP_COLOR=never; setup_colors ;;
      --version) MODE="version" ;;
      -h|--help) MODE="help" ;;
      *) usage >&2; die "unknown option: $1" "$EXIT_USAGE" ;;
    esac
    shift
  done
}

# --- Install locations ------------------------------------------------------------
set_locations() {
  if ((SYSTEM)); then
    APP_ROOT="/opt/fermata"
    BIN_DIR="/usr/local/bin"
    SHARE_DIR="/usr/share"
  else
    # Not ~/.local/share/fermata: path_provider_linux would adopt that directory
    # (named after the executable) as Fermata's data directory.
    APP_ROOT="$HOME/.local/lib/fermata"
    BIN_DIR="$HOME/.local/bin"
    SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
  fi
  VERSION_DIR="$APP_ROOT/$FERMATA_VERSION"
  MANIFEST="$APP_ROOT/$MANIFEST_NAME"
}

# Run a modifying command; through sudo for --system.
priv() {
  if ((SYSTEM)); then as_root "$@"; else "$@"; fi
}

# --- Temporary files ------------------------------------------------------------
WORK=""
INSTALL_STARTED=0
INSTALL_DONE=0

# shellcheck disable=SC2317  # invoked by the EXIT trap
cleanup() {
  local rc=$?
  if ((INSTALL_STARTED && !INSTALL_DONE)); then
    # Record what was already written so --uninstall can still remove it.
    if ((${#NEW_ENTRIES[@]})); then write_manifest merged >/dev/null 2>&1 || true; fi
    error "Installation did not complete. Run this installer again, or remove the partial installation with: $0 --uninstall$( ((SYSTEM)) && printf ' --system')"
  fi
  if [[ -n "$WORK" && -d "$WORK" ]]; then rm -rf -- "$WORK"; fi
  return "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

make_workdir() {
  [[ -n "$WORK" ]] && return 0
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/fermata-setup.XXXXXX")" || die "cannot create a temporary directory"
}

# --- Payload ----------------------------------------------------------------------
has_payload() { [[ "$PAYLOAD_SIZE" =~ ^[0-9]+$ ]]; }

sha256_of_stdin() {
  if have sha256sum; then sha256sum | cut -d' ' -f1
  elif have shasum; then shasum -a 256 | cut -d' ' -f1
  elif have openssl; then openssl dgst -sha256 -r | cut -d' ' -f1
  else return 1
  fi
}

verify_payload() {
  has_payload || die "This is the installer template from the source tree. Build dist/setup.sh with tool/package_linux.sh." "$EXIT_USAGE"
  [[ -r "$SELF" ]] || die "cannot read $SELF (run setup.sh as a file, not through a pipe)"
  local size actual
  size="$(wc -c <"$SELF" | tr -d ' ')"
  if ((size <= PAYLOAD_SIZE)); then
    die "The installer is truncated ($size bytes). Download setup.sh again." "$EXIT_INTEGRITY"
  fi
  actual="$(tail -c "$PAYLOAD_SIZE" -- "$SELF" | sha256_of_stdin)" \
    || die "no SHA-256 tool found (sha256sum, shasum or openssl)"
  if [[ "$actual" != "$PAYLOAD_SHA256" ]]; then
    error "Payload checksum mismatch: the installer is corrupt or was modified."
    info "expected $PAYLOAD_SHA256"
    info "actual   $actual"
    die "Download setup.sh again (and compare it with SHA256SUMS from the release)." "$EXIT_INTEGRITY"
  fi
  ok "Installer integrity verified (SHA-256)"
}

# extract_payload DIR [members...]
extract_payload() {
  local dir="$1"; shift
  mkdir -p -- "$dir"
  tail -c "$PAYLOAD_SIZE" -- "$SELF" | tar -xzf - --no-same-owner -C "$dir" "$@" \
    || die "could not extract the installer payload (disk full?)" "$EXIT_INTEGRITY"
}

# Extract the whole payload once into $WORK/payload.
PAYLOAD_DIR=""
unpack() {
  [[ -n "$PAYLOAD_DIR" ]] && return 0
  make_workdir
  PAYLOAD_DIR="$WORK/payload"
  extract_payload "$PAYLOAD_DIR"
  [[ -x "$PAYLOAD_DIR/$BIN_NAME" && -d "$PAYLOAD_DIR/lib" && -d "$PAYLOAD_DIR/data" ]] \
    || die "the payload does not contain a Fermata bundle" "$EXIT_INTEGRITY"
}

# --- Distribution detection -----------------------------------------------------
OS_ID=""; OS_LIKE=""; OS_NAME="unknown Linux"; FAMILY="unknown"; PKG_TOOL=""

detect_distro() {
  local f="${FERMATA_SETUP_OS_RELEASE:-/etc/os-release}" key value w
  [[ -r "$f" ]] || f="/usr/lib/os-release"
  if [[ -r "$f" ]]; then
    while IFS='=' read -r key value; do
      value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
      case "$key" in
        ID) OS_ID="$value" ;;
        ID_LIKE) OS_LIKE="$value" ;;
        PRETTY_NAME) OS_NAME="$value" ;;
      esac
    done <"$f"
  fi
  for w in "$OS_ID" $OS_LIKE; do
    case "$w" in
      debian|ubuntu|linuxmint|pop|elementary|zorin|kali|raspbian|neon|deepin|pureos|devuan|mx|tuxedo)
        FAMILY="debian"; PKG_TOOL="apt-get" ;;
      fedora|rhel|centos|rocky|almalinux|ol|nobara|ultramarine)
        FAMILY="fedora"; PKG_TOOL="dnf"; if ! have dnf && have yum; then PKG_TOOL="yum"; fi ;;
      arch|manjaro|endeavouros|garuda|cachyos|artix|arcolinux)
        FAMILY="arch"; PKG_TOOL="pacman" ;;
      suse|opensuse|opensuse-*|sles|sled)
        FAMILY="suse"; PKG_TOOL="zypper" ;;
      *) continue ;;
    esac
    break
  done
  # A test override describes another system: do not require its tools here.
  if [[ "$FAMILY" != unknown && -z "${FERMATA_SETUP_OS_RELEASE:-}" ]] && ! have "$PKG_TOOL"; then
    FAMILY="unknown"; PKG_TOOL=""
  fi
}

# --- Runtime libraries ------------------------------------------------------------
# kind|soname|alternative sonames|what it is for|Debian/Ubuntu|Fedora/RHEL|Arch|openSUSE
#   req: checked, needed to start/play   opt: checked, feature degrades
#   map: only used to name the package for a soname that ldd reports missing
# Debian/Ubuntu may list candidates (t64 renames): the first one apt knows wins.
# "soname()(64bit)" is an RPM capability: dnf/zypper install whatever provides it.
DEPS_TABLE="$(cat <<'EOF'
req|libgtk-3.so.0||GTK 3 (user interface)|libgtk-3-0t64 libgtk-3-0|gtk3|gtk3|libgtk-3-0
req|libepoxy.so.0||libepoxy (OpenGL loader)|libepoxy0|libepoxy|libepoxy|libepoxy0
req|libfontconfig.so.1||Fontconfig|libfontconfig1|fontconfig|fontconfig|libfontconfig1
req|libstdc++.so.6||C++ runtime|libstdc++6|libstdc++|gcc-libs|libstdc++6
req|libgcc_s.so.1||GCC runtime|libgcc-s1|libgcc|gcc-libs|libgcc_s1
req|libz.so.1||zlib|zlib1g|zlib|zlib|libz1
req|libX11.so.6||X11 client library (tray icon)|libx11-6|libX11|libx11|libX11-6
req|libXi.so.6||X11 input extension (tray icon)|libxi6|libXi|libxi|libXi6
req|libsecret-1.so.0||libsecret (sign-ins in the system keyring)|libsecret-1-0|libsecret|libsecret|libsecret-1-0
req|libkeybinder-3.0.so.0||keybinder (global hotkeys)|libkeybinder-3.0-0|keybinder3|libkeybinder3|libkeybinder-3.0.so.0()(64bit)
req|libmpv.so.2|libmpv.so.1 libmpv.so|libmpv (audio playback)|libmpv2 libmpv1|mpv-libs|mpv|libmpv.so.2()(64bit)
opt|libEGL.so.1||EGL (GPU rendering; without it Fermata renders in software)|libegl1|libglvnd-egl|libglvnd|libEGL1
map|libgdk-3.so.0||GTK 3|libgtk-3-0t64 libgtk-3-0|gtk3|gtk3|libgtk-3-0
map|libglib-2.0.so.0||GLib|libglib2.0-0t64 libglib2.0-0|glib2|glib2|libglib-2_0-0
map|libgio-2.0.so.0||GLib (GIO)|libglib2.0-0t64 libglib2.0-0|glib2|glib2|libgio-2_0-0
map|libgobject-2.0.so.0||GLib (GObject)|libglib2.0-0t64 libglib2.0-0|glib2|glib2|libgobject-2_0-0
map|libpango-1.0.so.0||Pango|libpango-1.0-0|pango|pango|libpango-1_0-0
map|libpangocairo-1.0.so.0||Pango|libpangocairo-1.0-0|pango|pango|libpango-1_0-0
map|libharfbuzz.so.0||HarfBuzz|libharfbuzz0b|harfbuzz|harfbuzz|libharfbuzz0
map|libatk-1.0.so.0||ATK|libatk1.0-0t64 libatk1.0-0|atk|at-spi2-core|libatk-1_0-0
map|libcairo.so.2||cairo|libcairo2|cairo|cairo|libcairo2
map|libcairo-gobject.so.2||cairo|libcairo-gobject2|cairo-gobject|cairo|libcairo-gobject2
map|libgdk_pixbuf-2.0.so.0||GdkPixbuf|libgdk-pixbuf-2.0-0|gdk-pixbuf2|gdk-pixbuf2|libgdk_pixbuf-2_0-0
map|libayatana-appindicator3.so.1||Ayatana AppIndicator (tray icon)|libayatana-appindicator3-1|libayatana-appindicator-gtk3|libayatana-appindicator|libayatana-appindicator3-1
EOF
)"

# Sonames ldd may legitimately report as missing: libdartjni.so (package:jni,
# unused on Linux) links libjvm.so, which is only loaded if Dart code calls JNI.
LDD_IGNORE=" libjvm.so "

LDCACHE=""
LDCACHE_LOADED=0
load_ldcache() {
  ((LDCACHE_LOADED)) && return 0
  LDCACHE_LOADED=1
  local ldc=""
  if have ldconfig; then ldc="ldconfig"
  elif [[ -x /sbin/ldconfig ]]; then ldc="/sbin/ldconfig"
  elif [[ -x /usr/sbin/ldconfig ]]; then ldc="/usr/sbin/ldconfig"
  fi
  if [[ -n "$ldc" ]]; then LDCACHE="$("$ldc" -p 2>/dev/null || true)"; fi
}

is_fake_missing() {
  local list=" ${FERMATA_SETUP_FAKE_MISSING:-} "
  list="${list//,/ }"
  [[ "$list" == *" $1 "* ]]
}

have_soname() {
  local so="$1" d
  is_fake_missing "$so" && return 1
  load_ldcache
  if [[ -n "$LDCACHE" ]]; then
    awk -v so="$so" '$1 == so && /x86-64/ { found = 1 } END { exit !found }' <<<"$LDCACHE" && return 0
  fi
  for d in /lib64 /usr/lib64 /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /usr/lib /lib /usr/local/lib; do
    [[ -e "$d/$so" ]] && return 0
  done
  return 1
}

# have_dep SONAME "ALTERNATIVES": prints the soname found. A soname faked
# missing (FERMATA_SETUP_FAKE_MISSING) hides its alternatives too.
have_dep() {
  local a
  if have_soname "$1"; then printf '%s\n' "$1"; return 0; fi
  is_fake_missing "$1" && return 1
  for a in $2; do
    if have_soname "$a"; then printf '%s\n' "$a"; return 0; fi
  done
  return 1
}

# Look up a table row by soname: sets ROW_* variables; 1 if unknown.
ROW_KIND=""; ROW_SO=""; ROW_ALTS=""; ROW_DEB=""; ROW_FED=""; ROW_ARCH=""; ROW_SUSE=""
find_row() {
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r ROW_KIND ROW_SO ROW_ALTS _ ROW_DEB ROW_FED ROW_ARCH ROW_SUSE <<<"$line"
    [[ "$ROW_SO" == "$1" ]] && return 0
  done <<<"$DEPS_TABLE"
  ROW_KIND=""; ROW_SO=""; ROW_ALTS=""; ROW_DEB=""; ROW_FED=""; ROW_ARCH=""; ROW_SUSE=""
  return 1
}

# Debian/Ubuntu: first candidate apt knows about (handles the t64 renames).
apt_pick() {
  local cand
  if have apt-cache; then
    for cand in "$@"; do
      if apt-cache show --no-all-versions "$cand" 2>/dev/null | grep -q '^Package:'; then
        printf '%s\n' "$cand"; return 0
      fi
    done
  fi
  printf '%s\n' "$1"
}

# Package that provides soname $1 on this distribution family ("" if unknown).
package_for() {
  local so="$1"
  if find_row "$so"; then
    case "$FAMILY" in
      debian) # shellcheck disable=SC2086
        apt_pick $ROW_DEB ;;
      fedora) printf '%s\n' "$ROW_FED" ;;
      arch) printf '%s\n' "$ROW_ARCH" ;;
      suse) printf '%s\n' "$ROW_SUSE" ;;
    esac
  else
    case "$FAMILY" in
      fedora|suse) printf '%s()(64bit)\n' "$so" ;;
    esac
  fi
}

MISSING_REQ=()   # sonames
MISSING_OPT=()
GLIBC_NEEDED=""
LDD_STATUS="not run"

# contains VALUE [LIST...] -> 0 if VALUE is one of LIST.
contains() {
  local x="$1" e
  shift
  for e in "$@"; do [[ "$e" == "$x" ]] && return 0; done
  return 1
}

# ldd every ELF file of the bundle; collect sonames reported "not found".
scan_bundle_with_ldd() {
  local dir="$1" f out line so v
  if ! have ldd; then LDD_STATUS="skipped (ldd not installed)"; return 0; fi
  LDD_STATUS="ok"
  for f in "$dir/$BIN_NAME" "$dir"/lib/*.so; do
    [[ -f "$f" ]] || continue
    out="$(ldd "$f" 2>&1)" || {
      if [[ "$out" == *"not a dynamic executable"* || "$out" == *"failed to map"* || "$out" == *"Permission denied"* ]]; then
        LDD_STATUS="skipped (cannot run ldd on files in ${TMPDIR:-/tmp}; noexec?)"
        return 0
      fi
    }
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+=\>[[:space:]]+not[[:space:]]found ]]; then
        so="${BASH_REMATCH[1]}"
        [[ "$LDD_IGNORE" == *" $so "* ]] && continue
        if find_row "$so" && [[ "$ROW_KIND" == opt ]]; then
          contains "$so" ${MISSING_OPT[@]+"${MISSING_OPT[@]}"} || MISSING_OPT+=("$so")
        else
          contains "$so" ${MISSING_REQ[@]+"${MISSING_REQ[@]}"} || MISSING_REQ+=("$so")
        fi
      elif [[ "$line" =~ version\ .GLIBC_([0-9.]+).\ not\ found ]]; then
        v="${BASH_REMATCH[1]}"
        if [[ -z "$GLIBC_NEEDED" ]] || [[ "$(printf '%s\n%s\n' "$GLIBC_NEEDED" "$v" | sort -V | tail -n1)" == "$v" ]]; then
          GLIBC_NEEDED="$v"
        fi
      fi
    done <<<"$out"
  done
}

# Prints the report; returns 0 if every required library is present.
check_runtime_deps() {
  local bundle_dir="${1:-}" line kind so alts label found
  MISSING_REQ=(); MISSING_OPT=(); GLIBC_NEEDED=""
  detect_distro
  step "Checking runtime libraries ($OS_NAME)"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r kind so alts label _ <<<"$line"
    [[ "$kind" == map ]] && continue
    if found="$(have_dep "$so" "$alts")"; then
      ok "$label ${C_DIM}($found)${C_OFF}"
    elif [[ "$kind" == opt ]]; then
      warn "optional: $label: $so not found"
      MISSING_OPT+=("$so")
    else
      printf '  %smissing%s %s %s(%s)%s\n' "$C_RED$C_BLD" "$C_OFF" "$label" "$C_DIM" "$so" "$C_OFF" >&2
      MISSING_REQ+=("$so")
    fi
  done <<<"$DEPS_TABLE"

  if [[ -n "$bundle_dir" ]]; then
    local before=${#MISSING_REQ[@]}
    scan_bundle_with_ldd "$bundle_dir"
    if [[ "$LDD_STATUS" == ok ]]; then
      if ((${#MISSING_REQ[@]} > before)); then
        warn "ldd reports more missing libraries: ${MISSING_REQ[*]:$before}"
      else
        ok "ldd: every library the bundle links against was found"
      fi
    else
      dim "ldd check $LDD_STATUS"
    fi
  fi
  if [[ -n "$GLIBC_NEEDED" ]]; then
    error "This build needs GNU C Library (glibc) $GLIBC_NEEDED or newer; your system has $(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')."
    info "Upgrade your distribution, or build Fermata from source (docs/BUILDING.md)."
  fi
  check_desktop_services
  [[ ${#MISSING_REQ[@]} -eq 0 && -z "$GLIBC_NEEDED" ]]
}

# Soft checks of D-Bus services (only possible inside a desktop session).
check_desktop_services() {
  have gdbus || return 0
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$EUID}/bus" ]] || return 0
  local tray secrets
  tray="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.NameHasOwner org.kde.StatusNotifierWatcher 2>/dev/null || true)"
  case "$tray" in
    "(true,)") ok "System tray (StatusNotifierItem host) available" ;;
    "(false,)")
      warn "No system tray host found in this session: Fermata's tray icon will be unavailable."
      info "Fermata still works; closing the window minimizes it instead of hiding it to the tray."
      if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
        info "On GNOME, install and enable the AppIndicator extension:"
        info "  package gnome-shell-extension-appindicator (Debian/Ubuntu/Fedora/Arch/openSUSE),"
        info "  then: gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com (log out and in)."
      fi ;;
  esac
  secrets="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListActivatableNames 2>/dev/null || true)"
  if [[ -n "$secrets" && "$secrets" != *"org.freedesktop.secrets"* ]]; then
    secrets="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.NameHasOwner org.freedesktop.secrets 2>/dev/null || true)"
    if [[ "$secrets" != "(true,)" ]]; then
      warn "No Secret Service (keyring) found: sign-ins to streaming services will not be remembered."
      info "Install gnome-keyring (or enable KeePassXC's Secret Service integration). Local playback is unaffected."
    fi
  fi
  return 0
}

# Offer to install the missing packages. Returns 0 if nothing required is missing afterwards.
resolve_missing_deps() {
  local so pkg pkgs=() unknown=() cmd=() display
  ((${#MISSING_REQ[@]} + ${#MISSING_OPT[@]})) || return 0
  [[ -z "$GLIBC_NEEDED" ]] || return 1

  if [[ "$FAMILY" == unknown ]]; then
    warn "Unknown distribution ($OS_NAME): install the packages that provide these libraries:"
    for so in ${MISSING_REQ[@]+"${MISSING_REQ[@]}"}; do info "  $so  (required)"; done
    for so in ${MISSING_OPT[@]+"${MISSING_OPT[@]}"}; do info "  $so  (optional)"; done
    info "libmpv: libmpv.so.2 or libmpv.so.1 (usually in a package named libmpv2, mpv-libs or mpv)."
    return 1
  fi

  for so in ${MISSING_REQ[@]+"${MISSING_REQ[@]}"} ${MISSING_OPT[@]+"${MISSING_OPT[@]}"}; do
    pkg="$(package_for "$so")"
    if [[ -z "$pkg" ]]; then unknown+=("$so")
    elif ! contains "$pkg" ${pkgs[@]+"${pkgs[@]}"}; then pkgs+=("$pkg"); fi
  done
  if ((${#unknown[@]})); then
    warn "No known package for: ${unknown[*]} (install the package that provides them)."
  fi
  ((${#pkgs[@]})) || return 1

  case "$FAMILY" in
    debian) cmd=(apt-get install); display="apt install" ;;
    fedora) cmd=("$PKG_TOOL" install); display="$PKG_TOOL install" ;;
    arch) cmd=(pacman -S --needed); display="pacman -S --needed" ;;
    suse) cmd=(zypper install); display="zypper install" ;;
  esac
  ((EUID == 0)) || display="sudo $display"
  step "Missing packages for $OS_NAME"
  info "$display $(show_cmd "${pkgs[@]}")"
  case "$OS_ID" in
    rhel|centos|rocky|almalinux|ol)
      note "mpv-libs and keybinder3 come from EPEL and RPM Fusion; enable those repositories first." ;;
  esac
  if [[ -n "${FERMATA_SETUP_OS_RELEASE:-}" ]]; then
    note "FERMATA_SETUP_OS_RELEASE is set (simulated system): not running the package manager."
    return 1
  fi
  if ! confirm "Install them now with $( ((EUID == 0)) && printf '%s' "$PKG_TOOL" || printf 'sudo %s' "$PKG_TOOL")?"; then
    info "Skipped. Install them later with the command above."
    return 1
  fi
  if ((ASSUME_YES)); then
    case "$FAMILY" in
      debian|fedora) cmd+=(-y) ;;
      arch) cmd+=(--noconfirm) ;;
      suse) cmd=(zypper --non-interactive install) ;;
    esac
  fi
  if ! as_root "${cmd[@]}" "${pkgs[@]}"; then
    if [[ "$FAMILY" == debian ]]; then
      info "Refreshing the package lists and retrying..."
      if ! { as_root apt-get update && as_root "${cmd[@]}" "${pkgs[@]}"; }; then
        error "Package installation failed."; return 1
      fi
    else
      error "Package installation failed."; return 1
    fi
  fi
  LDCACHE_LOADED=0
  local still=()
  for so in ${MISSING_REQ[@]+"${MISSING_REQ[@]}"}; do
    find_row "$so" || true
    have_dep "$so" "$ROW_ALTS" >/dev/null || still+=("$so")
  done
  if ((${#still[@]})); then
    warn "Still missing after installing packages: ${still[*]}"
    return 1
  fi
  ok "Runtime libraries installed"
  return 0
}

# --- Install ----------------------------------------------------------------------
NEW_ENTRIES=()     # "type path"
OLD_ENTRIES=()
OLD_VERSION=""

add_entry() { contains "$1 $2" ${NEW_ENTRIES[@]+"${NEW_ENTRIES[@]}"} || NEW_ENTRIES+=("$1 $2"); }

load_old_manifest() {
  OLD_ENTRIES=(); OLD_VERSION=""
  [[ -f "$MANIFEST" ]] || return 0
  if [[ "$(head -n1 "$MANIFEST")" != "$MANIFEST_MAGIC" ]]; then
    warn "Ignoring unreadable manifest $MANIFEST"
    return 0
  fi
  OLD_VERSION="$(manifest_get "$MANIFEST" version)"
  local line
  while IFS= read -r line; do
    case "$line" in [tfld]\ /*) OLD_ENTRIES+=("$line") ;; esac
  done <"$MANIFEST"
}

# write_manifest [merged]: merged = old + new entries (used after a failure).
write_manifest() {
  local tmp entry
  make_workdir
  tmp="$WORK/manifest.new"
  {
    printf '%s\n' "$MANIFEST_MAGIC"
    printf '# version=%s\n' "$FERMATA_VERSION"
    printf '# mode=%s\n' "$( ((SYSTEM)) && printf system || printf user)"
    printf '# app_root=%s\n' "$APP_ROOT"
    printf '# bin_dir=%s\n' "$BIN_DIR"
    printf '# share_dir=%s\n' "$SHARE_DIR"
    printf '# installed=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for entry in ${NEW_ENTRIES[@]+"${NEW_ENTRIES[@]}"}; do printf '%s\n' "$entry"; done
    if [[ "${1:-}" == merged ]]; then
      for entry in ${OLD_ENTRIES[@]+"${OLD_ENTRIES[@]}"}; do printf '%s\n' "$entry"; done
    fi
  } | awk '!seen[$0]++' >"$tmp"
  priv install -m 0644 "$tmp" "$MANIFEST"
}

# mkdir -p that records each directory it creates.
ensure_dir() {
  local p="$1" created=()
  while [[ ! -d "$p" ]]; do created+=("$p"); p="$(dirname -- "$p")"; done
  ((${#created[@]})) || return 0
  priv mkdir -p -- "$1"
  for p in "${created[@]}"; do add_entry d "$p"; done
}

install_file() { # install_file MODE SRC DST
  ensure_dir "$(dirname -- "$3")"
  priv install -m "$1" -- "$2" "$3"
  add_entry f "$3"
}

# Exec=/TryExec= of the desktop entry -> absolute path of the installed binary.
render_desktop_file() { # SRC DST EXE
  local src="$1" dst="$2" exe="$3" qexe line
  if [[ "$exe" =~ ^[A-Za-z0-9/._+-]+$ ]]; then
    qexe="$exe"
  else # Desktop Entry spec quoting, then key-file escaping of backslashes.
    qexe="$exe"; qexe="${qexe//\\/\\\\}"; qexe="${qexe//\"/\\\"}"; qexe="${qexe//\`/\\\`}"; qexe="${qexe//\$/\\\$}"
    qexe="\"$qexe\""; qexe="${qexe//\\/\\\\}"
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "Exec=$BIN_NAME") line="Exec=$qexe" ;;
      "Exec=$BIN_NAME "*) line="Exec=$qexe ${line#"Exec=$BIN_NAME "}" ;;
      TryExec=*) line="TryExec=$exe" ;;
    esac
    printf '%s\n' "$line"
  done <"$src" >"$dst"
}

# An autostart entry written by an older version may point at a versioned
# directory that the upgrade removes; point it at the stable "current" path.
fix_autostart_entry() {
  local f="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/$APP_ID.desktop" tmp line changed=0
  [[ -f "$f" && -w "$f" ]] || return 0
  tmp="$f.fermata-setup.$$"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^Exec=(\"?)"$APP_ROOT"/([^/\"]+)/"$BIN_NAME"(\"?)(.*)$ && "${BASH_REMATCH[2]}" != current ]]; then
      line="Exec=${BASH_REMATCH[1]}$APP_ROOT/current/$BIN_NAME${BASH_REMATCH[3]}${BASH_REMATCH[4]}"; changed=1
    fi
    printf '%s\n' "$line"
  done <"$f" >"$tmp"
  if ((changed)); then mv -f -- "$tmp" "$f"; note "Updated the autostart entry to $APP_ROOT/current/$BIN_NAME"; else rm -f -- "$tmp"; fi
}

remove_old_entry() { # "type path"
  local type="${1%% *}" path="${1#* }"
  if ! is_owned_path "$path" "$APP_ROOT" "$BIN_DIR" "$SHARE_DIR"; then
    warn "not removing $path (outside the installation)"; return 0
  fi
  case "$type" in
    t) [[ "$path" == "$APP_ROOT"/?* ]] && priv rm -rf -- "$path" ;;
    f|l) priv rm -f -- "$path" ;;
  esac
  return 0
}

do_install() {
  local other_root pids exe in_use=() entry type path keep e

  set_locations
  verify_payload
  unpack

  if ((SYSTEM)); then
    step "Installing Fermata $FERMATA_VERSION for all users"
    info "into $APP_ROOT, $BIN_DIR/$BIN_NAME and $SHARE_DIR"
    if ((EUID != 0)); then
      note "Writing there needs administrator rights: sudo will ask for your password for the copy steps."
    fi
  else
    if ((EUID == 0)); then
      if [[ -n "${SUDO_USER:-}" ]]; then
        warn "setup.sh is running through sudo, so it would install Fermata for root ($HOME)."
        info "Run it without sudo to install for yourself, or with --system for all users."
        confirm "Install for the root user anyway?" || exit "$EXIT_ABORTED"
      else
        note "Running as root without --system: installing for the root user only ($HOME)."
      fi
    fi
    step "Installing Fermata $FERMATA_VERSION for $(id -un 2>/dev/null || echo "$USER")"
    info "into $APP_ROOT"
  fi

  if ((CHECK_DEPS)); then
    if ! check_runtime_deps "$PAYLOAD_DIR"; then
      if ! resolve_missing_deps; then
        if [[ -n "$GLIBC_NEEDED" ]]; then die "Fermata cannot run on this system (glibc too old)." "$EXIT_MISSING_DEPS"; fi
        if [[ "${MISSING_REQ[*]}" == libmpv.so.2 ]]; then
          warn "Fermata starts, but cannot play audio until libmpv is installed."
        else
          warn "Fermata will not start until the missing libraries above are installed."
        fi
        confirm "Install Fermata anyway?" || exit "$EXIT_MISSING_DEPS"
      fi
    elif ((${#MISSING_OPT[@]})); then
      resolve_missing_deps || true
    fi
  else
    note "Skipping the runtime library check (--no-deps)"
  fi

  if ((SYSTEM)); then other_root="$HOME/.local/lib/fermata"; else other_root="/opt/fermata"; fi
  if [[ -f "$other_root/$MANIFEST_NAME" ]]; then
    note "Another Fermata installation exists in $other_root ($(manifest_get "$other_root/$MANIFEST_NAME" version)); the per-user one takes precedence in menus."
  fi

  load_old_manifest
  if [[ -n "$OLD_VERSION" ]]; then
    if [[ "$OLD_VERSION" == "$FERMATA_VERSION" ]]; then step "Reinstalling Fermata $FERMATA_VERSION"
    elif [[ "$(printf '%s\n%s\n' "$OLD_VERSION" "$FERMATA_VERSION" | sort -V | tail -n1)" == "$FERMATA_VERSION" ]]; then
      step "Upgrading Fermata $OLD_VERSION -> $FERMATA_VERSION (your data and settings are kept)"
    else
      warn "Replacing the newer Fermata $OLD_VERSION with $FERMATA_VERSION (downgrade)."
    fi
  fi

  pids="$(running_pids_under "$APP_ROOT")"
  if [[ -n "$pids" ]]; then
    warn "Fermata is running (PID $pids). Quit it (tray icon or app menu -> Quit) before upgrading."
    confirm "Continue anyway? The running copy keeps working; the new version is used from its next start" \
      || exit "$EXIT_ABORTED"
  fi

  # From here on, files are being modified.
  INSTALL_STARTED=1
  ensure_dir "$APP_ROOT"

  local staging="$APP_ROOT/.staging-$FERMATA_VERSION.$$" replaced=""
  priv rm -rf -- "$staging"
  priv mkdir -p -- "$staging"
  priv cp -R -- "$PAYLOAD_DIR/$BIN_NAME" "$PAYLOAD_DIR/lib" "$PAYLOAD_DIR/data" "$staging/"
  priv chmod -R u+rwX,go+rX,go-w -- "$staging"
  if [[ -e "$VERSION_DIR" ]]; then
    replaced="$APP_ROOT/.replaced-$FERMATA_VERSION.$$"
    priv mv -- "$VERSION_DIR" "$replaced"
  fi
  priv mv -- "$staging" "$VERSION_DIR"
  add_entry t "$VERSION_DIR"
  priv ln -sfn -- "$FERMATA_VERSION" "$APP_ROOT/current"
  add_entry l "$APP_ROOT/current"
  ok "Application: $VERSION_DIR"

  exe="$APP_ROOT/current/$BIN_NAME"

  # Launcher on PATH (never overwrite a file that is not ours).
  local launcher="$BIN_DIR/$BIN_NAME" ours=0
  if [[ -L "$launcher" ]]; then
    case "$(readlink -- "$launcher")" in "$APP_ROOT"/*) ours=1 ;; esac
  fi
  for entry in ${OLD_ENTRIES[@]+"${OLD_ENTRIES[@]}"}; do [[ "$entry" == "l $launcher" ]] && ours=1; done
  if [[ -e "$launcher" || -L "$launcher" ]] && ((ours == 0)); then
    warn "$launcher already exists and is not Fermata's launcher: leaving it alone."
    info "Start Fermata from the application menu or with $exe"
  else
    ensure_dir "$BIN_DIR"
    priv ln -sfn -- "$exe" "$launcher"
    add_entry l "$launcher"
    ok "Launcher: $launcher"
  fi

  # Desktop entry, AppStream metadata, icons.
  local src_desktop="$PAYLOAD_DIR/share/applications/$APP_ID.desktop"
  if [[ -f "$src_desktop" ]]; then
    render_desktop_file "$src_desktop" "$WORK/$APP_ID.desktop" "$exe"
    install_file 0644 "$WORK/$APP_ID.desktop" "$SHARE_DIR/applications/$APP_ID.desktop"
    ok "Desktop entry: $SHARE_DIR/applications/$APP_ID.desktop"
  else
    warn "The installer has no desktop entry; Fermata will not appear in the application menu."
  fi
  if [[ -f "$PAYLOAD_DIR/share/metainfo/$APP_ID.metainfo.xml" ]]; then
    install_file 0644 "$PAYLOAD_DIR/share/metainfo/$APP_ID.metainfo.xml" "$SHARE_DIR/metainfo/$APP_ID.metainfo.xml"
    ok "AppStream metadata: $SHARE_DIR/metainfo/$APP_ID.metainfo.xml"
  fi
  local icon rel n=0
  if [[ -d "$PAYLOAD_DIR/share/icons/hicolor" ]]; then
    while IFS= read -r -d '' icon; do
      rel="${icon#"$PAYLOAD_DIR/share/icons/hicolor/"}"
      install_file 0644 "$icon" "$SHARE_DIR/icons/hicolor/$rel"
      n=$((n + 1))
    done < <(find "$PAYLOAD_DIR/share/icons/hicolor" -type f \( -name "$APP_ID.*" -o -name "$APP_ID-symbolic.*" \) -print0 | sort -z)
  fi
  if ((n)); then ok "Icons: $n file(s) in $SHARE_DIR/icons/hicolor"; else warn "The installer contains no icons."; fi

  # Uninstaller.
  install_file 0755 "$PAYLOAD_DIR/share/fermata/uninstall.sh" "$APP_ROOT/uninstall.sh"

  # Upgrade: remove what the previous version installed and this one does not.
  for entry in ${OLD_ENTRIES[@]+"${OLD_ENTRIES[@]}"}; do
    type="${entry%% *}"; path="${entry#* }"
    keep=0
    for e in "${NEW_ENTRIES[@]}"; do [[ "${e#* }" == "$path" ]] && keep=1 && break; done
    ((keep)) && continue
    if [[ "$type" == d ]]; then add_entry d "$path"; continue; fi
    if [[ "$type" == t && -n "$(running_pids_under "$path")" ]]; then
      in_use+=("$path"); add_entry t "$path"; continue
    fi
    remove_old_entry "$entry"
  done
  if [[ -n "$replaced" ]]; then
    if [[ -n "$(running_pids_under "$replaced")" ]]; then in_use+=("$replaced"); add_entry t "$replaced"
    else priv rm -rf -- "$replaced"; fi
  fi
  if ((${#in_use[@]})); then
    note "Kept ${in_use[*]} because Fermata is running from it; it is removed by the next upgrade or uninstall."
  fi

  write_manifest
  INSTALL_DONE=1
  fix_autostart_entry || true
  refresh_desktop_caches "$SHARE_DIR" "$( ((SYSTEM)) && printf as_root)"

  step "Fermata $FERMATA_VERSION is installed"
  info "Start it from your application menu, or run: $( [[ -L "$launcher" ]] && printf '%s' "$BIN_NAME" || printf '%s' "$exe")"
  if [[ -L "$launcher" && ":$PATH:" != *":$BIN_DIR:"* ]]; then
    note "$BIN_DIR is not on your PATH. Add it (e.g. in ~/.profile): export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
  info "Uninstall: $APP_ROOT/uninstall.sh   (or: ./setup.sh --uninstall$( ((SYSTEM)) && printf ' --system'))"
}

# --- Uninstall --------------------------------------------------------------------
do_uninstall() {
  local root="" args=() user_root sys_root
  user_root="$HOME/.local/lib/fermata"; sys_root="/opt/fermata"
  if ((SYSTEM)); then root="$sys_root"
  elif [[ -f "$user_root/$MANIFEST_NAME" ]]; then root="$user_root"
  elif [[ -f "$sys_root/$MANIFEST_NAME" ]]; then
    root="$sys_root"; note "No per-user installation found; using the system-wide one in $sys_root."
  fi
  ((PURGE)) && args+=(--purge)
  ((ASSUME_YES)) && args+=(--yes)
  [[ -z "${C_OFF}" ]] && args+=(--no-color)

  if [[ -z "$root" || ! -f "$root/$MANIFEST_NAME" ]]; then
    if ((PURGE)); then
      note "Fermata is not installed${root:+ in $root}; only your data can be removed."
      [[ -n "$root" ]] || root="$user_root"
    else
      die "Fermata is not installed (no $MANIFEST_NAME in $user_root or $sys_root)." "$EXIT_NOT_INSTALLED"
    fi
  fi
  if [[ -x "$root/uninstall.sh" ]]; then
    exec bash "$root/uninstall.sh" ${args[@]+"${args[@]}"}
  fi
  # No (or a damaged) uninstaller next to the manifest: use the one in this payload.
  verify_payload
  make_workdir
  extract_payload "$WORK/u" ./share/fermata/uninstall.sh
  bash "$WORK/u/share/fermata/uninstall.sh" --manifest "$root/$MANIFEST_NAME" ${args[@]+"${args[@]}"}
}

# --- Other modes ------------------------------------------------------------------
do_check() {
  local rc=0
  if has_payload; then
    verify_payload
    make_workdir
    extract_payload "$WORK/check" ./"$BIN_NAME" ./lib
    check_runtime_deps "$WORK/check" || rc=$?
  else
    check_runtime_deps "" || rc=$?
  fi
  if ((rc)); then
    step "Some required libraries are missing"
    print_install_hint
    exit "$EXIT_MISSING_DEPS"
  fi
  step "All required runtime libraries are present"
}

print_install_hint() {
  local so pkg pkgs=()
  [[ -z "$GLIBC_NEEDED" ]] || return 0
  if [[ "$FAMILY" == unknown ]]; then
    info "Install the packages that provide: ${MISSING_REQ[*]}"
    return 0
  fi
  for so in "${MISSING_REQ[@]}"; do
    pkg="$(package_for "$so")"
    if [[ -n "$pkg" ]] && ! contains "$pkg" ${pkgs[@]+"${pkgs[@]}"}; then pkgs+=("$pkg"); fi
  done
  ((${#pkgs[@]})) || return 0
  case "$FAMILY" in
    debian) info "sudo apt install $(show_cmd "${pkgs[@]}")" ;;
    fedora) info "sudo $PKG_TOOL install $(show_cmd "${pkgs[@]}")" ;;
    arch) info "sudo pacman -S --needed $(show_cmd "${pkgs[@]}")" ;;
    suse) info "sudo zypper install $(show_cmd "${pkgs[@]}")" ;;
  esac
  info "or run ./setup.sh, which offers to install them."
}

do_extract() {
  local dir="$EXTRACT_DIR"
  verify_payload
  if [[ -d "$dir" && -n "$(ls -A -- "$dir" 2>/dev/null)" ]]; then
    dir="$dir/fermata-$FERMATA_VERSION"
    [[ ! -e "$dir" ]] || die "$dir already exists" "$EXIT_USAGE"
  fi
  extract_payload "$dir"
  rm -f -- "$dir/share/fermata/uninstall.sh"
  rmdir -- "$dir/share/fermata" 2>/dev/null || true
  dir="$(readlink -f -- "$dir")"
  step "Extracted Fermata $FERMATA_VERSION to $dir"
  info "Run: $dir/$BIN_NAME"
  info "Check the runtime libraries with: $0 --check"
}

main() {
  parse_args "$@"
  case "$MODE" in
    help) usage; exit 0 ;;
    version) printf 'Fermata %s (Linux x86_64 installer)\n' "$FERMATA_VERSION"; exit 0 ;;
  esac
  if [[ "$(uname -m)" != x86_64 && "$MODE" != uninstall ]]; then
    die "This build of Fermata is for x86_64; this machine is $(uname -m)."
  fi
  case "$MODE" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    check) do_check ;;
    extract) do_extract ;;
  esac
}

main "$@"; exit $?
# Everything below this line is the payload (binary data).
