#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="/Applications/AutoLowPower.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.autolowpower.plist"
PREFS_DOMAIN="com.autolowpower.app"

echo "🗑 Uninstalling AutoLowPower..."

# 1. Terminate process
pkill -x "AutoLowPower" 2>/dev/null || true

# 2. Remove app
if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
    echo "Removed /Applications/AutoLowPower.app"
fi

# 3. Remove LaunchAgent
if [ -f "$LAUNCH_AGENT" ]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT"
    echo "Removed launch agent"
fi

# 4. Remove preferences
defaults delete "$PREFS_DOMAIN" 2>/dev/null || true

# 5. Remove helper
"$SCRIPT_DIR/uninstall_helper.sh"

echo "✅ AutoLowPower completely uninstalled."
