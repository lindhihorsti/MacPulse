import Testing
@testable import MacPulse

struct IPAddressClassifierTests {
    @Test
    func classifiesPublicAddressesAsGeoEligible() {
        #expect(IPAddressClassifier.scope(for: "8.8.8.8") == .publicInternet)
        #expect(IPAddressClassifier.scope(for: "2001:4860:4860::8888") == .publicInternet)
        #expect(IPAddressClassifier.isEligibleForExternalGeoLookup("8.8.8.8"))
    }

    @Test
    func blocksPrivateAndSharedIPv4RangesFromGeoLookup() {
        #expect(IPAddressClassifier.scope(for: "10.0.0.1") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "172.16.0.1") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "172.31.255.255") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "192.168.1.1") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "100.64.0.1") == .privateNetwork)
        #expect(!IPAddressClassifier.isEligibleForExternalGeoLookup("192.168.1.1"))
    }

    @Test
    func blocksLoopbackLinkLocalMulticastAndReservedIPv4() {
        #expect(IPAddressClassifier.scope(for: "127.0.0.1") == .loopback)
        #expect(IPAddressClassifier.scope(for: "169.254.10.20") == .linkLocal)
        #expect(IPAddressClassifier.scope(for: "224.0.0.251") == .multicast)
        #expect(IPAddressClassifier.scope(for: "255.255.255.255") == .reserved)
        #expect(IPAddressClassifier.scope(for: "0.0.0.0") == .unspecified)
    }

    @Test
    func blocksLocalIPv6ScopesFromGeoLookup() {
        #expect(IPAddressClassifier.scope(for: "::1") == .loopback)
        #expect(IPAddressClassifier.scope(for: "::") == .unspecified)
        #expect(IPAddressClassifier.scope(for: "fe80::1") == .linkLocal)
        #expect(IPAddressClassifier.scope(for: "fc00::1") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "fd12:3456::1") == .privateNetwork)
        #expect(IPAddressClassifier.scope(for: "ff02::fb") == .multicast)
    }

    @Test
    func treatsInvalidInputAsNonRoutable() {
        #expect(IPAddressClassifier.scope(for: "not an ip") == .invalid)
        #expect(IPAddressClassifier.isLocalOrNonRoutable("not an ip"))
    }
}
