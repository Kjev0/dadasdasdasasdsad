# shellcheck shell=bash
# shellcheck disable=SC2034  # constants are used by the scripts that include this file
# Shared helpers for the Fermata Linux installer (setup.sh) and uninstaller
# (uninstall.sh). tool/package_linux.sh inlines this file into both scripts
# (between the "inline lib/common.sh" markers) so the shipped scripts are
# self-contained; from a source checkout they source it instead.
#
# Requires bash >= 4.0. Avoids bash 4.2+ features ([[ -v ]], declare -n,
# ${x@Q}, mapfile -d) and empty-array expansion under `set -u`.

APP_ID="app.fermata.player"
BIN_NAME="fermata"
MANIFEST_NAME="install-manifest"
MANIFEST_MAGIC="# fermata-install-manifest 1"

# Exit codes shared by setup.sh and uninstall.sh (documented in --help).
EXIT_OK=0
EXIT_ERROR=1
EXIT_USAGE=2
EXIT_INTEGRITY=3
EXIT_MISSING_DEPS=4
EXIT_NOT_INSTALLED=5
EXIT_ABORTED=6

ASSUME_YES=0

# --- Output -------------------------------------------------------------------
setup_colors() {
  if [[ -z "${NO_COLOR:-}" && "${FERMATA_SETUP_COLOR:-auto}" != never && -t 2 ]]; then
    C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_BLU=$'\e[34m'
    C_BLD=$'\e[1m'; C_DIM=$'\e[2m'; C_OFF=$'\e[0m'
  else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_BLD=''; C_DIM=''; C_OFF=''
  fi
}
setup_colors

# All messages go to stderr so stdout stays clean for machine use (--version).
step()  { printf '%s==>%s %s%s%s\n' "$C_BLU$C_BLD" "$C_OFF" "$C_BLD" "$*" "$C_OFF" >&2; }
info()  { printf '    %s\n' "$*" >&2; }
ok()    { printf '  %sok%s  %s\n' "$C_GRN" "$C_OFF" "$*" >&2; }
note()  { printf '  %snote:%s %s\n' "$C_BLU" "$C_OFF" "$*" >&2; }
warn()  { printf '%swarning:%s %s\n' "$C_YEL$C_BLD" "$C_OFF" "$*" >&2; }
error() { printf '%serror:%s %s\n' "$C_RED$C_BLD" "$C_OFF" "$*" >&2; }
die()   { error "$1"; exit "${2:-$EXIT_ERROR}"; }
dim()   { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_OFF" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# confirm "Question?" -> 0 for yes. Default is No. --yes answers yes. Reads the
# answer from stdin; EOF (e.g. stdin is /dev/null) counts as No.
confirm() {
  local answer=""
  if ((ASSUME_YES)); then
    printf '%s?%s %s [y/N] %syes (--yes)%s\n' "$C_YEL$C_BLD" "$C_OFF" "$1" "$C_DIM" "$C_OFF" >&2
    return 0
  fi
  printf '%s?%s %s [y/N] ' "$C_YEL$C_BLD" "$C_OFF" "$1" >&2
  if ! IFS= read -r answer; then
    printf '\n' >&2
    dim "(no answer on stdin: treated as No; use --yes for unattended runs)"
    return 1
  fi
  case "$answer" in
    [yY]|[yY][eE][sS]|[jJ]|[jJ][aA]) return 0 ;;
    *) return 1 ;;
  esac
}

# Quote a command for display.
show_cmd() {
  local out="" arg
  for arg in "$@"; do
    if [[ "$arg" =~ ^[A-Za-z0-9_./:=@+,-]+$ ]]; then out+="$arg "; else out+="'${arg//\'/\'\\\'\'}' "; fi
  done
  printf '%s' "${out% }"
}

# Run a command as root: directly when already root, else through sudo.
as_root() {
  if ((EUID == 0)); then
    "$@"
  elif have sudo; then
    sudo -- "$@"
  else
    error "administrator rights needed for: $(show_cmd "$@")"
    error "sudo is not installed; run this script as root instead."
    return 1
  fi
}

# Home directory of the user who invoked us (the real user under sudo).
invoking_user_home() {
  local h=""
  if ((EUID == 0)) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]] && have getent; then
    h="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  fi
  printf '%s\n' "${h:-$HOME}"
}

# --- Running instances ----------------------------------------------------------
# PIDs (of processes we may inspect) whose executable lives under directory $1.
running_pids_under() {
  local root="$1" exe pid pids=""
  root="$(readlink -f "$root" 2>/dev/null || printf '%s' "$root")"
  for exe in /proc/[0-9]*/exe; do
    pid="${exe#/proc/}"; pid="${pid%/exe}"
    [[ "$pid" == "$$" ]] && continue
    exe="$(readlink "$exe" 2>/dev/null)" || continue
    exe="${exe% (deleted)}"
    case "$exe" in "$root"/*) pids+="$pid " ;; esac
  done
  printf '%s' "${pids% }"
}

# --- Manifest -------------------------------------------------------------------
# One entry per line, "<type> <absolute path>":
#   t  directory tree we own completely (an installed version), removed recursively
#   f  file we installed          l  symlink we installed
#   d  directory we created; removed only if empty
# Header lines "# key=value" carry version, mode and the install locations.
manifest_get() { # manifest_get FILE KEY
  sed -n "s/^# $2=//p" "$1" | head -n1
}

# Is $1 a path the installer could legitimately have created for the
# installation rooted at app_root=$2 / bin_dir=$3 / share_dir=$4? Guards every
# removal against a damaged or edited manifest.
is_owned_path() {
  local p="$1" app_root="$2" bin_dir="$3" share_dir="$4"
  [[ "$p" == /* && "$p" != *"/../"* && "$p" != *"/./"* && "$p" != */.. ]] || return 1
  case "$p" in
    "$app_root"/?*) return 0 ;;
    "$bin_dir/$BIN_NAME") return 0 ;;
    "$share_dir/applications/$APP_ID.desktop") return 0 ;;
    "$share_dir/metainfo/$APP_ID.metainfo.xml") return 0 ;;
    "$share_dir/icons/hicolor/"*"/apps/$APP_ID".png) return 0 ;;
    "$share_dir/icons/hicolor/"*"/apps/$APP_ID".svg) return 0 ;;
    "$share_dir/icons/hicolor/"*"/apps/$APP_ID-symbolic".svg) return 0 ;;
  esac
  return 1
}

# Directories ("d" entries, only ever removed with rmdir when empty) may be the
# install roots, their parents (e.g. ~/.local/lib) or directories below the
# share root - never "/" or $HOME itself.
is_owned_dir() {
  local p="$1" app_root="$2" bin_dir="$3" share_dir="$4" r
  [[ "$p" == /?* && "$p" != *"/../"* && "$p" != */.. && "$p" != */ ]] || return 1
  [[ -z "${HOME:-}" || "$p" != "${HOME%/}" ]] || return 1
  case "$p" in "$share_dir"/?*) return 0 ;; esac
  for r in "$app_root" "$bin_dir" "$share_dir"; do
    [[ "$r/" == "$p/"* ]] && return 0
  done
  return 1
}

# Refresh desktop/icon caches; never fails.
refresh_desktop_caches() { # refresh_desktop_caches SHARE_DIR [as_root]
  local share="$1" runner=() d
  if [[ "${2:-}" == as_root ]]; then runner=(as_root); fi
  d="$share/applications"
  if [[ -d "$d" ]] && have update-desktop-database; then
    ${runner[@]+"${runner[@]}"} update-desktop-database -q "$d" >/dev/null 2>&1 || true
  fi
  d="$share/icons/hicolor"
  if [[ -d "$d" ]]; then
    ${runner[@]+"${runner[@]}"} touch "$d" 2>/dev/null || true
    if have gtk-update-icon-cache; then
      ${runner[@]+"${runner[@]}"} gtk-update-icon-cache -q -t -f "$d" >/dev/null 2>&1 || true
    fi
  fi
  return 0
}
