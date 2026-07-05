import Foundation

struct PacketInfo: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let `protocol`: PacketProtocol
    let length: Int
    let payload: Data
    let rawData: Data

    var summary: String {
        switch `protocol` {
        case .tcp:
            return "TCP \(sourceIP):\(sourcePort) → \(destinationIP):\(destinationPort)"
        case .udp:
            return "UDP \(sourceIP):\(sourcePort) → \(destinationIP):\(destinationPort)"
        case .icmp:
            return "ICMP \(sourceIP) → \(destinationIP)"
        case .arp:
            return "ARP \(sourceIP) → \(destinationIP)"
        case .ipv6:
            return "IPv6 \(sourceIP) → \(destinationIP)"
        case .other:
            return "\(sourceIP) → \(destinationIP)"
        }
    }

    var hexDump: String {
        var result = ""
        let bytes = [UInt8](rawData)
        for i in stride(from: 0, to: bytes.count, by: 16) {
            let end = min(i + 16, bytes.count)
            let hex = bytes[i..<end].map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = bytes[i..<end].map { (0x20...0x7E).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let offset = String(format: "%04X", i)
            let paddedHex = hex.padding(toLength: 48, withPad: " ", startingAt: 0)
            result += "\(offset)  \(paddedHex)  \(ascii)\n"
        }
        return result
    }
}

enum PacketProtocol: String {
    case tcp = "TCP"
    case udp = "UDP"
    case icmp = "ICMP"
    case arp = "ARP"
    case ipv6 = "IPv6"
    case other = "Other"
}

struct PortScanResult: Identifiable {
    let id = UUID()
    let port: UInt16
    let state: PortState
    let service: String
    let responseTime: TimeInterval?

    static let commonPorts: [UInt16: String] = [
        20: "FTP Data",
        21: "FTP",
        22: "SSH",
        23: "Telnet",
        25: "SMTP",
        53: "DNS",
        67: "DHCP",
        68: "DHCP",
        80: "HTTP",
        110: "POP3",
        119: "NNTP",
        123: "NTP",
        143: "IMAP",
        161: "SNMP",
        194: "IRC",
        443: "HTTPS",
        445: "SMB",
        465: "SMTPS",
        514: "Syslog",
        587: "SMTP",
        631: "IPP",
        993: "IMAPS",
        995: "POP3S",
        1080: "SOCKS",
        1433: "MSSQL",
        1434: "MSSQL",
        1521: "Oracle",
        3306: "MySQL",
        3389: "RDP",
        5432: "PostgreSQL",
        5900: "VNC",
        5901: "VNC",
        6379: "Redis",
        8080: "HTTP Alt",
        8443: "HTTPS Alt",
        27017: "MongoDB",
    ]

    static func serviceName(for port: UInt16) -> String {
        return commonPorts[port] ?? "Unknown"
    }
}

enum PortState: String {
    case open = "Open"
    case closed = "Closed"
    case filtered = "Filtered"
}
