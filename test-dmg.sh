#!/bin/bash
# Quick script to test DMG appearance without full release process

set -e

echo "Creating test DMG..."

# Unmount if already mounted
hdiutil detach /Volumes/Dorso 2>/dev/null || true

# Remove old test DMG
rm -f build/Dorso-test.dmg

# Make sure we have a built app
if [ ! -d "build/Dorso.app" ]; then
    echo "Building app first..."
    ./build.sh
fi

# Create DMG with new layout
create-dmg \
    --volname "Dorso" \
    --volicon "build/Dorso.app/Contents/Resources/AppIcon.icns" \
    --background "assets/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 654 444 \
    --icon-size 140 \
    --text-size 12 \
    --icon "Dorso.app" 197 195 \
    --hide-extension "Dorso.app" \
    --app-drop-link 473 195 \
    "build/Dorso-test.dmg" \
    build/Dorso.app

echo ""
echo "Test DMG created: build/Dorso-test.dmg"
echo "Opening DMG to preview..."
open build/Dorso-test.dmg
