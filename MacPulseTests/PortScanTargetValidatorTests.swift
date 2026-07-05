import Testing
@testable import MacPulse

struct PortScanTargetValidatorTests {
    @Test
    func acceptsAndNormalizesIPv4() {
        #expect(PortScanTargetValidator.normalizedTarget(" 192.168.1.10 ") == "192.168.1.10")
        #expect(PortScanTargetValidator.validationMessage(for: "192.168.1.10") == nil)
    }

    @Test
    func acceptsAndNormalizesHostnames() {
        #expect(PortScanTargetValidator.normalizedTarget("Example.COM") == "example.com")
        #expect(PortScanTargetValidator.normalizedTarget("localhost") == "localhost")
    }

    @Test
    func acceptsIPv6WithOrWithoutBrackets() {
        #expect(PortScanTargetValidator.normalizedTarget("::1") == "::1")
        #expect(PortScanTargetValidator.normalizedTarget("[::1]") == "::1")
    }

    @Test
    func rejectsUrlsPathsAndHostsWithSpaces() {
        #expect(PortScanTargetValidator.normalizedTarget("https://example.com") == nil)
        #expect(PortScanTargetValidator.normalizedTarget("example.com/admin") == nil)
        #expect(PortScanTargetValidator.normalizedTarget("bad host.local") == nil)
    }

    @Test
    func rejectsInvalidIPAddressesAndHostnames() {
        #expect(PortScanTargetValidator.normalizedTarget("999.1.1.1") == nil)
        #expect(PortScanTargetValidator.normalizedTarget("-example.local") == nil)
        #expect(PortScanTargetValidator.normalizedTarget("example_.local") == nil)
        #expect(PortScanTargetValidator.normalizedTarget(".example.local") == nil)
    }
}
