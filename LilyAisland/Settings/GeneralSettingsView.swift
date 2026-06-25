import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("launch_at_login") private var launchAtLogin = false
    @AppStorage("enable_haptics") private var enableHaptics = true
    @AppStorage("hover_in_fullscreen") private var hoverInFullscreen = false

    @AppStorage("notch_radius") private var notchRadius: Double = 7.0
    @AppStorage("app_language") private var appLanguage = "zh"

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.settings_general))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)

            Section {
                Toggle(loc.loc(.general_launch_at_login), isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }

                Toggle(loc.loc(.general_haptic_feedback), isOn: $enableHaptics)
                    .toggleStyle(.switch)

                Toggle(loc.loc(.general_hover_in_fullscreen), isOn: $hoverInFullscreen)
                    .toggleStyle(.switch)
            }

            Section(loc.loc(.general_language)) {
                Picker(loc.loc(.general_language), selection: $appLanguage) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            Section(loc.loc(.general_appearance)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.loc(.general_notch_curve_radius))
                        Spacer()
                        Text(String(format: "%.1f", notchRadius) + loc.loc(.label_pt))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $notchRadius, in: 4.0...16.0, step: 0.5)
                        .tint(.gray)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(30)
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("❌ 修改开机自启状态失败: \(error)")
        }
    }
}
