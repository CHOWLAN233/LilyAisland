import Foundation
import AppKit
import Combine
import ApplicationServices

class VolumeMonitor: ObservableObject {
    @Published var volume: Double = 0.5
    @Published var showVolumeUI: Bool = false
    
    private var hideTimer: Timer?
    private var syncTimer: Timer? // 【新增】用于监听外部音量变化
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "volume_enabled") }
    private var displayDuration: Double {
        let val = UserDefaults.standard.double(forKey: "volume_duration")
        return val > 0 ? val : 2.0
    }
    private var stepSize: Double {
        let val = UserDefaults.standard.double(forKey: "volume_step")
        return val > 0 ? val : 0.0625
    }
    
    func start() {
        if UserDefaults.standard.object(forKey: "volume_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "volume_enabled")
            UserDefaults.standard.set(2.0, forKey: "volume_duration")
            UserDefaults.standard.set(0.0625, forKey: "volume_step")
        }

        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted { return } // 等待用户授权

        executeVolumeFetch(triggerUI: false)
        setupEventTap() // 启动底层拦截器
        startSyncTimer() // 【新增】启动状态同步
    }
    
    // --- 【新增】后台状态同步 ---
    private func startSyncTimer() {
        // 每秒同步一次系统真实音量（比如用户拖动了控制中心、碰了 TouchBar）
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 仅在没有显示音量 UI（即用户没在频繁狂按键盘）时才执行同步，防止打断用户的手动输入
            if !self.showVolumeUI {
                self.executeVolumeFetch(triggerUI: false)
            }
        }
        
        if let syncTimer = syncTimer {
            // 加入 common 模式防止主线程拖拽等操作阻塞定时器
            RunLoop.main.add(syncTimer, forMode: .common)
        }
    }
    
    private func setupEventTap() {
        let eventMask = CGEventMask(1 << 14) // 14 代表 NX_SYSDEFINED
        
        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type.rawValue == 14 {
                guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
                
                if nsEvent.subtype.rawValue == 8 {
                    let data = nsEvent.data1
                    let keyCode = (data & 0xFFFF0000) >> 16
                    let keyFlags = (data & 0x0000FFFF)
                    let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
                    
                    if keyState {
                        if keyCode == 0 || keyCode == 1 || keyCode == 7 {
                            let monitor = Unmanaged<VolumeMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                            guard monitor.isEnabled else { return Unmanaged.passUnretained(event) }
                            monitor.handleInterceptedKey(keyCode: Int(keyCode))
                            return nil // 核心魔法：吞掉按键，干掉系统原生音量方块
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
    
    private func handleInterceptedKey(keyCode: Int) {
        // --- 【核心修复：脱离 AppleScript 计算，实现零延迟跟手】 ---
        var newVolume = self.volume
        var isMuteToggle = false
        
        if keyCode == 0 { // 加音量
            newVolume = min(1.0, self.volume + self.stepSize)
        } else if keyCode == 1 { // 减音量
            newVolume = max(0.0, self.volume - self.stepSize)
        } else if keyCode == 7 { // 静音
            isMuteToggle = true
        } else {
            return
        }
        
        // 1. 瞬间刷新 UI，进度条绝对跟手，不再忍受 AppleScript 的延迟
        DispatchQueue.main.async {
            if !isMuteToggle {
                self.volume = newVolume
            }
            self.triggerVolumeUI()
        }
        
        // 2. 将最终计算好的绝对值交给后台，静默执行物理音量调整
        DispatchQueue.global(qos: .userInitiated).async {
            let script: String
            if isMuteToggle {
                script = "set volume output muted not (output muted of (get volume settings))"
            } else {
                // 直接写入计算好的绝对值 (0~100)
                let scaledVolume = Int(newVolume * 100)
                script = "set volume output volume \(scaledVolume)"
            }
            
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            // 3. 执行完毕后，拉取一次真实状态进行校准兜底（例如防范系统设定的最小/最大音量限制）
            self.executeVolumeFetch(triggerUI: false)
        }
    }
    
    private func executeVolumeFetch(triggerUI: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            set volSettings to get volume settings
            set vol to output volume of volSettings
            set isMute to output muted of volSettings
            if isMute then
                return "0"
            else
                return vol as string
            end if
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                if let volStr = output.stringValue, let vol = Double(volStr) {
                    let normalizedVol = vol / 100.0
                    DispatchQueue.main.async {
                        // 防抖优化：只有当实际音量和内部记录出现偏差时，才真正修改 UI
                        if abs(self.volume - normalizedVol) > 0.01 {
                            self.volume = normalizedVol
                        }
                        if triggerUI { self.triggerVolumeUI() }
                    }
                }
            }
        }
    }
    
    private func triggerVolumeUI() {
        showVolumeUI = true
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.showVolumeUI = false
        }
    }
}
