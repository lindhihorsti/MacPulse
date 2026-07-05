import Foundation
import IOKit

struct DiskIOCounters: Equatable {
    var readBytes: UInt64
    var writeBytes: UInt64

    static let zero = DiskIOCounters(readBytes: 0, writeBytes: 0)

    static func rates(from previous: DiskIOCounters, to current: DiskIOCounters, elapsed: TimeInterval) -> DiskIOCounters {
        guard elapsed > 0 else { return .zero }

        let readDelta = current.readBytes >= previous.readBytes ? current.readBytes - previous.readBytes : 0
        let writeDelta = current.writeBytes >= previous.writeBytes ? current.writeBytes - previous.writeBytes : 0

        return DiskIOCounters(
            readBytes: UInt64(Double(readDelta) / elapsed),
            writeBytes: UInt64(Double(writeDelta) / elapsed)
        )
    }
}

enum DiskIOReader {
    static func currentCounters() -> DiskIOCounters {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .zero
        }
        defer { IOObjectRelease(iterator) }

        var counters = DiskIOCounters.zero
        var service = IOIteratorNext(iterator)

        while service != IO_OBJECT_NULL {
            if let stats = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                counters.readBytes += uint64Value(stats["Bytes (Read)"])
                counters.writeBytes += uint64Value(stats["Bytes (Write)"])
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return counters
    }

    private static func uint64Value(_ value: Any?) -> UInt64 {
        if let value = value as? UInt64 { return value }
        if let value = value as? UInt { return UInt64(value) }
        if let value = value as? Int { return UInt64(max(value, 0)) }
        if let value = value as? NSNumber { return value.uint64Value }
        return 0
    }
}
