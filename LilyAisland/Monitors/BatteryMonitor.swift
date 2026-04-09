import Foundation
import SwiftUI
import Combine
import IOKit.ps
import IOKit // 🌟 必须引入基础 IOKit 来查询底层硬件树

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var showBatteryUI: Bool = false
    
    // 底层电源数据状态
    @Published var isUsingAC: Bool = true
    @Published var adapterWattage: Int = 0
    @Published var batteryWattage: Double = 0.0
    
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
        
        // 每秒狂飙，抓取底层实时跳动数据
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo(triggerUI: true)
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    private func updateBatteryInfo(triggerUI: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        let providingSource = IOPSGetProvidingPowerSourceType(snapshot).takeRetainedValue() as String
        let isConnectedNow = (providingSource == kIOPSACPowerValue as String)
        
        var currentAdapterW = 0
        var currentBatteryW = 0.0
        
        // 🌟 终极解决方案：直接读取 IORegistry 硬件底层的 AppleSmartBattery
        // (传 0 代表自动匹配当前 macOS 版本的默认主端口，防止低版本报错)
        let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                if let dict = props?.takeRetainedValue() as? [String: Any] {
                    // 读取主板最底层的毫安和毫伏
                    let amp = dict["Amperage"] as? Int ?? 0
                    let volt = dict["Voltage"] as? Int ?? 0
                    
                    // 计算动态实时功率 W = V * A
                    currentBatteryW = abs((Double(amp) / 1000.0) * (Double(volt) / 1000.0))
                    
                    // 适配器功率通常也会下发在这个节点
                    if let adapterInfo = dict["AdapterDetails"] as? [String: Any],
                       let watts = adapterInfo["Watts"] as? Int {
                        currentAdapterW = watts
                    }
                }
            }
            IOObjectRelease(service) // 用完必须释放，防止内存泄漏
        }
        
        // 配合常规接口刷新 UI 基础状态 (电量/弹窗)
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any] else { continue }
            
            // 如果 IORegistry 没读到适配器瓦数（部分老款 Mac 会出现），退回从上层 IOPS 里读取
            if currentAdapterW == 0 {
                if let adapterDetails = info["Adapter Details"] as? [String: Any],
                   let watts = adapterDetails["Watts"] as? Int {
                    currentAdapterW = watts
                }
            }
            
            if let capacity = info[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey as String] as? Int {
                
                let level = Int((Double(capacity) / Double(maxCapacity)) * 100)
                
                DispatchQueue.main.async {
                    self.batteryLevel = level
                    self.isCharging = isConnectedNow
                    
                    // 同步硬件底层级数据给前端 UI
                    self.isUsingAC = isConnectedNow
                    self.adapterWattage = currentAdapterW
                    self.batteryWattage = currentBatteryW
                    
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
