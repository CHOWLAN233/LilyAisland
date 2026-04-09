import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("launch_at_login") private var launchAtLogin = false
    @AppStorage("enable_haptics") private var enableHaptics = true
    
    // 🌟 新增：全屏模式下是否允许鼠标悬浮触发
    @AppStorage("hover_in_fullscreen") private var hoverInFullscreen = false
    
    @AppStorage("island_x_offset") private var islandXOffset: Double = 0.0
    @AppStorage("default_y_offset") private var defaultYOffset: Double = 0.0
    @AppStorage("capsule_y_offset") private var capsuleYOffset: Double = 0.0
    
    // 🌟 新增：刘海倒角半径设置 (默认 7.0 更贴近物理真实感)
    @AppStorage("notch_radius") private var notchRadius: Double = 7.0
    
    var body: some View {
        Form {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("General")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)
            
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                
                Toggle("Haptic Feedback", isOn: $enableHaptics)
                    .toggleStyle(.switch)
                
                // 🌟 新增的 UI 开关
                Toggle("Hover in Full Screen", isOn: $hoverInFullscreen)
                    .toggleStyle(.switch)
                
                // 🌟 新增的刘海倒角半径调节器
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notch Curve Radius")
                        Spacer()
                        Text(String(format: "%.1f pt", notchRadius))
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
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Island X-Offset")
                        Spacer()
                        Text(String(format: "%.0f pt", islandXOffset))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $islandXOffset, in: -50.0...50.0, step: 1.0)
                        .tint(.gray)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Y-Offset")
                        Spacer()
                        Text(String(format: "%.0f pt", defaultYOffset))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $defaultYOffset, in: -30.0...30.0, step: 1.0)
                        .tint(.gray)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Capsule Y-Offset")
                        Spacer()
                        Text(String(format: "%.0f pt", capsuleYOffset))
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Slider(value: $capsuleYOffset, in: -30.0...30.0, step: 1.0)
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
