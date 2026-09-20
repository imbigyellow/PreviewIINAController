#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
OUTPUT="${1:-build}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd -- "$OUTPUT" && pwd)"
APP="$OUTPUT/PreviewIINAController.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -O -whole-module-optimization -warnings-as-errors -swift-version 5 \
  -target arm64-apple-macosx13.0 Sources/Settings.swift Sources/Control.swift Sources/main.swift \
  -framework AppKit -framework CoreGraphics -framework ApplicationServices \
  -o "$APP/Contents/MacOS/PreviewIINAController"
cp Info.plist "$APP/Contents/Info.plist"
# Stable designated requirement avoids a cdhash-based identity for local rebuilds.
# Set SIGNING_IDENTITY to a trusted code-signing certificate for stronger identity.
codesign --force --sign "${SIGNING_IDENTITY:--}" \
  --identifier local.PreviewIINAController \
  -r '=designated => identifier "local.PreviewIINAController"' "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf '%s\n' "$APP"
