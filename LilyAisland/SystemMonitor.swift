//
//  SystemMonitor.swift
//  LilyAisland
//
//  Created by gongzichao on 2026/3/8.
//

import Foundation
import Darwin
import Combine

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var memoryUsedString: String = "0 GB"
    
    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?
    
    // 开始监听（每 1.5 秒刷新一次，兼顾实时性与省电）
    func start() {
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func updateStats() {
        cpuUsage = getCPUUsage()
        let mem = getMemoryUsage()
        memoryUsage = mem.percentage
        memoryUsedString = String(format: "%.1f GB", mem.used)
    }
    
    // MARK: - 调用底层 Mach 内核接口获取 CPU
    private func getCPUUsage() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        if let prev = previousCPUInfo {
            let user = Double(cpuInfo.cpu_ticks.0) - Double(prev.cpu_ticks.0)
            let system = Double(cpuInfo.cpu_ticks.1) - Double(prev.cpu_ticks.1)
            let idle = Double(cpuInfo.cpu_ticks.2) - Double(prev.cpu_ticks.2)
            let nice = Double(cpuInfo.cpu_ticks.3) - Double(prev.cpu_ticks.3)
            
            let totalTicks = user + system + idle + nice
            let usedTicks = user + system + nice
            
            previousCPUInfo = cpuInfo
            return totalTicks > 0 ? (usedTicks / totalTicks) : 0.0
        } else {
            previousCPUInfo = cpuInfo
            return 0.0
        }
    }
    
    // MARK: - 调用底层 Mach 内核接口获取物理内存
    private func getMemoryUsage() -> (percentage: Double, used: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0.0, 0.0) }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        
        let usedMemory = active + wired + compressed
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        let usedGB = usedMemory / (1024 * 1024 * 1024)
        let percentage = physicalMemory > 0 ? (usedMemory / physicalMemory) : 0.0
        
        return (percentage, usedGB)
    }
}
