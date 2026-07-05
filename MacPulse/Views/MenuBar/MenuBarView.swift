import SwiftUI

struct MenuBarView: View {
    @Bindable var monitor: SystemMonitorService
    let openMainWindow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            MenuBarHeader(onOpen: openMainWindow)

            divider

            // Metric gauges grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MenuBarGauge(
                    value: monitor.cpuStats.usage,
                    label: "CPU",
                    icon: "cpu",
                    color: .cpuColor
                )
                MenuBarGauge(
                    value: Double(monitor.memoryStats.used) / Double(max(monitor.memoryStats.total, 1)) * 100,
                    label: "RAM",
                    icon: "memorychip",
                    color: .ramColor
                )
                MenuBarGauge(
                    value: monitor.gpuStats.usage,
                    label: "GPU",
                    icon: "display",
                    color: .gpuColor
                )
                MenuBarGauge(
                    value: diskUsagePercent,
                    label: "Disk",
                    icon: "internaldrive",
                    color: .diskColor
                )
            }
            .padding(12)

            divider

            // Network speeds
            MenuBarNetworkRow(
                inSpeed:  monitor.networkStats.bytesInPerSec,
                outSpeed: monitor.networkStats.bytesOutPerSec
            )

            // Battery row (if available)
            if monitor.batteryStats.percentage > 0 {
                divider
                MenuBarBatteryRow(stats: monitor.batteryStats)
            }

            divider

            // Footer
            MenuBarFooter(onOpen: openMainWindow)
        }
        .frame(width: 272)
        .background(Color.backgroundPrimary)
    }

    private var diskUsagePercent: Double {
        guard let vol = monitor.diskStats.volumes.first else { return 0 }
        return Double(vol.usedSpace) / Double(max(vol.totalSpace, 1)) * 100
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.surfaceBorder)
            .frame(height: 1)
    }
}

// MARK: - Header

private struct MenuBarHeader: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient.accentGradient)
                    .frame(width: 22, height: 22)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("MacPulse")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.textPrimary)

            Spacer()

            Button(action: onOpen) {
                HStack(spacing: 4) {
                    Text("Open")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.appAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.appAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Mini Gauge

struct MenuBarGauge: View {
    let value: Double
    let label: String
    let icon: String
    let color: Color

    private var displayColor: Color {
        if value > 88 { return .danger }
        if value > 70 { return .warning }
        return color
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(displayColor.opacity(0.15), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(displayColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: displayColor.opacity(0.45), radius: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.72), value: value)

                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(displayColor)
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.textPrimary)
                }
            }
            .frame(width: 54, height: 54)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.backgroundSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Network Row

private struct MenuBarNetworkRow: View {
    let inSpeed: UInt64
    let outSpeed: UInt64

    var body: some View {
        HStack(spacing: 0) {
            NetworkSpeedItem(
                icon: "arrow.down.circle.fill",
                speed: inSpeed,
                label: "Download",
                color: .success
            )

            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(width: 1, height: 32)

            NetworkSpeedItem(
                icon: "arrow.up.circle.fill",
                speed: outSpeed,
                label: "Upload",
                color: .netColor
            )
        }
        .padding(.vertical, 4)
    }
}

private struct NetworkSpeedItem: View {
    let icon: String
    let speed: UInt64
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.textTertiary)
                Text(formatSpeed(speed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func formatSpeed(_ b: UInt64) -> String {
        let v = Double(b)
        if v >= 1e9 { return String(format: "%.1f GB/s", v / 1e9) }
        if v >= 1e6 { return String(format: "%.1f MB/s", v / 1e6) }
        if v >= 1e3 { return String(format: "%.1f KB/s", v / 1e3) }
        return String(format: "%.0f B/s", v)
    }
}

// MARK: - Battery Row

private struct MenuBarBatteryRow: View {
    let stats: BatteryStats

    var fillColor: Color {
        if stats.isCharging          { return .success }
        if stats.percentage <= 10    { return .danger }
        if stats.percentage <= 20    { return .warning }
        return .success
    }

    var body: some View {
        HStack(spacing: 10) {
            // Battery shape
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(Color.textSecondary.opacity(0.6), lineWidth: 1)
                    .frame(width: 26, height: 13)
                // nub
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.6))
                    .frame(width: 2.5, height: 6)
                    .offset(x: 26)
                // fill
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(fillColor)
                    .frame(width: max(2, CGFloat(stats.percentage) / 100 * 22), height: 9)
                    .padding(.leading, 2)
                if stats.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 8)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(stats.percentage)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.textPrimary)
                if stats.isCharging {
                    Text("Charging")
                        .font(.system(size: 10))
                        .foregroundStyle(.success)
                } else if let mins = stats.timeRemaining {
                    Text(formatTime(mins))
                        .font(.system(size: 10))
                        .foregroundStyle(.textSecondary)
                }
            }

            Spacer()

            // Health badge
            if stats.cycleCount > 0 {
                Text("\(stats.cycleCount) cycles")
                    .font(.system(size: 10))
                    .foregroundStyle(.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatTime(_ mins: Int) -> String {
        let h = mins / 60; let m = mins % 60
        return h > 0 ? "\(h)h \(m)m remaining" : "\(m)m remaining"
    }
}

// MARK: - Footer

private struct MenuBarFooter: View {
    let onOpen: () -> Void

    var body: some View {
        HStack {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onOpen) {
                Text("Open MacPulse")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.backgroundSecondary.opacity(0.5))
    }
}

// MARK: - Retained legacy helper
struct BatteryIconView: View {
    let percentage: Int
    let isCharging: Bool

    var fillColor: Color {
        if isCharging { return .success }
        if percentage <= 10 { return .danger }
        if percentage <= 20 { return .warning }
        return .success
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.textSecondary, lineWidth: 1)
                .frame(width: 22, height: 11)
            Rectangle()
                .fill(Color.textSecondary)
                .frame(width: 2, height: 5)
                .offset(x: 22)
            RoundedRectangle(cornerRadius: 1)
                .fill(fillColor)
                .frame(width: max(2, CGFloat(percentage) / 100 * 18), height: 7)
                .padding(.leading, 2)
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.white)
                    .offset(x: 7)
            }
        }
    }
}
