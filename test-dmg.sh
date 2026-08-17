#!/bin/bash
# Quick script to test DMG appearance without full release process

set -e

echo "Creating test DMG..."

# Unmount if already mounted
hdiutil detach /Volumes/PostureAI 2>/dev/null || true

# Remove old test DMG
rm -f build/PostureAI-test.dmg

# Make sure we have a built app
if [ ! -d "build/PostureAI.app" ]; then
    echo "Building app first..."
    ./build.sh
fi

# Create DMG with new layout
create-dmg \
    --volname "PostureAI" \
    --volicon "build/PostureAI.app/Contents/Resources/AppIcon.icns" \
    --background "assets/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 654 444 \
    --icon-size 140 \
    --text-size 12 \
    --icon "PostureAI.app" 197 195 \
    --hide-extension "PostureAI.app" \
    --app-drop-link 473 195 \
    "build/PostureAI-test.dmg" \
    build/PostureAI.app

echo ""
echo "Test DMG created: build/PostureAI-test.dmg"
echo "Opening DMG to preview..."
open build/PostureAI-test.dmg
