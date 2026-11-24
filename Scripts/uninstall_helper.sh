#!/bin/bash
set -e

SUDOERS_FILE="/etc/sudoers.d/autolowpower"

echo "🗑 Removing AutoLowPower permissions helper..."

if [ -f "$SUDOERS_FILE" ]; then
    sudo rm -f "$SUDOERS_FILE"
    echo "✅ Helper removed successfully."
else
    echo "ℹ️ Helper file $SUDOERS_FILE does not exist."
fi
