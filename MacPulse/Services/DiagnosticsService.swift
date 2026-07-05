import Foundation

enum DiagnosticStatus: String, Equatable {
    case ok
    case warning
    case failed
}

struct DiagnosticCheck: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let status: DiagnosticStatus
}

struct DiagnosticsEnvironment {
    var fileExists: (String) -> Bool
    var isExecutableFile: (String) -> Bool
    var isReadableFile: (String) -> Bool
    var contentsOfDirectory: (String) -> [String]
    var refreshInterval: () -> Double

    static let live = DiagnosticsEnvironment(
        fileExists: { FileManager.default.fileExists(atPath: $0) },
        isExecutableFile: { FileManager.default.isExecutableFile(atPath: $0) },
        isReadableFile: { FileManager.default.isReadableFile(atPath: $0) },
        contentsOfDirectory: { path in
            (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        },
        refreshInterval: {
            MacPulseSettings.double(
                forKey: MacPulseSettings.Key.refreshInterval,
                defaultValue: MacPulseSettings.Default.refreshInterval
            )
        }
    )
}

final class DiagnosticsService {
    private let environment: DiagnosticsEnvironment

    init(environment: DiagnosticsEnvironment = .live) {
        self.environment = environment
    }

    func runChecks() -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []
        checks.append(contentsOf: systemToolChecks())
        checks.append(bpfAccessCheck())
        checks.append(bpfLaunchDaemonCheck())
        checks.append(settingsCheck())
        return checks
    }

    private func systemToolChecks() -> [DiagnosticCheck] {
        [
            (id: "tool-lsof", title: "lsof", path: "/usr/sbin/lsof"),
            (id: "tool-arp", title: "arp", path: "/usr/sbin/arp"),
            (id: "tool-netstat", title: "netstat", path: "/usr/sbin/netstat"),
            (id: "tool-networksetup", title: "networksetup", path: "/usr/sbin/networksetup"),
        ].map { tool in
            if environment.isExecutableFile(tool.path) {
                return DiagnosticCheck(
                    id: tool.id,
                    title: tool.title,
                    message: "\(tool.path) is executable",
                    status: .ok
                )
            }

            return DiagnosticCheck(
                id: tool.id,
                title: tool.title,
                message: "\(tool.path) is missing or not executable",
                status: .failed
            )
        }
    }

    private func bpfAccessCheck() -> DiagnosticCheck {
        let devices = environment.contentsOfDirectory("/dev")
            .filter { $0.hasPrefix("bpf") }
            .map { "/dev/\($0)" }
            .sorted()

        guard !devices.isEmpty else {
            return DiagnosticCheck(
                id: "bpf-devices",
                title: "BPF Devices",
                message: "No /dev/bpf* devices are visible",
                status: .warning
            )
        }

        let readableCount = devices.filter(environment.isReadableFile).count
        if readableCount > 0 {
            return DiagnosticCheck(
                id: "bpf-devices",
                title: "BPF Devices",
                message: "\(readableCount) of \(devices.count) BPF devices are readable",
                status: .ok
            )
        }

        return DiagnosticCheck(
            id: "bpf-devices",
            title: "BPF Devices",
            message: "\(devices.count) BPF devices found, none readable",
            status: .warning
        )
    }

    private func bpfLaunchDaemonCheck() -> DiagnosticCheck {
        let path = "/Library/LaunchDaemons/com.macpulse.bpf.plist"
        if environment.fileExists(path) {
            return DiagnosticCheck(
                id: "bpf-launchdaemon",
                title: "BPF LaunchDaemon",
                message: "\(path) is installed",
                status: .ok
            )
        }

        return DiagnosticCheck(
            id: "bpf-launchdaemon",
            title: "BPF LaunchDaemon",
            message: "Persistent BPF helper is not installed",
            status: .warning
        )
    }

    private func settingsCheck() -> DiagnosticCheck {
        let interval = environment.refreshInterval()
        guard interval > 0 else {
            return DiagnosticCheck(
                id: "settings-refresh-interval",
                title: "Refresh Interval",
                message: "Refresh interval must be greater than zero",
                status: .failed
            )
        }

        return DiagnosticCheck(
            id: "settings-refresh-interval",
            title: "Refresh Interval",
            message: "Refresh interval is \(interval)s",
            status: .ok
        )
    }
}
