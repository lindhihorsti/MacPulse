import Foundation

struct NetworkInterface: Identifiable {
    let id = UUID()
    var name: String
    var displayName: String
    var ipAddress: String
    var subnet: String
    var macAddress: String
    var isUp: Bool
    var isWifi: Bool
    var bytesIn: UInt64
    var bytesOut: UInt64
    var bytesInPerSec: UInt64
    var bytesOutPerSec: UInt64
}

struct NetworkDevice: Identifiable, Equatable {
    let id: String // MAC address
    var ipAddress: String
    var macAddress: String
    var hostname: String?
    var vendor: String?
    var lastSeen: Date
    var isRouter: Bool
    var isLocalDevice: Bool

    static func == (lhs: NetworkDevice, rhs: NetworkDevice) -> Bool {
        lhs.id == rhs.id
    }
}

struct NetworkConnection: Identifiable {
    let id = UUID()
    var localAddress: String
    var localPort: UInt16
    var remoteAddress: String
    var remotePort: UInt16
    var `protocol`: ConnectionProtocol
    var state: ConnectionState
    var processName: String?
    var pid: Int32?
}

enum ConnectionProtocol: String {
    case tcp = "TCP"
    case udp = "UDP"
    case tcp6 = "TCP6"
    case udp6 = "UDP6"
}

enum ConnectionState: String {
    case established = "ESTABLISHED"
    case listen = "LISTEN"
    case timeWait = "TIME_WAIT"
    case closeWait = "CLOSE_WAIT"
    case synSent = "SYN_SENT"
    case synReceived = "SYN_RECV"
    case finWait1 = "FIN_WAIT_1"
    case finWait2 = "FIN_WAIT_2"
    case closing = "CLOSING"
    case lastAck = "LAST_ACK"
    case closed = "CLOSED"
    case unknown = "UNKNOWN"

    var color: String {
        switch self {
        case .established: return "success"
        case .listen: return "appAccent"
        case .timeWait, .closeWait, .finWait1, .finWait2: return "warning"
        case .closed: return "textTertiary"
        default: return "textSecondary"
        }
    }
}
