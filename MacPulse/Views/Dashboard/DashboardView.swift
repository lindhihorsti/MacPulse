import SwiftUI

struct DashboardView: View {
    @Environment(SystemMonitorService.self) private var systemMonitor: SystemMonitorService?
    @State private var localMonitor: SystemMonitorService?

    private var monitor: SystemMonitorService {
        systemMonitor ?? localMonitor ?? SystemMonitorService()
    }

    private var hasBattery: Bool {
        monitor.batteryStats.percentage > 0 || monitor.batteryStats.cycleCount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(
                title: "Dashboard",
                subtitle: "System overview",
                icon: "chart.bar.xaxis",
                iconColor: .appAccent
            )

            ScrollView {
            VStack(spacing: 16) {
                // Top row: CPU and Memory — equal height via SectionCardView maxHeight
                HStack(spacing: 16) {
                    CPUCardView(stats: monitor.cpuStats, history: monitor.cpuHistory)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    MemoryCardView(stats: monitor.memoryStats)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Second row: Network and Disk — equal height
                HStack(spacing: 16) {
                    NetworkCardView(
                        stats: monitor.networkStats,
                        inHistory: monitor.networkInHistory,
                        outHistory: monitor.networkOutHistory
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    DiskCardView(stats: monitor.diskStats)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Third row: GPU and Battery/System — equal height
                HStack(spacing: 16) {
                    GPUCardView(stats: monitor.gpuStats)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if hasBattery {
                        BatteryCardView(stats: monitor.batteryStats)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SystemInfoCardView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            // Only start local monitor if no environment monitor
            if systemMonitor == nil {
                let newMonitor = SystemMonitorService()
                localMonitor = newMonitor
                newMonitor.start()
            }
        }
        .onDisappear {
            localMonitor?.stop()
        }
        } // end outer VStack
    }
}

// MARK: - CPU Card
struct CPUCardView: View {
    let stats: CPUStats
    let history: [Double]

    var body: some View {
        SectionCardView(title: "CPU", icon: "cpu", iconColor: .cpuColor) {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    GaugeRingView(
                        value: stats.usage,
                        color: .cpuColor
                    )
                    .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("User")
                                .font(.label)
                                .foregroundStyle(.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f%%", stats.userUsage))
                                .font(.mono)
                                .foregroundStyle(.textPrimary)
                        }
                        HStack {
                            Text("System")
                                .font(.label)
                                .foregroundStyle(.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f%%", stats.systemUsage))
                                .font(.mono)
                                .foregroundStyle(.textPrimary)
                        }
                        HStack {
                            Text("Idle")
                                .font(.label)
                                .foregroundStyle(.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f%%", stats.idleUsage))
                                .font(.mono)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Per-core usage bars
                if !stats.coreUsages.isEmpty {
                    CoreGridView(coreUsages: stats.coreUsages)
                        .frame(height: 50)
                }

                SparklineView(data: history, color: .cpuColor)
                    .frame(height: 40)

                // CPU Info
                Text(stats.modelName.isEmpty ? "CPU" : stats.modelName)
                    .font(.monoSmall)
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Core Grid
struct CoreGridView: View {
    let coreUsages: [Double]

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let count = CGFloat(coreUsages.count)
            let barWidth = (geometry.size.width - (spacing * (count - 1))) / count

            HStack(spacing: spacing) {
                ForEach(0..<coreUsages.count, id: \.self) { index in
                    CoreBarView(usage: coreUsages[index], index: index)
                        .frame(width: barWidth)
                }
            }
        }
    }
}

struct CoreBarView: View {
    let usage: Double
    let index: Int

    var color: Color {
        if usage > 80 { return .danger }
        if usage > 50 { return .warning }
        return .cpuColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.backgroundTertiary)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(height: geometry.size.height * min(max(usage / 100, 0), 1))
            }
        }
    }
}

// MARK: - Memory Card
struct MemoryCardView: View {
    let stats: MemoryStats

    var body: some View {
        SectionCardView(title: "Memory", icon: "memorychip", iconColor: .ramColor) {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    GaugeRingView(
                        value: stats.usedPercentage,
                        color: .ramColor
                    )
                    .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 6) {
                        MemoryRow(label: "Wired", value: stats.wired, color: .danger)
                        MemoryRow(label: "Active", value: stats.active, color: .ramColor)
                        MemoryRow(label: "Compressed", value: stats.compressed, color: .warning)
                        MemoryRow(label: "Free", value: stats.free, color: .textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Memory bar
                MemoryBreakdownView(stats: stats)
                    .frame(height: 8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used")
                            .font(.label)
                            .foregroundStyle(.textSecondary)
                        Text(stats.used.formattedBytes)
                            .font(.metricSmall)
                            .foregroundStyle(.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Total")
                            .font(.label)
                            .foregroundStyle(.textSecondary)
                        Text(stats.total.formattedBytes)
                            .font(.metricSmall)
                            .foregroundStyle(.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Available")
                            .font(.label)
                            .foregroundStyle(.textSecondary)
                        Text(stats.available.formattedBytes)
                            .font(.metricSmall)
                            .foregroundStyle(.success)
                    }
                }

                if stats.swapUsed > 0 {
                    HStack {
                        Text("Swap")
                            .font(.label)
                            .foregroundStyle(.textSecondary)
                        Spacer()
                        Text("\(stats.swapUsed.formattedBytes) / \(stats.swapTotal.formattedBytes)")
                            .font(.mono)
                            .foregroundStyle(.warning)
                    }
                }
            }
        }
    }
}

struct MemoryRow: View {
    let label: String
    let value: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.label)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(value.formattedBytes)
                .font(.mono)
                .foregroundStyle(.textPrimary)
        }
    }
}

struct MemoryBreakdownView: View {
    let stats: MemoryStats

    var body: some View {
        GeometryReader { geometry in
            let total = max(Double(stats.total), 1)
            let wiredWidth = geometry.size.width * Double(stats.wired) / total
            let activeWidth = geometry.size.width * Double(stats.active) / total
            let compressedWidth = geometry.size.width * Double(stats.compressed) / total

            HStack(spacing: 1) {
                if wiredWidth > 0 {
                    Rectangle()
                        .fill(Color.danger.opacity(0.8))
                        .frame(width: wiredWidth)
                }
                if activeWidth > 0 {
                    Rectangle()
                        .fill(Color.ramColor)
                        .frame(width: activeWidth)
                }
                if compressedWidth > 0 {
                    Rectangle()
                        .fill(Color.warning)
                        .frame(width: compressedWidth)
                }
                Rectangle()
                    .fill(Color.backgroundTertiary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - GPU Card
struct GPUCardView: View {
    let stats: GPUStats

    var body: some View {
        SectionCardView(title: "GPU", icon: "gpu", iconColor: .gpuColor) {
            HStack(spacing: 16) {
                if stats.usage > 0 {
                    GaugeRingView(
                        value: stats.usage,
                        lineWidth: 8,
                        color: .gpuColor
                    )
                    .frame(width: 60, height: 60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.name.isEmpty ? "Apple Silicon GPU" : stats.name)
                        .font(.metricSmall)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    if stats.usage > 0 {
                        Text("Utilization: \(Int(stats.usage))%")
                            .font(.mono)
                            .foregroundStyle(.textSecondary)
                    } else {
                        Text("Unified Memory")
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Disk Card
struct DiskCardView: View {
    let stats: DiskStats

    var body: some View {
        SectionCardView(title: "Storage", icon: "internaldrive", iconColor: .diskColor) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    SpeedIndicator(
                        label: "Read",
                        speed: stats.readBytesPerSec,
                        icon: "arrow.down.to.line",
                        color: .netColor
                    )
                    SpeedIndicator(
                        label: "Write",
                        speed: stats.writeBytesPerSec,
                        icon: "arrow.up.to.line",
                        color: .diskColor
                    )
                }

                if stats.volumes.isEmpty {
                    Text("Loading volumes...")
                        .font(.label)
                        .foregroundStyle(.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(stats.volumes) { volume in
                        VolumeRowView(volume: volume)
                    }
                }
            }
        }
    }
}

struct VolumeRowView: View {
    let volume: VolumeInfo

    var color: Color {
        if volume.usedPercentage > 90 { return .danger }
        if volume.usedPercentage > 75 { return .warning }
        return .diskColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(color)

                Text(volume.name)
                    .font(.metricSmall)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(Int(volume.usedPercentage))%")
                    .font(.mono)
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.backgroundTertiary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(volume.usedPercentage / 100, 1))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(volume.usedSpace.formattedBytes) used")
                    .font(.label)
                    .foregroundStyle(.textSecondary)
                Spacer()
                Text("\(volume.freeSpace.formattedBytes) free")
                    .font(.label)
                    .foregroundStyle(.textTertiary)
            }
        }
    }
}

// MARK: - Battery Card
struct BatteryCardView: View {
    let stats: BatteryStats

    var statusColor: Color {
        if stats.percentage <= 10 { return .danger }
        if stats.percentage <= 20 { return .warning }
        return .success
    }

    var hasBattery: Bool {
        stats.percentage > 0 || stats.cycleCount > 0
    }

    var body: some View {
        SectionCardView(title: "Battery", icon: batteryIcon, iconColor: statusColor) {
            if hasBattery {
                VStack(spacing: 10) {
                    HStack {
                        Text("\(stats.percentage)%")
                            .font(.metricMedium)
                            .foregroundStyle(.textPrimary)

                        if stats.isCharging {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.success)
                        }

                        Spacer()

                        if let timeRemaining = stats.timeRemaining, timeRemaining > 0 {
                            Text(timeRemaining.formattedMinutes)
                                .font(.mono)
                                .foregroundStyle(.textSecondary)
                        }
                    }

                    // Battery bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.backgroundTertiary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(statusColor)
                                .frame(width: geometry.size.width * Double(stats.percentage) / 100)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Label("\(stats.cycleCount) cycles", systemImage: "arrow.triangle.2.circlepath")
                            .font(.label)
                            .foregroundStyle(.textSecondary)

                        Spacer()

                        Label(stats.healthStatus, systemImage: stats.health >= 80 ? "checkmark.circle" : "exclamationmark.triangle")
                            .font(.label)
                            .foregroundStyle(stats.health >= 80 ? .success : .warning)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "bolt.slash")
                        .foregroundStyle(.textTertiary)
                    Text("No battery detected")
                        .font(.label)
                        .foregroundStyle(.textTertiary)
                    Spacer()
                }
            }
        }
    }

    var batteryIcon: String {
        if !hasBattery { return "powerplug" }
        if stats.isCharging { return "battery.100.bolt" }
        switch stats.percentage {
        case 0..<13: return "battery.0"
        case 13..<38: return "battery.25"
        case 38..<63: return "battery.50"
        case 63..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

// MARK: - System Info Card (for Desktop Macs without battery)
struct SystemInfoCardView: View {
    var body: some View {
        SectionCardView(title: "System", icon: "desktopcomputer", iconColor: .appAccent) {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                InfoRow(label: "Uptime", value: uptimeString)
                InfoRow(label: "Host", value: Host.current().localizedName ?? "Mac")
            }
        }
    }

    private var uptimeString: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.label)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(value)
                .font(.mono)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - Network Card
struct NetworkCardView: View {
    let stats: NetworkStats
    let inHistory: [Double]
    let outHistory: [Double]

    var body: some View {
        SectionCardView(title: "Network", icon: "network", iconColor: .netColor) {
            VStack(spacing: 12) {
                // Current speeds
                HStack(spacing: 20) {
                    SpeedIndicator(
                        label: "Download",
                        speed: stats.bytesInPerSec,
                        icon: "arrow.down",
                        color: .success
                    )

                    SpeedIndicator(
                        label: "Upload",
                        speed: stats.bytesOutPerSec,
                        icon: "arrow.up",
                        color: .appAccent
                    )
                }

                // Traffic graph
                NetworkGraphView(inData: inHistory, outData: outHistory)
                    .frame(height: 60)

                // Total transferred
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.success)
                        Text(stats.bytesIn.formattedBytes)
                            .font(.mono)
                            .foregroundStyle(.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.appAccent)
                        Text(stats.bytesOut.formattedBytes)
                            .font(.mono)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
    }
}

struct SpeedIndicator: View {
    let label: String
    let speed: UInt64
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.label)
                    .foregroundStyle(.textSecondary)
            }

            Text(speed.formattedSpeed)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NetworkGraphView: View {
    let inData: [Double]
    let outData: [Double]
    @AppStorage(MacPulseSettings.Key.appTheme)
    private var appTheme = MacPulseSettings.Default.appTheme

    private var isLightTheme: Bool {
        MacPulseTheme(rawValue: appTheme) == .light
    }

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(inData.max() ?? 1, outData.max() ?? 1, 1)

            ZStack {
                // Download area
                Path { path in
                    guard inData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(inData.count - 1)

                    path.move(to: CGPoint(x: 0, y: geometry.size.height))

                    for (index, value) in inData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (CGFloat(value / maxValue) * geometry.size.height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.success.opacity(isLightTheme ? 0.22 : 0.3),
                            Color.success.opacity(isLightTheme ? 0.04 : 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Upload area
                Path { path in
                    guard outData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(outData.count - 1)

                    path.move(to: CGPoint(x: 0, y: geometry.size.height))

                    for (index, value) in outData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (CGFloat(value / maxValue) * geometry.size.height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appAccent.opacity(isLightTheme ? 0.22 : 0.3),
                            Color.appAccent.opacity(isLightTheme ? 0.04 : 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Download line
                Path { path in
                    guard inData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(inData.count - 1)

                    for (index, value) in inData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (CGFloat(value / maxValue) * geometry.size.height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.success, lineWidth: isLightTheme ? 2.0 : 1.5)

                // Upload line
                Path { path in
                    guard outData.count > 1 else { return }
                    let stepX = geometry.size.width / CGFloat(outData.count - 1)

                    for (index, value) in outData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (CGFloat(value / maxValue) * geometry.size.height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.appAccent, lineWidth: isLightTheme ? 2.0 : 1.5)
            }
        }
        .background(Color.backgroundTertiary.opacity(isLightTheme ? 0.72 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .id("network-graph-\(appTheme)")
    }
}

#Preview {
    DashboardView()
        .frame(width: 900, height: 700)
}
