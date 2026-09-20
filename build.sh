#!/usr/bin/env bash
# Gets LivingFolders.app into ./build and (with --open) launches it.
#
# Two paths, same result:
#   Xcode installed     -> builds from source
#   Xcode not installed -> downloads the prebuilt app from GitHub Releases
#
# SwiftUI's @State is a macro, and Swift macro plugins ship inside Xcode.app,
# so Command Line Tools alone cannot compile this app. That is why the
# download path exists: so cloning and running works on a plain Mac.
#
# Usage: ./build.sh [--debug] [--open] [--download] [--from-source]
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=release
OPEN=0
FORCE_DOWNLOAD=0
FORCE_SOURCE=0
for arg in "$@"; do
  case "$arg" in
    --debug)       CONFIG=debug ;;
    --open)        OPEN=1 ;;
    --download)    FORCE_DOWNLOAD=1 ;;
    --from-source) FORCE_SOURCE=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

APP=build/LivingFolders.app
RELEASE_URL="https://github.com/diegocp01/living-folders/releases/latest/download/LivingFolders.zip"

# Command Line Tools provide swift but not xcodebuild; that is the signal.
have_xcode() { xcodebuild -version >/dev/null 2>&1; }

build_from_source() {
  echo "Xcode found — building from source."
  swift build -c "$CONFIG" --product LivingFolders
  local bin
  bin="$(swift build -c "$CONFIG" --show-bin-path)/LivingFolders"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp "$bin" "$APP/Contents/MacOS/LivingFolders"
  cp Resources/Info.plist "$APP/Contents/Info.plist"
  printf 'APPL????' > "$APP/Contents/PkgInfo"
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
  echo "Built $APP"
}

download_prebuilt() {
  echo "No Xcode here — downloading the prebuilt app."
  local tmp
  tmp="$(mktemp -d)"
  if ! curl -fsSL "$RELEASE_URL" -o "$tmp/LivingFolders.zip"; then
    rm -rf "$tmp"
    cat >&2 <<'MSG'
Could not download the prebuilt app.

Either the release is not published yet, or you are offline. You can also
install Xcode from the App Store and run ./build.sh again to build from source.
MSG
    exit 1
  fi
  rm -rf "$APP"
  mkdir -p build
  ditto -x -k "$tmp/LivingFolders.zip" build
  rm -rf "$tmp"
  # Downloaded apps are quarantined; strip it so the first launch is not blocked.
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
  echo "Downloaded $APP"
}

if   [[ $FORCE_DOWNLOAD == 1 ]]; then download_prebuilt
elif [[ $FORCE_SOURCE   == 1 ]]; then build_from_source
elif have_xcode;                 then build_from_source
else                                  download_prebuilt
fi

[[ $OPEN == 1 ]] && open "$APP"
exit 0
