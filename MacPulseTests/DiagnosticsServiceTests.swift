import XCTest
@testable import MacPulse

final class DiagnosticsServiceTests: XCTestCase {
    func testDiagnosticsReportHealthyToolsAndReadableBPF() {
        let service = DiagnosticsService(environment: .fake(
            existing: ["/Library/LaunchDaemons/com.macpulse.bpf.plist"],
            executable: ["/usr/sbin/lsof", "/usr/sbin/arp", "/usr/sbin/netstat", "/usr/sbin/networksetup"],
            readable: ["/dev/bpf0"],
            directoryContents: ["/dev": ["bpf0", "bpf1"]],
            refreshInterval: 1.0
        ))

        let checks = service.runChecks()

        XCTAssertEqual(checks.first { $0.id == "tool-lsof" }?.status, .ok)
        XCTAssertEqual(checks.first { $0.id == "bpf-devices" }?.status, .ok)
        XCTAssertEqual(checks.first { $0.id == "bpf-launchdaemon" }?.status, .ok)
        XCTAssertEqual(checks.first { $0.id == "settings-refresh-interval" }?.status, .ok)
    }

    func testDiagnosticsWarnWhenBPFDevicesAreNotReadable() {
        let service = DiagnosticsService(environment: .fake(
            existing: [],
            executable: ["/usr/sbin/lsof", "/usr/sbin/arp", "/usr/sbin/netstat", "/usr/sbin/networksetup"],
            readable: [],
            directoryContents: ["/dev": ["bpf0"]],
            refreshInterval: 1.0
        ))

        let checks = service.runChecks()

        XCTAssertEqual(checks.first { $0.id == "bpf-devices" }?.status, .warning)
        XCTAssertEqual(checks.first { $0.id == "bpf-launchdaemon" }?.status, .warning)
    }

    func testDiagnosticsFailForMissingToolAndInvalidRefreshInterval() {
        let service = DiagnosticsService(environment: .fake(
            existing: [],
            executable: ["/usr/sbin/arp", "/usr/sbin/netstat", "/usr/sbin/networksetup"],
            readable: [],
            directoryContents: ["/dev": []],
            refreshInterval: 0
        ))

        let checks = service.runChecks()

        XCTAssertEqual(checks.first { $0.id == "tool-lsof" }?.status, .failed)
        XCTAssertEqual(checks.first { $0.id == "settings-refresh-interval" }?.status, .failed)
        XCTAssertEqual(checks.first { $0.id == "bpf-devices" }?.status, .warning)
    }
}

private extension DiagnosticsEnvironment {
    static func fake(
        existing: Set<String>,
        executable: Set<String>,
        readable: Set<String>,
        directoryContents: [String: [String]],
        refreshInterval: Double
    ) -> DiagnosticsEnvironment {
        DiagnosticsEnvironment(
            fileExists: { existing.contains($0) },
            isExecutableFile: { executable.contains($0) },
            isReadableFile: { readable.contains($0) },
            contentsOfDirectory: { directoryContents[$0] ?? [] },
            refreshInterval: { refreshInterval }
        )
    }
}
