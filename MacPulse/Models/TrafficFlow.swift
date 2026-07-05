import Foundation

struct TrafficFlowKey: Hashable {
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let `protocol`: PacketProtocol

    var id: String {
        "\(self.protocol.rawValue)|\(sourceIP):\(sourcePort)->\(destinationIP):\(destinationPort)"
    }
}

struct TrafficFlow: Identifiable {
    let id: String
    let key: TrafficFlowKey
    var bytesTransferred: UInt64 = 0
    var packetCount: Int = 0
    var lastSeen: Date = Date()
    var bytesPerSecond: Double = 0

    var sourceIP: String { key.sourceIP }
    var sourcePort: UInt16 { key.sourcePort }
    var destinationIP: String { key.destinationIP }
    var destinationPort: UInt16 { key.destinationPort }
    var `protocol`: PacketProtocol { key.protocol }

    init(key: TrafficFlowKey) {
        self.id = key.id
        self.key = key
    }

    init(sourceIP: String, destinationIP: String) {
        self.init(
            key: TrafficFlowKey(
                sourceIP: sourceIP,
                sourcePort: 0,
                destinationIP: destinationIP,
                destinationPort: 0,
                protocol: .other
            )
        )
    }

    var isActive: Bool {
        Date().timeIntervalSince(lastSeen) < 5.0
    }
}

struct FlowStats {
    var totalBytesIn: UInt64 = 0
    var totalBytesOut: UInt64 = 0
    var activeFlows: Int = 0
    var topTalkers: [(ip: String, bytes: UInt64)] = []
}
