# 🏝️ Lily Island · 莉莉灵动岛

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015.2+-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
</p>

<p align="center">
  <b>English</b> &nbsp;|&nbsp; <a href="#中文">中文</a>
</p>

---

**Lily Island** brings the iPhone Dynamic Island experience to your Mac's menu bar. A floating, interactive pill-shaped widget that docks at the top of your screen — showing system status at a glance and giving you instant access to volume, brightness, focus modes, battery, and now-playing controls. All without leaving your current app.

> 🎯 **Inspired by iPhone's Dynamic Island** — reimagined for macOS.

---

## ✨ Features

| Module | Description |
|---|---|
| 🎵 **Now Playing** | Displays current track, artist, album art, and playback progress from Apple Music. Full controls: play/pause, previous, next. |
| 🔊 **Volume** | Intercepts system volume keys and displays a sleek custom HUD — no more giant macOS bezel. |
| ☀️ **Brightness** | Smooth, rubber-banded brightness transitions with a custom overlay instead of the native bezel. |
| 🔋 **Battery** | Real-time battery percentage, charge/discharge wattage (from IOKit), adapter wattage. Alerts on plug/unplug and low battery. |
| 🌙 **Focus (DND)** | Toggle Do Not Disturb via a custom moon indicator. Optional system sound feedback. |
| 🎧 **Connectivity** | Bluetooth device connect/disconnect notifications with device-type recognition (AirPods, headphones, speakers). |
| 📊 **System Stats** | CPU, GPU, and memory usage with temperature readings from AppleSMC. |
| 🌐 **Localization** | Full Chinese (中文) and English support — switchable on the fly in Settings. |

### Expanded View
Click the island to expand and see detailed system statistics, full media player controls, battery info, and device connections — all in one gorgeous dark panel.

---

## 📋 System Requirements

| Requirement | Details |
|---|---|
| **macOS** | 15.2 (Sequoia) or later |
| **Chip** | Apple Silicon (native) · Intel (supported) |
| **Xcode** | 16+ (for building from source) |

> ⚠️ **Accessibility Permission Required**: Lily Island uses `CGEventTap` to intercept hardware keys. On first launch, it will prompt you to grant **Accessibility** access in **System Settings → Privacy & Security → Accessibility**.

---

## 📥 Installation

### Download (Recommended)

Go to the [**Releases**](https://github.com/CHOWLAN233/LilyAisland/releases) page and download the latest `LilyAisland.app.zip`.

1. Unzip and drag **LilyAisland.app** to your `Applications` folder.
2. Launch the app.
3. Grant **Accessibility** permission when prompted.
4. The island will appear at the top center of your screen.

### Build from Source

```bash
git clone https://github.com/CHOWLAN233/LilyAisland.git
cd LilyAisland
open LilyAisland.xcodeproj
```

Then **Product → Archive** in Xcode, or build directly:

```bash
xcodebuild -project LilyAisland.xcodeproj \
  -scheme LilyAisland \
  -configuration Release \
  build
```

The built app will be in the DerivedData directory. Copy it to `/Applications/`.

---

## 🎮 Usage

| Action | How |
|---|---|
| **View status** | Glance at the island — colored dots show CPU (🔵🟡🔴) and memory (🟢🟡🔴) load. |
| **Hover** | Move your mouse over the island to reveal the mini audio equalizer or now-playing snippet. |
| **Click to expand** | Click the island to open the full dashboard with system stats and media controls. |
| **Adjust volume** | Press your keyboard's volume keys — a custom slider appears inside the island. |
| **Adjust brightness** | Press your keyboard's brightness keys — a smooth slider animates inside the island. |
| **Toggle DND** | Press the Do Not Disturb / Focus key (F6 or 🌙 key). |
| **Battery alerts** | Plug/unplug your charger or dip below the battery threshold to see a popup. |
| **Bluetooth devices** | Connect/disconnect a Bluetooth audio device to see its name in the island. |
| **Settings** | Click the menu bar icon (💊) → **Preferences…** to customize everything. |

---

## ⚙️ Settings

| Section | Options |
|---|---|
| **General** | Launch at login, haptic feedback, hover-to-expand on fullscreen, notch curve radius, language (中文/English). |
| **Battery** | Enable/disable alerts, plug/unplug notifications, show percentage, alert dwell time (1–10 s), low-battery threshold (5–50%). |
| **Connectivity** | Enable/disable Bluetooth alerts, show device name. |
| **Focus** | Enable/disable DND toggle, alert dwell time (1–10 s), play sound on enter, hide label. |
| **Display** | Enable/disable brightness overlay, alert dwell time (1–5 s). |
| **Sound** | Enable/disable volume overlay, alert dwell time (1–5 s). |
| **Now Playing** | Enable/disable, show album artwork, show progress bar, polling interval (0.5–5 s). |

---

## 🏗️ Architecture

```
LilyAisland/
├── App/
│   ├── LilyAislandApp.swift     # App entry point + MenuBarExtra
│   └── Assets.xcassets          # App icon & accent colors
├── UI/
│   └── ContentView.swift        # Main island UI (collapsed/hovered/expanded/modal)
├── Monitors/
│   ├── MediaMonitor.swift       # Apple Music now-playing (AppleScript)
│   ├── VolumeMonitor.swift      # Volume key interception (CGEventTap)
│   ├── BrightnessMonitor.swift  # Brightness key interception (DisplayServices)
│   ├── BatteryMonitor.swift     # Battery stats (IOKit → AppleSmartBattery)
│   ├── DNDMonitor.swift         # Focus mode toggle (CGEventTap + AppleScript UI scripting)
│   ├── ConnectivityMonitor.swift # Bluetooth monitoring (IOBluetooth)
│   └── SystemMonitor.swift      # CPU/GPU/Memory/Temperature (Mach, IOKit, SMC)
├── Settings/
│   ├── SettingsView.swift       # Settings window (NavigationSplitView)
│   ├── GeneralSettingsView.swift
│   ├── BatterySettingsView.swift
│   ├── ConnectivitySettingsView.swift
│   ├── FocusSettingsView.swift
│   ├── DisplaySettingsView.swift
│   ├── SoundSettingsView.swift
│   └── NowPlayingSettingsView.swift
└── Helpers/
    └── LocalizationManager.swift # Bilingual zh/en localization
```

- **`IslandState`**: Central `ObservableObject` coordinator that manages UI mode transitions (collapsed ↔ hovered ↔ expanded ↔ modal) based on monitor signals.
- **`CGEventTap`**: All hardware key monitors use `.cghidEventTap` at `.headInsertEventTap` placement to eat system events before macOS shows its native HUD.
- **IOKit / SMC / Mach**: System monitors talk directly to kernel services for accurate real-time data.

---

## 🔒 Privacy

Lily Island runs **entirely locally** on your Mac. It does **not**:
- Collect any analytics or telemetry
- Send data over the network
- Access your microphone, camera, or location
- Read files outside its own sandbox

The only permission it requires is **Accessibility** (to intercept keyboard events so it can replace the system volume/brightness HUD).

---

## 📝 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Credits

Built with ❤️ by [CHOWLAN233](https://github.com/CHOWLAN233).

- Inspired by Apple's Dynamic Island on iPhone 14 Pro+
- System temperature reading via AppleSMC
- Brightness control via DisplayServices private framework
- Battery wattage calculation via IOKit AppleSmartBattery

---

---

## <a name="中文"></a>🎴 中文

# 🏝️ Lily Island · 莉莉灵动岛

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS%2015.2+-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="swift">
  <img src="https://img.shields.io/badge/协议-MIT-green" alt="license">
</p>

**Lily Island（莉莉灵动岛）** 将 iPhone 灵动岛的体验带到 Mac 菜单栏。它是一个悬浮于屏幕顶部的交互式胶囊形控件，让你一眼就能看到系统状态，并能即时调节音量、亮度、专注模式、电池以及正在播放的音乐 —— 无需离开当前应用。

> 🎯 **灵感来自 iPhone 的灵动岛** —— 在 macOS 上重新演绎。

---

## ✨ 功能介绍

| 模块 | 说明 |
|---|---|
| 🎵 **正在播放** | 显示 Apple Music 当前曲目、艺术家、专辑封面和播放进度。支持播放/暂停、上一首、下一首。 |
| 🔊 **音量** | 拦截系统音量键，显示精致的自定义 HUD —— 告别系统原生大黑框。 |
| ☀️ **亮度** | 平滑的橡皮筋式亮度过渡动画，替代原生调节弹窗。 |
| 🔋 **电池** | 实时电量百分比、充/放电功率（来自 IOKit）、电源适配器功率。插拔电源和低电量提醒。 |
| 🌙 **专注模式** | 通过自定义月亮图标切换勿扰模式。可选的系统音效反馈。 |
| 🎧 **连接设备** | 蓝牙设备连接/断开通知，支持设备类型识别（AirPods、耳机、音箱）。 |
| 📊 **系统状态** | CPU、GPU、内存使用率及温度读数（通过 AppleSMC）。 |
| 🌐 **多语言** | 完整的中文和 English 支持 —— 可在设置中即时切换。 |

### 展开视图
点击灵动岛可展开详细视图，查看系统仪表盘、完整音乐播放器、电池信息和已连接设备 —— 全部整合在一个精美的深色面板中。

---

## 📋 系统要求

| 要求 | 详情 |
|---|---|
| **系统** | macOS 15.2 (Sequoia) 及以上 |
| **芯片** | Apple Silicon（原生）· Intel（兼容） |
| **Xcode** | 16+（仅用于从源码构建） |

> ⚠️ **需要辅助功能权限**：Lily Island 使用 `CGEventTap` 拦截硬件按键。首次启动时，它会提示你在 **系统设置 → 隐私与安全性 → 辅助功能** 中授予权限。

---

## 📥 安装

### 下载（推荐）

前往 [**Releases**](https://github.com/CHOWLAN233/LilyAisland/releases) 页面下载最新的 `LilyAisland.app.zip`。

1. 解压并将 **LilyAisland.app** 拖入 `应用程序` 文件夹。
2. 启动应用。
3. 根据提示授予**辅助功能**权限。
4. 灵动岛将出现在屏幕顶部中央。

### 从源码构建

```bash
git clone https://github.com/CHOWLAN233/LilyAisland.git
cd LilyAisland
open LilyAisland.xcodeproj
```

然后在 Xcode 中选择 **Product → Archive**，或直接构建：

```bash
xcodebuild -project LilyAisland.xcodeproj \
  -scheme LilyAisland \
  -configuration Release \
  build
```

构建后的 app 位于 DerivedData 目录中，将其拷贝到 `/应用程序/` 即可。

---

## 🎮 使用方法

| 操作 | 方式 |
|---|---|
| **查看状态** | 扫一眼灵动岛 —— 彩色圆点显示 CPU（🔵🟡🔴）和内存（🟢🟡🔴）负载。 |
| **悬停** | 鼠标移到灵动岛上，显示迷你音频均衡器或播放摘要。 |
| **点击展开** | 点击灵动岛展开完整仪表盘，包含系统状态和媒体控制。 |
| **调节音量** | 按下键盘音量键 —— 自定义滑动条会出现在灵动岛内。 |
| **调节亮度** | 按下键盘亮度键 —— 平滑的滑动条会在灵动岛内动画显示。 |
| **切换专注** | 按下勿扰模式/专注键（F6 或 🌙 键）。 |
| **电池提醒** | 插拔充电器或电量低于阈值时会弹出提示。 |
| **蓝牙设备** | 连接/断开蓝牙音频设备时显示设备名称。 |
| **设置** | 点击菜单栏图标（💊）→ **设置…** 进行个性化配置。 |

---

## ⚙️ 设置

| 分类 | 选项 |
|---|---|
| **通用** | 开机启动、触觉反馈、全屏时悬停展开、刘海圆角半径（4–16 pt）、语言（中文/English）。 |
| **电池** | 启用/禁用提醒、插拔通知、显示百分比、弹窗驻留时长（1–10 秒）、低电量阈值（5–50%）。 |
| **连接设备** | 启用/禁用蓝牙提醒、显示设备名称。 |
| **专注** | 启用/禁用专注切换、弹窗驻留时长（1–10 秒）、进入时播放声音、隐藏标签。 |
| **显示** | 启用/禁用亮度弹窗、驻留时长（1–5 秒）。 |
| **声音** | 启用/禁用音量弹窗、驻留时长（1–5 秒）。 |
| **正在播放** | 启用/禁用、显示专辑封面、显示进度条、轮询间隔（0.5–5 秒）。 |

---

## 🔒 隐私说明

Lily Island **完全在本地运行**。它**不会**：
- 收集任何分析数据或遥测数据
- 通过网络发送数据
- 访问你的麦克风、摄像头或位置信息
- 读取自身沙盒之外的文件

唯一需要的权限是**辅助功能**（用于拦截键盘事件，以替代系统音量/亮度 HUD）。

---

## 📝 开源协议

MIT 协议。详见 [LICENSE](LICENSE) 文件。

---

## 🙏 鸣谢

由 [CHOWLAN233](https://github.com/CHOWLAN233) 用 ❤️ 构建。

- 灵感源自 iPhone 14 Pro+ 的灵动岛
- 系统温度读取通过 AppleSMC
- 亮度控制通过 DisplayServices 私有框架
- 电池功率计算通过 IOKit AppleSmartBattery
