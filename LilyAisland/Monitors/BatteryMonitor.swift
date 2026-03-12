import Foundation
import SwiftUI
import Combine
import IOKit.ps

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var showBatteryUI: Bool = false
    
    private var timer: Timer?
    private var hideTimer: Timer?
    private var lastPowerState: Bool?
    private var hasAlertedLowBattery = false
    
    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: "battery_enabled") }
    private var alertOnCharge: Bool { UserDefaults.standard.bool(forKey: "battery_charging_alert") }
    private var lowThreshold: Double { UserDefaults.standard.double(forKey: "battery_low_threshold") }
    private var displayDuration: Double {
        let val = UserDefaults.standard.double(forKey: "battery_duration")
        return val > 0 ? val : 3.0
    }
    
    func start() {
        if UserDefaults.standard.object(forKey: "battery_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "battery_enabled")
            UserDefaults.standard.set(true, forKey: "battery_charging_alert")
            UserDefaults.standard.set(true, forKey: "battery_show_percentage")
            UserDefaults.standard.set(20.0, forKey: "battery_low_threshold")
            UserDefaults.standard.set(3.0, forKey: "battery_duration")
        }
        
        updateBatteryInfo(triggerUI: false)
        
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo(triggerUI: true)
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    private func updateBatteryInfo(triggerUI: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        // 🌟 终极破局：直接询问主板，当前整机的供电来源是不是“交流电源(AC Power)”！
        // 这绕过了 macOS 恶心的“优化电池充电”假死状态
        let providingSource = IOPSGetProvidingPowerSourceType(snapshot).takeRetainedValue() as String
        let isConnectedNow = (providingSource == kIOPSACPowerValue as String)
        
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any] else { continue }
            
            if let capacity = info[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey as String] as? Int {
                
                let level = Int((Double(capacity) / Double(maxCapacity)) * 100)
                
                DispatchQueue.main.async {
                    self.batteryLevel = level
                    // 强制 UI 使用物理连接状态作为“充电中”的依据
                    self.isCharging = isConnectedNow
                    
                    if triggerUI && self.lastPowerState != nil && self.lastPowerState != isConnectedNow {
                        if self.isEnabled && self.alertOnCharge {
                            self.triggerUI()
                        }
                    }
                    
                    if triggerUI && !isConnectedNow && level <= Int(self.lowThreshold) {
                        if self.isEnabled && !self.hasAlertedLowBattery {
                            self.triggerUI()
                            self.hasAlertedLowBattery = true
                        }
                    } else if isConnectedNow || level > Int(self.lowThreshold) {
                        self.hasAlertedLowBattery = false
                    }
                    
                    self.lastPowerState = isConnectedNow
                }
                break
            }
        }
    }
    
    private func triggerUI() {
        self.showBatteryUI = true
        self.hideTimer?.invalidate()
        self.hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.showBatteryUI = false
        }
    }
}
