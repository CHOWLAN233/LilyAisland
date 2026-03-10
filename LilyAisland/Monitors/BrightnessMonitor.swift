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
    private var eventTap: CFMachPort?
    
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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) { return }
        
        updateBrightnessValue()
        setupEventTap()
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
                            // 原生标准步长 1/16
                            monitor.adjustBrightness(increment: keyCode == 2 ? 0.0625 : -0.0625)
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
        internalTargetBrightness = max(0.0, min(1.0, internalTargetBrightness + increment))
        let targetValue = internalTargetBrightness
        
        // 1. 瞬间刷新 UI，进度条绝对跟手
        DispatchQueue.main.async {
            self.brightness = targetValue
            self.showBrightnessUI = true
            self.hideTimer?.invalidate()
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.showBrightnessUI = false
            }
            
            // 2. 启动原生级别的硬件平滑插值引擎
            self.startHardwareAnimator()
        }
    }
    
    private func startHardwareAnimator() {
        if hardwareAnimator != nil { return }
        
        // 以 60Hz 的完美帧率运行插值动画
        hardwareAnimator = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 锁定当前目标值，准备交给后台派发
            let target = self.internalTargetBrightness
            
            self.hardwareQueue.async {
                let diff = target - self.currentPhysicalBrightness
                
                // 差值极小（已达到目标），终止动画释放系统资源
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
                
                // --- 【原生手感的灵魂】 ---
                // 指数平滑（Exponential Smoothing）
                // 每次逼近剩余差距的 25%。无论你点按多快，物理屏幕都自带极致丝滑的缓动刹车 (Ease-Out)
                self.currentPhysicalBrightness += diff * 0.25
                
                if let setB = self.setBrightnessNative {
                    _ = setB(CGMainDisplayID(), Float(self.currentPhysicalBrightness))
                }
            }
        }
        
        // 将 Timer 加入 .common 模式，防止你在拖拽其他窗口或进行复杂交互时动画被系统挂起掉帧
        RunLoop.main.add(hardwareAnimator!, forMode: .common)
    }
    
    private func updateBrightnessValue() {
        hardwareQueue.async {
            var currentRealBrightness: Float = 0.5
            if let getBrightness = self.getBrightnessNative {
                _ = getBrightness(CGMainDisplayID(), &currentRealBrightness)
                
                let actualValue = Double(currentRealBrightness)
                self.currentPhysicalBrightness = actualValue
                
                DispatchQueue.main.async {
                    self.internalTargetBrightness = actualValue
                    self.brightness = actualValue
                }
            }
        }
    }
}
