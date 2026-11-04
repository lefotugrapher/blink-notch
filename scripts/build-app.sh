#!/usr/bin/env bash
# Build "Blink Notch.app" into ./build using only the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product BlinkNotch
BIN="$(swift build -c release --show-bin-path)/BlinkNotch"
APP="build/Blink Notch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BlinkNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$PWD/$APP"
