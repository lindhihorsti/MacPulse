import XCTest
@testable import MacPulse

final class ReportExportServiceTests: XCTestCase {
    func testJSONExportRedactsSensitiveValuesWhenPrivacyModeIsEnabled() throws {
        let data = try ReportExportService.jsonData(from: input(privacyMode: true))
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("192.168.1.10"))
        XCTAssertFalse(json.contains("AA:BB:CC:DD:EE:FF"))
        XCTAssertFalse(json.contains("dennis-macbook.local"))
        XCTAssertFalse(json.contains("Safari"))
        XCTAssertTrue(json.contains("xxx.xxx.xxx.10"))
        XCTAssertTrue(json.contains("xx:xx:xx:xx:xx:FF"))
        XCTAssertTrue(json.contains("process-"))
        XCTAssertTrue(json.contains("\"privacyMode\" : true"))
    }

    func testMarkdownExportKeepsRawValuesWhenPrivacyModeIsDisabled() {
        let markdown = ReportExportService.markdown(from: input(privacyMode: false))

        XCTAssertTrue(markdown.contains("# MacPulse Report"))
        XCTAssertTrue(markdown.contains("Privacy Mode: Disabled"))
        XCTAssertTrue(markdown.contains("192.168.1.10"))
        XCTAssertTrue(markdown.contains("AA:BB:CC:DD:EE:FF"))
        XCTAssertTrue(markdown.contains("dennis-macbook.local"))
        XCTAssertTrue(markdown.contains("Safari"))
    }

    func testSnapshotIncludesMetadataOnlyCountsAndDiagnostics() {
        let snapshot = ReportExportService.snapshot(from: input(privacyMode: false))

        XCTAssertEqual(snapshot.interfaces.count, 1)
        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.connections.count, 1)
        XCTAssertEqual(snapshot.flows.count, 1)
        XCTAssertEqual(snapshot.processActivities.first?.connectionCount, 1)
        XCTAssertEqual(snapshot.diagnostics.first?.status, "warning")
    }

    private func input(privacyMode: Bool) -> ReportExportInput {
        let connection = NetworkConnection(
            localAddress: "192.168.1.10",
            localPort: 50_000,
            remoteAddress: "142.250.185.14",
            remotePort: 443,
            protocol: .tcp,
            state: .established,
            processName: "Safari",
            pid: 42
        )
        var flow = TrafficFlow(
            key: TrafficFlowKey(
                sourceIP: "192.168.1.10",
                sourcePort: 50_000,
                destinationIP: "142.250.185.14",
                destinationPort: 443,
                protocol: .tcp
            )
        )
        flow.bytesTransferred = 1_024
        flow.bytesPerSecond = 512
        flow.packetCount = 2

        let activities = NetworkCorrelationEngine.correlate(connections: [connection], flows: [flow])

        return ReportExportInput(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            interfaces: [
                NetworkInterface(
                    name: "en0",
                    displayName: "Wi-Fi",
                    ipAddress: "192.168.1.10",
                    subnet: "255.255.255.0",
                    macAddress: "AA:BB:CC:DD:EE:FF",
                    isUp: true,
                    isWifi: true,
                    bytesIn: 10_000,
                    bytesOut: 5_000,
                    bytesInPerSec: 100,
                    bytesOutPerSec: 50
                ),
            ],
            devices: [
                NetworkDevice(
                    id: "AA:BB:CC:DD:EE:FF",
                    ipAddress: "192.168.1.10",
                    macAddress: "AA:BB:CC:DD:EE:FF",
                    hostname: "dennis-macbook.local",
                    vendor: "Apple",
                    lastSeen: Date(),
                    isRouter: false,
                    isLocalDevice: true
                ),
            ],
            connections: [connection],
            flows: [flow],
            processActivities: activities,
            diagnostics: [
                DiagnosticCheck(
                    id: "bpf-devices",
                    title: "BPF Devices",
                    message: "1 BPF device found at 192.168.1.10",
                    status: .warning
                ),
            ],
            privacyMode: privacyMode
        )
    }
}
