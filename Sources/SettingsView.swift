import SwiftUI
import AppKit

final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var helperStatusMessage: String?
    @Published var isInstallingHelper: Bool = false
    
    func installHelper(controller: PowerModeController) {
        isInstallingHelper = true
        helperStatusMessage = "Prompting for authorization..."
        controller.installHelper { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isInstallingHelper = false
                if success {
                    self?.helperStatusMessage = "✓ Helper installed and verified successfully!"
                } else {
                    self?.helperStatusMessage = "Setup error: \(error ?? "Unknown error")"
                }
            }
        }
    }
    
    func uninstallHelper(controller: PowerModeController) {
        controller.uninstallHelper { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.helperStatusMessage = "Helper removed."
                } else {
                    self?.helperStatusMessage = "Error: \(error ?? "Unknown error")"
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var config = AppConfig.shared
    @ObservedObject var batteryManager = BatteryManager.shared
    @ObservedObject var powerController = PowerModeController.shared
    @ObservedObject var viewModel = SettingsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("AutoLowPower")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Smart Low Power Mode automation for MacBook")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Live status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(powerController.isLowPowerModeActive ? Color.yellow : Color.green)
                        .frame(width: 8, height: 8)
                    Text(powerController.isLowPowerModeActive ? "Low Power: ON" : "Normal Mode")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Selection
            Picker("", selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 }
            )) {
                Text("Automation").tag(0)
                Text("Preferences").tag(1)
                Text("System Permissions").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.selectedTab == 0 {
                        automationTab
                    } else if viewModel.selectedTab == 1 {
                        preferencesTab
                    } else {
                        permissionsTab
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Battery: \(batteryManager.currentInfo.percentage)% (\(batteryManager.currentInfo.isCharging ? "Charging" : (batteryManager.currentInfo.isPluggedIn ? "Power Adapter" : "Battery")))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    let target = !powerController.isLowPowerModeActive
                    powerController.setLowPowerMode(enabled: target)
                }) {
                    Text(powerController.isLowPowerModeActive ? "Turn Off Low Power Mode" : "Turn On Low Power Mode")
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 520, height: 480)
    }
    
    // MARK: - Automation Tab
    
    private var automationTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Master toggle
            Toggle(isOn: Binding(
                get: { config.autoSwitchEnabled },
                set: { config.autoSwitchEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Automatic Switching")
                        .font(.headline)
                    Text("Automatically activate Low Power Mode when battery drops below threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle())
            
            Divider()
            
            // Threshold Slider Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activation Threshold")
                        .font(.headline)
                    Spacer()
                    Text("≤ \(config.thresholdPercentage)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(8)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(config.thresholdPercentage) },
                        set: { config.thresholdPercentage = Int($0) }
                    ),
                    in: 5...80,
                    step: 1
                )
                
                // Quick preset buttons
                HStack(spacing: 8) {
                    ForEach([10, 15, 20, 25, 30, 40, 50], id: \.self) { pct in
                        Button("\(pct)%") {
                            config.thresholdPercentage = pct
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(config.thresholdPercentage == pct ? .accentColor : nil)
                    }
                }
                
                Text("Low Power Mode will automatically kick in when your MacBook battery reaches \(config.thresholdPercentage)% or below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Rules
            VStack(alignment: .leading, spacing: 12) {
                Text("Switching Rules")
                    .font(.headline)
                
                Toggle("Turn off Low Power Mode when connected to power", isOn: Binding(
                    get: { config.disableWhenCharging },
                    set: { config.disableWhenCharging = $0 }
                ))
                .font(.body)
                
                Toggle("Apply only to Battery Power (keep AC at full speed)", isOn: Binding(
                    get: { config.applyToBatteryOnly },
                    set: { config.applyToBatteryOnly = $0 }
                ))
                .font(.body)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recovery Buffer (Hysteresis)")
                            .font(.body)
                        Text("Prevents rapid switching. Re-disables Low Power Mode at \(config.thresholdPercentage + config.hysteresisBuffer)%.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: Binding(
                        get: { config.hysteresisBuffer },
                        set: { config.hysteresisBuffer = $0 }
                    )) {
                        Text("+2%").tag(2)
                        Text("+3% (Recommended)").tag(3)
                        Text("+5%").tag(5)
                        Text("+10%").tag(10)
                    }
                    .frame(width: 170)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Preferences Tab
    
    private var preferencesTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar Display")
                    .font(.headline)
                
                Toggle("Show battery percentage in menu bar", isOn: Binding(
                    get: { config.showPercentageInMenuBar },
                    set: { config.showPercentageInMenuBar = $0 }
                ))
                Text("Displays current percentage next to the battery icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Notifications")
                    .font(.headline)
                
                Toggle("Send notifications on mode switch", isOn: Binding(
                    get: { config.sendNotifications },
                    set: { config.sendNotifications = $0 }
                ))
                Toggle("Play sound with notifications", isOn: Binding(
                    get: { config.playNotificationSound },
                    set: { config.playNotificationSound = $0 }
                ))
                .disabled(!config.sendNotifications)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Startup")
                    .font(.headline)
                
                Toggle("Launch AutoLowPower at login", isOn: Binding(
                    get: { config.startAtLogin },
                    set: { newValue in
                        config.startAtLogin = newValue
                        AppDelegate.shared?.setLaunchAtLogin(enabled: newValue)
                    }
                ))
                Text("Runs silently in the menu bar whenever you log into macOS.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Permissions Tab
    
    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status Card
            HStack(spacing: 12) {
                Image(systemName: powerController.isHelperInstalled ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(powerController.isHelperInstalled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(powerController.isHelperInstalled ? "Permission Helper Active" : "Helper Setup Recommended")
                        .font(.headline)
                    Text(powerController.isHelperInstalled
                         ? "AutoLowPower can seamlessly switch power modes in the background without password prompts."
                         : "One-time setup allows seamless automatic background switching via macOS pmset.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.installHelper(controller: powerController)
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text(powerController.isHelperInstalled ? "Re-Install Helper" : "Install Helper (Touch ID / Password)")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                if powerController.isHelperInstalled {
                    Button("Uninstall Helper") {
                        viewModel.uninstallHelper(controller: powerController)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if let msg = viewModel.helperStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Manual Terminal Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Setup (Optional for Power Users)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("If you prefer not to use the button above, run this in Terminal:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let cmd = "echo \"%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a lowpowermode [01], /usr/bin/pmset -b lowpowermode [01], /usr/bin/pmset -c lowpowermode [01], /usr/bin/pmset -g custom\" | sudo tee /etc/sudoers.d/autolowpower && sudo chmod 0440 /etc/sudoers.d/autolowpower"
                
                HStack {
                    Text(cmd)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(3)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                    
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("This allows members of the admin group to execute pmset lowpowermode without sudo passwords.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
