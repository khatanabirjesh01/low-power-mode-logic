import Foundation
import UserNotifications
import AppKit

final class AutoSwitchEngine {
    static let shared = AutoSwitchEngine()
    
    private let batteryManager = BatteryManager.shared
    private let powerController = PowerModeController.shared
    private let config = AppConfig.shared
    
    private var wasAutomaticallyEnabled: Bool = false
    private var isSwitching: Bool = false
    
    private init() {
        setupNotifications()
        bindEvents()
    }
    
    func start() {
        evaluate(with: batteryManager.currentInfo)
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func bindEvents() {
        batteryManager.onBatteryChange = { [weak self] info in
            self?.evaluate(with: info)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged),
            name: AppConfig.configDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func configChanged() {
        evaluate(with: batteryManager.currentInfo)
    }
    
    func evaluate(with battery: BatteryInfo) {
        guard config.autoSwitchEnabled else { return }
        guard !isSwitching else { return }
        
        let threshold = config.thresholdPercentage
        let hysteresis = config.hysteresisBuffer
        let isLPM = powerController.isLowPowerModeActive
        
        // Scenario A: On battery, drops to or below threshold -> Enable LPM
        if !battery.isPluggedIn && battery.percentage <= threshold {
            if !isLPM {
                isSwitching = true
                powerController.setLowPowerMode(enabled: true) { [weak self] success, err in
                    guard let self = self else { return }
                    self.isSwitching = false
                    if success {
                        self.wasAutomaticallyEnabled = true
                        self.sendNotification(
                            title: "Low Power Mode Activated",
                            body: "Battery reached \(battery.percentage)% (threshold is \(threshold)%). Low Power Mode enabled."
                        )
                    }
                }
            }
            return
        }
        
        // Scenario B: Plugged in / Charging -> Disable LPM if config permits
        if battery.isPluggedIn && config.disableWhenCharging {
            if isLPM && wasAutomaticallyEnabled {
                isSwitching = true
                powerController.setLowPowerMode(enabled: false) { [weak self] success, err in
                    guard let self = self else { return }
                    self.isSwitching = false
                    if success {
                        self.wasAutomaticallyEnabled = false
                        self.sendNotification(
                            title: "Low Power Mode Deactivated",
                            body: "MacBook connected to power. Normal performance restored."
                        )
                    }
                }
            }
            return
        }
        
        // Scenario C: On battery, but battery increased above threshold + hysteresis buffer
        if !battery.isPluggedIn && battery.percentage >= (threshold + hysteresis) {
            if isLPM && wasAutomaticallyEnabled {
                isSwitching = true
                powerController.setLowPowerMode(enabled: false) { [weak self] success, err in
                    guard let self = self else { return }
                    self.isSwitching = false
                    if success {
                        self.wasAutomaticallyEnabled = false
                        self.sendNotification(
                            title: "Low Power Mode Deactivated",
                            body: "Battery level recovered to \(battery.percentage)%. Normal performance restored."
                        )
                    }
                }
            }
            return
        }
    }
    
    private func sendNotification(title: String, body: String) {
        guard config.sendNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if config.playNotificationSound {
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }
}
