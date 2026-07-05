import Foundation

enum PrivacyRedactor {
    static func isEnabled() -> Bool {
        MacPulseSettings.bool(
            forKey: MacPulseSettings.Key.privacyMode,
            defaultValue: MacPulseSettings.Default.privacyMode
        )
    }

    static func ipAddress(_ value: String, enabled: Bool) -> String {
        guard enabled else { return value }

        if value.contains(".") {
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 4 else { return "redacted-ip" }
            return "xxx.xxx.xxx.\(parts[3])"
        }

        if value.contains(":") {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            if let last = parts.last, !last.isEmpty {
                return "xxxx:...:\(last)"
            }
            return "redacted-ipv6"
        }

        return "redacted-ip"
    }

    static func macAddress(_ value: String, enabled: Bool) -> String {
        guard enabled else { return value }

        let separator: Character = value.contains("-") ? "-" : ":"
        let parts = value.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 6, let last = parts.last else { return "redacted-mac" }
        return "xx\(separator)xx\(separator)xx\(separator)xx\(separator)xx\(separator)\(last.uppercased())"
    }

    static func hostname(_ value: String?, enabled: Bool) -> String? {
        guard let value, !value.isEmpty else { return value }
        guard enabled else { return value }
        return "host-\(stableToken(for: value))"
    }

    static func processName(_ value: String?, enabled: Bool) -> String? {
        guard let value, !value.isEmpty else { return value }
        guard enabled else { return value }
        return "process-\(stableToken(for: value))"
    }

    static func redactSensitiveText(_ value: String, enabled: Bool) -> String {
        guard enabled else { return value }

        var result = replaceMatches(
            in: value,
            pattern: #"\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b"#
        ) {
            macAddress($0, enabled: true)
        }
        result = replaceMatches(
            in: result,
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
        ) {
            ipAddress($0, enabled: true)
        }
        return result
    }

    private static func stableToken(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(String(hash, radix: 16).prefix(8))
    }

    private static func replaceMatches(
        in value: String,
        pattern: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }

        var result = value
        let matches = regex.matches(
            in: value,
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        )

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(String(result[range])))
        }

        return result
    }
}
