#!/usr/bin/env bash
# Builds LivingFolders.app into ./build. Usage: ./build.sh [--debug] [--open]
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=release
OPEN=0
for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG=debug ;;
    --open) OPEN=1 ;;
  esac
done

swift build -c "$CONFIG" --product LivingFolders
BIN="$(swift build -c "$CONFIG" --show-bin-path)/LivingFolders"

APP=build/LivingFolders.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LivingFolders"
cp Resources/Info.plist "$APP/Contents/Info.plist"
echo -n 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
[[ $OPEN == 1 ]] && open "$APP"
exit 0
