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
    @State private var selectedMenu: SettingsMenu? = .general
    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMenu) {
                Section {
                    NavigationLink(value: SettingsMenu.general) {
                        Label(loc.loc(.settings_general), systemImage: "gearshape.fill")
                            .foregroundColor(.gray)
                    }
                }

                Section(loc.loc(.settings_notifications)) {
                    NavigationLink(value: SettingsMenu.battery) {
                        Label(loc.loc(.settings_battery), systemImage: "bolt.fill")
                            .foregroundColor(.orange)
                    }
                    NavigationLink(value: SettingsMenu.connectivity) {
                        Label(loc.loc(.settings_connectivity), systemImage: "headphones")
                            .foregroundColor(.green)
                    }
                    NavigationLink(value: SettingsMenu.focus) {
                        Label(loc.loc(.settings_focus), systemImage: "moon.fill")
                            .foregroundColor(.indigo)
                    }
                    NavigationLink(value: SettingsMenu.display) {
                        Label(loc.loc(.settings_display), systemImage: "sun.max.fill")
                            .foregroundColor(.purple)
                    }
                    NavigationLink(value: SettingsMenu.sound) {
                        Label(loc.loc(.settings_sound), systemImage: "speaker.wave.2.fill")
                            .foregroundColor(.pink)
                    }
                }

                Section(loc.loc(.settings_live_activities)) {
                    NavigationLink(value: SettingsMenu.nowPlaying) {
                        Label(loc.loc(.settings_now_playing), systemImage: "play.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)

        } detail: {
            Group {
                switch selectedMenu {
                case .general:
                    GeneralSettingsView()
                case .focus:
                    FocusSettingsView()
                case .battery:
                    BatterySettingsView()
                case .connectivity:
                    ConnectivitySettingsView()
                case .display:
                    DisplaySettingsView()
                case .sound:
                    SoundSettingsView()
                case .nowPlaying:
                    NowPlayingSettingsView()
                default:
                    Text(loc.loc(.settings_select_module))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
    }
}
