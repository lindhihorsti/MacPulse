import Foundation

enum ByteFormatter {
    static func format(_ bytes: UInt64, decimals: Int = 1) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }

        return String(format: "%.\(decimals)f %@", value, units[unitIndex])
    }

    static func formatSpeed(_ bytesPerSecond: UInt64) -> String {
        let formatted = format(bytesPerSecond)
        return "\(formatted)/s"
    }

    static func formatCompact(_ bytes: UInt64) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value < 10 {
            return String(format: "%.1f%@", value, units[unitIndex])
        }
        return String(format: "%.0f%@", value, units[unitIndex])
    }
}

extension UInt64 {
    var formattedBytes: String {
        ByteFormatter.format(self)
    }

    var formattedBytesCompact: String {
        ByteFormatter.formatCompact(self)
    }

    var formattedSpeed: String {
        ByteFormatter.formatSpeed(self)
    }
}

extension Int {
    var formattedMinutes: String {
        let hours = self / 60
        let minutes = self % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
