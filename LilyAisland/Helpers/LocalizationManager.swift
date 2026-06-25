import SwiftUI
import Combine

// MARK: - 字符串 Key 注册表（全文仅此一份，避免拼写错误）
enum L10n: String {
    // 菜单栏
    case menu_preferences
    case menu_quit
    case menu_app_name

    // 设置 - 侧边栏
    case settings_general
    case settings_notifications
    case settings_battery
    case settings_connectivity
    case settings_focus
    case settings_display
    case settings_sound
    case settings_live_activities
    case settings_now_playing

    // 设置 - 通用
    case general_launch_at_login
    case general_haptic_feedback
    case general_hover_in_fullscreen
    case general_island_position
    case general_horizontal_alignment
    case general_fine_tune
    case general_distance_from_top
    case general_appearance
    case general_notch_curve_radius
    case general_language
    case general_pt  // pt 单位

    // 设置 - 水平对齐
    case alignment_left
    case alignment_center
    case alignment_right

    // 设置 - 电池
    case battery_enable_alerts
    case battery_alert_on_connect
    case battery_show_percentage
    case battery_duration
    case battery_low_threshold
    case battery_title

    // 设置 - 连接性
    case connectivity_enable_alerts
    case connectivity_show_device_name
    case connectivity_duration
    case connectivity_title

    // 设置 - 专注
    case focus_enable
    case focus_duration
    case focus_play_sound
    case focus_hide_label
    case focus_title

    // 设置 - 显示
    case display_enable
    case display_duration
    case display_step_size
    case display_title

    // 设置 - 声音
    case sound_enable
    case sound_duration
    case sound_step_size
    case sound_title

    // 设置 - 正在播放
    case nowplaying_enable
    case nowplaying_show_artwork
    case nowplaying_show_progress
    case nowplaying_polling_interval
    case nowplaying_title

    // 通用
    case label_duration
    case label_step_size
    case label_s
    case label_pt
    case label_percent

    // 灵动岛 UI
    case island_control_playing
    case island_not_playing
    case island_ac_power
    case island_battery_power
    case island_adapter_wattage
    case island_battery_charge_wattage
    case island_battery_output_wattage
    case island_charging
    case island_battery_label

    // 蓝牙
    case bluetooth_connected_devices
    case bluetooth_none
    case bluetooth_connected
    case bluetooth_disconnected
    case bluetooth_label
    case device_headphones
    case device_speaker
    case device_airpods
    case device_unknown_type

    // 设置 - 通用 placeholder
    case settings_select_module
    case settings_coming_soon
}

// 每个 key 的 "zh" / "en" 翻译
fileprivate let rawStrings: [L10n: [String: String]] = [
    .menu_preferences:           ["zh": "偏好设置...",      "en": "Preferences..."],
    .menu_quit:                  ["zh": "退出 LilyAisland",  "en": "Quit LilyAisland"],
    .menu_app_name:              ["zh": "LilyAisland",       "en": "LilyAisland"],

    .settings_general:           ["zh": "通用",               "en": "General"],
    .settings_notifications:     ["zh": "通知",               "en": "Notifications"],
    .settings_battery:           ["zh": "电池",               "en": "Battery"],
    .settings_connectivity:      ["zh": "连接性",             "en": "Connectivity"],
    .settings_focus:             ["zh": "专注",               "en": "Focus"],
    .settings_display:           ["zh": "显示",               "en": "Display"],
    .settings_sound:             ["zh": "声音",               "en": "Sound"],
    .settings_live_activities:   ["zh": "实时活动",           "en": "Live Activities"],
    .settings_now_playing:       ["zh": "正在播放",           "en": "Now Playing"],

    .general_launch_at_login:    ["zh": "开机自启",           "en": "Launch at login"],
    .general_haptic_feedback:    ["zh": "触觉反馈",           "en": "Haptic Feedback"],
    .general_hover_in_fullscreen:["zh": "全屏下悬停触发",     "en": "Hover in Full Screen"],
    .general_island_position:    ["zh": "灵动岛位置",         "en": "Island Position"],
    .general_horizontal_alignment:["zh": "水平对齐",           "en": "Horizontal Alignment"],
    .general_fine_tune:          ["zh": "水平微调",           "en": "Fine Tune"],
    .general_distance_from_top:  ["zh": "距屏幕顶部距离",     "en": "Distance from Top"],
    .general_appearance:         ["zh": "外观",               "en": "Appearance"],
    .general_notch_curve_radius: ["zh": "刘海倒角半径",       "en": "Notch Curve Radius"],
    .general_language:           ["zh": "语言",               "en": "Language"],
    .general_pt:                 ["zh": "pt",                 "en": "pt"],

    .alignment_left:             ["zh": "左侧",               "en": "Left"],
    .alignment_center:           ["zh": "居中",               "en": "Center"],
    .alignment_right:            ["zh": "右侧",               "en": "Right"],

    .battery_title:              ["zh": "电池",               "en": "Battery"],
    .battery_enable_alerts:      ["zh": "启用电池提醒",       "en": "Enable Battery Alerts"],
    .battery_alert_on_connect:   ["zh": "充/断电弹窗提醒",    "en": "Alert on Connect/Disconnect"],
    .battery_show_percentage:    ["zh": "显示电量百分比文字", "en": "Show Percentage Text"],
    .battery_duration:           ["zh": "弹窗驻留时长",       "en": "Duration"],
    .battery_low_threshold:      ["zh": "低电量提醒阈值",     "en": "Low Battery Alert Threshold"],

    .connectivity_title:         ["zh": "连接性",             "en": "Connectivity"],
    .connectivity_enable_alerts: ["zh": "启用连接性提醒",     "en": "Enable Connectivity Alerts"],
    .connectivity_show_device_name:["zh": "显示设备名称",      "en": "Show Device Name"],
    .connectivity_duration:      ["zh": "弹窗驻留时长",       "en": "Duration"],

    .focus_title:                ["zh": "专注",               "en": "Focus"],
    .focus_enable:               ["zh": "启用专注模式",       "en": "Focus"],
    .focus_duration:             ["zh": "弹窗驻留时长",       "en": "Duration"],
    .focus_play_sound:           ["zh": "进入专注时播放声音", "en": "Play sound on sleep focus"],
    .focus_hide_label:           ["zh": "隐藏标签",           "en": "Hide label"],

    .display_title:              ["zh": "显示",               "en": "Display"],
    .display_enable:             ["zh": "启用亮度显示",       "en": "Enable Brightness Display"],
    .display_duration:           ["zh": "弹窗驻留时长",       "en": "Duration"],
    .display_step_size:          ["zh": "亮度步长",           "en": "Step Size"],

    .sound_title:                ["zh": "声音",               "en": "Sound"],
    .sound_enable:               ["zh": "启用音量显示",       "en": "Enable Volume Display"],
    .sound_duration:             ["zh": "弹窗驻留时长",       "en": "Duration"],
    .sound_step_size:            ["zh": "音量步长",           "en": "Step Size"],

    .nowplaying_title:           ["zh": "正在播放",           "en": "Now Playing"],
    .nowplaying_enable:          ["zh": "启用正在播放",       "en": "Enable Now Playing"],
    .nowplaying_show_artwork:    ["zh": "显示专辑封面",       "en": "Show Album Artwork"],
    .nowplaying_show_progress:   ["zh": "显示进度条",         "en": "Show Progress Bar"],
    .nowplaying_polling_interval:["zh": "轮询间隔",           "en": "Polling Interval"],

    .label_duration:             ["zh": "驻留时长",           "en": "Duration"],
    .label_step_size:            ["zh": "步长",               "en": "Step Size"],
    .label_s:                    ["zh": " 秒",                "en": " s"],
    .label_pt:                   ["zh": " pt",                "en": " pt"],
    .label_percent:              ["zh": "%",                  "en": "%"],

    .island_control_playing:     ["zh": "控制正在播放",       "en": "Control Playing"],
    .island_not_playing:         ["zh": "未在播放",           "en": "Not Playing"],
    .island_ac_power:            ["zh": "正在使用电源适配器", "en": "Using Power Adapter"],
    .island_battery_power:       ["zh": "正在使用电池供电",   "en": "Using Battery Power"],
    .island_adapter_wattage:     ["zh": "适配器供电",         "en": "Adapter Power"],
    .island_battery_charge_wattage:["zh": "电池充电功率",      "en": "Battery Charge Rate"],
    .island_battery_output_wattage:["zh": "电池输出功率",     "en": "Battery Output Rate"],
    .island_charging:            ["zh": "正在充电",           "en": "Charging"],
    .island_battery_label:       ["zh": "电池",               "en": "Battery"],

    .bluetooth_connected_devices:["zh": "已连接的蓝牙设备",   "en": "Connected Bluetooth Devices"],
    .bluetooth_none:             ["zh": "无",                 "en": "None"],
    .bluetooth_connected:        ["zh": "已连接",             "en": "Connected"],
    .bluetooth_disconnected:     ["zh": "已断开",             "en": "Disconnected"],
    .bluetooth_label:            ["zh": "蓝牙",               "en": "Bluetooth"],
    .device_headphones:          ["zh": "耳机",               "en": "Headphones"],
    .device_speaker:             ["zh": "音响",               "en": "Speaker"],
    .device_airpods:             ["zh": "AirPods",            "en": "AirPods"],
    .device_unknown_type:        ["zh": "设备",               "en": "Device"],

    .settings_select_module:     ["zh": "从侧边栏选择一个模块。","en": "Select a module from the sidebar."],
    .settings_coming_soon:       ["zh": "即将推出...",         "en": "Coming Soon..."],
]

// MARK: - 全局语言管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("app_language") var language = "zh" {
        didSet { objectWillChange.send() }
    }

    func loc(_ key: L10n) -> String {
        rawStrings[key]?[language] ?? key.rawValue
    }

    func locFormat(_ key: L10n, _ args: CVarArg...) -> String {
        let fmt = loc(key)
        return String(format: fmt, arguments: args)
    }
}

// MARK: - 便捷 View Extension
extension View {
    func localized() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}
