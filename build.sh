#!/bin/bash
set -e

APP="ClaudeBar.app"
BUNDLE_ID="net.claudebar"
SRC="Sources/main.swift"

echo "→ Compiling..."
swiftc "$SRC" \
    -framework AppKit \
    -framework ServiceManagement \
    -O \
    -o claudebar_bin

echo "→ Bundling..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mv claudebar_bin "$APP/Contents/MacOS/claudebar"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
    ICON_KEY=""
fi

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>ClaudeBar</string>
    <key>CFBundleDisplayName</key>
    <string>ClaudeBar</string>
    <key>CFBundleExecutable</key>
    <string>claudebar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

echo "→ Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo ""
echo "✓ Built: $(pwd)/$APP"
echo ""
echo "Install to Applications:"
echo "  cp -r $APP /Applications/"
echo ""
echo "Or open directly:"
echo "  open $APP"
