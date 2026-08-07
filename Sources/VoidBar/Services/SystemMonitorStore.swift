import Foundation
import Combine

@MainActor
final class SystemMonitorStore: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    
    // Network speeds in bytes per second
    @Published var networkDownloadSpeed: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0

    private var timer: Timer?

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private var previousCPUInfo: processor_info_array_t?
    private var previousCPUInfoCnt: mach_msg_type_number_t = 0
    private var previousTotalTicks: Double = 0
    private var previousIdleTicks: Double = 0
    
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var lastPollTime: Date = Date()

    private func poll() {
        pollCPU()
        pollMemory()
        pollNetwork()
    }

    private func pollCPU() {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCnt: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &cpuCount,
                                         &cpuInfo,
                                         &cpuInfoCnt)

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }

        var totalTicks: Double = 0
        var idleTicks: Double = 0

        for i in 0..<Int(cpuCount) {
            let offset = i * Int(CPU_STATE_MAX)
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])

            totalTicks += user + system + idle + nice
            idleTicks += idle
        }

        if previousTotalTicks > 0 {
            let totalDiff = totalTicks - previousTotalTicks
            let idleDiff = idleTicks - previousIdleTicks

            if totalDiff > 0 {
                let usage = (1.0 - (idleDiff / totalDiff)) * 100.0
                self.cpuUsage = max(0, min(100, usage))
            }
        }

        if let prevInfo = previousCPUInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(previousCPUInfoCnt) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        previousCPUInfo = cpuInfo
        previousCPUInfoCnt = cpuInfoCnt
        previousTotalTicks = totalTicks
        previousIdleTicks = idleTicks
    }

    private func pollMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        let usedMemory = Double(active + wired + compressed)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

        if totalMemory > 0 {
            self.memoryUsage = (usedMemory / totalMemory) * 100.0
        }
    }
    
    private func pollNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            let interface = ptr?.pointee
            
            // Look for interface link layer data (AF_LINK)
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_LINK) {
                if let data = interface?.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    bytesIn += UInt64(networkData.ifi_ibytes)
                    bytesOut += UInt64(networkData.ifi_obytes)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastPollTime)
        
        if previousBytesIn > 0 && previousBytesOut > 0 && timeInterval > 0 {
            let inDiff = bytesIn > previousBytesIn ? bytesIn - previousBytesIn : 0
            let outDiff = bytesOut > previousBytesOut ? bytesOut - previousBytesOut : 0
            
            self.networkDownloadSpeed = Double(inDiff) / timeInterval
            self.networkUploadSpeed = Double(outDiff) / timeInterval
        }
        
        self.previousBytesIn = bytesIn
        self.previousBytesOut = bytesOut
        self.lastPollTime = now
    }
}
