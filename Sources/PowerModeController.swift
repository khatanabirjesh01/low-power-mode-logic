import Foundation
import AppKit

final class PowerModeController: ObservableObject {
    static let shared = PowerModeController()
    
    @Published private(set) var isLowPowerModeActive: Bool = false
    @Published private(set) var isHelperInstalled: Bool = false
    
    var onPowerModeChanged: ((Bool) -> Void)?
    
    private init() {
        refreshState()
        checkHelperStatus()
        
        // Listen to macOS system power state change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemPowerStateDidChange),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    @objc private func systemPowerStateDidChange() {
        refreshState()
    }
    
    func refreshState() {
        let active = ProcessInfo.processInfo.isLowPowerModeEnabled
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isLowPowerModeActive != active {
                self.isLowPowerModeActive = active
                self.onPowerModeChanged?(active)
            }
        }
    }
    
    @discardableResult
    func checkHelperStatus() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-g", "custom"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let installed = (process.terminationStatus == 0)
            DispatchQueue.main.async { [weak self] in
                self?.isHelperInstalled = installed
            }
            return installed
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isHelperInstalled = false
            }
            return false
        }
    }
    
    func setLowPowerMode(enabled: Bool, completion: ((Bool, String?) -> Void)? = nil) {
        let flag = enabled ? "1" : "0"
        let scope = AppConfig.shared.applyToBatteryOnly ? "-b" : "-a"
        let pmsetPath = "/usr/bin/pmset"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. First attempt: fast passwordless sudo
            let sudoProcess = Process()
            sudoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            sudoProcess.arguments = ["-n", pmsetPath, scope, "lowpowermode", flag]
            let errPipe = Pipe()
            sudoProcess.standardError = errPipe
            
            do {
                try sudoProcess.run()
                sudoProcess.waitUntilExit()
                
                if sudoProcess.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        self.refreshState()
                        self.isHelperInstalled = true
                        completion?(true, nil)
                    }
                    return
                }
            } catch {
                // Sudo failed or blocked
            }
            
            // 2. Second attempt: AppleScript administrator prompt
            let script = "do shell script \"\(pmsetPath) \(scope) lowpowermode \(flag)\" with administrator privileges"
            var errorInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorInfo)
                
                if let err = errorInfo {
                    let errMsg = err[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                    DispatchQueue.main.async {
                        completion?(false, errMsg)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.refreshState()
                        completion?(true, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false, "Failed to create authorization script")
                }
            }
        }
    }
    
    func installHelper(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Script creates a secure sudoers entry validated with visudo
            let sudoersContent = """
            # AutoLowPower - Permission helper for pmset lowpowermode
            %admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1, /usr/bin/pmset -b lowpowermode 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -c lowpowermode 0, /usr/bin/pmset -c lowpowermode 1, /usr/bin/pmset -g custom
            """
            
            let tempFile = "/tmp/autolowpower_sudoers"
            let targetFile = "/etc/sudoers.d/autolowpower"
            
            do {
                try sudoersContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to write temp config: \(error.localizedDescription)")
                }
                return
            }
            
            let bashCommand = "visudo -cf \(tempFile) && cp \(tempFile) \(targetFile) && chmod 0440 \(targetFile) && rm -f \(tempFile)"
            let escapedBash = bashCommand.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"/bin/bash -c \\\"\(escapedBash)\\\"\" with administrator privileges"
            
            var errorInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorInfo)
                
                if let err = errorInfo {
                    let errMsg = err[NSAppleScript.errorMessage] as? String ?? "Setup canceled or failed"
                    DispatchQueue.main.async {
                        completion(false, errMsg)
                    }
                } else {
                    let verified = self.checkHelperStatus()
                    DispatchQueue.main.async {
                        self.isHelperInstalled = verified
                        completion(true, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Could not initialize AppleScript")
                }
            }
        }
    }
    
    func uninstallHelper(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let script = "do shell script \"rm -f /etc/sudoers.d/autolowpower\" with administrator privileges"
            var errorInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorInfo)
                
                if let err = errorInfo {
                    let errMsg = err[NSAppleScript.errorMessage] as? String ?? "Removal failed"
                    DispatchQueue.main.async {
                        completion(false, errMsg)
                    }
                } else {
                    let active = self.checkHelperStatus()
                    DispatchQueue.main.async {
                        self.isHelperInstalled = active
                        completion(true, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Could not initialize AppleScript")
                }
            }
        }
    }
}
