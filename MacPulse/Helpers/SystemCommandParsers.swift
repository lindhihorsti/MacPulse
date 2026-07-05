import Foundation

struct ParsedARPEntry {
    let ipAddress: String
    let macAddress: String
    let hostname: String?
}

enum SystemCommandParsers {
    static func parseLsofConnections(_ output: String) -> [NetworkConnection] {
        output
            .components(separatedBy: "\n")
            .dropFirst()
            .compactMap(parseLsofConnectionLine)
    }

    static func parseDefaultGateway(fromNetstat output: String) -> String {
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 2, parts[0] == "default" else { continue }
            return parts[1]
        }
        return ""
    }

    static func parseARPEntries(_ output: String) -> [ParsedARPEntry] {
        output.components(separatedBy: "\n").compactMap(parseARPLine)
    }

    static func parseHardwarePorts(_ output: String) -> [String: String] {
        var ports: [String: String] = [:]
        var currentPort = ""

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("Hardware Port:") {
                currentPort = line
                    .replacingOccurrences(of: "Hardware Port: ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("Device:") {
                let device = line
                    .replacingOccurrences(of: "Device: ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !device.isEmpty && !currentPort.isEmpty {
                    ports[device] = currentPort
                }
            }
        }

        return ports
    }

    private static func parseLsofConnectionLine(_ line: String) -> NetworkConnection? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 9 else { return nil }

        let processName = parts[0]
        let pid = Int32(parts[1]) ?? 0
        let protocolStr = parts[7].uppercased()
        let nameField = parts[8...].joined(separator: " ")

        let proto: ConnectionProtocol
        if protocolStr.contains("TCP") {
            proto = protocolStr.contains("6") ? .tcp6 : .tcp
        } else if protocolStr.contains("UDP") {
            proto = protocolStr.contains("6") ? .udp6 : .udp
        } else {
            return nil
        }

        let cleanedNameField = nameField.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = parseConnectionState(in: cleanedNameField, defaultProtocol: proto)
        let endpointField = cleanedNameField.replacingOccurrences(
            of: #"\s+\([A-Z0-9_]+\)$"#,
            with: "",
            options: .regularExpression
        )

        let addressParts = endpointField.components(separatedBy: "->")
        guard let localPart = addressParts.first else { return nil }

        let (localAddr, localPort) = parseAddressPort(localPart)
        var remoteAddr = "*"
        var remotePort: UInt16 = 0

        if addressParts.count > 1 {
            (remoteAddr, remotePort) = parseAddressPort(addressParts[1])
        }

        return NetworkConnection(
            localAddress: localAddr,
            localPort: localPort,
            remoteAddress: remoteAddr,
            remotePort: remotePort,
            protocol: proto,
            state: state,
            processName: processName,
            pid: pid
        )
    }

    private static func parseARPLine(_ line: String) -> ParsedARPEntry? {
        guard let ipStart = line.firstIndex(of: "("),
              let ipEnd = line.firstIndex(of: ")"),
              line.contains(" at "),
              !line.contains("(incomplete)")
        else { return nil }

        let ip = String(line[line.index(after: ipStart)..<ipEnd])

        guard let atRange = line.range(of: " at "),
              let onRange = line.range(of: " on ")
        else { return nil }

        let rawMAC = String(line[atRange.upperBound..<onRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawMAC.contains(":"), rawMAC != "(incomplete)" else { return nil }

        let normalizedMAC = normalizeMACAddress(rawMAC)
        guard !normalizedMAC.isEmpty else { return nil }

        var hostname: String?
        let rawHostname = String(line[..<ipStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        if rawHostname != "?" && !rawHostname.isEmpty {
            hostname = rawHostname
        }

        return ParsedARPEntry(ipAddress: ip, macAddress: normalizedMAC, hostname: hostname)
    }

    private static func parseAddressPort(_ str: String) -> (String, UInt16) {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("[") {
            guard let bracketEnd = trimmed.lastIndex(of: "]") else { return (trimmed, 0) }
            let addr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<bracketEnd])
            let portPart = trimmed[trimmed.index(after: bracketEnd)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return (addr, UInt16(portPart) ?? 0)
        }

        guard let colonIndex = trimmed.lastIndex(of: ":") else { return (trimmed, 0) }
        let addr = String(trimmed[..<colonIndex])
        let port = UInt16(trimmed[trimmed.index(after: colonIndex)...]) ?? 0
        return (addr, port)
    }

    private static func parseConnectionState(in field: String, defaultProtocol: ConnectionProtocol) -> ConnectionState {
        if let openParen = field.lastIndex(of: "("),
           let closeParen = field.lastIndex(of: ")"),
           openParen < closeParen {
            let state = String(field[field.index(after: openParen)..<closeParen])
            return parseConnectionState(state)
        }

        if defaultProtocol == .udp || defaultProtocol == .udp6 {
            return .unknown
        }

        return .established
    }

    private static func parseConnectionState(_ str: String) -> ConnectionState {
        switch str.uppercased() {
        case "ESTABLISHED": return .established
        case "LISTEN": return .listen
        case "TIME_WAIT": return .timeWait
        case "CLOSE_WAIT": return .closeWait
        case "SYN_SENT": return .synSent
        case "SYN_RECV", "SYN_RECEIVED": return .synReceived
        case "FIN_WAIT_1", "FIN_WAIT1": return .finWait1
        case "FIN_WAIT_2", "FIN_WAIT2": return .finWait2
        case "CLOSING": return .closing
        case "LAST_ACK": return .lastAck
        case "CLOSED": return .closed
        default: return .unknown
        }
    }

    private static func normalizeMACAddress(_ mac: String) -> String {
        let parts = mac.split(separator: ":")
        guard parts.count == 6 else { return "" }

        return parts.map { part in
            let hex = String(part).uppercased()
            return hex.count == 1 ? "0" + hex : hex
        }.joined(separator: ":")
    }
}
