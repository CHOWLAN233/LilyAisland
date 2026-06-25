import SwiftUI

struct BatterySettingsView: View {
    @AppStorage("battery_enabled") private var isBatteryEnabled = true
    @AppStorage("battery_charging_alert") private var chargingAlert = true
    @AppStorage("battery_show_percentage") private var showPercentage = true
    @AppStorage("battery_low_threshold") private var lowThreshold: Double = 20.0
    // 🌟 新增：驻留时间设置
    @AppStorage("battery_duration") private var batteryDuration: Double = 3.0

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.battery_title))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)
            
            Section {
                Toggle(loc.loc(.battery_enable_alerts), isOn: $isBatteryEnabled)
                    .toggleStyle(.switch)
                
                Toggle(loc.loc(.battery_alert_on_connect), isOn: $chargingAlert)
                    .toggleStyle(.switch)
                    .disabled(!isBatteryEnabled)
                
                Toggle(loc.loc(.battery_show_percentage), isOn: $showPercentage)
                    .toggleStyle(.switch)
                    .disabled(!isBatteryEnabled)
                
                // 🌟 新增：电池弹窗显示持续时间
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.battery_duration))
                        Spacer()
                        Text(String(format: "%.1f", batteryDuration) + loc.loc(.label_s))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $batteryDuration, in: 1.0...10.0, step: 0.5)
                        .tint(.orange)
                }
                .padding(.vertical, 4)
                .disabled(!isBatteryEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.battery_low_threshold))
                        Spacer()
                        Text(String(format: "%.0f", lowThreshold) + loc.loc(.label_percent))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $lowThreshold, in: 5.0...50.0, step: 5.0)
                        .tint(.orange)
                }
                .padding(.vertical, 4)
                .disabled(!isBatteryEnabled)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
