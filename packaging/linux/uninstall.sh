#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
#
# Fermata for Linux: uninstaller.
#
# setup.sh installs a copy of this script next to the install manifest
# (~/.local/lib/fermata/uninstall.sh or /opt/fermata/uninstall.sh). It removes
# exactly the files listed in the manifest. Your data (library database,
# settings, cache, sign-ins) is only removed with --purge, after confirmation.

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "The Fermata uninstaller needs bash 4 or newer (found ${BASH_VERSION})." >&2
  exit 1
fi
set -euo pipefail

# >>> inline lib/common.sh >>>
# shellcheck source=lib/common.sh
. "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/lib/common.sh"
# <<< inline lib/common.sh <<<

SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--purge] [--yes] [--manifest FILE]

Removes Fermata (only the files its installer created). Your library,
settings, cache and sign-ins are kept unless --purge is given.

Options:
  --purge          Also delete your Fermata data, after confirmation:
                     ~/.local/share/app.fermata.player   (library, settings, logs)
                     ~/.cache/app.fermata.player         (artwork, partial downloads)
                     ~/.config/autostart/app.fermata.player.desktop
                     the sign-in tokens stored in your keyring
                   Music you downloaded to ~/Music/Fermata is never deleted.
  -y, --yes        Do not ask questions (with --purge: delete without asking).
  --manifest FILE  Install manifest to use (default: next to this script).
  -h, --help       Show this help.

Exit codes: 0 removed, 1 error, 2 usage, 5 not installed, 6 cancelled.
EOF
}

PURGE=0
REMOVE_ONLY=0
MANIFEST=""

while (($#)); do
  case "$1" in
    --purge) PURGE=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    --manifest) [[ $# -ge 2 ]] || die "--manifest needs a file" "$EXIT_USAGE"; MANIFEST="$2"; shift ;;
    --manifest=*) MANIFEST="${1#*=}" ;;
    --no-color) FERMATA_SETUP_COLOR=never; setup_colors ;;
    --remove-only) REMOVE_ONLY=1 ;; # internal: privileged part of a system uninstall
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" "$EXIT_USAGE" ;;
  esac
  shift
done
[[ -n "$MANIFEST" ]] || MANIFEST="$(dirname -- "$SELF")/$MANIFEST_NAME"

# --- Manifest -----------------------------------------------------------------------
INSTALLED=0
VERSION=""; INSTALL_MODE=""; APP_ROOT=""; BIN_DIR=""; SHARE_DIR=""
if [[ -f "$MANIFEST" ]]; then
  [[ "$(head -n1 "$MANIFEST")" == "$MANIFEST_MAGIC" ]] || die "$MANIFEST is not a Fermata install manifest"
  VERSION="$(manifest_get "$MANIFEST" version)"
  INSTALL_MODE="$(manifest_get "$MANIFEST" mode)"
  APP_ROOT="$(manifest_get "$MANIFEST" app_root)"
  BIN_DIR="$(manifest_get "$MANIFEST" bin_dir)"
  SHARE_DIR="$(manifest_get "$MANIFEST" share_dir)"
  [[ "$APP_ROOT" == /?*/?* && -n "$BIN_DIR" && -n "$SHARE_DIR" ]] || die "$MANIFEST is damaged (bad install locations)"
  [[ "$(readlink -f -- "$MANIFEST")" == "$(readlink -f -- "$APP_ROOT")/$MANIFEST_NAME" ]] \
    || die "$MANIFEST does not belong to the installation in $APP_ROOT"
  INSTALLED=1
fi

# --- User data (--purge) -------------------------------------------------------------
USER_HOME="$(invoking_user_home)"
if ((EUID == 0)) && [[ "$USER_HOME" != "$HOME" ]]; then
  # Under sudo the XDG_* variables are root's: use the defaults of the real user.
  DATA_DIR="$USER_HOME/.local/share/$APP_ID"
  CACHE_DIR="$USER_HOME/.cache/$APP_ID"
  AUTOSTART="$USER_HOME/.config/autostart/$APP_ID.desktop"
else
  DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_ID"
  CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$APP_ID"
  AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/$APP_ID.desktop"
fi
KEYRING_ACCOUNT="$APP_ID.secureStorage" # flutter_secure_storage_linux: account=<APPLICATION_ID>.secureStorage

purge_targets() {
  local p
  for p in "$DATA_DIR" "$CACHE_DIR" "$AUTOSTART"; do
    [[ -e "$p" || -L "$p" ]] && printf '%s\n' "$p"
  done
  return 0
}

confirm_purge() {
  local targets size p
  targets="$(purge_targets)"
  step "Your Fermata data"
  if [[ -n "$targets" ]]; then
    while IFS= read -r p; do
      size="$(du -sh -- "$p" 2>/dev/null | cut -f1)"
      info "$p ${size:+($size)}"
    done <<<"$targets"
  fi
  have secret-tool && ((EUID != 0)) && info "sign-in tokens in your keyring (account $KEYRING_ACCOUNT)"
  if [[ -d "$USER_HOME/Music/Fermata" ]]; then
    note "Downloaded music in $USER_HOME/Music/Fermata is NOT deleted."
  fi
  warn "This permanently deletes your Fermata library database, playlists, settings and cache."
  confirm "Delete your Fermata data?"
}

do_purge() {
  local p
  for p in "$DATA_DIR" "$CACHE_DIR"; do
    if [[ -e "$p" ]]; then rm -rf -- "$p"; ok "Deleted $p"; fi
  done
  if [[ -e "$AUTOSTART" || -L "$AUTOSTART" ]]; then rm -f -- "$AUTOSTART"; ok "Deleted $AUTOSTART"; fi
  if ((EUID != 0)) && have secret-tool; then
    if timeout 10 secret-tool clear account "$KEYRING_ACCOUNT" >/dev/null 2>&1; then
      ok "Removed stored sign-ins from the keyring"
    else
      dim "No sign-ins in the keyring (or the keyring is locked/unavailable)."
    fi
  fi
}

# The autostart entry Fermata writes ("Start on login") would point at a
# program that no longer exists: remove it when it points at this install.
remove_dangling_autostart() {
  [[ -f "$AUTOSTART" && -n "$APP_ROOT" ]] || return 0
  local line exe
  line="$(grep -m1 '^Exec=' "$AUTOSTART" || true)"
  exe="${line#Exec=}"; exe="${exe#\"}"
  case "$exe" in
    "$APP_ROOT"/*|"$BIN_DIR/$BIN_NAME"|"$BIN_DIR/$BIN_NAME "*|"$BIN_DIR/$BIN_NAME\""*)
      rm -f -- "$AUTOSTART"
      ok "Removed the start-on-login entry $AUTOSTART" ;;
  esac
  return 0
}

# --- Removal -----------------------------------------------------------------------------
remove_installation() {
  local line type path removed=0 skipped=0 dirs=()
  mapfile -t dirs < <(sed -n 's/^d \(\/.*\)$/\1/p' "$MANIFEST")
  step "Removing Fermata $VERSION from $APP_ROOT"
  # Files and symlinks first, then version trees, then directories (deepest first).
  while IFS= read -r line; do
    type="${line%% *}"; path="${line#* }"
    case "$type" in f|l|t) ;; *) continue ;; esac
    if ! is_owned_path "$path" "$APP_ROOT" "$BIN_DIR" "$SHARE_DIR"; then
      warn "Skipping $path: not part of the Fermata installation"
      skipped=$((skipped + 1)); continue
    fi
    case "$type" in
      f|l) if [[ -e "$path" || -L "$path" ]]; then rm -f -- "$path"; removed=$((removed + 1)); fi ;;
      t) if [[ -e "$path" ]]; then rm -rf -- "$path"; removed=$((removed + 1)); fi ;;
    esac
  done < <(grep -E '^[fl] /' "$MANIFEST"; grep -E '^t /' "$MANIFEST")

  rm -f -- "$MANIFEST" "$APP_ROOT/uninstall.sh" "$APP_ROOT/current"
  # Leftovers of interrupted installs.
  find "$APP_ROOT" -mindepth 1 -maxdepth 1 \( -name '.staging-*' -o -name '.replaced-*' \) -exec rm -rf -- {} + 2>/dev/null || true

  refresh_desktop_caches "$SHARE_DIR"

  # Directories the installer created, deepest first, if nothing else is in
  # them (the caches regenerated above do not count).
  if ((${#dirs[@]})); then
    while IFS= read -r path; do
      is_owned_dir "$path" "$APP_ROOT" "$BIN_DIR" "$SHARE_DIR" || continue
      [[ -d "$path" && ! -L "$path" ]] || continue
      if [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 ! -name mimeinfo.cache ! -name icon-theme.cache -print -quit 2>/dev/null)" ]]; then
        rm -f -- "$path/mimeinfo.cache" "$path/icon-theme.cache"
        rmdir -- "$path" 2>/dev/null || true
      fi
    done < <(printf '%s\n' "${dirs[@]}" | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2-)
  fi
  rmdir -- "$APP_ROOT" 2>/dev/null || true
  if [[ -d "$APP_ROOT" ]]; then
    note "$APP_ROOT was kept because it contains files the installer did not create."
  fi
  ok "Removed $removed item(s)$( ((skipped)) && printf ', skipped %d' "$skipped")"
}

main() {
  local pids purge_ok=0 sub_args=(--remove-only --yes)
  if ((REMOVE_ONLY)); then
    ((INSTALLED)) || die "Fermata is not installed ($MANIFEST not found)" "$EXIT_NOT_INSTALLED"
    remove_installation
    return 0
  fi

  if ((!INSTALLED)) && ((!PURGE)); then
    die "Fermata is not installed ($MANIFEST not found)." "$EXIT_NOT_INSTALLED"
  fi

  if ((PURGE)); then
    if confirm_purge; then purge_ok=1; else info "Keeping your data."; fi
  fi

  if ((INSTALLED)); then
    pids="$(running_pids_under "$APP_ROOT")"
    if [[ -n "$pids" ]]; then
      warn "Fermata is running (PID $pids). Quit it first (tray icon or app menu -> Quit)."
      confirm "Remove it anyway?" || exit "$EXIT_ABORTED"
    fi
    if [[ "$INSTALL_MODE" == system && $EUID -ne 0 ]]; then
      note "Removing the system-wide installation needs administrator rights: sudo may ask for your password."
      [[ -n "$C_OFF" ]] || sub_args+=(--no-color)
      as_root bash "$SELF" --manifest "$MANIFEST" "${sub_args[@]}"
    else
      remove_installation
    fi
    remove_dangling_autostart
  fi

  if ((purge_ok)); then do_purge; fi

  if ((INSTALLED)); then
    step "Fermata has been uninstalled"
    ((purge_ok)) || info "Your data was kept in $DATA_DIR (remove it with --purge)."
  else
    step "Done"
  fi
}

main "$@"; exit $?
