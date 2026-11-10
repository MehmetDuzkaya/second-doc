#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 SecondDock derleniyor..."

# 1. Compile native binary
mkdir -p build
mkdir -p /tmp/swift-cache

SOURCES=(
    Sources/SecondDock/Models/*.swift
    Sources/SecondDock/Managers/*.swift
    Sources/SecondDock/Views/*.swift
    Sources/SecondDock/AppDelegate.swift
    Sources/SecondDock/main.swift
)

swiftc -module-cache-path /tmp/swift-cache \
       -O \
       -target arm64-apple-macos13.0 \
       -o build/SecondDock \
       ${SOURCES[@]}

echo "✅ Binary başarıyla derlendi."

# 2. Create .app bundle structure
APP_DIR="build/SecondDock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

export COPYFILE_DISABLE=1

# 3. Copy files
cp build/SecondDock "$MACOS_DIR/SecondDock"
chmod +x "$MACOS_DIR/SecondDock"
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Clean any AppleDouble files that external filesystems might create
find "$APP_DIR" -name "._*" -delete 2>/dev/null || true

# 4. Ad-hoc codesign
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "🎉 SecondDock.app paketi hazır!"
echo "📦 Konum: $SCRIPT_DIR/$APP_DIR"
echo ""
echo "Uygulamayı hemen başlatmak için:"
echo "  open $SCRIPT_DIR/$APP_DIR"
echo ""
echo "Veya Uygulamalar (Applications) klasörüne kopyalamak için:"
echo "  cp -R $SCRIPT_DIR/$APP_DIR /Applications/"
