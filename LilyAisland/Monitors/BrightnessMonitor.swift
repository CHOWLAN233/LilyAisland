import Foundation
import AppKit
import Combine
import ApplicationServices

class BrightnessMonitor: ObservableObject {
    @Published var brightness: Double = 0.5
    @Published var showBrightnessUI: Bool = false
    
    // --- 【苹果原生逻辑核心】 ---
    // UI 显示的逻辑目标亮度（瞬间跟手）
    private var internalTargetBrightness: Double = 0.5
    // 硬件正在渲染的真实物理亮度（橡皮筋追赶）
    private var currentPhysicalBrightness: Double = 0.5
    
    private var hideTimer: Timer?
    private var hardwareAnimator: Timer?
    private var syncTimer: Timer?
    private var eventTap: CFMachPort?

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "brightness_enabled") }
    private var displayDuration: Double {
        let val = UserDefaults.standard.double(forKey: "brightness_duration")
        return val > 0 ? val : 2.0
    }
    private var stepSize: Double {
        let val = UserDefaults.standard.double(forKey: "brightness_step")
        return val > 0 ? val : 0.0625
    }
    
    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    
    private var setBrightnessNative: SetBrightnessFunc?
    private var getBrightnessNative: GetBrightnessFunc?
    
    private let hardwareQueue = DispatchQueue(label: "LilyIsland.brightness.hardware", qos: .userInteractive)
    
    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let handle = handle {
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessNative = unsafeBitCast(setSym, to: SetBrightnessFunc.self)
            }
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessNative = unsafeBitCast(getSym, to: GetBrightnessFunc.self)
            }
        }
    }
    
    func start() {
        if UserDefaults.standard.object(forKey: "brightness_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "brightness_enabled")
            UserDefaults.standard.set(2.0, forKey: "brightness_duration")
            UserDefaults.standard.set(0.0625, forKey: "brightness_step")
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) { return }

        updateBrightnessValue()
        setupEventTap()
        startSyncTimer()
    }
    
    // --- 【新增】后台状态同步 ---
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 关键：只有在我们的插值动画不在运行，且没有显示亮度 UI 时才去同步
            // 避免抢夺用户的交互控制权
            if self.hardwareAnimator == nil && !self.showBrightnessUI {
                self.updateBrightnessValue()
            }
        } // ⬅️ 截图里的报错就是因为少了这一个闭合括号！！！
        
        // 加入 common 模式防止主线程其他 UI 交互阻塞定时器
        if let syncTimer = syncTimer {
            RunLoop.main.add(syncTimer, forMode: .common)
        }
    }
    
    private func setupEventTap() {
        let eventMask = CGEventMask(1 << 14)
        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type.rawValue == 14 {
                guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
                if nsEvent.subtype.rawValue == 8 {
                    let keyCode = (nsEvent.data1 & 0xFFFF0000) >> 16
                    if (((nsEvent.data1 & 0x0000FFFF) & 0xFF00) >> 8) == 0xA {
                        if keyCode == 2 || keyCode == 3 {
                            let monitor = Unmanaged<BrightnessMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                            guard monitor.isEnabled else { return Unmanaged.passUnretained(event) }
                            monitor.adjustBrightness(increment: keyCode == 2 ? monitor.stepSize : -monitor.stepSize)
                            return nil
                        }
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: eventMask, callback: tapCallback,
                                    userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func adjustBrightness(increment: Double) {
        var realBrightness: Float = 0.0
        if let getBrightness = self.getBrightnessNative {
            _ = getBrightness(CGMainDisplayID(), &realBrightness)
            let actualValue = Double(realBrightness)
            
            if abs(self.internalTargetBrightness - actualValue) > 0.01 {
                self.internalTargetBrightness = actualValue
                self.currentPhysicalBrightness = actualValue
            }
        }
        
        internalTargetBrightness = max(0.0, min(1.0, internalTargetBrightness + increment))
        let targetValue = internalTargetBrightness
        
        DispatchQueue.main.async {
            self.brightness = targetValue
            self.showBrightnessUI = true
            self.hideTimer?.invalidate()
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: self.displayDuration, repeats: false) { [weak self] _ in
                self?.showBrightnessUI = false
            }
            
            self.startHardwareAnimator()
        }
    }
    
    private func startHardwareAnimator() {
        if hardwareAnimator != nil { return }
        
        hardwareAnimator = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let target = self.internalTargetBrightness
            
            self.hardwareQueue.async {
                let diff = target - self.currentPhysicalBrightness
                
                if abs(diff) < 0.001 {
                    self.currentPhysicalBrightness = target
                    if let setB = self.setBrightnessNative {
                        _ = setB(CGMainDisplayID(), Float(target))
                    }
                    DispatchQueue.main.async {
                        self.hardwareAnimator?.invalidate()
                        self.hardwareAnimator = nil
                    }
                    return
                }
                
                self.currentPhysicalBrightness += diff * 0.25
                
                if let setB = self.setBrightnessNative {
                    _ = setB(CGMainDisplayID(), Float(self.currentPhysicalBrightness))
                }
            }
        }
        RunLoop.main.add(hardwareAnimator!, forMode: .common)
    }
    
    private func updateBrightnessValue() {
        hardwareQueue.async {
            var currentRealBrightness: Float = 0.5
            if let getBrightness = self.getBrightnessNative {
                _ = getBrightness(CGMainDisplayID(), &currentRealBrightness)
                
                let actualValue = Double(currentRealBrightness)
                
                DispatchQueue.main.async {
                    if abs(self.brightness - actualValue) > 0.01 {
                        self.internalTargetBrightness = actualValue
                        self.currentPhysicalBrightness = actualValue
                        self.brightness = actualValue
                    }
                }
            }
        }
    }
}
