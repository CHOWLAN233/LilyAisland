import Foundation
import Darwin
import Combine
import IOKit

// MARK: - SMC 温度读取
private enum SMC {
    private static var conn: io_connect_t = 0
    private static var opened = false

    // SMC 数据结构
    private struct SMCKeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttr: UInt8 = 0
    }

    static func open() -> Bool {
        if opened { return true }
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        let r = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        opened = (r == kIOReturnSuccess)
        return opened
    }

    static func close() {
        if opened { IOServiceClose(conn); opened = false }
    }

    private static func readKeyInfo(_ key: String) -> (UInt32, UInt32)? {
        var input: [UInt8] = Array(key.utf8) + [UInt8](repeating: 0, count: max(0, 5 - key.utf8.count))
        var output = SMCKeyInfo()
        var size = MemoryLayout<SMCKeyInfo>.size
        let kr = input.withUnsafeMutableBytes { inp in
            withUnsafeMutablePointer(to: &output) { outp in
                IOConnectCallStructMethod(conn, 9, inp.baseAddress!, 5, outp, &size)
            }
        }
        guard kr == kIOReturnSuccess else { return nil }
        return (output.dataSize, output.dataType)
    }

    static func read(_ key: String) -> Double? {
        guard opened else { return nil }
        guard let (dataSize, _) = readKeyInfo(key), dataSize > 0, dataSize <= 8 else { return nil }

        let ds = Int(dataSize)
        let input = [UInt8(2)] + Array(key.utf8) + [UInt8](repeating: 0, count: max(0, 5 - key.utf8.count)) + [0, 0]
        var output = [UInt8](repeating: 0, count: ds)
        var outSize = ds

        let kr = input.withUnsafeBytes { inp in
            output.withUnsafeMutableBytes { outp in
                IOConnectCallStructMethod(conn, 5, inp.baseAddress!, input.count, outp.baseAddress!, &outSize)
            }
        }
        guard kr == kIOReturnSuccess else { return nil }

        if dataSize == 2 {
            let raw = (UInt16(output[0]) << 8) | UInt16(output[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        } else if dataSize >= 4 {
            let raw = (UInt32(output[0]) << 24) | (UInt32(output[1]) << 16) | (UInt32(output[2]) << 8) | UInt32(output[3])
            return Double(Int32(bitPattern: raw)) / 65536.0
        }
        return nil
    }

    static func anyTemp(_ keys: [String]) -> Double? {
        for k in keys { if let v = read(k), v > 0, v < 150 { return v } }
        return nil
    }
}

// MARK: - GPU 利用率读取
private func gpuUtilization() -> Double {
    var iterator: io_iterator_t = 0
    // IOAccelerator 是 Apple GPU 驱动的通用类名
    guard IOServiceGetMatchingServices(kIOMasterPortDefault,
                                        IOServiceMatching("IOAccelerator"),
                                        &iterator) == kIOReturnSuccess else { return 0 }

    defer { IOObjectRelease(iterator) }
    var maxUtil: Double = 0
    var device = IOIteratorNext(iterator)
    while device != 0 {
        if let props = IORegistryEntryCreateCFProperty(device, "PerformanceStatistics" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
            // Apple Silicon 用 "GPU Core Utilization"
            if let v = props["GPU Core Utilization"] as? Double, v > 0 { maxUtil = max(maxUtil, v) }
            // Intel 用 "GPU Utilization" 或 "utilization"
            if let v = props["GPU Utilization"] as? Int, v > 0 { maxUtil = max(maxUtil, Double(v) / 100.0) }
            if let v = props["Device Utilization %"] as? Int, v > 0 { maxUtil = max(maxUtil, Double(v) / 100.0) }
            // 百分比整数格式
            if let v = props["GPU Activity(%)"] as? Int, v >= 0 { maxUtil = max(maxUtil, Double(v) / 100.0) }
        }
        IOObjectRelease(device)
        device = IOIteratorNext(iterator)
    }
    return min(1.0, maxUtil)
}

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var memoryUsedString: String = "0 GB"

    @Published var gpuUsage: Double = 0.0
    @Published var cpuTemp: Double = 0.0
    @Published var gpuTemp: Double = 0.0

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    func start() {
        _ = SMC.open()
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

        // GPU 利用率
        gpuUsage = gpuUtilization()

        // 温度：常见 SMC 键（Intel key / Apple Silicon key 合并探测）
        cpuTemp = SMC.anyTemp(["TC0P", "TC0p", "Tp09", "Tp0T", "Tp01"]) ?? 0
        gpuTemp = SMC.anyTemp(["TG0P", "TG0p", "Tg0d", "Tg0T"]) ?? 0
    }

    // MARK: - CPU
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

    // MARK: - 物理内存
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
