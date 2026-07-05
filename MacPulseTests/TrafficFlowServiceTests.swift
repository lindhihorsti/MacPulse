import XCTest
@testable import MacPulse

final class TrafficFlowServiceTests: XCTestCase {
    func testSameIPPairWithDifferentPortsCreatesDistinctFlows() {
        let service = TrafficFlowService()

        service.record(packet: packet(sourcePort: 50_000, destinationPort: 443, length: 120))
        service.record(packet: packet(sourcePort: 50_001, destinationPort: 443, length: 140))

        XCTAssertEqual(service.flows.count, 2)
        XCTAssertTrue(service.flows.keys.contains("TCP|8.8.8.8:50000->142.250.185.14:443"))
        XCTAssertTrue(service.flows.keys.contains("TCP|8.8.8.8:50001->142.250.185.14:443"))
    }

    func testSameTupleAggregatesBytesAndPackets() {
        let service = TrafficFlowService()

        service.record(packet: packet(sourcePort: 50_000, destinationPort: 443, length: 120))
        service.record(packet: packet(sourcePort: 50_000, destinationPort: 443, length: 80))

        let flow = service.flows["TCP|8.8.8.8:50000->142.250.185.14:443"]
        XCTAssertEqual(flow?.packetCount, 2)
        XCTAssertEqual(flow?.bytesTransferred, 200)
    }

    func testProtocolAndDirectionArePartOfFlowIdentity() {
        let service = TrafficFlowService()

        service.record(packet: packet(protocol: .tcp, sourcePort: 53_000, destinationPort: 53))
        service.record(packet: packet(protocol: .udp, sourcePort: 53_000, destinationPort: 53))
        service.record(packet: packet(sourceIP: "142.250.185.14", sourcePort: 443, destinationIP: "8.8.8.8", destinationPort: 50_000))

        XCTAssertEqual(service.flows.count, 3)
        XCTAssertTrue(service.flows.keys.contains("TCP|8.8.8.8:53000->142.250.185.14:53"))
        XCTAssertTrue(service.flows.keys.contains("UDP|8.8.8.8:53000->142.250.185.14:53"))
        XCTAssertTrue(service.flows.keys.contains("TCP|142.250.185.14:443->8.8.8.8:50000"))
    }

    func testNonFlowPacketsAndIgnoredAddressesAreSkipped() {
        let service = TrafficFlowService()

        service.record(packet: packet(protocol: .arp, sourcePort: 0, destinationPort: 0))
        service.record(packet: packet(sourceIP: "127.0.0.1", sourcePort: 50_000, destinationPort: 443))
        service.record(packet: packet(sourceIP: "fe80:0:0:0:1:2:3:4", sourcePort: 50_000, destinationPort: 443))
        service.record(packet: packet(sourceIP: "192.168.1.10", sourcePort: 50_000, destinationPort: 443))

        XCTAssertTrue(service.flows.isEmpty)
    }

    private func packet(
        protocol packetProtocol: PacketProtocol = .tcp,
        sourceIP: String = "8.8.8.8",
        sourcePort: UInt16 = 50_000,
        destinationIP: String = "142.250.185.14",
        destinationPort: UInt16 = 443,
        length: Int = 100
    ) -> PacketInfo {
        PacketInfo(
            timestamp: Date(),
            sourceIP: sourceIP,
            sourcePort: sourcePort,
            destinationIP: destinationIP,
            destinationPort: destinationPort,
            protocol: packetProtocol,
            length: length,
            payload: Data(),
            rawData: Data()
        )
    }
}
