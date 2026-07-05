import SwiftUI

struct PortScanView: View {
    @State private var scanner = PortScannerService()
    @State private var targetHost = ""
    @State private var selectedProfile: PortScannerService.ScanProfile = .quick

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                // Target input
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.textSecondary)
                    TextField("Target IP or hostname", text: $targetHost)
                        .textFieldStyle(.plain)
                        .font(.mono)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 300)

                // Profile picker
                Picker("Profile", selection: $selectedProfile) {
                    ForEach(PortScannerService.ScanProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue).tag(profile)
                    }
                }
                .frame(width: 180)

                Spacer()

                // Scan button
                Button {
                    if scanner.isScanning {
                        scanner.stopScan()
                    } else if !targetHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        scanner.startScan(target: targetHost, profile: selectedProfile)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scanner.isScanning ? "stop.fill" : "play.fill")
                        Text(scanner.isScanning ? "Stop" : "Scan")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(scanner.isScanning ? Color.danger : Color.appAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(targetHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !scanner.isScanning)
            }
            .padding(16)
            .background(Color.backgroundSecondary)

            if let errorMessage = scanner.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.warning)
                    Text(errorMessage)
                        .font(.label)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Button {
                        scanner.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.warning.opacity(0.08))
            }

            // Progress bar
            if scanner.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scanner.progress)
                        .tint(.appAccent)

                    HStack {
                        Text("Scanning port \(scanner.currentPort)...")
                            .font(.label)
                            .foregroundStyle(.textSecondary)

                        Spacer()

                        Text("\(Int(scanner.progress * 100))%")
                            .font(.mono)
                            .foregroundStyle(.textSecondary)

                        Text("•")
                            .foregroundStyle(.textTertiary)

                        Text("\(Int(scanner.scanSpeed)) ports/s")
                            .font(.mono)
                            .foregroundStyle(.netColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.backgroundTertiary.opacity(0.5))
            }

            // Stats bar
            HStack(spacing: 24) {
                StatBadge(
                    value: "\(scanner.openPorts)",
                    label: "Open",
                    color: .success
                )
                StatBadge(
                    value: "\(scanner.results.count)",
                    label: "Found",
                    color: .netColor
                )

                Spacer()

                if !scanner.results.isEmpty {
                    Button {
                        copyResults()
                    } label: {
                        Label("Copy Results", systemImage: "doc.on.doc")
                            .font(.label)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.backgroundSecondary.opacity(0.5))

            // Results table
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Port")
                        .frame(width: 80, alignment: .leading)
                    Text("State")
                        .frame(width: 80, alignment: .center)
                    Text("Service")
                        .frame(width: 120, alignment: .leading)
                    Text("Response Time")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.label)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.backgroundTertiary)

                // Results
                if scanner.results.isEmpty && !scanner.isScanning {
                    VStack(spacing: 12) {
                        Image(systemName: "network")
                            .font(.system(size: 40))
                            .foregroundStyle(.textTertiary)
                        Text("Enter a target and start scanning")
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(scanner.results.sorted { $0.port < $1.port }) { result in
                                PortResultRow(result: result)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.backgroundPrimary)
    }

    private func copyResults() {
        let text = scanner.results
            .sorted { $0.port < $1.port }
            .map { "\($0.port)\t\($0.state.rawValue)\t\($0.service)" }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Port\tState\tService\n" + text, forType: .string)
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.label)
                .foregroundStyle(.textSecondary)
        }
    }
}

struct PortResultRow: View {
    let result: PortScanResult

    var stateColor: Color {
        switch result.state {
        case .open: return .success
        case .closed: return .textTertiary
        case .filtered: return .warning
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(result.port)")
                .font(.mono)
                .foregroundStyle(.textPrimary)
                .frame(width: 80, alignment: .leading)

            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(result.state.rawValue)
                    .foregroundStyle(stateColor)
            }
            .font(.system(size: 12, weight: .medium))
            .frame(width: 80, alignment: .center)

            Text(result.service)
                .font(.label)
                .foregroundStyle(.textSecondary)
                .frame(width: 120, alignment: .leading)

            if let time = result.responseTime {
                Text(String(format: "%.0f ms", time * 1000))
                    .font(.mono)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("-")
                    .font(.mono)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(result.state == .open ? Color.success.opacity(0.05) : Color.clear)
    }
}

#Preview {
    PortScanView()
        .frame(width: 700, height: 500)
}
