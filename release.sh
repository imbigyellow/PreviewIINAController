#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
# A fresh staging directory prevents stray files entering the release bundle.
mkdir -p dist
STAGE="$(mktemp -d "$PWD/dist/stage.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
./build.sh "$STAGE"
APP="$STAGE/PreviewIINAController.app"
[[ "$(lipo -archs "$APP/Contents/MacOS/PreviewIINAController")" == arm64 ]]
codesign --verify --strict "$APP"
ZIP="$PWD/dist/PreviewIINAController-arm64.zip"
# Replace this generated archive only; never touch the user's running build.
rm -f -- "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
printf '%s\n' "$ZIP"
