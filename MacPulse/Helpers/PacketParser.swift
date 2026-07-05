import Foundation

enum PacketParser {
    static func parse(rawData: Data, length: Int, timestamp: Date) -> PacketInfo? {
        guard rawData.count >= 14 else { return nil }

        let bytes = [UInt8](rawData)
        let etherType = readUInt16(bytes, at: 12)

        switch etherType {
        case 0x0800:
            return parseIPv4(bytes: bytes, rawData: rawData, length: length, timestamp: timestamp)
        case 0x0806:
            return parseARP(bytes: bytes, rawData: rawData, length: length, timestamp: timestamp)
        case 0x86DD:
            return parseIPv6(bytes: bytes, rawData: rawData, length: length, timestamp: timestamp)
        default:
            return PacketInfo(
                timestamp: timestamp,
                sourceIP: "N/A",
                sourcePort: 0,
                destinationIP: "N/A",
                destinationPort: 0,
                protocol: .other,
                length: length,
                payload: Data(),
                rawData: rawData
            )
        }
    }

    private static func parseIPv4(bytes: [UInt8], rawData: Data, length: Int, timestamp: Date) -> PacketInfo? {
        let ipHeaderStart = 14
        guard bytes.count >= ipHeaderStart + 20 else { return nil }
        guard bytes[ipHeaderStart] >> 4 == 4 else { return nil }

        let ipHeaderLength = Int(bytes[ipHeaderStart] & 0x0F) * 4
        guard ipHeaderLength >= 20, bytes.count >= ipHeaderStart + ipHeaderLength else { return nil }

        let ipProtocol = bytes[ipHeaderStart + 9]
        let sourceIP = ipv4String(bytes, start: ipHeaderStart + 12)
        let destinationIP = ipv4String(bytes, start: ipHeaderStart + 16)
        let transportStart = ipHeaderStart + ipHeaderLength

        return parseTransport(
            ipProtocol: ipProtocol,
            bytes: bytes,
            rawData: rawData,
            length: length,
            timestamp: timestamp,
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            transportStart: transportStart,
            fallbackProtocol: .other
        )
    }

    private static func parseIPv6(bytes: [UInt8], rawData: Data, length: Int, timestamp: Date) -> PacketInfo? {
        let ipHeaderStart = 14
        guard bytes.count >= ipHeaderStart + 40 else { return nil }
        guard bytes[ipHeaderStart] >> 4 == 6 else { return nil }

        let nextHeader = bytes[ipHeaderStart + 6]
        let sourceIP = ipv6String(bytes, start: ipHeaderStart + 8)
        let destinationIP = ipv6String(bytes, start: ipHeaderStart + 24)
        let transportStart = ipHeaderStart + 40

        return parseTransport(
            ipProtocol: nextHeader,
            bytes: bytes,
            rawData: rawData,
            length: length,
            timestamp: timestamp,
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            transportStart: transportStart,
            fallbackProtocol: .ipv6
        )
    }

    private static func parseARP(bytes: [UInt8], rawData: Data, length: Int, timestamp: Date) -> PacketInfo? {
        let arpStart = 14
        guard bytes.count >= arpStart + 28 else { return nil }

        let hardwareType = readUInt16(bytes, at: arpStart)
        let protocolType = readUInt16(bytes, at: arpStart + 2)
        let hardwareLength = bytes[arpStart + 4]
        let protocolLength = bytes[arpStart + 5]
        guard hardwareType == 1, protocolType == 0x0800, hardwareLength == 6, protocolLength == 4 else {
            return PacketInfo(
                timestamp: timestamp,
                sourceIP: "N/A",
                sourcePort: 0,
                destinationIP: "N/A",
                destinationPort: 0,
                protocol: .arp,
                length: length,
                payload: Data(),
                rawData: rawData
            )
        }

        return PacketInfo(
            timestamp: timestamp,
            sourceIP: ipv4String(bytes, start: arpStart + 14),
            sourcePort: 0,
            destinationIP: ipv4String(bytes, start: arpStart + 24),
            destinationPort: 0,
            protocol: .arp,
            length: length,
            payload: Data(),
            rawData: rawData
        )
    }

    private static func parseTransport(
        ipProtocol: UInt8,
        bytes: [UInt8],
        rawData: Data,
        length: Int,
        timestamp: Date,
        sourceIP: String,
        destinationIP: String,
        transportStart: Int,
        fallbackProtocol: PacketProtocol
    ) -> PacketInfo? {
        var sourcePort: UInt16 = 0
        var destinationPort: UInt16 = 0
        var packetProtocol = fallbackProtocol
        var payload = Data()

        if ipProtocol == 6, bytes.count >= transportStart + 20 {
            packetProtocol = .tcp
            sourcePort = readUInt16(bytes, at: transportStart)
            destinationPort = readUInt16(bytes, at: transportStart + 2)
            let tcpHeaderLength = Int(bytes[transportStart + 12] >> 4) * 4
            let payloadStart = transportStart + tcpHeaderLength
            if tcpHeaderLength >= 20, payloadStart < bytes.count {
                payload = Data(bytes[payloadStart...])
            }
        } else if ipProtocol == 17, bytes.count >= transportStart + 8 {
            packetProtocol = .udp
            sourcePort = readUInt16(bytes, at: transportStart)
            destinationPort = readUInt16(bytes, at: transportStart + 2)
            let payloadStart = transportStart + 8
            if payloadStart < bytes.count {
                payload = Data(bytes[payloadStart...])
            }
        } else if ipProtocol == 1 || ipProtocol == 58 {
            packetProtocol = .icmp
        }

        return PacketInfo(
            timestamp: timestamp,
            sourceIP: sourceIP,
            sourcePort: sourcePort,
            destinationIP: destinationIP,
            destinationPort: destinationPort,
            protocol: packetProtocol,
            length: length,
            payload: payload,
            rawData: rawData
        )
    }

    private static func readUInt16(_ bytes: [UInt8], at index: Int) -> UInt16 {
        guard bytes.count > index + 1 else { return 0 }
        return UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }

    private static func ipv4String(_ bytes: [UInt8], start: Int) -> String {
        guard bytes.count >= start + 4 else { return "N/A" }
        return "\(bytes[start]).\(bytes[start + 1]).\(bytes[start + 2]).\(bytes[start + 3])"
    }

    private static func ipv6String(_ bytes: [UInt8], start: Int) -> String {
        guard bytes.count >= start + 16 else { return "N/A" }
        var groups: [String] = []
        for offset in stride(from: 0, to: 16, by: 2) {
            let value = readUInt16(bytes, at: start + offset)
            groups.append(String(format: "%x", value))
        }
        return groups.joined(separator: ":")
    }
}
