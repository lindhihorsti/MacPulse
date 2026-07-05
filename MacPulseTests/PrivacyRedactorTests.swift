import XCTest
@testable import MacPulse

final class PrivacyRedactorTests: XCTestCase {
    func testIPAddressRedactionKeepsShapeWithoutFullAddress() {
        XCTAssertEqual(
            PrivacyRedactor.ipAddress("192.168.1.42", enabled: true),
            "xxx.xxx.xxx.42"
        )
        XCTAssertEqual(
            PrivacyRedactor.ipAddress("192.168.1.42", enabled: false),
            "192.168.1.42"
        )
    }

    func testIPv6RedactionKeepsOnlyLastSegment() {
        XCTAssertEqual(
            PrivacyRedactor.ipAddress("fe80::aede:48ff:fe00:1122", enabled: true),
            "xxxx:...:1122"
        )
    }

    func testMacRedactionKeepsSuffix() {
        XCTAssertEqual(
            PrivacyRedactor.macAddress("AA:BB:CC:DD:EE:FF", enabled: true),
            "xx:xx:xx:xx:xx:FF"
        )
        XCTAssertEqual(
            PrivacyRedactor.macAddress("aa-bb-cc-dd-ee-01", enabled: true),
            "xx-xx-xx-xx-xx-01"
        )
    }

    func testHostAndProcessTokensAreDeterministic() {
        XCTAssertEqual(
            PrivacyRedactor.hostname("dennis-macbook.local", enabled: true),
            PrivacyRedactor.hostname("dennis-macbook.local", enabled: true)
        )
        XCTAssertEqual(
            PrivacyRedactor.processName("Safari", enabled: true),
            PrivacyRedactor.processName("Safari", enabled: true)
        )
        XCTAssertEqual(
            PrivacyRedactor.hostname("dennis-macbook.local", enabled: false),
            "dennis-macbook.local"
        )
    }

    func testSensitiveTextRedactionMasksIPsAndMacs() {
        let text = "Device 192.168.1.42 at AA:BB:CC:DD:EE:FF"
        XCTAssertEqual(
            PrivacyRedactor.redactSensitiveText(text, enabled: true),
            "Device xxx.xxx.xxx.42 at xx:xx:xx:xx:xx:FF"
        )
    }
}
