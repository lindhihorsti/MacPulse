import Foundation

struct CPUStats {
    var usage: Double
    var userUsage: Double
    var systemUsage: Double
    var idleUsage: Double
    var coreUsages: [Double]
    var temperature: Double?
    var frequency: Double?
    var coreCount: Int
    var modelName: String
}

struct MemoryStats {
    var total: UInt64
    var used: UInt64
    var free: UInt64
    var wired: UInt64
    var active: UInt64
    var inactive: UInt64
    var compressed: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var pressure: Double // 0-100

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var available: UInt64 {
        free + inactive
    }
}

struct DiskStats {
    var volumes: [VolumeInfo]
    var readBytesPerSec: UInt64
    var writeBytesPerSec: UInt64
}

struct VolumeInfo: Identifiable {
    let id = UUID()
    var name: String
    var mountPoint: String
    var totalSpace: UInt64
    var freeSpace: UInt64
    var usedSpace: UInt64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct BatteryStats {
    var percentage: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    var cycleCount: Int
    var health: Double // 0-100
    var timeRemaining: Int? // minutes
    var temperature: Double?

    var healthStatus: String {
        if health >= 80 { return "Normal" }
        if health >= 50 { return "Service Recommended" }
        return "Replace Soon"
    }
}

struct GPUStats {
    var name: String
    var usage: Double
    var vramUsed: UInt64
    var vramTotal: UInt64
    var temperature: Double?
}

struct NetworkStats {
    var bytesIn: UInt64
    var bytesOut: UInt64
    var bytesInPerSec: UInt64
    var bytesOutPerSec: UInt64
}
