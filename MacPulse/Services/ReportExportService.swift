import Foundation

struct ReportExportInput {
    var generatedAt: Date
    var interfaces: [NetworkInterface]
    var devices: [NetworkDevice]
    var connections: [NetworkConnection]
    var flows: [TrafficFlow]
    var processActivities: [ProcessNetworkActivity]
    var diagnostics: [DiagnosticCheck]
    var privacyMode: Bool

    init(
        generatedAt: Date = Date(),
        interfaces: [NetworkInterface] = [],
        devices: [NetworkDevice] = [],
        connections: [NetworkConnection] = [],
        flows: [TrafficFlow] = [],
        processActivities: [ProcessNetworkActivity] = [],
        diagnostics: [DiagnosticCheck] = [],
        privacyMode: Bool = MacPulseSettings.bool(
            forKey: MacPulseSettings.Key.privacyMode,
            defaultValue: MacPulseSettings.Default.privacyMode
        )
    ) {
        self.generatedAt = generatedAt
        self.interfaces = interfaces
        self.devices = devices
        self.connections = connections
        self.flows = flows
        self.processActivities = processActivities
        self.diagnostics = diagnostics
        self.privacyMode = privacyMode
    }
}

struct ReportSnapshot: Codable, Equatable {
    let generatedAt: Date
    let privacyMode: Bool
    let interfaces: [ReportInterface]
    let devices: [ReportDevice]
    let connections: [ReportConnection]
    let flows: [ReportFlow]
    let processActivities: [ReportProcessActivity]
    let diagnostics: [ReportDiagnostic]
}

struct ReportInterface: Codable, Equatable {
    let name: String
    let displayName: String
    let ipAddress: String
    let subnet: String
    let macAddress: String
    let isUp: Bool
    let isWifi: Bool
    let bytesInPerSec: UInt64
    let bytesOutPerSec: UInt64
}

struct ReportDevice: Codable, Equatable {
    let ipAddress: String
    let macAddress: String
    let hostname: String?
    let vendor: String?
    let isRouter: Bool
    let isLocalDevice: Bool
}

struct ReportConnection: Codable, Equatable {
    let localAddress: String
    let localPort: UInt16
    let remoteAddress: String
    let remotePort: UInt16
    let `protocol`: String
    let state: String
    let processName: String?
    let pid: Int32?
}

struct ReportFlow: Codable, Equatable {
    let sourceIP: String
    let sourcePort: UInt16
    let destinationIP: String
    let destinationPort: UInt16
    let `protocol`: String
    let bytesTransferred: UInt64
    let bytesPerSecond: Double
    let packetCount: Int
}

struct ReportProcessActivity: Codable, Equatable {
    let processName: String
    let pid: Int32?
    let connectionCount: Int
    let correlatedFlowCount: Int
    let bytesTransferred: UInt64
    let bytesPerSecond: Double
    let packetCount: Int
}

struct ReportDiagnostic: Codable, Equatable {
    let id: String
    let title: String
    let message: String
    let status: String
}

enum ReportExportService {
    static func snapshot(from input: ReportExportInput) -> ReportSnapshot {
        let privacyMode = input.privacyMode

        return ReportSnapshot(
            generatedAt: input.generatedAt,
            privacyMode: privacyMode,
            interfaces: input.interfaces.map {
                ReportInterface(
                    name: $0.name,
                    displayName: $0.displayName,
                    ipAddress: PrivacyRedactor.ipAddress($0.ipAddress, enabled: privacyMode),
                    subnet: $0.subnet,
                    macAddress: PrivacyRedactor.macAddress($0.macAddress, enabled: privacyMode),
                    isUp: $0.isUp,
                    isWifi: $0.isWifi,
                    bytesInPerSec: $0.bytesInPerSec,
                    bytesOutPerSec: $0.bytesOutPerSec
                )
            },
            devices: input.devices.map {
                ReportDevice(
                    ipAddress: PrivacyRedactor.ipAddress($0.ipAddress, enabled: privacyMode),
                    macAddress: PrivacyRedactor.macAddress($0.macAddress, enabled: privacyMode),
                    hostname: PrivacyRedactor.hostname($0.hostname, enabled: privacyMode),
                    vendor: $0.vendor,
                    isRouter: $0.isRouter,
                    isLocalDevice: $0.isLocalDevice
                )
            },
            connections: input.connections.map {
                ReportConnection(
                    localAddress: PrivacyRedactor.ipAddress($0.localAddress, enabled: privacyMode),
                    localPort: $0.localPort,
                    remoteAddress: PrivacyRedactor.ipAddress($0.remoteAddress, enabled: privacyMode),
                    remotePort: $0.remotePort,
                    protocol: $0.protocol.rawValue,
                    state: $0.state.rawValue,
                    processName: PrivacyRedactor.processName($0.processName, enabled: privacyMode),
                    pid: $0.pid
                )
            },
            flows: input.flows.map {
                ReportFlow(
                    sourceIP: PrivacyRedactor.ipAddress($0.sourceIP, enabled: privacyMode),
                    sourcePort: $0.sourcePort,
                    destinationIP: PrivacyRedactor.ipAddress($0.destinationIP, enabled: privacyMode),
                    destinationPort: $0.destinationPort,
                    protocol: $0.protocol.rawValue,
                    bytesTransferred: $0.bytesTransferred,
                    bytesPerSecond: $0.bytesPerSecond,
                    packetCount: $0.packetCount
                )
            },
            processActivities: input.processActivities.map {
                ReportProcessActivity(
                    processName: PrivacyRedactor.processName($0.processName, enabled: privacyMode) ?? "System",
                    pid: $0.pid,
                    connectionCount: $0.connections.count,
                    correlatedFlowCount: $0.correlatedFlows.count,
                    bytesTransferred: $0.bytesTransferred,
                    bytesPerSecond: $0.bytesPerSecond,
                    packetCount: $0.packetCount
                )
            },
            diagnostics: input.diagnostics.map {
                ReportDiagnostic(
                    id: $0.id,
                    title: $0.title,
                    message: PrivacyRedactor.redactSensitiveText($0.message, enabled: privacyMode),
                    status: $0.status.rawValue
                )
            }
        )
    }

    static func jsonData(from input: ReportExportInput) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot(from: input))
    }

    static func markdown(from input: ReportExportInput) -> String {
        let snapshot = snapshot(from: input)
        let date = ISO8601DateFormatter().string(from: snapshot.generatedAt)

        var lines: [String] = [
            "# MacPulse Report",
            "",
            "- Generated: \(date)",
            "- Privacy Mode: \(snapshot.privacyMode ? "Enabled" : "Disabled")",
            "",
            "## Interfaces",
        ]

        lines.append(contentsOf: snapshot.interfaces.map {
            "- \($0.displayName) (\($0.name)): \($0.ipAddress), MAC \($0.macAddress), \($0.isUp ? "up" : "down")"
        })
        if snapshot.interfaces.isEmpty { lines.append("- None") }

        lines.append(contentsOf: ["", "## Devices"])
        lines.append(contentsOf: snapshot.devices.map {
            "- \($0.hostname ?? $0.vendor ?? "Unknown Device"): \($0.ipAddress), MAC \($0.macAddress)"
        })
        if snapshot.devices.isEmpty { lines.append("- None") }

        lines.append(contentsOf: ["", "## Connections"])
        lines.append(contentsOf: snapshot.connections.map {
            "- \($0.processName ?? "System") [\($0.protocol)] \($0.localAddress):\($0.localPort) -> \($0.remoteAddress):\($0.remotePort) \($0.state)"
        })
        if snapshot.connections.isEmpty { lines.append("- None") }

        lines.append(contentsOf: ["", "## Top Flows"])
        lines.append(contentsOf: snapshot.flows
            .sorted { $0.bytesPerSecond > $1.bytesPerSecond }
            .prefix(10)
            .map {
                "- \($0.protocol) \($0.sourceIP):\($0.sourcePort) -> \($0.destinationIP):\($0.destinationPort), \(ByteFormatter.formatSpeed(UInt64($0.bytesPerSecond)))"
            })
        if snapshot.flows.isEmpty { lines.append("- None") }

        lines.append(contentsOf: ["", "## Process Network Activity"])
        lines.append(contentsOf: snapshot.processActivities
            .sorted { $0.bytesPerSecond > $1.bytesPerSecond }
            .prefix(10)
            .map {
                "- \($0.processName): \($0.connectionCount) connections, \($0.correlatedFlowCount) flows, \(ByteFormatter.formatSpeed(UInt64($0.bytesPerSecond)))"
            })
        if snapshot.processActivities.isEmpty { lines.append("- None") }

        lines.append(contentsOf: ["", "## Diagnostics"])
        lines.append(contentsOf: snapshot.diagnostics.map {
            "- [\($0.status)] \($0.title): \($0.message)"
        })
        if snapshot.diagnostics.isEmpty { lines.append("- None") }

        return lines.joined(separator: "\n") + "\n"
    }
}
