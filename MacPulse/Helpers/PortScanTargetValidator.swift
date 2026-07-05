import Foundation
import Network

enum PortScanTargetValidator {
    static func normalizedTarget(_ rawValue: String) -> String? {
        validate(rawValue).target
    }

    static func validationMessage(for rawValue: String) -> String? {
        validate(rawValue).message
    }

    private static func validate(_ rawValue: String) -> (target: String?, message: String?) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return (nil, "Enter an IP address or hostname.")
        }

        guard !trimmed.contains("://") else {
            return (nil, "Enter only a host, not a URL.")
        }

        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return (nil, "Hosts cannot contain spaces.")
        }

        guard !trimmed.contains("/") else {
            return (nil, "Enter only a host, not a path.")
        }

        if let ipv4 = IPv4Address(trimmed) {
            return (String(describing: ipv4), nil)
        }

        if looksLikeIPv4Address(trimmed) {
            return (nil, "IPv4 addresses must be valid.")
        }

        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            let unwrapped = String(trimmed.dropFirst().dropLast())
            if let ipv6 = IPv6Address(unwrapped) {
                return (String(describing: ipv6), nil)
            }
            return (nil, "IPv6 addresses in brackets must be valid.")
        }

        if trimmed.contains(":") {
            if let ipv6 = IPv6Address(trimmed) {
                return (String(describing: ipv6), nil)
            }
            return (nil, "IPv6 addresses must be valid.")
        }

        let lowercased = trimmed.lowercased()
        guard isValidHostname(lowercased) else {
            return (nil, "Enter a valid hostname or IP address.")
        }

        return (lowercased, nil)
    }

    private static func isValidHostname(_ value: String) -> Bool {
        guard value.count <= 253, !value.hasPrefix("."), !value.hasSuffix(".") else {
            return false
        }

        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }

        return labels.allSatisfy { label in
            guard (1...63).contains(label.count) else { return false }
            guard label.first != "-", label.last != "-" else { return false }

            return label.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "-")
            }
        }
    }

    private static func looksLikeIPv4Address(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }
}
