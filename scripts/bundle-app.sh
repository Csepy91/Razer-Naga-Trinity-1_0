#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/app"
swift build -c release --arch arm64

BIN="$(swift build -c release --arch arm64 --show-bin-path)/NagaTrinityControl"
APP="$ROOT/build/Naga Trinity Control.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"

cp "$BIN" "$APP/Contents/MacOS/NagaTrinityControl"

RES_BUNDLE="$(dirname "$BIN")/NagaTrinityControl_NagaTrinityControl.bundle"
if [[ -d "$RES_BUNDLE" ]]; then
  cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
fi

cp -R "$ROOT/app/Resources/i18n" "$APP/Contents/Resources/"
if [[ -f "$ROOT/app/Resources/Info.plist" ]]; then
  cp "$ROOT/app/Resources/Info.plist" "$APP/Contents/Info.plist"
fi
if [[ -f "$ROOT/app/Resources/local.naga-trinity-control.plist" ]]; then
  cp "$ROOT/app/Resources/local.naga-trinity-control.plist" \
    "$APP/Contents/Library/LaunchAgents/"
fi

codesign --force --deep -s - "$APP"
echo "Bundled: $APP"
