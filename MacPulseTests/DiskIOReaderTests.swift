import XCTest
@testable import MacPulse

final class DiskIOReaderTests: XCTestCase {
    func testDiskIORatesCalculateBytesPerSecond() {
        let previous = DiskIOCounters(readBytes: 1_000, writeBytes: 2_000)
        let current = DiskIOCounters(readBytes: 5_000, writeBytes: 8_000)

        let rates = DiskIOCounters.rates(from: previous, to: current, elapsed: 2)

        XCTAssertEqual(rates.readBytes, 2_000)
        XCTAssertEqual(rates.writeBytes, 3_000)
    }

    func testDiskIORatesClampCounterResetsToZero() {
        let previous = DiskIOCounters(readBytes: 5_000, writeBytes: 8_000)
        let current = DiskIOCounters(readBytes: 1_000, writeBytes: 2_000)

        let rates = DiskIOCounters.rates(from: previous, to: current, elapsed: 2)

        XCTAssertEqual(rates, .zero)
    }

    func testDiskIORatesRequirePositiveElapsedTime() {
        let previous = DiskIOCounters(readBytes: 1_000, writeBytes: 2_000)
        let current = DiskIOCounters(readBytes: 5_000, writeBytes: 8_000)

        XCTAssertEqual(DiskIOCounters.rates(from: previous, to: current, elapsed: 0), .zero)
        XCTAssertEqual(DiskIOCounters.rates(from: previous, to: current, elapsed: -1), .zero)
    }
}
