import XCTest
@testable import MacPulse

final class NetworkCorrelationServiceTests: XCTestCase {
    func testExactFiveTupleCorrelationAggregatesByProcess() {
        let connections = [
            connection(pid: 42, processName: "Safari", localPort: 50_000, remotePort: 443),
        ]
        let flows = [
            flow(sourcePort: 50_000, destinationPort: 443, bytes: 1_200, speed: 400, packets: 3),
        ]

        let activities = NetworkCorrelationEngine.correlate(connections: connections, flows: flows)

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].pid, 42)
        XCTAssertEqual(activities[0].processName, "Safari")
        XCTAssertEqual(activities[0].bytesTransferred, 1_200)
        XCTAssertEqual(activities[0].bytesPerSecond, 400)
        XCTAssertEqual(activities[0].packetCount, 3)
        XCTAssertEqual(activities[0].correlatedFlows.first?.direction, .direct)
    }

    func testReverseFlowDirectionMatchesSameConnection() {
        let connections = [
            connection(pid: 42, processName: "Safari", localPort: 50_000, remotePort: 443),
        ]
        let flows = [
            flow(
                sourceIP: "142.250.185.14",
                sourcePort: 443,
                destinationIP: "192.168.1.10",
                destinationPort: 50_000,
                bytes: 900,
                speed: 100,
                packets: 2
            ),
        ]

        let activity = NetworkCorrelationEngine.correlate(connections: connections, flows: flows).first

        XCTAssertEqual(activity?.processName, "Safari")
        XCTAssertEqual(activity?.correlatedFlows.first?.direction, .reverse)
        XCTAssertEqual(activity?.bytesTransferred, 900)
    }

    func testDifferentPortsDoNotCrossCorrelate() {
        let connections = [
            connection(pid: 42, processName: "Safari", localPort: 50_000, remotePort: 443),
        ]
        let flows = [
            flow(sourcePort: 50_001, destinationPort: 443, bytes: 1_200, speed: 400),
        ]

        let activities = NetworkCorrelationEngine.correlate(connections: connections, flows: flows)

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].correlatedFlows.count, 0)
        XCTAssertEqual(activities[0].bytesTransferred, 0)
    }

    func testProtocolIsPartOfCorrelationKey() {
        let connections = [
            connection(protocol: .tcp, pid: 42, processName: "Safari", localPort: 53_000, remotePort: 53),
        ]
        let flows = [
            flow(protocol: .udp, sourcePort: 53_000, destinationPort: 53, bytes: 1_200, speed: 400),
        ]

        let activities = NetworkCorrelationEngine.correlate(connections: connections, flows: flows)

        XCTAssertEqual(activities.first?.correlatedFlows.count, 0)
    }

    func testActivitiesSortByCurrentSpeed() {
        let connections = [
            connection(pid: 1, processName: "Slow", localPort: 50_000, remotePort: 443),
            connection(pid: 2, processName: "Fast", localPort: 50_001, remotePort: 443),
        ]
        let flows = [
            flow(sourcePort: 50_000, destinationPort: 443, bytes: 2_000, speed: 100),
            flow(sourcePort: 50_001, destinationPort: 443, bytes: 1_000, speed: 900),
        ]

        let activities = NetworkCorrelationEngine.correlate(connections: connections, flows: flows)

        XCTAssertEqual(activities.map(\.processName), ["Fast", "Slow"])
    }

    private func connection(
        protocol connectionProtocol: ConnectionProtocol = .tcp,
        pid: Int32?,
        processName: String?,
        localAddress: String = "192.168.1.10",
        localPort: UInt16,
        remoteAddress: String = "142.250.185.14",
        remotePort: UInt16
    ) -> NetworkConnection {
        NetworkConnection(
            localAddress: localAddress,
            localPort: localPort,
            remoteAddress: remoteAddress,
            remotePort: remotePort,
            protocol: connectionProtocol,
            state: .established,
            processName: processName,
            pid: pid
        )
    }

    private func flow(
        protocol packetProtocol: PacketProtocol = .tcp,
        sourceIP: String = "192.168.1.10",
        sourcePort: UInt16,
        destinationIP: String = "142.250.185.14",
        destinationPort: UInt16,
        bytes: UInt64,
        speed: Double,
        packets: Int = 1
    ) -> TrafficFlow {
        var flow = TrafficFlow(
            key: TrafficFlowKey(
                sourceIP: sourceIP,
                sourcePort: sourcePort,
                destinationIP: destinationIP,
                destinationPort: destinationPort,
                protocol: packetProtocol
            )
        )
        flow.bytesTransferred = bytes
        flow.bytesPerSecond = speed
        flow.packetCount = packets
        return flow
    }
}
