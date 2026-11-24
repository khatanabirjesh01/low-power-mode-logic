# AutoLowPower 🍃⚡️

> **Smart Low Power Mode automation for macOS.**  
> Automatically activates Low Power Mode when your MacBook battery reaches a threshold (e.g., ≤ 20%), and automatically turns it off when plugged in or charged.

---

## 🎯 Why AutoLowPower?

By default, macOS only allows Low Power Mode to be set to **"Always"**, **"Only on Battery"**, or **"Never"**. It does not allow you to activate Low Power Mode only when your battery drops to a specific percentage (like the iPhone does at 20%).

If you choose "Only on Battery", your MacBook runs in low performance mode even at 100% battery! If you choose "Never", your battery drains quickly when it is running dangerously low.

**AutoLowPower** solves this:
- Your MacBook runs at **full speed** while battery is healthy.
- As soon as your battery reaches your chosen threshold (e.g. **20%**, **25%**, or **30%**), Low Power Mode turns **ON** automatically.
- Once you plug in your charger, Low Power Mode turns **OFF** automatically.

---

## ✨ Features

- **⚡️ Ultra-Lightweight**:
  - Native Swift + AppKit / SwiftUI.
  - Binary size: **~530 KB**.
  - Memory footprint: **~15 MB RAM**.
  - CPU usage: **0.0% idle**. Listens directly to IOKit power runloop notifications instead of busy polling.
  - Battery impact: Negligible (0.00%).
- **🔋 Native iOS-Style Status Bar Battery**:
  - Exact Apple iOS status bar battery geometry, styling, and colors.
  - Seamlessly turns **solid iOS yellow** (`#FFD60A`) when Low Power Mode is active.
  - Clean charging bolt glyph and green fill (`#34C759`) when plugged in.
  - Optional menu bar percentage readout matching macOS system typography.
- **🎯 Customizable Activation Threshold**:
  - Smooth slider (5% – 80%) with quick presets (10%, 15%, 20%, 25%, 30%, 40%, 50%).
- **🔄 Smart Recovery & Hysteresis**:
  - Configurable recovery buffer (e.g., +3%) prevents rapid on/off flapping if battery percentage fluctuates.
  - Option to automatically restore normal performance when connected to power.
  - Option to apply Low Power Mode only to battery power (`pmset -b`) so plugged-in performance is never throttled.
- **🔔 macOS Notifications**:
  - Get notified when Low Power Mode is automatically activated or deactivated.
- **🛡 Safe One-Time Permission Setup**:
  - Includes a built-in 1-click helper installer for passwordless `pmset` execution, validated with `visudo` syntax verification.
- **🚀 Launch at Login**:
  - Uses modern macOS `SMAppService` / LaunchAgent to start automatically when you log in.

---

## 🚀 Quick Start

### 1. Build and Run Directly

```bash
cd AutoLowPower
make build
make run
```

### 2. Install to `/Applications`

To install the app into `/Applications` and configure the one-time background permission helper:

```bash
cd AutoLowPower
./Scripts/install.sh
```

Or using `make`:

```bash
make install
```

---

## ⚙️ How Background Power Switching Works

macOS controls Low Power Mode via the system power utility `/usr/bin/pmset`:
- Enable: `pmset -b lowpowermode 1`
- Disable: `pmset -b lowpowermode 0`

Because modifying system power states requires administrator privileges, AutoLowPower provides a **targeted, passwordless sudoers entry** in `/etc/sudoers.d/autolowpower`:

```sudoers
%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1, /usr/bin/pmset -b lowpowermode 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -c lowpowermode 0, /usr/bin/pmset -c lowpowermode 1, /usr/bin/pmset -g custom
```

### Security & Safety
1. **Targeted**: Only allows toggling `lowpowermode` to `0` or `1`. It cannot run any other command as root.
2. **Validated**: All writes are validated using `visudo -cf` before installation to guarantee syntax integrity.
3. **Reversible**: You can remove it anytime via the Settings window ("Uninstall Helper") or by running `./Scripts/uninstall_helper.sh`.

---

## 📁 Project Structure

```
AutoLowPower/
├── Makefile                     # Build, install, run, and clean targets
├── README.md                    # Project documentation
├── build/
│   └── AutoLowPower.app         # Compiled native macOS application bundle
├── Resources/
│   ├── AppIcon.icns             # Multi-resolution macOS app icon
│   └── Info.plist               # App metadata and accessory configuration
├── Scripts/
│   ├── build.sh                 # Compiles Swift code and codesigns bundle
│   ├── install.sh               # Installs to /Applications and configures helper
│   ├── setup_helper.sh          # Standalone permission setup script
│   ├── uninstall.sh             # Complete uninstaller
│   └── uninstall_helper.sh      # Helper removal script
└── Sources/
    ├── main.swift               # Application entry point
    ├── AppDelegate.swift        # AppKit lifecycle and activation policy
    ├── AppConfig.swift          # UserDefaults settings management
    ├── BatteryManager.swift     # IOKit power sources & runloop listener
    ├── PowerModeController.swift# macOS ProcessInfo & pmset controller
    ├── AutoSwitchEngine.swift   # Automated threshold & hysteresis engine
    ├── StatusBarController.swift# Menu bar icon and dropdown menu
    └── SettingsView.swift       # SwiftUI Preferences window
```

---

## 🗑 Uninstallation

To cleanly remove AutoLowPower, its preferences, launch agents, and permission helper:

```bash
cd AutoLowPower
./Scripts/uninstall.sh
```
