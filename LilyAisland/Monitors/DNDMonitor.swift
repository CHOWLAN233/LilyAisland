import Foundation
import SwiftUI
import Combine
import ApplicationServices
import AppKit // 🌟 新增：为了使用 NSSound 播放提示音

class DNDMonitor: ObservableObject {
    @Published var isDNDOn: Bool = false
    @Published var showDNDUI: Bool = false
    
    private var hideTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // 🌟 1. 安全读取用户的偏好设置
    private var isFocusEnabled: Bool {
        if UserDefaults.standard.object(forKey: "focus_enabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "focus_enabled")
    }
    
    private var focusDuration: Double {
        if UserDefaults.standard.object(forKey: "focus_duration") == nil { return 2.0 }
        return UserDefaults.standard.double(forKey: "focus_duration")
    }
    
    func start() {
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted {
            return
        }
        
        fetchDNDState(triggerUI: false)
        setupEventTap()
    }
    
    private func setupEventTap() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << 14)
        
        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            let monitor = Unmanaged<DNDMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            
            // 🌟 2. 总开关：如果用户在设置里关闭了 Focus 模块，直接放行，不拦截按键
            guard monitor.isFocusEnabled else {
                return Unmanaged.passUnretained(event)
            }
            
            // --- 拦截 1：普通 F6 键及现代 Mac 专注模式键 ---
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                // 97 是标准的 F6 键，178 是现代 Mac 的月亮专属键
                if keyCode == 97 || keyCode == 178 {
                    monitor.handleInterceptedKey()
                    return nil
                }
            }
            
            // --- 拦截 2：多媒体功能键通道 ---
            if type.rawValue == 14 {
                if let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 {
                    let data = nsEvent.data1
                    let keyCode = (data & 0xFFFF0000) >> 16
                    let keyFlags = (data & 0x0000FFFF)
                    let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
                    
                    if keyState {
                        if keyCode == 131 || keyCode == 11 {
                            monitor.handleInterceptedKey()
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
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func handleInterceptedKey() {
        DispatchQueue.global(qos: .userInitiated).async {
            // 🌟 3. 声音逻辑：如果开启了提示音，按下按键时伴随清脆的反馈
            let shouldPlaySound = UserDefaults.standard.bool(forKey: "focus_play_sound")
            if shouldPlaySound {
                DispatchQueue.main.async {
                    NSSound(named: "Glass")?.play()
                }
            }
            
            // 🌟 4. 核心修复：彻底删除了报错时强行按 Esc (key code 53) 的逻辑
            let script = """
            tell application "System Events"
                tell application process "ControlCenter"
                    try
                        click menu bar item "控制中心" of menu bar 1
                        delay 0.15
                        click checkbox 1 of scroll area 1 of window "控制中心"
                        delay 0.15
                        click menu bar item "控制中心" of menu bar 1
                    on error
                        -- 即使找不到菜单栏（比如全屏模式下），也安静地失败，绝不触发 Esc 退出全屏
                    end try
                end tell
            end tell
            """
            
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                self.isDNDOn.toggle()
                self.triggerDNDUI()
            }
        }
    }
    
    private func fetchDNDState(triggerUI: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            return "false"
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                let isOn = (output.stringValue == "true")
                
                DispatchQueue.main.async {
                    self.isDNDOn = isOn
                    if triggerUI { self.triggerDNDUI() }
                }
            }
        }
    }
    
    private func triggerDNDUI() {
        self.showDNDUI = true
        self.hideTimer?.invalidate()
        
        // 🌟 5. 替换为读取用户设置的滑动条时间！
        self.hideTimer = Timer.scheduledTimer(withTimeInterval: focusDuration, repeats: false) { [weak self] _ in
            self?.showDNDUI = false
        }
    }
}
