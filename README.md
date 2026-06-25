# LilyAisland

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015.2+-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
</p>

<p align="center">
  <b>English</b> &nbsp;|&nbsp; <a href="#chinese">中文</a>
</p>

---

**LilyAisland** brings the iPhone Dynamic Island experience to your Mac's menu bar. A floating, interactive pill-shaped widget that docks at the top of your screen — showing system status at a glance and giving you instant access to volume, brightness, focus modes, battery, and now-playing controls.

Inspired by iPhone's Dynamic Island, reimagined for macOS.

---

## Features

| Module | Description |
|---|---|
| Now Playing | Current track, artist, album art, and playback progress from Apple Music. Play/pause, previous, next. |
| Volume | Intercepts system volume keys, displays a custom HUD instead of the macOS bezel. |
| Brightness | Smooth, rubber-banded brightness transitions with custom overlay. |
| Battery | Real-time battery percentage, charge/discharge wattage (IOKit), adapter wattage. Plug/unplug and low-battery alerts. |
| Focus (DND) | Toggle Do Not Disturb with a custom indicator. Optional system sound feedback. |
| Connectivity | Bluetooth device connect/disconnect notifications with device-type recognition (AirPods, headphones, speakers). |
| System Stats | CPU, GPU, memory usage and temperature readings via AppleSMC. |
| Localization | Full Chinese and English support, switchable on the fly in Settings. |

Click the island to expand and see detailed system statistics, full media player controls, battery info, and device connections.

---

## System Requirements

| Requirement | Details |
|---|---|
| **macOS** | 15.2 (Sequoia) or later |
| **Chip** | Apple Silicon (native) / Intel (supported) |
| **Xcode** | 16+ (for building from source) |

Accessibility Permission Required: LilyAisland uses `CGEventTap` to intercept hardware keys. On first launch, grant **Accessibility** access in **System Settings > Privacy & Security > Accessibility**.

---

## Installation

### Download (Recommended)

Go to the [**Releases**](https://github.com/CHOWLAN233/LilyAisland/releases) page and download the latest `LilyAisland.app.zip`.

1. Unzip and drag **LilyAisland.app** to your `Applications` folder.
2. Launch the app.
3. Grant **Accessibility** permission when prompted.
4. The island appears at the top center of your screen.

### Build from Source

```bash
git clone https://github.com/CHOWLAN233/LilyAisland.git
cd LilyAisland
open LilyAisland.xcodeproj
```

Then **Product > Archive** in Xcode, or build directly:

```bash
xcodebuild -project LilyAisland.xcodeproj \
  -scheme LilyAisland \
  -configuration Release \
  build
```

Copy the built app from DerivedData to `/Applications/`.

---

## Usage

| Action | How |
|---|---|
| **View status** | Glance at the island — colored dots show CPU and memory load. |
| **Hover** | Move mouse over the island to see the mini equalizer or now-playing snippet. |
| **Click to expand** | Click the island to open the full dashboard. |
| **Adjust volume** | Press keyboard volume keys — a custom slider appears. |
| **Adjust brightness** | Press keyboard brightness keys — a smooth slider animates. |
| **Toggle DND** | Press the Do Not Disturb / Focus key (F6 or Moon key). |
| **Battery alerts** | Plug/unplug charger or dip below the battery threshold. |
| **Bluetooth devices** | Connect/disconnect a Bluetooth audio device. |
| **Settings** | Click the menu bar icon and select **Preferences...** |

---

## Settings

| Section | Options |
|---|---|
| **General** | Launch at login, haptic feedback, fullscreen hover trigger, notch curve radius (4-16 pt), language. |
| **Battery** | Enable/disable alerts, plug/unplug notifications, show percentage, alert dwell time (1-10 s), low-battery threshold (5-50%). |
| **Connectivity** | Enable/disable Bluetooth alerts, show device name. |
| **Focus** | Enable/disable DND toggle, alert dwell time (1-10 s), play sound on enter, hide label. |
| **Display** | Enable/disable brightness overlay, alert dwell time (1-5 s). |
| **Sound** | Enable/disable volume overlay, alert dwell time (1-5 s). |
| **Now Playing** | Enable/disable, show album artwork, show progress bar, polling interval (0.5-5 s). |

---

## Architecture

```
LilyAisland/
├── App/
│   ├── LilyAislandApp.swift     # App entry point + MenuBarExtra
│   └── Assets.xcassets          # App icon & accent colors
├── UI/
│   └── ContentView.swift        # Island UI (collapsed/hovered/expanded/modal)
├── Monitors/
│   ├── MediaMonitor.swift       # Apple Music now-playing (AppleScript)
│   ├── VolumeMonitor.swift      # Volume key interception (CGEventTap)
│   ├── BrightnessMonitor.swift  # Brightness key interception (DisplayServices)
│   ├── BatteryMonitor.swift     # Battery stats (IOKit > AppleSmartBattery)
│   ├── DNDMonitor.swift         # Focus mode toggle (CGEventTap + AppleScript)
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

- **IslandState**: Central `ObservableObject` coordinator managing UI mode transitions.
- **CGEventTap**: All hardware key monitors use `.cghidEventTap` at `.headInsertEventTap` to intercept system events before macOS shows its native HUD.
- **IOKit / SMC / Mach**: System monitors talk directly to kernel services for accurate real-time data.

---

## Privacy

LilyAisland runs entirely locally on your Mac. It does not:

- Collect analytics or telemetry
- Send data over the network
- Access your microphone, camera, or location
- Read files outside its own sandbox

The only permission required is **Accessibility** (to intercept keyboard events).

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Credits

Built by [CHOWLAN233](https://github.com/CHOWLAN233).

- Inspired by Apple's Dynamic Island on iPhone 14 Pro+
- System temperature via AppleSMC
- Brightness via DisplayServices private framework
- Battery wattage via IOKit AppleSmartBattery

---

---

## <a name="chinese"></a>中文

# LilyAisland

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS%2015.2+-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="swift">
  <img src="https://img.shields.io/badge/协议-MIT-green" alt="license">
</p>

**LilyAisland** 将 iPhone 灵动岛的体验带到 Mac 菜单栏。它是一个悬浮于屏幕顶部的交互式胶囊形控件，让你一眼就能看到系统状态，并能即时调节音量、亮度、专注模式、电池以及正在播放的音乐。

灵感来自 iPhone 的灵动岛，在 macOS 上重新演绎。

---

## 功能介绍

| 模块 | 说明 |
|---|---|
| 正在播放 | Apple Music 当前曲目、艺术家、专辑封面和播放进度。支持播放/暂停、上一首、下一首。 |
| 音量 | 拦截系统音量键，显示自定义 HUD，替代系统原生弹窗。 |
| 亮度 | 平滑的橡皮筋式亮度过渡动画，替代原生调节弹窗。 |
| 电池 | 实时电量百分比、充/放电功率（IOKit）、电源适配器功率。插拔电源和低电量提醒。 |
| 专注模式 | 自定义勿扰模式切换指示器。可选系统音效反馈。 |
| 连接设备 | 蓝牙设备连接/断开通知，支持设备类型识别（AirPods、耳机、音箱）。 |
| 系统状态 | CPU、GPU、内存使用率及温度读数（AppleSMC）。 |
| 多语言 | 完整的中文和 English 支持，可在设置中即时切换。 |

点击灵动岛可展开详细视图，查看系统仪表盘、完整音乐播放器、电池信息和已连接设备。

---

## 系统要求

| 要求 | 详情 |
|---|---|
| **系统** | macOS 15.2 (Sequoia) 及以上 |
| **芯片** | Apple Silicon（原生）/ Intel（兼容） |
| **Xcode** | 16+（仅用于从源码构建） |

需要辅助功能权限：LilyAisland 使用 `CGEventTap` 拦截硬件按键。首次启动时，在 **系统设置 > 隐私与安全性 > 辅助功能** 中授予权限。

---

## 安装

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

然后在 Xcode 中选择 **Product > Archive**，或直接构建：

```bash
xcodebuild -project LilyAisland.xcodeproj \
  -scheme LilyAisland \
  -configuration Release \
  build
```

将构建后的 app 从 DerivedData 拷贝到 `/应用程序/`。

---

## 使用方法

| 操作 | 方式 |
|---|---|
| **查看状态** | 扫一眼灵动岛，彩色圆点显示 CPU 和内存负载。 |
| **悬停** | 鼠标移到灵动岛上，显示迷你均衡器或播放摘要。 |
| **点击展开** | 点击灵动岛展开完整仪表盘。 |
| **调节音量** | 按下键盘音量键，自定义滑动条出现。 |
| **调节亮度** | 按下键盘亮度键，平滑滑动条动画显示。 |
| **切换专注** | 按下勿扰模式/专注键（F6 或月亮键）。 |
| **电池提醒** | 插拔充电器或电量低于阈值时弹出提示。 |
| **蓝牙设备** | 连接/断开蓝牙音频设备时显示设备名称。 |
| **设置** | 点击菜单栏图标，选择 **设置...** |

---

## 设置

| 分类 | 选项 |
|---|---|
| **通用** | 开机启动、触觉反馈、全屏时悬停展开、刘海圆角半径（4-16 pt）、语言。 |
| **电池** | 启用/禁用提醒、插拔通知、显示百分比、弹窗驻留时长（1-10 秒）、低电量阈值（5-50%）。 |
| **连接设备** | 启用/禁用蓝牙提醒、显示设备名称。 |
| **专注** | 启用/禁用专注切换、弹窗驻留时长（1-10 秒）、进入时播放声音、隐藏标签。 |
| **显示** | 启用/禁用亮度弹窗、驻留时长（1-5 秒）。 |
| **声音** | 启用/禁用音量弹窗、驻留时长（1-5 秒）。 |
| **正在播放** | 启用/禁用、显示专辑封面、显示进度条、轮询间隔（0.5-5 秒）。 |

---

## 隐私说明

LilyAisland 完全在本地运行。它不会：

- 收集任何分析数据或遥测数据
- 通过网络发送数据
- 访问你的麦克风、摄像头或位置信息
- 读取自身沙盒之外的文件

唯一需要的权限是**辅助功能**（用于拦截键盘事件，替代系统音量/亮度 HUD）。

---

## 开源协议

MIT 协议。详见 [LICENSE](LICENSE) 文件。

---

## 鸣谢

由 [CHOWLAN233](https://github.com/CHOWLAN233) 构建。

- 灵感源自 iPhone 14 Pro+ 的灵动岛
- 系统温度读取通过 AppleSMC
- 亮度控制通过 DisplayServices 私有框架
- 电池功率计算通过 IOKit AppleSmartBattery
