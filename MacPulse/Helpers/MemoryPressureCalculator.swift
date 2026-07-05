import Foundation

struct MemoryPressureInput {
    var total: UInt64
    var free: UInt64
    var inactive: UInt64
    var wired: UInt64
    var active: UInt64
    var compressed: UInt64
    var swapUsed: UInt64
}

enum MemoryPressureCalculator {
    static func pressure(for input: MemoryPressureInput) -> Double {
        guard input.total > 0 else { return 0 }

        let total = Double(input.total)
        let available = Double(input.free + input.inactive)
        let wired = Double(input.wired)
        let active = Double(input.active)
        let compressed = Double(input.compressed)
        let swapUsed = Double(input.swapUsed)

        let availablePressure = (1 - min(max(available / total, 0), 1)) * 55
        let activePressure = min(active / total, 1) * 20
        let wiredPressure = min(wired / total, 1) * 15
        let compressionPressure = min(compressed / total, 1) * 30
        let swapPressure = min(swapUsed / total, 1) * 45

        return min(max(availablePressure + activePressure + wiredPressure + compressionPressure + swapPressure, 0), 100)
    }
}
