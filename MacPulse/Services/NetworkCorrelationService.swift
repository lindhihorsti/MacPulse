import Foundation

enum NetworkFlowMatchDirection: String, Equatable {
    case direct
    case reverse
}

struct CorrelatedNetworkFlow: Identifiable {
    let id: String
    let flow: TrafficFlow
    let connection: NetworkConnection
    let direction: NetworkFlowMatchDirection
}

struct ProcessNetworkActivity: Identifiable {
    let id: String
    let pid: Int32?
    let processName: String
    let connections: [NetworkConnection]
    let correlatedFlows: [CorrelatedNetworkFlow]
    let bytesTransferred: UInt64
    let bytesPerSecond: Double
    let packetCount: Int

    var remoteEndpointCount: Int {
        Set(connections.map { "\($0.remoteAddress):\($0.remotePort)" }).count
    }
}

enum NetworkCorrelationEngine {
    static func correlate(
        connections: [NetworkConnection],
        flows: [TrafficFlow]
    ) -> [ProcessNetworkActivity] {
        let indexedConnections = Dictionary(grouping: connections.compactMap(ConnectionIndex.init(connection:))) {
            $0.processKey
        }

        var correlatedByProcess: [String: [CorrelatedNetworkFlow]] = [:]
        var connectionsByProcess: [String: [NetworkConnection]] = [:]

        for connection in connections {
            let processKey = ProcessKey(connection: connection).id
            connectionsByProcess[processKey, default: []].append(connection)
        }

        for flow in flows {
            guard let directKey = FlowLookupKey(flow: flow, direction: .direct),
                  let reverseKey = FlowLookupKey(flow: flow, direction: .reverse) else {
                continue
            }

            if let match = firstConnectionMatch(for: directKey, indexedConnections: indexedConnections) {
                correlatedByProcess[match.processKey.id, default: []].append(
                    CorrelatedNetworkFlow(
                        id: "\(flow.id)|\(match.connection.id)|direct",
                        flow: flow,
                        connection: match.connection,
                        direction: .direct
                    )
                )
            } else if let match = firstConnectionMatch(for: reverseKey, indexedConnections: indexedConnections) {
                correlatedByProcess[match.processKey.id, default: []].append(
                    CorrelatedNetworkFlow(
                        id: "\(flow.id)|\(match.connection.id)|reverse",
                        flow: flow,
                        connection: match.connection,
                        direction: .reverse
                    )
                )
            }
        }

        let processKeys = Set(connectionsByProcess.keys).union(correlatedByProcess.keys)
        return processKeys.map { key in
            let processConnections = connectionsByProcess[key] ?? []
            let correlatedFlows = correlatedByProcess[key] ?? []
            let processKey = ProcessKey(id: key, connections: processConnections, correlatedFlows: correlatedFlows)

            return ProcessNetworkActivity(
                id: key,
                pid: processKey.pid,
                processName: processKey.processName,
                connections: processConnections.sorted(by: sortConnections),
                correlatedFlows: correlatedFlows.sorted { $0.flow.bytesPerSecond > $1.flow.bytesPerSecond },
                bytesTransferred: correlatedFlows.reduce(0) { $0 + $1.flow.bytesTransferred },
                bytesPerSecond: correlatedFlows.reduce(0) { $0 + $1.flow.bytesPerSecond },
                packetCount: correlatedFlows.reduce(0) { $0 + $1.flow.packetCount }
            )
        }
        .sorted {
            if $0.bytesPerSecond != $1.bytesPerSecond {
                return $0.bytesPerSecond > $1.bytesPerSecond
            }
            if $0.bytesTransferred != $1.bytesTransferred {
                return $0.bytesTransferred > $1.bytesTransferred
            }
            return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
        }
    }

    private static func firstConnectionMatch(
        for lookupKey: FlowLookupKey,
        indexedConnections: [ProcessKey: [ConnectionIndex]]
    ) -> ConnectionIndex? {
        indexedConnections
            .values
            .lazy
            .flatMap { $0 }
            .first { $0.lookupKey == lookupKey }
    }

    private static func sortConnections(lhs: NetworkConnection, rhs: NetworkConnection) -> Bool {
        if (lhs.processName ?? "") != (rhs.processName ?? "") {
            return (lhs.processName ?? "").localizedCaseInsensitiveCompare(rhs.processName ?? "") == .orderedAscending
        }
        if lhs.remoteAddress != rhs.remoteAddress {
            return lhs.remoteAddress < rhs.remoteAddress
        }
        return lhs.remotePort < rhs.remotePort
    }
}

private struct ProcessKey: Hashable {
    let id: String
    let pid: Int32?
    let processName: String

    init(connection: NetworkConnection) {
        let normalizedName = connection.processName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pid = connection.pid {
            self.id = "pid:\(pid)"
            self.pid = pid
            self.processName = normalizedName?.isEmpty == false ? normalizedName! : "PID \(pid)"
        } else {
            let name = normalizedName?.isEmpty == false ? normalizedName! : "System"
            self.id = "name:\(name.lowercased())"
            self.pid = nil
            self.processName = name
        }
    }

    init(id: String, connections: [NetworkConnection], correlatedFlows: [CorrelatedNetworkFlow]) {
        let connection = connections.first ?? correlatedFlows.first?.connection
        if let connection {
            let normalizedName = connection.processName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pid = connection.pid {
                self.id = "pid:\(pid)"
                self.pid = pid
                self.processName = normalizedName?.isEmpty == false ? normalizedName! : "PID \(pid)"
            } else {
                let name = normalizedName?.isEmpty == false ? normalizedName! : "System"
                self.id = "name:\(name.lowercased())"
                self.pid = nil
                self.processName = name
            }
        } else {
            self.id = id
            self.pid = nil
            self.processName = "System"
        }
    }
}

private struct ConnectionIndex {
    let processKey: ProcessKey
    let lookupKey: FlowLookupKey
    let connection: NetworkConnection

    init?(connection: NetworkConnection) {
        guard let protocolValue = PacketProtocol(connectionProtocol: connection.protocol),
              !Self.isWildcard(connection.localAddress),
              !Self.isWildcard(connection.remoteAddress) else {
            return nil
        }

        self.processKey = ProcessKey(connection: connection)
        self.lookupKey = FlowLookupKey(
            sourceIP: connection.localAddress,
            sourcePort: connection.localPort,
            destinationIP: connection.remoteAddress,
            destinationPort: connection.remotePort,
            protocol: protocolValue
        )
        self.connection = connection
    }

    private static func isWildcard(_ address: String) -> Bool {
        address == "*"
            || address == "0.0.0.0"
            || address == "::"
            || address == "::0"
            || address.isEmpty
    }
}

private struct FlowLookupKey: Hashable {
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let `protocol`: PacketProtocol

    init(
        sourceIP: String,
        sourcePort: UInt16,
        destinationIP: String,
        destinationPort: UInt16,
        protocol: PacketProtocol
    ) {
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.protocol = `protocol`
    }

    init?(flow: TrafficFlow, direction: NetworkFlowMatchDirection) {
        guard flow.protocol == .tcp || flow.protocol == .udp else { return nil }

        switch direction {
        case .direct:
            self.init(
                sourceIP: flow.sourceIP,
                sourcePort: flow.sourcePort,
                destinationIP: flow.destinationIP,
                destinationPort: flow.destinationPort,
                protocol: flow.protocol
            )
        case .reverse:
            self.init(
                sourceIP: flow.destinationIP,
                sourcePort: flow.destinationPort,
                destinationIP: flow.sourceIP,
                destinationPort: flow.sourcePort,
                protocol: flow.protocol
            )
        }
    }
}

private extension PacketProtocol {
    init?(connectionProtocol: ConnectionProtocol) {
        switch connectionProtocol {
        case .tcp, .tcp6:
            self = .tcp
        case .udp, .udp6:
            self = .udp
        }
    }
}
