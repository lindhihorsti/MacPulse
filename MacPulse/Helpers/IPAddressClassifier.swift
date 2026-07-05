import Foundation
import Network

enum IPAddressScope: Equatable {
    case publicInternet
    case privateNetwork
    case loopback
    case linkLocal
    case multicast
    case unspecified
    case reserved
    case invalid
}

enum IPAddressClassifier {
    static func scope(for rawValue: String) -> IPAddressScope {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let ipv4 = IPv4Address(value) {
            return ipv4Scope(Array(ipv4.rawValue))
        }

        if let ipv6 = IPv6Address(value) {
            return ipv6Scope(Array(ipv6.rawValue))
        }

        return .invalid
    }

    static func isEligibleForExternalGeoLookup(_ rawValue: String) -> Bool {
        scope(for: rawValue) == .publicInternet
    }

    static func isLocalOrNonRoutable(_ rawValue: String) -> Bool {
        scope(for: rawValue) != .publicInternet
    }

    private static func ipv4Scope(_ bytes: [UInt8]) -> IPAddressScope {
        guard bytes.count == 4 else { return .invalid }

        switch bytes[0] {
        case 0:
            return .unspecified
        case 10:
            return .privateNetwork
        case 100 where (64...127).contains(bytes[1]):
            return .privateNetwork
        case 127:
            return .loopback
        case 169 where bytes[1] == 254:
            return .linkLocal
        case 172 where (16...31).contains(bytes[1]):
            return .privateNetwork
        case 192 where bytes[1] == 168:
            return .privateNetwork
        case 224...239:
            return .multicast
        case 240...255:
            return .reserved
        default:
            return .publicInternet
        }
    }

    private static func ipv6Scope(_ bytes: [UInt8]) -> IPAddressScope {
        guard bytes.count == 16 else { return .invalid }

        if bytes.allSatisfy({ $0 == 0 }) {
            return .unspecified
        }

        if bytes.prefix(15).allSatisfy({ $0 == 0 }) && bytes[15] == 1 {
            return .loopback
        }

        if bytes[0] == 0xff {
            return .multicast
        }

        if (bytes[0] & 0xfe) == 0xfc {
            return .privateNetwork
        }

        if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 {
            return .linkLocal
        }

        return .publicInternet
    }
}
