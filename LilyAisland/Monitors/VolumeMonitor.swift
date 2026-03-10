import Foundation
import AppKit
import Combine
import ApplicationServices

class VolumeMonitor: ObservableObject {
    @Published var volume: Double = 0.5
    @Published var showVolumeUI: Bool = false
    
    private var hideTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    func start() {
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted { return } // 等待用户授权
        
        executeVolumeFetch(triggerUI: false)
        setupEventTap() // 启动底层拦截器
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
        DispatchQueue.global(qos: .userInitiated).async {
            let script: String
            switch keyCode {
            case 0: script = "set volume output volume ((output volume of (get volume settings)) + 6)"
            case 1: script = "set volume output volume ((output volume of (get volume settings)) - 6)"
            case 7: script = "set volume output muted not (output muted of (get volume settings))"
            default: return
            }
            
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            self.executeVolumeFetch(triggerUI: true)
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
                        self.volume = normalizedVol
                        if triggerUI { self.triggerVolumeUI() }
                    }
                }
            }
        }
    }
    
    private func triggerVolumeUI() {
        showVolumeUI = true
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.showVolumeUI = false
        }
    }
}
