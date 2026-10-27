#!/usr/bin/env bash
# Build the Fermata Android release APK(s) and copy them to dist/.
#
#   tool/build_android.sh [options] [-- <extra flutter build apk args>]
#
# Outputs:
#   dist/app.apk                 universal release APK (all ABIs)
#   dist/app-<abi>.apk           per-ABI APKs (only with --split-per-abi)
#
# Signing is decided by android/app/build.gradle.kts: android/key.properties,
# else FERMATA_KEYSTORE_PATH / FERMATA_KEYSTORE_PASSWORD / FERMATA_KEY_ALIAS /
# FERMATA_KEY_PASSWORD, else the DEBUG key (with a loud warning here).
# See docs/BUILDING.md and docs/RELEASING.md.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tool/build_android.sh [options] [-- <extra args for flutter build apk>]

Options:
  --split-per-abi                 Also build one APK per ABI (dist/app-<abi>.apk)
                                  in addition to the universal dist/app.apk.
  --skip-build                    Do not run flutter; package and verify the APKs
                                  already in build/app/outputs/flutter-apk/.
  --dart-define-from-file FILE    Pass build-time defines (developer credentials,
                                  see docs/BUILDING.md) to flutter.
  --require-release-signing       Fail (exit 3) if the APK is signed with the
                                  Android debug key.
  --out-dir DIR                   Output directory (default: dist).
  -h, --help                      Show this help.

Environment:
  ANDROID_HOME / ANDROID_SDK_ROOT  Android SDK (apksigner/aapt2 are taken from
                                   the newest build-tools there).
  FERMATA_DART_DEFINES_FILE        Default for --dart-define-from-file.
  FERMATA_REQUIRE_RELEASE_SIGNING=1  Same as --require-release-signing.
  FERMATA_KEYSTORE_PATH, FERMATA_KEYSTORE_PASSWORD, FERMATA_KEY_ALIAS,
  FERMATA_KEY_PASSWORD             Release signing (when android/key.properties
                                   does not exist).
Exit codes: 0 ok, 1 build/packaging error, 2 usage error,
            3 debug-signed with --require-release-signing.
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
  exit "${2:-1}"
}

SPLIT=0
SKIP_BUILD=0
REQUIRE_RELEASE="${FERMATA_REQUIRE_RELEASE_SIGNING:-0}"
[[ "$REQUIRE_RELEASE" == 1 ]] || REQUIRE_RELEASE=0
OUT_DIR="dist"
DEFINES_FILE="${FERMATA_DART_DEFINES_FILE:-}"
EXTRA_ARGS=()
while (($#)); do
  case "$1" in
    --split-per-abi) SPLIT=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --require-release-signing) REQUIRE_RELEASE=1 ;;
    --out-dir) [[ $# -ge 2 ]] || die "--out-dir needs a value" 2; OUT_DIR="$2"; shift ;;
    --out-dir=*) OUT_DIR="${1#*=}" ;;
    --dart-define-from-file) [[ $# -ge 2 ]] || die "--dart-define-from-file needs a value" 2; DEFINES_FILE="$2"; shift ;;
    --dart-define-from-file=*) DEFINES_FILE="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    --) shift; EXTRA_ARGS=("$@"); break ;;
    *) usage >&2; die "unknown option: $1" 2 ;;
  esac
  shift
done

APP_ID="app.fermata.player"
APK_DIR="build/app/outputs/flutter-apk"
ABIS=(armeabi-v7a arm64-v8a x86_64)

VERSION="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' pubspec.yaml | head -n1)"
[[ -n "$VERSION" ]] || die "could not read version from pubspec.yaml"
info "Fermata ${VERSION} (Android)"

# --- Signing configuration as Gradle will see it -----------------------------
if [[ -f android/key.properties ]]; then
  SIGNING_SOURCE="android/key.properties"
elif [[ -n "${FERMATA_KEYSTORE_PATH:-}${FERMATA_KEYSTORE_PASSWORD:-}${FERMATA_KEY_ALIAS:-}${FERMATA_KEY_PASSWORD:-}" ]]; then
  SIGNING_SOURCE="FERMATA_KEYSTORE_* environment variables"
else
  SIGNING_SOURCE=""
fi
if [[ -n "$SIGNING_SOURCE" ]]; then
  info "Release signing configured via ${SIGNING_SOURCE}"
else
  warn "No release signing configuration (android/key.properties or FERMATA_KEYSTORE_*): the APK will be signed with the DEBUG key."
  ((REQUIRE_RELEASE == 0)) || die "--require-release-signing was given but no release keystore is configured" 3
fi

# --- Build --------------------------------------------------------------------
flutter_build() {
  local args=(build apk --release)
  if [[ -n "$DEFINES_FILE" ]]; then
    [[ -f "$DEFINES_FILE" ]] || die "dart-define file not found: $DEFINES_FILE" 2
    args+=("--dart-define-from-file=$DEFINES_FILE")
  fi
  args+=("$@" "${EXTRA_ARGS[@]}")
  info "flutter ${args[*]}"
  flutter "${args[@]}"
}

if ((SKIP_BUILD == 0)); then
  command -v flutter >/dev/null 2>&1 || die "flutter not found on PATH (dev container: source /opt/sdk/env.sh)"
  # Stale outputs must never be mistaken for fresh ones.
  rm -f "$APK_DIR"/app-release.apk "$APK_DIR"/app-*-release.apk
  flutter_build
  if ((SPLIT)); then
    flutter_build --split-per-abi
  fi
else
  info "Skipping flutter build (--skip-build)"
fi

# --- Tools from the SDK ------------------------------------------------------
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
find_build_tool() {
  local name="$1" dir
  if [[ -n "$SDK" && -d "$SDK/build-tools" ]]; then
    dir="$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V | tail -n1)"
    if [[ -n "$dir" && -x "$SDK/build-tools/$dir/$name" ]]; then
      printf '%s\n' "$SDK/build-tools/$dir/$name"
      return 0
    fi
  fi
  command -v "$name" 2>/dev/null || return 1
}
APKSIGNER="$(find_build_tool apksigner || true)"
AAPT2="$(find_build_tool aapt2 || true)"

# --- Copy + verify ------------------------------------------------------------
mkdir -p "$OUT_DIR"
DEBUG_SIGNED=0
OUTPUTS=()

verify_apk() {
  local apk="$1" size badging pkg vname vcode certs
  size="$(du -h "$apk" | cut -f1)"
  info "$apk (${size})"
  if [[ -n "$AAPT2" ]]; then
    badging="$("$AAPT2" dump badging "$apk" 2>/dev/null | head -n1 || true)"
    # package: name='app.fermata.player' versionCode='1' versionName='1.0.0' platformBuild...
    pkg="$(sed -n -E "s/^package: name='([^']*)'.*/\1/p" <<<"$badging")"
    vcode="$(sed -n -E "s/^package: .* versionCode='([^']*)'.*/\1/p" <<<"$badging")"
    vname="$(sed -n -E "s/^package: .* versionName='([^']*)'.*/\1/p" <<<"$badging")"
    printf '     package %s, versionName %s, versionCode %s\n' "${pkg:-?}" "${vname:-?}" "${vcode:-?}"
    [[ -z "$pkg" || "$pkg" == "$APP_ID" ]] || die "unexpected applicationId '$pkg' in $apk (expected $APP_ID)"
  fi
  if [[ -z "$APKSIGNER" ]]; then
    warn "apksigner not found (set ANDROID_HOME); cannot report the signing certificate of $apk"
    return 0
  fi
  if ! certs="$("$APKSIGNER" verify --verbose --print-certs "$apk" 2>&1)"; then
    printf '%s\n' "$certs" >&2
    die "apksigner verify FAILED for $apk"
  fi
  grep -E '^Verified using v[0-9]+(\.[0-9]+)? scheme' <<<"$certs" | sed 's/^/     /' || true
  grep -E '^Signer #1 certificate (DN|SHA-256 digest):' <<<"$certs" | sed 's/^/     /' || true
  if grep -q 'CN=Android Debug' <<<"$certs"; then
    DEBUG_SIGNED=1
  fi
}

copy_apk() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || die "expected APK not found: $src (did the build fail?)"
  cp -f "$src" "$dst"
  OUTPUTS+=("$dst")
  verify_apk "$dst"
}

copy_apk "$APK_DIR/app-release.apk" "$OUT_DIR/app.apk"
if ((SPLIT)); then
  for abi in "${ABIS[@]}"; do
    copy_apk "$APK_DIR/app-$abi-release.apk" "$OUT_DIR/app-$abi.apk"
  done
fi

if ((DEBUG_SIGNED)); then
  printf '\n%s%s' "$C_RED" "$C_BLD" >&2
  cat >&2 <<'EOF'
############################################################################
#  WARNING: this APK is signed with the ANDROID DEBUG KEY.                 #
#  Do NOT distribute it. It cannot be updated in place by a properly       #
#  signed build (users would have to uninstall first and lose their data). #
#  Configure android/key.properties or FERMATA_KEYSTORE_* (docs/RELEASING.md)
############################################################################
EOF
  printf '%s\n' "$C_OFF" >&2
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::warning::Android APK is DEBUG-signed (no release keystore configured)\n'
  fi
  ((REQUIRE_RELEASE == 0)) || die "APK is debug-signed but --require-release-signing was given" 3
else
  [[ -z "$APKSIGNER" ]] || ok "Release-signed (not the debug key)"
fi

info "Done: ${OUTPUTS[*]}"
