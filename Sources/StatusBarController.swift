import AppKit
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private let batteryManager = BatteryManager.shared
    private let powerController = PowerModeController.shared
    private let config = AppConfig.shared
    
    private var cancellables = Set<AnyCancellable>()
    var onOpenSettings: (() -> Void)?
    
    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        setupMenu()
        updateStatusItem()
        bindEvents()
    }
    
    private func bindEvents() {
        // Battery changes
        batteryManager.$currentInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
                self?.setupMenu()
            }
            .store(in: &cancellables)
        
        // Power mode changes
        powerController.$isLowPowerModeActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
                self?.setupMenu()
            }
            .store(in: &cancellables)
        
        // Helper status changes
        powerController.$isHelperInstalled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupMenu()
            }
            .store(in: &cancellables)
        
        // Config changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged),
            name: AppConfig.configDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func configChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItem()
            self?.setupMenu()
        }
    }
    
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        
        let battery = batteryManager.currentInfo
        let isLPM = powerController.isLowPowerModeActive
        
        // Render custom crisp menu bar icon
        button.image = createMenuBarIcon(percentage: battery.percentage, isCharging: battery.isCharging, isLowPower: isLPM)
        button.imagePosition = .imageLeft
        
        if config.showPercentageInMenuBar {
            let lpmIndicator = isLPM ? " 🍃" : ""
            button.title = " \(battery.percentage)%\(lpmIndicator)"
        } else {
            button.title = isLPM ? " 🍃" : ""
        }
    }
    
    private func createMenuBarIcon(percentage: Int, isCharging: Bool, isLowPower: Bool) -> NSImage {
        let size = NSSize(width: 26, height: 16)
        let img = NSImage(size: size)
        img.lockFocus()
        
        // Battery Shell
        let shellRect = NSRect(x: 1, y: 2, width: 20, height: 12)
        let shellPath = NSBezierPath(roundedRect: shellRect, xRadius: 2.5, yRadius: 2.5)
        
        // Color choice: If LPM is active, amber/orange; if low battery (<20%), red; otherwise template/white
        let strokeColor: NSColor
        if isLowPower {
            strokeColor = NSColor.systemYellow
        } else if percentage <= 20 && !isCharging {
            strokeColor = NSColor.systemRed
        } else {
            strokeColor = NSColor.labelColor
        }
        
        strokeColor.setStroke()
        shellPath.lineWidth = 1.2
        shellPath.stroke()
        
        // Terminal Cap (positive pin on the right)
        let capRect = NSRect(x: 21.5, y: 5.5, width: 2, height: 5)
        let capPath = NSBezierPath(roundedRect: capRect, xRadius: 0.8, yRadius: 0.8)
        strokeColor.setFill()
        capPath.fill()
        
        // Battery Fill Level
        let maxFillWidth: CGFloat = 16.0
        let fillWidth = max(2.0, maxFillWidth * CGFloat(min(max(percentage, 5), 100)) / 100.0)
        let fillRect = NSRect(x: 3, y: 4, width: fillWidth, height: 8)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5)
        
        if isLowPower {
            NSColor.systemYellow.setFill()
            fillPath.fill()
        } else if percentage <= 20 && !isCharging {
            NSColor.systemRed.setFill()
            fillPath.fill()
        } else if isCharging {
            NSColor.systemGreen.setFill()
            fillPath.fill()
        } else {
            NSColor.labelColor.setFill()
            fillPath.fill()
        }
        
        // Bolt glyph when charging
        if isCharging {
            let boltPath = NSBezierPath()
            let cx: CGFloat = 11.0
            let cy: CGFloat = 8.0
            boltPath.move(to: NSPoint(x: cx + 1.5, y: cy + 4.5))
            boltPath.line(to: NSPoint(x: cx - 2.5, y: cy))
            boltPath.line(to: NSPoint(x: cx, y: cy))
            boltPath.line(to: NSPoint(x: cx - 1.5, y: cy - 4.5))
            boltPath.line(to: NSPoint(x: cx + 2.5, y: cy))
            boltPath.line(to: NSPoint(x: cx, y: cy))
            boltPath.close()
            
            NSColor.white.setFill()
            boltPath.fill()
        }
        
        img.unlockFocus()
        // If normal mode and not low battery, use template image so macOS adapts to light/dark mode
        if !isLowPower && percentage > 20 && !isCharging {
            img.isTemplate = true
        } else {
            img.isTemplate = false
        }
        
        return img
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let battery = batteryManager.currentInfo
        let isLPM = powerController.isLowPowerModeActive
        let threshold = config.thresholdPercentage
        
        // --- 1. Header Information ---
        let statusTitle: String
        if battery.isCharging {
            statusTitle = "⚡️ Battery: \(battery.percentage)% (Charging)"
        } else if battery.isPluggedIn {
            statusTitle = "🔌 Battery: \(battery.percentage)% (Power Adapter)"
        } else {
            statusTitle = "🔋 Battery: \(battery.percentage)% (Discharging)"
        }
        let batteryItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        batteryItem.isEnabled = false
        menu.addItem(batteryItem)
        
        if let timeRem = battery.timeRemainingFormatted {
            let timeItem = NSMenuItem(title: "    ⏱ \(timeRem)", action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)
        }
        
        let lpmTitle = isLPM ? "🍃 Low Power Mode: Active" : "⚡️ Low Power Mode: Inactive"
        let lpmItem = NSMenuItem(title: lpmTitle, action: nil, keyEquivalent: "")
        lpmItem.isEnabled = false
        menu.addItem(lpmItem)
        
        let thresholdDesc = "🎯 Auto-triggers at ≤ \(threshold)%"
        let thresholdItem = NSMenuItem(title: thresholdDesc, action: nil, keyEquivalent: "")
        thresholdItem.isEnabled = false
        menu.addItem(thresholdItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 2. Auto Switch Toggle ---
        let autoToggle = NSMenuItem(
            title: "Auto-Switch Low Power Mode",
            action: #selector(toggleAutoSwitch),
            keyEquivalent: ""
        )
        autoToggle.target = self
        autoToggle.state = config.autoSwitchEnabled ? .on : .off
        menu.addItem(autoToggle)
        
        // --- 3. Threshold Selector Submenu ---
        let thresholdMenu = NSMenu()
        let presetPercentages = [10, 15, 20, 25, 30, 35, 40, 50]
        for pct in presetPercentages {
            let item = NSMenuItem(
                title: "\(pct)%",
                action: #selector(setThresholdFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = pct
            item.state = (config.thresholdPercentage == pct) ? .on : .off
            thresholdMenu.addItem(item)
        }
        
        let thresholdSubmenuItem = NSMenuItem(title: "Set Threshold (\(threshold)%)", action: nil, keyEquivalent: "")
        thresholdSubmenuItem.submenu = thresholdMenu
        menu.addItem(thresholdSubmenuItem)
        
        // --- 4. Manual Toggle ---
        let toggleTitle = isLPM ? "Turn Off Low Power Mode Now" : "Turn On Low Power Mode Now"
        let manualToggle = NSMenuItem(
            title: toggleTitle,
            action: #selector(manualTogglePowerMode),
            keyEquivalent: "t"
        )
        manualToggle.target = self
        menu.addItem(manualToggle)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 5. Quick Preferences ---
        let disableOnACItem = NSMenuItem(
            title: "Disable When Connected to Power",
            action: #selector(toggleDisableWhenCharging),
            keyEquivalent: ""
        )
        disableOnACItem.target = self
        disableOnACItem.state = config.disableWhenCharging ? .on : .off
        menu.addItem(disableOnACItem)
        
        let showPctItem = NSMenuItem(
            title: "Show Percentage in Menu Bar",
            action: #selector(toggleShowPercentage),
            keyEquivalent: ""
        )
        showPctItem.target = self
        showPctItem.state = config.showPercentageInMenuBar ? .on : .off
        menu.addItem(showPctItem)
        
        let notifItem = NSMenuItem(
            title: "Send Notifications",
            action: #selector(toggleNotifications),
            keyEquivalent: ""
        )
        notifItem.target = self
        notifItem.state = config.sendNotifications ? .on : .off
        menu.addItem(notifItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 6. Helper Status ---
        if powerController.isHelperInstalled {
            let helperItem = NSMenuItem(title: "✓ Permission Helper: Installed", action: nil, keyEquivalent: "")
            helperItem.isEnabled = false
            menu.addItem(helperItem)
        } else {
            let helperItem = NSMenuItem(
                title: "⚠️ Setup Permission Helper...",
                action: #selector(setupHelperClicked),
                keyEquivalent: ""
            )
            helperItem.target = self
            menu.addItem(helperItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 7. App Actions ---
        let settingsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let aboutItem = NSMenuItem(
            title: "About AutoLowPower",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(
            title: "Quit AutoLowPower",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func toggleAutoSwitch() {
        config.autoSwitchEnabled.toggle()
    }
    
    @objc private func setThresholdFromMenu(_ sender: NSMenuItem) {
        config.thresholdPercentage = sender.tag
    }
    
    @objc private func manualTogglePowerMode() {
        let target = !powerController.isLowPowerModeActive
        powerController.setLowPowerMode(enabled: target) { [weak self] success, error in
            if !success, let error = error {
                self?.showErrorAlert(title: "Failed to switch Low Power Mode", message: error)
            }
        }
    }
    
    @objc private func toggleDisableWhenCharging() {
        config.disableWhenCharging.toggle()
    }
    
    @objc private func toggleShowPercentage() {
        config.showPercentageInMenuBar.toggle()
    }
    
    @objc private func toggleNotifications() {
        config.sendNotifications.toggle()
    }
    
    @objc private func setupHelperClicked() {
        powerController.installHelper { [weak self] success, error in
            if success {
                let alert = NSAlert()
                alert.messageText = "Helper Installed Successfully"
                alert.informativeText = "AutoLowPower can now switch Low Power Mode automatically in the background without password prompts."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else if let error = error {
                self?.showErrorAlert(title: "Helper Setup Failed", message: error)
            }
        }
    }
    
    @objc private func openPreferences() {
        onOpenSettings?()
    }
    
    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "AutoLowPower v1.0"
        alert.informativeText = "A lightweight macOS menu bar utility that automatically enables Low Power Mode when your battery drops below a custom threshold, saving your MacBook's battery when you need it most.\n\nCreated with native Swift & AppKit for near-zero resource usage."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
