#!/bin/bash
set -euo pipefail

APP_NAME="Mac AI Memory Manager"
EXECUTABLE="MacAIMemoryManager"
APP="dist/${APP_NAME}.app"

swift build --configuration release
rm -rf "$APP" dist/*.zip
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp ".build/release/${EXECUTABLE}" "$APP/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "LICENSE" "$APP/Contents/Resources/LICENSE.md"
cp "TERMS.md" "$APP/Contents/Resources/TERMS.md"
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/${APP_NAME}.zip"
echo "Created dist/${APP_NAME}.app and dist/${APP_NAME}.zip"
