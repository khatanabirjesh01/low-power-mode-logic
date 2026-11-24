#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/AutoLowPower.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building AutoLowPower.app..."

# 1. Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 2. Copy Resources & Plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 3. Compile Swift source files
SOURCES=(
    "$PROJECT_ROOT/Sources/AppConfig.swift"
    "$PROJECT_ROOT/Sources/BatteryManager.swift"
    "$PROJECT_ROOT/Sources/PowerModeController.swift"
    "$PROJECT_ROOT/Sources/AutoSwitchEngine.swift"
    "$PROJECT_ROOT/Sources/StatusBarController.swift"
    "$PROJECT_ROOT/Sources/SettingsView.swift"
    "$PROJECT_ROOT/Sources/AppDelegate.swift"
    "$PROJECT_ROOT/Sources/main.swift"
)

echo "Compiling Swift sources..."
swiftc -O \
    -module-cache-path /tmp/clang-cache \
    -target arm64-apple-macos12.0 \
    "${SOURCES[@]}" \
    -o "$MACOS_DIR/AutoLowPower"

chmod +x "$MACOS_DIR/AutoLowPower"

# 4. Ad-hoc codesign bundle
echo "Codesigning app bundle..."
codesign -s - --force --deep "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"
ls -lh "$MACOS_DIR/AutoLowPower"
