import Foundation
import Combine

final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    private let defaults = UserDefaults.standard
    
    // Notification when config changes
    static let configDidChangeNotification = Notification.Name("AutoLowPowerConfigDidChange")
    
    enum Keys {
        static let thresholdPercentage = "thresholdPercentage"
        static let autoSwitchEnabled = "autoSwitchEnabled"
        static let disableWhenCharging = "disableWhenCharging"
        static let hysteresisBuffer = "hysteresisBuffer"
        static let showPercentageInMenuBar = "showPercentageInMenuBar"
        static let sendNotifications = "sendNotifications"
        static let playNotificationSound = "playNotificationSound"
        static let startAtLogin = "startAtLogin"
        static let applyToBatteryOnly = "applyToBatteryOnly"
    }
    
    @Published var thresholdPercentage: Int {
        didSet {
            defaults.set(thresholdPercentage, forKey: Keys.thresholdPercentage)
            notifyChange()
        }
    }
    
    @Published var autoSwitchEnabled: Bool {
        didSet {
            defaults.set(autoSwitchEnabled, forKey: Keys.autoSwitchEnabled)
            notifyChange()
        }
    }
    
    @Published var disableWhenCharging: Bool {
        didSet {
            defaults.set(disableWhenCharging, forKey: Keys.disableWhenCharging)
            notifyChange()
        }
    }
    
    @Published var hysteresisBuffer: Int {
        didSet {
            defaults.set(hysteresisBuffer, forKey: Keys.hysteresisBuffer)
            notifyChange()
        }
    }
    
    @Published var showPercentageInMenuBar: Bool {
        didSet {
            defaults.set(showPercentageInMenuBar, forKey: Keys.showPercentageInMenuBar)
            notifyChange()
        }
    }
    
    @Published var sendNotifications: Bool {
        didSet {
            defaults.set(sendNotifications, forKey: Keys.sendNotifications)
            notifyChange()
        }
    }
    
    @Published var playNotificationSound: Bool {
        didSet {
            defaults.set(playNotificationSound, forKey: Keys.playNotificationSound)
            notifyChange()
        }
    }
    
    @Published var startAtLogin: Bool {
        didSet {
            defaults.set(startAtLogin, forKey: Keys.startAtLogin)
            notifyChange()
        }
    }
    
    @Published var applyToBatteryOnly: Bool {
        didSet {
            defaults.set(applyToBatteryOnly, forKey: Keys.applyToBatteryOnly)
            notifyChange()
        }
    }
    
    private init() {
        // Register defaults
        defaults.register(defaults: [
            Keys.thresholdPercentage: 20,
            Keys.autoSwitchEnabled: true,
            Keys.disableWhenCharging: true,
            Keys.hysteresisBuffer: 3,
            Keys.showPercentageInMenuBar: true,
            Keys.sendNotifications: true,
            Keys.playNotificationSound: true,
            Keys.startAtLogin: false,
            Keys.applyToBatteryOnly: true
        ])
        
        self.thresholdPercentage = defaults.integer(forKey: Keys.thresholdPercentage)
        self.autoSwitchEnabled = defaults.bool(forKey: Keys.autoSwitchEnabled)
        self.disableWhenCharging = defaults.bool(forKey: Keys.disableWhenCharging)
        self.hysteresisBuffer = defaults.integer(forKey: Keys.hysteresisBuffer)
        self.showPercentageInMenuBar = defaults.bool(forKey: Keys.showPercentageInMenuBar)
        self.sendNotifications = defaults.bool(forKey: Keys.sendNotifications)
        self.playNotificationSound = defaults.bool(forKey: Keys.playNotificationSound)
        self.startAtLogin = defaults.bool(forKey: Keys.startAtLogin)
        self.applyToBatteryOnly = defaults.bool(forKey: Keys.applyToBatteryOnly)
    }
    
    private func notifyChange() {
        NotificationCenter.default.post(name: AppConfig.configDidChangeNotification, object: self)
    }
}
