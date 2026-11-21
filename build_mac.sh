#!/bin/bash
# ============================================================================
# Build script for shirSEARCH on macOS ⚡
# Compiles shirSEARCH.swift into a native standalone binary and .app bundle
# ============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Building shirSEARCH for macOS..."

# 1. Compile native Swift binary
swiftc -O shirSEARCH.swift -o shirSEARCH -framework Cocoa -framework CoreGraphics

echo "✅ Compiled native binary: shirSEARCH"

# 2. Package into a stealth .app bundle (LSUIElement = Menu Bar only, no Dock icon)
APP_NAME="shirSEARCH.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/shirSEARCH" "$MACOS_DIR/shirSEARCH"
chmod +x "$MACOS_DIR/shirSEARCH"

# Create Info.plist with LSUIElement=1 (pure stealth accessory app)
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>shirSEARCH</string>
    <key>CFBundleIdentifier</key>
    <string>com.shirish.shirsearch</string>
    <key>CFBundleName</key>
    <string>shirSEARCH</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy local apikey.txt if present
if [ -f "$DIR/apikey.txt" ]; then
    cp "$DIR/apikey.txt" "$DIR/apikey.txt"
fi

# Ad-hoc code sign for macOS Gatekeeper
if command -v codesign &> /dev/null; then
    codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

echo "🎉 Build complete!"
echo "👉 Standalone Binary: $DIR/shirSEARCH"
echo "👉 macOS App Bundle:  $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_NAME"
echo "  or"
echo "  ./shirSEARCH"
