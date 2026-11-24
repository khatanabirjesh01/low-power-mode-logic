import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    
    private var statusBarController: StatusBarController?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Hide dock icon - pure menu bar accessory app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize status bar item
        statusBarController = StatusBarController()
        statusBarController?.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }
        
        // Start automation engine
        AutoSwitchEngine.shared.start()
        
        // Listen to system wake events to refresh state immediately
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func systemDidWake() {
        BatteryManager.shared.refresh()
        PowerModeController.shared.refreshState()
    }
    
    func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = SettingsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "AutoLowPower Preferences"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("SMAppService registration failed: \(error)")
                configureLaunchAgent(enabled: enabled)
            }
        } else {
            configureLaunchAgent(enabled: enabled)
        }
    }
    
    private func configureLaunchAgent(enabled: Bool) {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistURL = launchAgentsDir.appendingPathComponent("com.autolowpower.plist")
        
        if enabled {
            try? fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            
            let bundlePath = Bundle.main.bundlePath
            let executablePath = Bundle.main.executablePath ?? bundlePath
            
            let plistContent: [String: Any] = [
                "Label": "com.autolowpower",
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "ProcessType": "Interactive"
            ]
            
            let data = try? PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
            try? data?.write(to: plistURL)
        } else {
            try? fileManager.removeItem(at: plistURL)
        }
    }
}
