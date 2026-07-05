import Foundation
import AppKit

struct ProcessStats: Identifiable, Equatable {
    let id: Int32 // PID
    var name: String
    var user: String
    var cpuUsage: Double
    var memoryUsage: UInt64 // bytes
    var threads: Int
    var status: ProcessStatus
    var icon: NSImage?
    var executablePath: String
    var bundleIdentifier: String?

    var memoryUsageGB: Double {
        Double(memoryUsage) / 1_073_741_824 // 1024^3
    }

    static func == (lhs: ProcessStats, rhs: ProcessStats) -> Bool {
        lhs.id == rhs.id &&
        lhs.cpuUsage == rhs.cpuUsage &&
        lhs.memoryUsage == rhs.memoryUsage &&
        lhs.threads == rhs.threads &&
        lhs.status == rhs.status
    }
}

enum ProcessStatus: String, CaseIterable, Equatable {
    case running = "Running"
    case sleeping = "Sleeping"
    case idle = "Idle"
    case stopped = "Stopped"
    case zombie = "Zombie"
    case unknown = "Unknown"

    var colorName: String {
        switch self {
        case .running: return "success"
        case .sleeping, .idle: return "textSecondary"
        case .stopped: return "warning"
        case .zombie, .unknown: return "danger"
        }
    }
}
