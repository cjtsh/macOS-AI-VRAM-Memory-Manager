#!/bin/bash
set -euo pipefail

APP_NAME="Mac AI Memory Manager"
EXECUTABLE="MacAIMemoryManager"
APP="dist/${APP_NAME}.app"

swift build --configuration release
rm -rf "$APP" dist/*.zip
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/${EXECUTABLE}" "$APP/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/${APP_NAME}.zip"
echo "Created dist/${APP_NAME}.app and dist/${APP_NAME}.zip"
