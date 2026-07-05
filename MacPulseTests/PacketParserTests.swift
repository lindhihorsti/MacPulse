import XCTest
@testable import MacPulse

final class PacketParserTests: XCTestCase {
    func testParseIPv4TCPPacket() throws {
        let data = Data(ethernetHeader(etherType: 0x0800) + ipv4Header(protocolNumber: 6) + tcpHeader(sourcePort: 12345, destinationPort: 443))

        let packet = try XCTUnwrap(PacketParser.parse(rawData: data, length: data.count, timestamp: Date()))

        XCTAssertEqual(packet.protocol, .tcp)
        XCTAssertEqual(packet.sourceIP, "192.168.1.20")
        XCTAssertEqual(packet.sourcePort, 12345)
        XCTAssertEqual(packet.destinationIP, "142.250.185.14")
        XCTAssertEqual(packet.destinationPort, 443)
    }

    func testParseIPv4UDPPacketWithPayload() throws {
        let payload: [UInt8] = [0x01, 0x02, 0x03]
        let data = Data(ethernetHeader(etherType: 0x0800) + ipv4Header(protocolNumber: 17) + udpHeader(sourcePort: 5353, destinationPort: 53, payloadLength: payload.count) + payload)

        let packet = try XCTUnwrap(PacketParser.parse(rawData: data, length: data.count, timestamp: Date()))

        XCTAssertEqual(packet.protocol, .udp)
        XCTAssertEqual(packet.sourcePort, 5353)
        XCTAssertEqual(packet.destinationPort, 53)
        XCTAssertEqual(packet.payload, Data(payload))
    }

    func testParseARPPacket() throws {
        let arpPayload: [UInt8] = [
            0x00, 0x01,             // Ethernet
            0x08, 0x00,             // IPv4
            0x06, 0x04,             // MAC and IPv4 lengths
            0x00, 0x01,             // request
            0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
            192, 168, 1, 20,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            192, 168, 1, 1
        ]
        let data = Data(ethernetHeader(etherType: 0x0806) + arpPayload)

        let packet = try XCTUnwrap(PacketParser.parse(rawData: data, length: data.count, timestamp: Date()))

        XCTAssertEqual(packet.protocol, .arp)
        XCTAssertEqual(packet.sourceIP, "192.168.1.20")
        XCTAssertEqual(packet.destinationIP, "192.168.1.1")
        XCTAssertEqual(packet.summary, "ARP 192.168.1.20 → 192.168.1.1")
    }

    func testParseIPv6ICMPPacket() throws {
        let data = Data(ethernetHeader(etherType: 0x86DD) + ipv6Header(nextHeader: 58) + [0x80, 0x00, 0x00, 0x00])

        let packet = try XCTUnwrap(PacketParser.parse(rawData: data, length: data.count, timestamp: Date()))

        XCTAssertEqual(packet.protocol, .icmp)
        XCTAssertEqual(packet.sourceIP, "2001:db8:0:0:0:0:0:1")
        XCTAssertEqual(packet.destinationIP, "2001:db8:0:0:0:0:0:2")
    }

    func testParseIPv6UnknownNextHeaderKeepsIPv6Protocol() throws {
        let data = Data(ethernetHeader(etherType: 0x86DD) + ipv6Header(nextHeader: 59))

        let packet = try XCTUnwrap(PacketParser.parse(rawData: data, length: data.count, timestamp: Date()))

        XCTAssertEqual(packet.protocol, .ipv6)
        XCTAssertEqual(packet.sourcePort, 0)
        XCTAssertEqual(packet.destinationPort, 0)
    }

    private func ethernetHeader(etherType: UInt16) -> [UInt8] {
        [
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
            UInt8(etherType >> 8), UInt8(etherType & 0xff)
        ]
    }

    private func ipv4Header(protocolNumber: UInt8) -> [UInt8] {
        [
            0x45, 0x00, 0x00, 0x28,
            0x00, 0x00, 0x00, 0x00,
            0x40, protocolNumber, 0x00, 0x00,
            192, 168, 1, 20,
            142, 250, 185, 14
        ]
    }

    private func ipv6Header(nextHeader: UInt8) -> [UInt8] {
        [
            0x60, 0x00, 0x00, 0x00,
            0x00, 0x04,
            nextHeader,
            0x40,
            0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02
        ]
    }

    private func tcpHeader(sourcePort: UInt16, destinationPort: UInt16) -> [UInt8] {
        [
            UInt8(sourcePort >> 8), UInt8(sourcePort & 0xff),
            UInt8(destinationPort >> 8), UInt8(destinationPort & 0xff),
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x50, 0x02, 0x20, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]
    }

    private func udpHeader(sourcePort: UInt16, destinationPort: UInt16, payloadLength: Int) -> [UInt8] {
        let udpLength = UInt16(8 + payloadLength)
        return [
            UInt8(sourcePort >> 8), UInt8(sourcePort & 0xff),
            UInt8(destinationPort >> 8), UInt8(destinationPort & 0xff),
            UInt8(udpLength >> 8), UInt8(udpLength & 0xff),
            0x00, 0x00
        ]
    }
}
