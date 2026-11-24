#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="AutoLowPower.app"
SOURCE_APP="$PROJECT_ROOT/build/$APP_NAME"
DEST_APP="/Applications/$APP_NAME"

echo "🚀 Installing AutoLowPower..."

# 1. Build if not already built
if [ ! -d "$SOURCE_APP" ]; then
    echo "App bundle not found. Building first..."
    "$SCRIPT_DIR/build.sh"
fi

# 2. Terminate any running instances
pkill -x "AutoLowPower" 2>/dev/null || true

# 3. Copy to /Applications
echo "Copying to /Applications..."
rm -rf "$DEST_APP"
cp -R "$SOURCE_APP" "/Applications/"

echo "✅ Installed $APP_NAME to /Applications/"

# 4. Configure permission helper
echo ""
echo "⚙️ Configuring background power switching helper..."
"$SCRIPT_DIR/setup_helper.sh"

echo ""
echo "🎉 Installation complete!"
echo "You can launch AutoLowPower by running:"
echo "    open /Applications/AutoLowPower.app"
