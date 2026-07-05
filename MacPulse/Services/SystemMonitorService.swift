import Foundation
import Darwin
import IOKit
import IOKit.ps

@Observable
final class SystemMonitorService {
    // MARK: - Published Stats
    var cpuStats = CPUStats(
        usage: 0, userUsage: 0, systemUsage: 0, idleUsage: 0,
        coreUsages: [], temperature: nil, frequency: nil,
        coreCount: 0, modelName: ""
    )
    var memoryStats = MemoryStats(
        total: 0, used: 0, free: 0, wired: 0, active: 0,
        inactive: 0, compressed: 0, swapUsed: 0, swapTotal: 0, pressure: 0
    )
    var diskStats = DiskStats(volumes: [], readBytesPerSec: 0, writeBytesPerSec: 0)
    var batteryStats = BatteryStats(
        percentage: 0, isCharging: false, isPluggedIn: false,
        cycleCount: 0, health: 100, timeRemaining: nil, temperature: nil
    )
    var gpuStats = GPUStats(name: "", usage: 0, vramUsed: 0, vramTotal: 0, temperature: nil)
    var networkStats = NetworkStats(bytesIn: 0, bytesOut: 0, bytesInPerSec: 0, bytesOutPerSec: 0)

    var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    var networkInHistory: [Double] = Array(repeating: 0, count: 60)
    var networkOutHistory: [Double] = Array(repeating: 0, count: 60)

    // MARK: - Private State
    private var previousCPUInfo: host_cpu_load_info?
    private var previousCoreInfos: [host_cpu_load_info] = []
    private var previousNetworkIn: UInt64 = 0
    private var previousNetworkOut: UInt64 = 0
    private var lastNetworkUpdate: Date?
    private var previousDiskIO: DiskIOCounters?
    private var lastDiskIOUpdate: Date?
    private var timer: Timer?

    // MARK: - Init
    init() {
        loadStaticInfo()
        updateAllStats()
    }

    // MARK: - Start/Stop
    func start(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateAllStats()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Static Info
    private func loadStaticInfo() {
        cpuStats.coreCount = ProcessInfo.processInfo.processorCount
        cpuStats.modelName = getCPUModelName()
        cpuStats.coreUsages = Array(repeating: 0, count: cpuStats.coreCount)
    }

    private func getCPUModelName() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var name = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
        return String(cString: name)
    }

    // MARK: - Update All
    private func updateAllStats() {
        updateCPU()
        updateMemory()
        updateDisk()
        updateBattery()
        updateGPU()
        updateNetwork()
    }

    // MARK: - CPU
    private func updateCPU() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if let previous = previousCPUInfo {
            let userDiff = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
            let systemDiff = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
            let idleDiff = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
            let niceDiff = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)

            let totalDiff = userDiff + systemDiff + idleDiff + niceDiff

            if totalDiff > 0 {
                cpuStats.userUsage = (userDiff / totalDiff) * 100
                cpuStats.systemUsage = (systemDiff / totalDiff) * 100
                cpuStats.idleUsage = (idleDiff / totalDiff) * 100
                cpuStats.usage = 100 - cpuStats.idleUsage

                cpuHistory.append(cpuStats.usage)
                if cpuHistory.count > 60 {
                    cpuHistory.removeFirst()
                }
            }
        }

        previousCPUInfo = cpuInfo
        updatePerCoreUsage()
    }

    private func updatePerCoreUsage() {
        var cpuInfoArray: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfoArray,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfoArray = cpuInfoArray else { return }

        let cpuCount = Int(numCPUs)

        if previousCoreInfos.isEmpty {
            previousCoreInfos = Array(repeating: host_cpu_load_info(), count: cpuCount)
        }

        for i in 0..<cpuCount {
            let offset = Int(CPU_STATE_MAX) * i
            let user = cpuInfoArray[offset + Int(CPU_STATE_USER)]
            let system = cpuInfoArray[offset + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfoArray[offset + Int(CPU_STATE_IDLE)]
            let nice = cpuInfoArray[offset + Int(CPU_STATE_NICE)]

            let prevUser = previousCoreInfos[i].cpu_ticks.0
            let prevSystem = previousCoreInfos[i].cpu_ticks.1
            let prevIdle = previousCoreInfos[i].cpu_ticks.2
            let prevNice = previousCoreInfos[i].cpu_ticks.3

            let userDiff = Double(user - Int32(prevUser))
            let systemDiff = Double(system - Int32(prevSystem))
            let idleDiff = Double(idle - Int32(prevIdle))
            let niceDiff = Double(nice - Int32(prevNice))

            let total = userDiff + systemDiff + idleDiff + niceDiff

            if total > 0 && i < cpuStats.coreUsages.count {
                cpuStats.coreUsages[i] = ((userDiff + systemDiff + niceDiff) / total) * 100
            }

            previousCoreInfos[i].cpu_ticks.0 = UInt32(user)
            previousCoreInfos[i].cpu_ticks.1 = UInt32(system)
            previousCoreInfos[i].cpu_ticks.2 = UInt32(idle)
            previousCoreInfos[i].cpu_ticks.3 = UInt32(nice)
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfoArray), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size))
    }

    // MARK: - Memory
    private func updateMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)

        memoryStats.total = ProcessInfo.processInfo.physicalMemory
        memoryStats.free = UInt64(stats.free_count) * pageSize
        memoryStats.active = UInt64(stats.active_count) * pageSize
        memoryStats.inactive = UInt64(stats.inactive_count) * pageSize
        memoryStats.wired = UInt64(stats.wire_count) * pageSize
        memoryStats.compressed = UInt64(stats.compressor_page_count) * pageSize
        memoryStats.used = memoryStats.active + memoryStats.wired + memoryStats.compressed

        // Swap info
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        memoryStats.swapUsed = swapUsage.xsu_used
        memoryStats.swapTotal = swapUsage.xsu_total

        memoryStats.pressure = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: memoryStats.total,
                free: memoryStats.free,
                inactive: memoryStats.inactive,
                wired: memoryStats.wired,
                active: memoryStats.active,
                compressed: memoryStats.compressed,
                swapUsed: memoryStats.swapUsed
            )
        )
    }

    // MARK: - Disk
    private func updateDisk() {
        let fileManager = FileManager.default
        guard let mountedVolumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeNameKey],
            options: [.skipHiddenVolumes]
        ) else { return }

        var volumes: [VolumeInfo] = []

        for volumeURL in mountedVolumes {
            guard let resourceValues = try? volumeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey
            ]) else { continue }

            let total = UInt64(resourceValues.volumeTotalCapacity ?? 0)
            let free = UInt64(resourceValues.volumeAvailableCapacity ?? 0)

            // Skip tiny volumes (< 1GB)
            guard total > 1_000_000_000 else { continue }

            let volume = VolumeInfo(
                name: resourceValues.volumeName ?? volumeURL.lastPathComponent,
                mountPoint: volumeURL.path,
                totalSpace: total,
                freeSpace: free,
                usedSpace: total - free
            )
            volumes.append(volume)
        }

        diskStats.volumes = volumes
        updateDiskThroughput()
    }

    private func updateDiskThroughput() {
        let current = DiskIOReader.currentCounters()
        let now = Date()

        guard let previous = previousDiskIO, let lastUpdate = lastDiskIOUpdate else {
            previousDiskIO = current
            lastDiskIOUpdate = now
            return
        }

        let elapsed = now.timeIntervalSince(lastUpdate)
        let rates = DiskIOCounters.rates(from: previous, to: current, elapsed: elapsed)
        diskStats.readBytesPerSec = rates.readBytes
        diskStats.writeBytesPerSec = rates.writeBytes
        previousDiskIO = current
        lastDiskIOUpdate = now
    }

    // MARK: - Battery
    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else { return }

        if let capacity = description[kIOPSCurrentCapacityKey] as? Int {
            batteryStats.percentage = capacity
        }

        if let isCharging = description[kIOPSIsChargingKey] as? Bool {
            batteryStats.isCharging = isCharging
        }

        if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
            batteryStats.isPluggedIn = (powerSource == kIOPSACPowerValue)
        }

        if let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int, timeRemaining > 0 {
            batteryStats.timeRemaining = timeRemaining
        } else {
            batteryStats.timeRemaining = nil
        }

        // Get cycle count from IOKit
        updateBatteryCycleCount()
    }

    private func updateBatteryCycleCount() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        if let cycleCountRef = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) {
            batteryStats.cycleCount = cycleCountRef.takeRetainedValue() as? Int ?? 0
        }

        if let maxCapacity = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
           let designCapacity = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
           designCapacity > 0 {
            batteryStats.health = Double(maxCapacity) / Double(designCapacity) * 100
        }
    }

    // MARK: - GPU
    private func updateGPU() {
        gpuStats.name = getGPUName()

        // Try to get GPU utilization from IOKit (Apple Silicon)
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AGXAccelerator")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        // Try to get PerformanceStatistics
        if let perfStats = IORegistryEntryCreateCFProperty(
            service,
            "PerformanceStatistics" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] {

            // Device Utilization % (0-100)
            if let deviceUtil = perfStats["Device Utilization %"] as? Int {
                gpuStats.usage = Double(deviceUtil)
            } else if let deviceUtil = perfStats["deviceUtilization"] as? Int {
                gpuStats.usage = Double(deviceUtil)
            }

            // Try alternative keys
            if gpuStats.usage == 0 {
                if let gpuActivity = perfStats["GPU Activity(%)"] as? Int {
                    gpuStats.usage = Double(gpuActivity)
                }
            }
        }
    }

    private func getGPUName() -> String {
        // For Apple Silicon, get chip name
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuBrand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuBrand, &size, nil, 0)
        let brandString = String(cString: cpuBrand)

        // Check if Apple Silicon
        if brandString.contains("Apple") {
            // Extract chip name (M1, M2, M3, etc.)
            if let match = brandString.range(of: "M\\d+( Pro| Max| Ultra)?", options: .regularExpression) {
                return "Apple \(brandString[match]) GPU"
            }
            return "Apple Silicon GPU"
        }

        // For Intel Macs, try to find discrete GPU
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOPCIDevice")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return "Integrated Graphics"
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data {
                if let model = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) {
                    if model.contains("GPU") || model.contains("Graphics") || model.contains("Radeon") || model.contains("Intel") {
                        IOObjectRelease(service)
                        return model
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return "Integrated Graphics"
    }

    // MARK: - Network
    private func updateNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee

            // Only count AF_LINK interfaces (data link layer)
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)

                // Skip loopback
                if name != "lo0" {
                    if let data = interface.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalBytesIn += UInt64(networkData.ifi_ibytes)
                        totalBytesOut += UInt64(networkData.ifi_obytes)
                    }
                }
            }

            if let next = interface.ifa_next {
                ptr = next
            } else {
                break
            }
        }

        let now = Date()
        networkStats.bytesIn = totalBytesIn
        networkStats.bytesOut = totalBytesOut

        if let lastUpdate = lastNetworkUpdate, previousNetworkIn > 0 {
            let timeDiff = now.timeIntervalSince(lastUpdate)
            if timeDiff > 0 {
                let bytesInDiff = totalBytesIn > previousNetworkIn ? totalBytesIn - previousNetworkIn : 0
                let bytesOutDiff = totalBytesOut > previousNetworkOut ? totalBytesOut - previousNetworkOut : 0

                networkStats.bytesInPerSec = UInt64(Double(bytesInDiff) / timeDiff)
                networkStats.bytesOutPerSec = UInt64(Double(bytesOutDiff) / timeDiff)

                // Update history
                networkInHistory.append(Double(networkStats.bytesInPerSec))
                networkOutHistory.append(Double(networkStats.bytesOutPerSec))
                if networkInHistory.count > 60 { networkInHistory.removeFirst() }
                if networkOutHistory.count > 60 { networkOutHistory.removeFirst() }
            }
        }

        previousNetworkIn = totalBytesIn
        previousNetworkOut = totalBytesOut
        lastNetworkUpdate = now
    }
}
