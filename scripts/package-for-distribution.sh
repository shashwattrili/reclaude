#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "Building release binary..."
swift build -c release 2>&1

APP_DIR=".build/Reclaude.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp .build/release/Reclaude "$APP_DIR/Contents/MacOS/Reclaude"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Reclaude</string>
    <key>CFBundleIdentifier</key>
    <string>com.shashwataggarwal.Reclaude</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Reclaude</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Reclaude needs permission to open Terminal to resume conversations.</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Create the zip
DIST_DIR="$PROJECT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/Reclaude-v2.0.0-macos.zip"
rm -f "$ZIP_PATH"

cd .build
ditto -c -k --keepParent "Reclaude.app" "$ZIP_PATH"
cd "$PROJECT_DIR"

SIZE=$(du -h "$ZIP_PATH" | cut -f1 | xargs)
echo ""
echo "✅ Distribution package created:"
echo "   $ZIP_PATH ($SIZE)"
echo ""
echo "Recipients should:"
echo "  1. Unzip the file"
echo "  2. Move 'Reclaude.app' to /Applications"
echo "  3. Run: xattr -cr '/Applications/Reclaude.app'"
echo "  4. Open the app"
