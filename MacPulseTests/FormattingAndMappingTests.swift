import XCTest
@testable import MacPulse

final class FormattingAndMappingTests: XCTestCase {
    func testByteFormatterFormatsBinaryUnits() {
        XCTAssertEqual(ByteFormatter.format(0), "0 B")
        XCTAssertEqual(ByteFormatter.format(512), "512 B")
        XCTAssertEqual(ByteFormatter.format(1024), "1.0 KB")
        XCTAssertEqual(ByteFormatter.format(1_048_576), "1.0 MB")
        XCTAssertEqual(ByteFormatter.format(1_073_741_824), "1.0 GB")
    }

    func testByteFormatterRespectsDecimalCount() {
        XCTAssertEqual(ByteFormatter.format(1536, decimals: 2), "1.50 KB")
        XCTAssertEqual(ByteFormatter.format(1536, decimals: 0), "2 KB")
    }

    func testByteFormatterFormatsSpeedAndCompactValues() {
        XCTAssertEqual(ByteFormatter.formatSpeed(1024), "1.0 KB/s")
        XCTAssertEqual(ByteFormatter.formatCompact(512), "512B")
        XCTAssertEqual(ByteFormatter.formatCompact(1536), "1.5K")
        XCTAssertEqual(ByteFormatter.formatCompact(12 * 1024), "12K")
    }

    func testMinuteFormatting() {
        XCTAssertEqual(45.formattedMinutes, "45m")
        XCTAssertEqual(125.formattedMinutes, "2h 5m")
    }

    func testCommonPortServiceMapping() {
        XCTAssertEqual(PortScanResult.serviceName(for: 22), "SSH")
        XCTAssertEqual(PortScanResult.serviceName(for: 443), "HTTPS")
        XCTAssertEqual(PortScanResult.serviceName(for: 5432), "PostgreSQL")
        XCTAssertEqual(PortScanResult.serviceName(for: 65000), "Unknown")
    }
}
