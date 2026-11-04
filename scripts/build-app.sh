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
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "$PWD/$APP"

# `--install` copies the app to ~/Applications so Launch at login has a stable path.
if [ "${1:-}" = "--install" ]; then
    pkill -x BlinkNotch 2>/dev/null || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Blink Notch.app"
    cp -R "$APP" "$HOME/Applications/Blink Notch.app"
    echo "installed: $HOME/Applications/Blink Notch.app"
fi
