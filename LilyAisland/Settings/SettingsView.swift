import SwiftUI

// --- 侧边栏的菜单枚举 ---
enum SettingsMenu: String, CaseIterable {
    case general = "General"
    case battery = "Battery"
    case connectivity = "Connectivity"
    case focus = "Focus"
    case display = "Display"
    case sound = "Sound"
    case nowPlaying = "Now Playing"
}

// --- 设置面板主视图 ---
struct SettingsView: View {
    @State private var selectedMenu: SettingsMenu? = .general // 🌟 改为默认打开 General 面板
    
    var body: some View {
        NavigationSplitView {
            // 左侧边栏
            List(selection: $selectedMenu) {
                Section {
                    NavigationLink(value: SettingsMenu.general) { Label("General", systemImage: "gearshape.fill").foregroundColor(.gray) }
                }
                
                Section("Notifications") {
                    NavigationLink(value: SettingsMenu.battery) { Label("Battery", systemImage: "bolt.fill").foregroundColor(.orange) }
                    NavigationLink(value: SettingsMenu.connectivity) { Label("Connectivity", systemImage: "headphones").foregroundColor(.green) }
                    NavigationLink(value: SettingsMenu.focus) { Label("Focus", systemImage: "moon.fill").foregroundColor(.indigo) }
                    NavigationLink(value: SettingsMenu.display) { Label("Display", systemImage: "sun.max.fill").foregroundColor(.purple) }
                    NavigationLink(value: SettingsMenu.sound) { Label("Sound", systemImage: "speaker.wave.2.fill").foregroundColor(.pink) }
                }
                
                Section("Live Activities") {
                    NavigationLink(value: SettingsMenu.nowPlaying) { Label("Now Playing", systemImage: "play.circle.fill").foregroundColor(.red) }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            
        } detail: {
            // 右侧内容区：根据左侧的点击切换不同的面板
            Group {
                switch selectedMenu {
                case .general:
                    GeneralSettingsView() // 🌟 路由到新的通用设置页面
                case .focus:
                    FocusSettingsView()   // 🌟 路由到勿扰模式页面
                case .battery:
                    BatterySettingsView()
                case .connectivity:
                    Text("Connectivity Settings Coming Soon...")
                case .display:
                    Text("Display Settings Coming Soon...")
                case .sound:
                    Text("Sound Settings Coming Soon...")
                case .nowPlaying:
                    Text("Now Playing Settings Coming Soon...")
                default:
                    Text("Select a module from the sidebar.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500) // 锁定窗口默认尺寸
    }
}
