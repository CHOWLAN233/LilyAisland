import Foundation
import SwiftUI
import Combine
import IOBluetooth
import AppKit
import ApplicationServices

class ConnectivityMonitor: ObservableObject {
    @Published var showConnectivityUI: Bool = false
    @Published var connectedDeviceName: String = ""
    @Published var isConnected: Bool = false
    @Published var deviceType: ConnectivityDeviceType = .unknown

    enum ConnectivityDeviceType {
        case airpods
        case bluetoothHeadphones
        case wiredHeadphones
        case bluetoothSpeaker
        case unknown

        var icon: String {
            switch self {
            case .airpods: return "airpodspro"
            case .bluetoothHeadphones, .wiredHeadphones, .unknown: return "headphones"
            case .bluetoothSpeaker: return "hifispeaker.fill"
            }
        }

        var label: String {
            switch self {
            case .airpods: return "AirPods"
            case .bluetoothHeadphones: return "Bluetooth"
            case .wiredHeadphones: return "Headphones"
            case .bluetoothSpeaker: return "Speaker"
            case .unknown: return "Device"
            }
        }

        /// 用于本地化的 L10n Key —— 在 UI 层通过 loc() 翻译为中文/英文
        var localizationKey: L10n {
            switch self {
            case .airpods: return .device_airpods
            case .bluetoothHeadphones, .wiredHeadphones: return .device_headphones
            case .bluetoothSpeaker: return .device_speaker
            case .unknown: return .device_unknown_type
            }
        }
    }

    // --- 与 VolumeMonitor/BrightnessMonitor 结构完全对齐 ---
    private var hideTimer: Timer?
    private var syncTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // IOBluetooth 通知对象（强引用 → 部分 macOS 版本自动抑制系统弹窗）
    private var connectNotification: IOBluetoothUserNotification?

    // 轮询状态追踪
    private var lastConnectedDevices: Set<String> = []
    private var connectionTimestamps: [String: Date] = [:]
    private var hasCompletedInitialScan = false

    // 用户设置
    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "connectivity_enabled") }
    var showDeviceName: Bool { UserDefaults.standard.bool(forKey: "connectivity_show_device_name") }
    var displayDuration: Double {
        let val = UserDefaults.standard.double(forKey: "connectivity_duration")
        return val > 0 ? val : 3.0
    }

    // MARK: - start（完全参照 VolumeMonitor 结构）
    func start() {
        if UserDefaults.standard.object(forKey: "connectivity_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "connectivity_enabled")
            UserDefaults.standard.set(true, forKey: "connectivity_show_device_name")
            UserDefaults.standard.set(3.0, forKey: "connectivity_duration")
        }

        guard isEnabled else { return }

        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted { return } // CGEventTap 需要辅助功能权限

        // 1️⃣ IOBluetooth 注册：获取设备名和类型
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(bluetoothDeviceDidConnect(_:device:))
        )

        // 2️⃣ CGEventTap：拦截蓝牙系统事件（与音量/亮度共享同一事件通道）
        setupEventTap()

        // 3️⃣ 后台状态同步（等价于 VolumeMonitor.startSyncTimer）
        startSyncTimer()
    }

    deinit {
        syncTimer?.invalidate()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
    }

    // MARK: - 后台状态同步（完全参照 VolumeMonitor.startSyncTimer）
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 仅在未显示 UI 时轮询，不干扰用户交互
            if !self.showConnectivityUI {
                self.pollDeviceStates()
            }
        }
        if let syncTimer = syncTimer {
            RunLoop.main.add(syncTimer, forMode: .common)
        }

        // 延迟首次扫描
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pollDeviceStates()
        }
    }

    // MARK: - CGEventTap（完全参照 VolumeMonitor.setupEventTap）
    private func setupEventTap() {
        let eventMask = CGEventMask(1 << 14) // NX_SYSDEFINED

        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type.rawValue == 14 {
                guard let nsEvent = NSEvent(cgEvent: event) else {
                    return Unmanaged.passUnretained(event)
                }
                if nsEvent.subtype.rawValue == 8 {
                    let data = nsEvent.data1
                    let keyCode = (data & 0xFFFF0000) >> 16
                    let keyFlags = (data & 0x0000FFFF)
                    let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA

                    if keyState {
                        // 蓝牙设备连接/断开在 Apple Vendor Page (0xFF00) 上触发的事件。
                        // 已知 mac 实测 keyCode：
                        //   0xB0 = 蓝牙外设已连接
                        //   0xB1 = 蓝牙外设已断开
                        // 这些 keyCode 与音量(0,1,7)/亮度(2,3) 互不冲突。
                        if keyCode == 0xB0 || keyCode == 0xB1 {
                            let monitor = Unmanaged<ConnectivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                            guard monitor.isEnabled else {
                                return Unmanaged.passUnretained(event)
                            }
                            monitor.handleInterceptedEvent(connected: keyCode == 0xB0)
                            return nil // 🔑 吞事件 —— 阻止系统弹原生窗
                        }
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: eventMask, callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - 处理拦截到的蓝牙系统事件（参照 VolumeMonitor.handleInterceptedKey）
    private func handleInterceptedEvent(connected: Bool) {
        DispatchQueue.main.async {
            // 优先使用 IOBluetooth 回调已获取的准确名称
            if connected && self.connectedDeviceName.isEmpty {
                self.connectedDeviceName = "Bluetooth Device"
                self.deviceType = .bluetoothHeadphones
                self.connectionTimestamps[self.connectedDeviceName] = Date()
            }
            self.isConnected = connected
            // 不弹窗 —— 蓝牙状态在 expanded 面板展示
        }
    }

    // MARK: - IOBluetooth 回调：获取准确的设备名称和类型
    @objc private func bluetoothDeviceDidConnect(_ notification: Any, device: Any) {
        guard isEnabled else { return }
        guard let btDevice = device as? IOBluetoothDevice,
              let name = btDevice.nameOrAddress else { return }

        let type = classifyDevice(btDevice)

        DispatchQueue.main.async {
            self.connectedDeviceName = name
            self.deviceType = type
            self.isConnected = true
            self.connectionTimestamps[name] = Date()
            self.lastConnectedDevices.insert(name)
            // 不弹窗 —— 蓝牙信息整合在 expanded 面板中显示
        }
    }

    // MARK: - 轮询设备状态（等价于 VolumeMonitor.executeVolumeFetch）
    private func pollDeviceStates() {
        guard isEnabled else { return }
        guard let paired = IOBluetoothDevice.pairedDevices() else { return }

        var foundDevices: [String: IOBluetoothDevice] = [:]
        for element in paired {
            guard let device = element as? IOBluetoothDevice,
                  device.isConnected(),
                  let name = device.nameOrAddress else { continue }
            foundDevices[name] = device
        }

        let foundNames = Set(foundDevices.keys)
        let now = Date()

        if !hasCompletedInitialScan {
            lastConnectedDevices = foundNames
            for name in foundNames { connectionTimestamps[name] = now }
            hasCompletedInitialScan = true
            return
        }

        // 新连接（轮询兜底，防抖 2s）
        let added = foundNames.subtracting(lastConnectedDevices)
        for name in added {
            if let device = foundDevices[name] {
                connectionTimestamps[name] = now
                let type = classifyDevice(device)
                DispatchQueue.main.async {
                    self.connectedDeviceName = name
                    self.isConnected = true
                    self.deviceType = type
                    // 不弹窗 —— expanded 面板展示
                }
            }
        }

        // 断开（防抖 2s）
        let removed = lastConnectedDevices.subtracting(foundNames)
        for name in removed {
            if let ts = connectionTimestamps[name], now.timeIntervalSince(ts) < 2.0 { continue }
            connectionTimestamps[name] = nil
            DispatchQueue.main.async {
                self.connectedDeviceName = name
                self.isConnected = false
                self.deviceType = .bluetoothHeadphones
                // 不弹窗 —— expanded 面板展示
            }
        }

        lastConnectedDevices = foundNames
    }

    // MARK: - 设备类型判断
    private func classifyDevice(_ device: IOBluetoothDevice) -> ConnectivityDeviceType {
        guard let rawName = device.nameOrAddress else { return .bluetoothHeadphones }
        let name = rawName.lowercased()
        if name.contains("airpods") || name.contains("airpod") { return .airpods }
        let cod = device.classOfDevice
        let majorDevice = (cod >> 8) & 0x1F
        if majorDevice == 0x05 { return .bluetoothHeadphones }
        if majorDevice == 0x06 || name.contains("speaker") { return .bluetoothSpeaker }
        return .bluetoothHeadphones
    }

    // MARK: - 触发自定义 UI（完全参照 VolumeMonitor.triggerVolumeUI）
    private func triggerConnectivityUI() {
        showConnectivityUI = true
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.showConnectivityUI = false
        }
    }
}
