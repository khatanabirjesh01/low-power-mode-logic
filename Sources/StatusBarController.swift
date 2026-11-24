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
        
        // Render authentic iOS / macOS Sequoia battery pill with percentage inside
        button.image = createMenuBarIcon(
            percentage: battery.percentage,
            isCharging: battery.isCharging,
            isLowPower: isLPM,
            showPercentage: config.showPercentageInMenuBar
        )
        button.imagePosition = .imageOnly
        button.title = ""
    }
    
    private func createMenuBarIcon(percentage: Int, isCharging: Bool, isLowPower: Bool, showPercentage: Bool) -> NSImage {
        let width: CGFloat = 27.5
        let height: CGFloat = 12.0
        
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)
            
            // 1. Pill Dimensions (24.0 x 12.0 pt, radius 4.2 pt - matches native menu bar battery)
            let pillWidth: CGFloat = 24.0
            let pillHeight: CGFloat = 12.0
            let pillY: CGFloat = (height - pillHeight) / 2.0
            let pillRect = NSRect(x: 0, y: pillY, width: pillWidth, height: pillHeight)
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 4.2, yRadius: 4.2)
            
            // Gray background color of unfilled battery pill
            let emptyColor = NSColor(srgbRed: 0.44, green: 0.44, blue: 0.47, alpha: 0.80)
            emptyColor.setFill()
            pillPath.fill()
            
            // 2. Terminal Cap (Right pin)
            let capWidth: CGFloat = 1.8
            let capHeight: CGFloat = 4.5
            let capX: CGFloat = pillWidth + 0.6
            let capY: CGFloat = (height - capHeight) / 2.0
            let capRect = NSRect(x: capX, y: capY, width: capWidth, height: capHeight)
            let capPath = NSBezierPath(roundedRect: capRect, xRadius: 0.9, yRadius: 0.9)
            emptyColor.setFill()
            capPath.fill()
            
            // 3. Fill Charged Level
            let clampedPct = CGFloat(min(max(percentage, 0), 100))
            let fillWidth = pillWidth * (clampedPct / 100.0)
            
            if fillWidth > 0 {
                NSGraphicsContext.saveGraphicsState()
                pillPath.addClip()
                
                let fillRect = NSRect(x: 0, y: pillY, width: fillWidth, height: pillHeight)
                let fillColor: NSColor
                if isLowPower {
                    // Exact Apple iOS Low Power Mode Yellow: #FFD50B
                    fillColor = NSColor(srgbRed: 255/255.0, green: 213/255.0, blue: 11/255.0, alpha: 1.0)
                } else if isCharging {
                    // Exact Apple iOS Charging Green: #34C759
                    fillColor = NSColor(srgbRed: 52/255.0, green: 199/255.0, blue: 89/255.0, alpha: 1.0)
                } else if percentage <= 20 {
                    // Exact Apple iOS Low Battery Red: #FF3B30
                    fillColor = NSColor(srgbRed: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0)
                } else {
                    // Normal discharging: solid white fill
                    fillColor = NSColor.white
                }
                
                fillColor.setFill()
                fillRect.fill()
                
                NSGraphicsContext.restoreGraphicsState()
            }
            
            // 4. Percentage Digits (Centered directly inside the battery pill)
            if showPercentage {
                let text = "\(percentage)"
                let fontSize: CGFloat = (percentage >= 100) ? 8.5 : 10.0
                let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
                
                let textColor: NSColor
                if percentage <= 20 && !isLowPower && !isCharging {
                    textColor = NSColor.white
                } else {
                    textColor = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)
                }
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                
                let str = NSAttributedString(string: text, attributes: attrs)
                let strSize = str.size()
                
                if isCharging {
                    let bolt = NSBezierPath()
                    let bx: CGFloat = 3.5
                    let by: CGFloat = height / 2.0
                    bolt.move(to: NSPoint(x: bx + 1.0, y: by + 3.2))
                    bolt.line(to: NSPoint(x: bx - 1.6, y: by + 0.2))
                    bolt.line(to: NSPoint(x: bx - 0.2, y: by + 0.2))
                    bolt.line(to: NSPoint(x: bx - 1.0, y: by - 3.2))
                    bolt.line(to: NSPoint(x: bx + 1.6, y: by - 0.2))
                    bolt.line(to: NSPoint(x: bx + 0.2, y: by - 0.2))
                    bolt.close()
                    textColor.setFill()
                    bolt.fill()
                    
                    let textX = 7.0 + ((pillWidth - 8.0 - strSize.width) / 2.0)
                    let textY = (height - strSize.height) / 2.0
                    str.draw(at: NSPoint(x: textX, y: textY))
                } else {
                    let textX = (pillWidth - strSize.width) / 2.0
                    let textY = (height - strSize.height) / 2.0
                    str.draw(at: NSPoint(x: textX, y: textY))
                }
            }
            
            return true
        }
        
        img.isTemplate = false
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
            statusTitle = "Battery: \(battery.percentage)% (Charging)"
        } else if battery.isPluggedIn {
            statusTitle = "Battery: \(battery.percentage)% (Power Adapter)"
        } else {
            statusTitle = "Battery: \(battery.percentage)% (Discharging)"
        }
        let batteryItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        batteryItem.isEnabled = false
        menu.addItem(batteryItem)
        
        if let timeRem = battery.timeRemainingFormatted {
            let timeItem = NSMenuItem(title: "    \(timeRem)", action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)
        }
        
        let lpmTitle = isLPM ? "Low Power Mode: On" : "Low Power Mode: Off"
        let lpmItem = NSMenuItem(title: lpmTitle, action: nil, keyEquivalent: "")
        lpmItem.isEnabled = false
        menu.addItem(lpmItem)
        
        let thresholdDesc = "Auto-triggers at ≤ \(threshold)%"
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
