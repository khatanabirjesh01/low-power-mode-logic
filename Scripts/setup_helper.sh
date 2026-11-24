#!/bin/bash
set -e

# ==============================================================================
# AutoLowPower - Permission Helper Setup Script
# Configures targeted, passwordless sudo permissions for toggling Low Power Mode.
# ==============================================================================

SUDOERS_FILE="/etc/sudoers.d/autolowpower"
TEMP_FILE="/tmp/autolowpower_sudoers"

echo "🔋 Setting up AutoLowPower permissions..."
echo "This will allow AutoLowPower to toggle Low Power Mode automatically in the background."

# Write sudoers rule
cat << 'EOF' > "$TEMP_FILE"
# AutoLowPower - Allow admin users to toggle low power mode without password
%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1, /usr/bin/pmset -b lowpowermode 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -c lowpowermode 0, /usr/bin/pmset -c lowpowermode 1, /usr/bin/pmset -g custom
EOF

# Verify syntax with visudo
if ! sudo visudo -cf "$TEMP_FILE"; then
    echo "❌ Sudoers syntax validation failed. Aborting."
    rm -f "$TEMP_FILE"
    exit 1
fi

# Move into place with secure 0440 permissions
sudo cp "$TEMP_FILE" "$SUDOERS_FILE"
sudo chmod 0440 "$SUDOERS_FILE"
rm -f "$TEMP_FILE"

# Test verification
if sudo -n /usr/bin/pmset -g custom >/dev/null 2>&1; then
    echo "✅ Permissions configured successfully!"
    echo "AutoLowPower can now switch Low Power Mode seamlessly."
else
    echo "⚠️ Setup complete, but verification check returned non-zero."
fi
