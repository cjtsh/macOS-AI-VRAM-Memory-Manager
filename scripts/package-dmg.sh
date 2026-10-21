#!/bin/bash
set -euo pipefail

APP="dist/Mac AI Memory Manager.app"
STAGING="dist/dmg-root"
DMG="dist/Mac-AI-Memory-Manager-macOS-arm64.dmg"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Mac AI Memory Manager.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE "$STAGING/LICENSE.txt"
cp TERMS.md "$STAGING/TERMS.txt"
hdiutil create -volname "Mac AI Memory Manager" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
echo "Created $DMG"
