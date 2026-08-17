#!/bin/bash

# PostureAI Build Script
# Compiles the app and creates the app bundle

set -e

# Configuration
APP_NAME="PostureAI"
BUNDLE_ID="chill.PostureAI"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"

# Fallback values for Sparkle updates
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://localhost/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-placeholder}"

# Check flags
APP_STORE_BUILD=false
DEV_BUILD=false
BUILD_CONFIG="release"

if [[ "$*" == *"--appstore"* ]]; then
    APP_STORE_BUILD=true
    SWIFT_BUILD_FLAGS=(-Xswiftc -D -Xswiftc APP_STORE -Xlinker -dead_strip_dylibs)
    echo "Building for App Store (no private APIs)..."
else
    SWIFT_BUILD_FLAGS=(-Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi

if [[ "$*" == *"--dev"* ]]; then
    DEV_BUILD=true
    BUILD_CONFIG="debug"
    echo "Dev build: debug config, host arch only..."
fi

# Directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building $APP_NAME v$VERSION${NC}"

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile Swift code
if [ "$DEV_BUILD" = true ]; then
    HOST_ARCH="$(uname -m)"
    swift build -c "$BUILD_CONFIG" --arch "$HOST_ARCH" --product PostureAI "${SWIFT_BUILD_FLAGS[@]}"
    DEV_BINARY="$SCRIPT_DIR/.build/${HOST_ARCH}-apple-macosx/${BUILD_CONFIG}/PostureAI"
    if [ ! -f "$DEV_BINARY" ]; then
        echo -e "${RED}Error: Expected SwiftPM binary not found at $DEV_BINARY${NC}"
        exit 1
    fi
    cp "$DEV_BINARY" "$MACOS_DIR/$APP_NAME"
else
    swift build -c release --arch arm64 --product PostureAI "${SWIFT_BUILD_FLAGS[@]}"
    swift build -c release --arch x86_64 --product PostureAI "${SWIFT_BUILD_FLAGS[@]}"

    ARM64_BINARY="$SCRIPT_DIR/.build/arm64-apple-macosx/release/PostureAI"
    X86_BINARY="$SCRIPT_DIR/.build/x86_64-apple-macosx/release/PostureAI"

    if [ ! -f "$ARM64_BINARY" ] || [ ! -f "$X86_BINARY" ]; then
        echo -e "${RED}Error: Expected SwiftPM binaries not found.${NC}"
        exit 1
    fi

    cp "$ARM64_BINARY" "$MACOS_DIR/${APP_NAME}_arm64"
    cp "$X86_BINARY" "$MACOS_DIR/${APP_NAME}_x86"

    lipo -create -output "$MACOS_DIR/$APP_NAME" \
        "$MACOS_DIR/${APP_NAME}_arm64" \
        "$MACOS_DIR/${APP_NAME}_x86"

    rm "$MACOS_DIR/${APP_NAME}_arm64" "$MACOS_DIR/${APP_NAME}_x86"
fi

# Copy SPM-generated Resource Bundles (.bundle)
echo "Copying SwiftPM resource bundles..."
if [ "$DEV_BUILD" = true ]; then
    HOST_ARCH="$(uname -m)"
    find "$SCRIPT_DIR/.build/${HOST_ARCH}-apple-macosx/${BUILD_CONFIG}" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$RESOURCES_DIR/" \; 2>/dev/null || true
else
    find "$SCRIPT_DIR/.build/arm64-apple-macosx/release" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$RESOURCES_DIR/" \; 2>/dev/null || true
fi

# Embed Sparkle.framework (direct-distribution builds only)
if [ "$APP_STORE_BUILD" = false ]; then
    SPARKLE_FRAMEWORK=$(find "$SCRIPT_DIR/.build" -name "Sparkle.framework" -type d | head -n 1)
    if [ -z "$SPARKLE_FRAMEWORK" ] || [ ! -d "$SPARKLE_FRAMEWORK" ]; then
        echo -e "${RED}Error: Sparkle.framework not found.${NC}"
        echo "Run 'swift package resolve' to fetch it."
        exit 1
    fi
    echo "Embedding Sparkle.framework..."
    mkdir -p "$CONTENTS/Frameworks"
    ditto "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/Sparkle.framework"
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <key>NSCameraUsageDescription</key>
    <string>PostureAI needs camera access to monitor your posture.</string>
    <key>NSMotionUsageDescription</key>
    <string>PostureAI needs access to motion data to monitor your posture using AirPods.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>PostureAI uses Bluetooth to detect paired AirPods for head motion tracking.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
</dict>
</plist>
EOF

if [ "$APP_STORE_BUILD" = false ]; then
    /usr/libexec/PlistBuddy \
        -c "Add :SUFeedURL string $SPARKLE_FEED_URL" \
        -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" \
        "$CONTENTS/Info.plist"
fi

# Copy Icon
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -d "$SCRIPT_DIR/PostureAI.iconset" ]; then
    iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$SCRIPT_DIR/PostureAI.iconset"
fi

# Copy raw localization directories if present
if [ -d "$SCRIPT_DIR/Sources/Resources" ]; then
    for lproj in "$SCRIPT_DIR/Sources/Resources"/*.lproj; do
        if [ -d "$lproj" ]; then
            cp -r "$lproj" "$RESOURCES_DIR/"
        fi
    done
fi

# Create entitlements file
echo "Creating entitlements..."
if [ "$APP_STORE_BUILD" = true ]; then
    cat > "$BUILD_DIR/PostureAI.entitlements" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.bluetooth</key>
    <true/>
</dict>
</plist>
EOF
else
    cat > "$BUILD_DIR/PostureAI.entitlements" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.camera</key>
    <true/>
</dict>
</plist>
EOF
fi

# Set executable permission
chmod +x "$MACOS_DIR/$APP_NAME"

# Strip extended attributes before signing
xattr -cr "$APP_BUNDLE"

# Sign embedded framework first (if present)
if [ -d "$CONTENTS/Frameworks/Sparkle.framework" ]; then
    echo "Signing embedded Sparkle.framework..."
    codesign --force --sign - "$CONTENTS/Frameworks/Sparkle.framework"
fi

# Ad-hoc sign app bundle WITH entitlements
echo "Signing app bundle..."
codesign --force --deep --options runtime --entitlements "$BUILD_DIR/PostureAI.entitlements" --sign - "$APP_BUNDLE"

echo -e "${GREEN}Build successful! Path: $APP_BUNDLE${NC}"
