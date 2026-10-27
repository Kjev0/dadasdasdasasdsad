#!/usr/bin/env bash
# Build and package Fermata for Linux (x86_64).
#
#   tool/package_linux.sh [options]
#
# Outputs (version = pubspec.yaml "version" without the +build suffix):
#   dist/setup.sh                              self-extracting installer
#   dist/fermata-<version>-linux-x64.tar.gz    portable archive
#
# The installer is packaging/linux/setup.sh with lib/common.sh inlined, the
# version and payload checksum filled in, and a tar.gz payload appended (the
# release bundle, desktop entry, AppStream metadata, icons and uninstall.sh).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tool/package_linux.sh [options]

Options:
  --skip-build                   Package the existing build/linux/x64/release/bundle.
  --dart-define-from-file FILE   Build-time defines (developer credentials; see
                                 docs/BUILDING.md).
  --allow-missing-assets         Package even if icons, the desktop entry or the
                                 AppStream file are missing (local testing only).
  --out-dir DIR                  Output directory (default: dist).
  -h, --help                     Show this help.
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\e[31m'; C_YEL=$'\e[33m'; C_GRN=$'\e[32m'; C_BLD=$'\e[1m'; C_OFF=$'\e[0m'
else
  C_RED=''; C_YEL=''; C_GRN=''; C_BLD=''; C_OFF=''
fi
info() { printf '%s==>%s %s\n' "$C_BLD" "$C_OFF" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn() {
  printf '%swarning:%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then printf '::warning::%s\n' "$*"; fi
}
die() {
  printf '%serror:%s %s\n' "$C_RED" "$C_OFF" "$*" >&2
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then printf '::error::%s\n' "$*"; fi
  exit 1
}

SKIP_BUILD=0
ALLOW_MISSING=0
OUT_DIR="dist"
DEFINES_FILE=""
while (($#)); do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --allow-missing-assets) ALLOW_MISSING=1 ;;
    --out-dir) [[ $# -ge 2 ]] || die "--out-dir needs a value"; OUT_DIR="$2"; shift ;;
    --out-dir=*) OUT_DIR="${1#*=}" ;;
    --dart-define-from-file) [[ $# -ge 2 ]] || die "--dart-define-from-file needs a value"; DEFINES_FILE="$2"; shift ;;
    --dart-define-from-file=*) DEFINES_FILE="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

APP_ID="app.fermata.player"
BIN_NAME="fermata"
PKG_DIR="packaging/linux"
BUNDLE="build/linux/x64/release/bundle"

FULL_VERSION="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' pubspec.yaml | head -n1)"
VERSION="${FULL_VERSION%%+*}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.~][0-9A-Za-z.~-]+)?$ ]] \
  || die "unexpected version '$FULL_VERSION' in pubspec.yaml (expected e.g. 1.2.3+4)"
info "Fermata $VERSION (pubspec $FULL_VERSION), Linux x86_64"

for tool in tar gzip sha256sum awk sed; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done

# --- Build ---------------------------------------------------------------------------
if ((SKIP_BUILD == 0)); then
  command -v flutter >/dev/null 2>&1 || die "flutter not found on PATH (dev container: source /opt/sdk/env.sh)"
  args=(build linux --release)
  if [[ -n "$DEFINES_FILE" ]]; then
    [[ -f "$DEFINES_FILE" ]] || die "dart-define file not found: $DEFINES_FILE"
    args+=("--dart-define-from-file=$DEFINES_FILE")
  fi
  info "flutter ${args[*]}"
  flutter "${args[@]}"
else
  info "Skipping flutter build (--skip-build)"
fi

[[ -x "$BUNDLE/$BIN_NAME" ]] || die "$BUNDLE/$BIN_NAME not found (build first or drop --skip-build)"
[[ -f "$BUNDLE/lib/libapp.so" ]] || die "$BUNDLE/lib/libapp.so missing: not a release bundle?"
[[ -f "$BUNDLE/lib/libflutter_linux_gtk.so" && -d "$BUNDLE/data/flutter_assets" && -f "$BUNDLE/data/icudtl.dat" ]] \
  || die "$BUNDLE is incomplete"

# --- Desktop integration files (owned by other parts of the repo) ------------------
missing_asset() {
  if ((ALLOW_MISSING)); then warn "$1 (continuing: --allow-missing-assets)"; else die "$1"; fi
}
DESKTOP="$PKG_DIR/$APP_ID.desktop"
METAINFO="$PKG_DIR/$APP_ID.metainfo.xml"
ICONS="$PKG_DIR/icons/hicolor"
[[ -f "$DESKTOP" ]] || missing_asset "$DESKTOP is missing"
[[ -f "$METAINFO" ]] || missing_asset "$METAINFO is missing"
ICON_FILES=()
if [[ -d "$ICONS" ]]; then
  while IFS= read -r -d '' f; do ICON_FILES+=("$f"); done \
    < <(find "$ICONS" -type f \( -path "*/apps/$APP_ID.png" -o -path "*/apps/$APP_ID.svg" -o -path "*/apps/$APP_ID-symbolic.svg" \) -print0 | sort -z)
fi
((${#ICON_FILES[@]})) || missing_asset "no icons in $ICONS/<size>/apps/$APP_ID.{png,svg}"

if [[ -f "$DESKTOP" ]] && command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$DESKTOP" || die "desktop-file-validate failed for $DESKTOP"
  ok "desktop-file-validate $DESKTOP"
fi
if [[ -f "$METAINFO" ]] && command -v appstreamcli >/dev/null 2>&1; then
  # Warnings (e.g. url-homepage-missing) are reported but only errors fail.
  as_out="$(appstreamcli validate --no-net "$METAINFO" 2>&1 || true)"
  if grep -q '^E:' <<<"$as_out"; then
    printf '%s\n' "$as_out" >&2
    die "appstreamcli validate found errors in $METAINFO"
  fi
  while IFS= read -r line; do warn "appstreamcli: $line"; done < <(grep '^W:' <<<"$as_out" || true)
  ok "appstreamcli validate $METAINFO (no errors)"
fi

# --- Stage the payload ----------------------------------------------------------------
mkdir -p "$OUT_DIR"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/fermata-pkg.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
STAGE="$WORK/stage"
mkdir -p "$STAGE/share/fermata"

cp -R "$BUNDLE/$BIN_NAME" "$BUNDLE/lib" "$BUNDLE/data" "$STAGE/"
if [[ -f "$DESKTOP" ]]; then install -D -m 0644 "$DESKTOP" "$STAGE/share/applications/$APP_ID.desktop"; fi
if [[ -f "$METAINFO" ]]; then install -D -m 0644 "$METAINFO" "$STAGE/share/metainfo/$APP_ID.metainfo.xml"; fi
for f in ${ICON_FILES[@]+"${ICON_FILES[@]}"}; do
  install -D -m 0644 "$f" "$STAGE/share/icons/hicolor/${f#"$ICONS/"}"
done
printf '%s\n' "$VERSION" >"$STAGE/share/fermata/VERSION"

# Inline lib/common.sh into a script (between the "inline lib/common.sh" markers).
inline_common() { # SRC DST
  local n
  n="$(grep -c -E '^# (>>>|<<<) inline lib/common.sh (>>>|<<<)$' "$1" || true)"
  [[ "$n" == 2 ]] || die "$1: expected one '# >>> inline lib/common.sh >>>' block"
  awk -v inc="$PKG_DIR/lib/common.sh" '
    /^# >>> inline lib\/common.sh >>>$/ { print; while ((getline line < inc) > 0) print line; skip = 1; next }
    /^# <<< inline lib\/common.sh <<<$/ { skip = 0; print; next }
    !skip { print }
  ' "$1" >"$2"
}
inline_common "$PKG_DIR/uninstall.sh" "$STAGE/share/fermata/uninstall.sh"
chmod 0755 "$STAGE/share/fermata/uninstall.sh"
chmod -R u+rwX,go+rX,go-w "$STAGE"

# Reproducible archives: fixed order, owner and timestamps.
EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || date +%s)}"
make_tar() { # DIR TRANSFORM OUT
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$EPOCH" \
    --transform="$2" -C "$1" -cf - . | gzip -9n >"$3"
}

info "Creating the payload"
PAYLOAD="$WORK/payload.tar.gz"
make_tar "$STAGE" 's,^\./,./,' "$PAYLOAD"
PAYLOAD_SIZE="$(wc -c <"$PAYLOAD" | tr -d ' ')"
PAYLOAD_SHA256="$(sha256sum "$PAYLOAD" | cut -d' ' -f1)"

# --- Installer -------------------------------------------------------------------------
HEADER="$WORK/header.sh"
inline_common "$PKG_DIR/setup.sh" "$WORK/setup.inlined"
sed -e "s|@FERMATA_VERSION@|$VERSION|" \
    -e "s|@PAYLOAD_SHA256@|$PAYLOAD_SHA256|" \
    -e "s|@PAYLOAD_SIZE@|$PAYLOAD_SIZE|" \
    "$WORK/setup.inlined" >"$HEADER"
if grep -nE '@(FERMATA_VERSION|PAYLOAD_SHA256|PAYLOAD_SIZE)@' "$HEADER"; then
  die "placeholders left in the installer header"
fi
[[ "$(tail -c1 "$HEADER" | od -An -c | tr -d ' ')" == '\n' ]] || printf '\n' >>"$HEADER"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s bash -e SC2034,SC2317 "$HEADER" "$STAGE/share/fermata/uninstall.sh" \
    || die "shellcheck failed on the generated scripts"
  ok "shellcheck (generated setup.sh and uninstall.sh)"
fi
bash -n "$HEADER" || die "syntax error in the generated installer"

SETUP="$OUT_DIR/setup.sh"
cat "$HEADER" "$PAYLOAD" >"$SETUP.tmp"
chmod 0755 "$SETUP.tmp"
mv -f "$SETUP.tmp" "$SETUP"

# Self-test: the installer must verify its own payload.
"$SETUP" --version >/dev/null || die "the generated installer does not run"
if ! out="$("$SETUP" --extract "$WORK/selftest" 2>&1)"; then
  printf '%s\n' "$out" >&2
  die "the generated installer failed its extraction self-test"
fi
cmp -s "$WORK/selftest/lib/libapp.so" "$BUNDLE/lib/libapp.so" || die "self-test: extracted bundle differs from the build"
ok "Installer self-test (checksum + extraction)"

# --- Portable archive --------------------------------------------------------------------
TARBALL="$OUT_DIR/fermata-$VERSION-linux-x64.tar.gz"
rm -f "$STAGE/share/fermata/uninstall.sh"
make_tar "$STAGE" "s,^\\.,fermata-$VERSION-linux-x64," "$TARBALL.tmp"
mv -f "$TARBALL.tmp" "$TARBALL"

info "Done"
for f in "$SETUP" "$TARBALL"; do
  printf '    %-45s %8s  sha256 %s\n' "$f" "$(du -h "$f" | cut -f1)" "$(sha256sum "$f" | cut -d' ' -f1)"
done
