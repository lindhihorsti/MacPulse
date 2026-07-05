import XCTest
@testable import MacPulse

final class SystemCommandParsersTests: XCTestCase {
    func testParseLsofTCPConnectionWithState() {
        let output = """
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
Safari   123 dennis 42u  IPv4 0xabc1234567890000      0t0  TCP 192.168.1.20:53312->142.250.185.14:443 (ESTABLISHED)
"""

        let connections = SystemCommandParsers.parseLsofConnections(output)

        XCTAssertEqual(connections.count, 1)
        XCTAssertEqual(connections[0].processName, "Safari")
        XCTAssertEqual(connections[0].pid, 123)
        XCTAssertEqual(connections[0].protocol, .tcp)
        XCTAssertEqual(connections[0].localAddress, "192.168.1.20")
        XCTAssertEqual(connections[0].localPort, 53312)
        XCTAssertEqual(connections[0].remoteAddress, "142.250.185.14")
        XCTAssertEqual(connections[0].remotePort, 443)
        XCTAssertEqual(connections[0].state, .established)
    }

    func testParseLsofListenConnection() {
        let output = """
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
ControlC 456 dennis 10u  IPv6 0xabc1234567890000      0t0  TCP *:7000 (LISTEN)
"""

        let connections = SystemCommandParsers.parseLsofConnections(output)

        XCTAssertEqual(connections.count, 1)
        XCTAssertEqual(connections[0].localAddress, "*")
        XCTAssertEqual(connections[0].localPort, 7000)
        XCTAssertEqual(connections[0].remoteAddress, "*")
        XCTAssertEqual(connections[0].remotePort, 0)
        XCTAssertEqual(connections[0].state, .listen)
    }

    func testParseDefaultGatewayFromNetstat() {
        let output = """
Routing tables

Internet:
Destination        Gateway            Flags               Netif Expire
default            192.168.1.1        UGScg                 en0
127                127.0.0.1          UCS                   lo0
"""

        XCTAssertEqual(SystemCommandParsers.parseDefaultGateway(fromNetstat: output), "192.168.1.1")
    }

    func testParseARPEntriesNormalizesMACAndSkipsIncompleteRows() {
        let output = """
router.local (192.168.1.1) at 0:1d:63:aa:b:5 on en0 ifscope [ethernet]
? (192.168.1.44) at (incomplete) on en0 ifscope [ethernet]
iphone.local (192.168.1.22) at a4:83:e7:1:2:3 on en0 ifscope [ethernet]
"""

        let entries = SystemCommandParsers.parseARPEntries(output)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].hostname, "router.local")
        XCTAssertEqual(entries[0].ipAddress, "192.168.1.1")
        XCTAssertEqual(entries[0].macAddress, "00:1D:63:AA:0B:05")
        XCTAssertEqual(entries[1].hostname, "iphone.local")
        XCTAssertEqual(entries[1].macAddress, "A4:83:E7:01:02:03")
    }

    func testParseHardwarePorts() {
        let output = """
Hardware Port: Wi-Fi
Device: en0
Ethernet Address: aa:bb:cc:dd:ee:ff

Hardware Port: Thunderbolt Bridge
Device: bridge0
Ethernet Address: 11:22:33:44:55:66
"""

        let ports = SystemCommandParsers.parseHardwarePorts(output)

        XCTAssertEqual(ports["en0"], "Wi-Fi")
        XCTAssertEqual(ports["bridge0"], "Thunderbolt Bridge")
    }
}
