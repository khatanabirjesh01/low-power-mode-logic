import Foundation
import IOKit.ps

struct BatteryInfo: Equatable {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemainingMinutes: Int?
    
    var isDischarging: Bool {
        return !isPluggedIn && !isCharging
    }
    
    var statusDescription: String {
        if isCharging {
            return "Charging (\(percentage)%)"
        } else if isPluggedIn {
            return "On Power Adapter (\(percentage)%)"
        } else {
            return "On Battery (\(percentage)%)"
        }
    }
    
    var timeRemainingFormatted: String? {
        guard let mins = timeRemainingMinutes, mins > 0, mins < 65535 else { return nil }
        let hours = mins / 60
        let remainder = mins % 60
        if hours > 0 {
            return "\(hours)h \(remainder)m remaining"
        } else {
            return "\(remainder)m remaining"
        }
    }
}

final class BatteryManager: ObservableObject {
    static let shared = BatteryManager()
    
    @Published private(set) var currentInfo: BatteryInfo = BatteryInfo(
        percentage: 100,
        isCharging: false,
        isPluggedIn: true,
        timeRemainingMinutes: nil
    )
    
    var onBatteryChange: ((BatteryInfo) -> Void)?
    
    private var runLoopSource: CFRunLoopSource?
    private var fallbackTimer: Timer?
    
    private init() {
        startMonitoring()
        refresh()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func refresh() {
        let newInfo = fetchBatteryInfo()
        if newInfo != currentInfo {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentInfo = newInfo
                self.onBatteryChange?(newInfo)
            }
        }
    }
    
    private func startMonitoring() {
        // Register IOKit power source notification
        let context = Unmanaged.passUnretained(self).toOpaque()
        let loopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
            manager.refresh()
        }, context)?.takeRetainedValue()
        
        if let loopSource = loopSource {
            self.runLoopSource = loopSource
            CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .defaultMode)
        }
        
        // Periodic fallback timer (every 30 seconds)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    private func fetchBatteryInfo() -> BatteryInfo {
        // 1. Try IOKit.ps
        if let info = fetchFromIOKit() {
            return info
        }
        
        // 2. Fallback to pmset CLI
        if let info = fetchFromPmsetCLI() {
            return info
        }
        
        // Return default fallback if nothing works
        return currentInfo
    }
    
    private func fetchFromIOKit() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return nil
        }
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            let type = desc[kIOPSTypeKey] as? String
            if type == kIOPSInternalBatteryType {
                let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String ?? ""
                let isPluggedIn = (powerSourceState == kIOPSACPowerValue)
                let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
                
                let percent = maxCapacity > 0 ? Int((Double(currentCapacity) / Double(maxCapacity)) * 100.0) : currentCapacity
                let clampedPercent = Swift.min(Swift.max(percent, 0), 100)
                
                return BatteryInfo(
                    percentage: clampedPercent,
                    isCharging: isCharging,
                    isPluggedIn: isPluggedIn,
                    timeRemainingMinutes: (timeToEmpty != nil && timeToEmpty! > 0 && timeToEmpty! < 65535) ? timeToEmpty : nil
                )
            }
        }
        
        return nil
    }
    
    private func fetchFromPmsetCLI() -> BatteryInfo? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return nil
            }
            
            // Format examples:
            // "Now drawing from 'Battery Power'"
            // " -InternalBattery-0 (id=...) 58%; discharging; 3:12 remaining present: true"
            // "Now drawing from 'AC Power'"
            // " -InternalBattery-0 (id=...) 100%; charged; 0:00 remaining present: true"
            let isPluggedIn = output.contains("AC Power") || output.contains("charged") || output.contains("charging")
            let isCharging = output.contains("charging") && !output.contains("discharging")
            
            // Parse percentage using regex
            let pattern = "(\\d{1,3})%"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let pctRange = Range(match.range(at: 1), in: output),
               let pct = Int(output[pctRange]) {
                
                return BatteryInfo(
                    percentage: min(max(pct, 0), 100),
                    isCharging: isCharging,
                    isPluggedIn: isPluggedIn,
                    timeRemainingMinutes: nil
                )
            }
        } catch {
            // Failed to run pmset
        }
        
        return nil
    }
}
