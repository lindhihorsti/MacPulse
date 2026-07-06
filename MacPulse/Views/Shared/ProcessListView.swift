import SwiftUI
import AppKit

struct ProcessListView: View {
    @State private var processMonitor = ProcessMonitorService()
    @State private var searchText = ""
    @State private var sortKey: SortKey = .cpu
    @State private var sortAscending = false
    @State private var selectedProcess: ProcessStats?
    @State private var showTerminateAlert = false
    @State private var selectedTab = 0

    enum SortKey {
        case name, pid, cpu, memory, user
    }

    var filteredProcesses: [ProcessStats] {
        var result = processMonitor.processes

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                "\($0.id)".contains(searchText)
            }
        }

        return result.sorted { a, b in
            let comparison: Bool
            switch sortKey {
            case .name: comparison = a.name.lowercased() < b.name.lowercased()
            case .pid: comparison = a.id < b.id
            case .cpu: comparison = a.cpuUsage < b.cpuUsage
            case .memory: comparison = a.memoryUsage < b.memoryUsage
            case .user: comparison = a.user < b.user
            }
            return sortAscending ? comparison : !comparison
        }
    }

    var totalCPUUsage: Double {
        filteredProcesses.reduce(0) { $0 + $1.cpuUsage }
    }

    var totalMemoryUsage: UInt64 {
        filteredProcesses.reduce(0) { $0 + $1.memoryUsage }
    }

    var activeProcessCount: Int {
        filteredProcesses.filter { $0.status == .running }.count
    }

    var highImpactProcessCount: Int {
        filteredProcesses.filter { $0.cpuUsage >= 20 || $0.memoryUsageGB >= 1.5 }.count
    }

    var currentSelectedProcess: ProcessStats? {
        guard let selectedProcess else { return nil }
        return processMonitor.processes.first(where: { $0.id == selectedProcess.id }) ?? selectedProcess
    }

    private let processTabs: [SubTabBar.Tab] = [
        .init(id: 0, icon: "tablecells",          title: "Explorer"),
        .init(id: 1, icon: "arrow.triangle.branch", title: "Load Flow"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page header with live process count
            PageHeaderView(
                title: "Processes",
                subtitle: "Running processes & load",
                icon: "list.bullet.rectangle.portrait",
                iconColor: .cpuColor
            ) {
                Text("\(filteredProcesses.count) processes")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Sub-tab bar
            SubTabBar(tabs: processTabs, selectedIndex: $selectedTab)

            if selectedTab == 0 {
                // Search & filter bar
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.textSecondary)
                        TextField("Search processes…", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                    }
                    .frame(maxWidth: 340)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.backgroundSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.surfaceBorder).frame(height: 1)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            ProcessOverviewDashboard(
                                processes: filteredProcesses,
                                totalCPUUsage: totalCPUUsage,
                                totalMemoryUsage: totalMemoryUsage,
                                activeProcessCount: activeProcessCount,
                                highImpactProcessCount: highImpactProcessCount,
                                selectedProcess: $selectedProcess,
                                cpuHistory: { processMonitor.cpuHistory(for: $0.id) },
                                memoryHistory: { processMonitor.memoryHistory(for: $0.id) }
                            )
                            .padding(16)
                        }
                        .background(Color.backgroundPrimary)

                        if let process = currentSelectedProcess {
                            ProcessDetailPanel(
                                process: process,
                                summary: processMonitor.summary(for: process),
                                cpuHistory: processMonitor.cpuHistory(for: process.id),
                                memoryHistory: processMonitor.memoryHistory(for: process.id)
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                        }

                        HStack(spacing: 0) {
                            SortableHeader(title: "Process", key: .name, currentKey: $sortKey, ascending: $sortAscending)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            SortableHeader(title: "PID", key: .pid, currentKey: $sortKey, ascending: $sortAscending)
                                .frame(width: 70, alignment: .trailing)

                            SortableHeader(title: "User", key: .user, currentKey: $sortKey, ascending: $sortAscending)
                                .frame(width: 80, alignment: .leading)

                            SortableHeader(title: "CPU %", key: .cpu, currentKey: $sortKey, ascending: $sortAscending)
                                .frame(width: 80, alignment: .trailing)

                            SortableHeader(title: "Memory", key: .memory, currentKey: $sortKey, ascending: $sortAscending)
                                .frame(width: 90, alignment: .trailing)

                            Text("Status")
                                .font(.label)
                                .foregroundStyle(.textSecondary)
                                .frame(width: 80, alignment: .center)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.backgroundTertiary)

                        LazyVStack(spacing: 0) {
                            ForEach(filteredProcesses) { process in
                                ProcessRow(process: process)
                                    .onTapGesture {
                                        selectedProcess = process
                                    }
                                    .contextMenu {
                                        Button("Copy PID") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString("\(process.id)", forType: .string)
                                        }
                                        Button("Copy Name") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(process.name, forType: .string)
                                        }
                                        Divider()
                                        Button("Terminate Process", role: .destructive) {
                                            selectedProcess = process
                                            showTerminateAlert = true
                                        }
                                    }
                            }
                        }
                    }
                }
            } else {
                ProcessLoadFlowView(
                    processes: filteredProcesses,
                    processSummary: { processMonitor.summary(for: $0) },
                    selectedProcess: $selectedProcess
                )
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            processMonitor.start()
        }
        .onChange(of: processMonitor.processes) { _, _ in
            if let selectedProcess {
                self.selectedProcess = processMonitor.processes.first(where: { $0.id == selectedProcess.id }) ?? selectedProcess
            }
        }
        .onDisappear {
            processMonitor.stop()
        }
        .alert("Terminate Process?", isPresented: $showTerminateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Terminate", role: .destructive) {
                if let process = selectedProcess {
                    _ = processMonitor.terminateProcess(pid: process.id)
                }
            }
        } message: {
            if let process = selectedProcess {
                Text("Are you sure you want to terminate \(process.name) (PID: \(process.id))?")
            }
        }
    }
}

struct ProcessOverviewDashboard: View {
    let processes: [ProcessStats]
    let totalCPUUsage: Double
    let totalMemoryUsage: UInt64
    let activeProcessCount: Int
    let highImpactProcessCount: Int
    @Binding var selectedProcess: ProcessStats?
    let cpuHistory: (ProcessStats) -> [Double]
    let memoryHistory: (ProcessStats) -> [Double]

    private var topCPU: [ProcessStats] {
        Array(processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(6))
    }

    private var topMemory: [ProcessStats] {
        Array(processes.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(6))
    }

    private var userGroups: [ProcessUserSummary] {
        let grouped = Dictionary(grouping: processes, by: \.user)
        return grouped.map { user, processes in
            ProcessUserSummary(
                user: user,
                processCount: processes.count,
                cpuUsage: processes.reduce(0) { $0 + $1.cpuUsage },
                memoryUsage: processes.reduce(0) { $0 + $1.memoryUsage }
            )
        }
        .sorted {
            if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
            return $0.memoryUsage > $1.memoryUsage
        }
    }

    private var statusGroups: [ProcessStatusSummary] {
        ProcessStatus.allCases.compactMap { status in
            let matches = processes.filter { $0.status == status }
            guard !matches.isEmpty else { return nil }
            return ProcessStatusSummary(
                status: status,
                count: matches.count,
                cpuUsage: matches.reduce(0) { $0 + $1.cpuUsage }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProcessMetricCard(
                    title: "Visible Processes",
                    value: "\(processes.count)",
                    detail: "\(activeProcessCount) running",
                    color: .appAccent
                )
                ProcessMetricCard(
                    title: "CPU Footprint",
                    value: String(format: "%.0f%%", totalCPUUsage),
                    detail: "\(highImpactProcessCount) high impact",
                    color: .cpuColor
                )
                ProcessMetricCard(
                    title: "Memory Footprint",
                    value: totalMemoryUsage.formattedBytesCompact,
                    detail: topMemory.first.map { "\($0.name) leads" } ?? "No data",
                    color: .ramColor
                )
                ProcessMetricCard(
                    title: "Selection",
                    value: selectedProcess?.name ?? "None",
                    detail: selectedProcess.map { "PID \($0.id) • \($0.threads) threads" } ?? "Tap a process row",
                    color: .netColor
                )
            }

            HStack(alignment: .top, spacing: 16) {
                ProcessResourcePanel(
                    title: "CPU Hotspots",
                    icon: "flame.fill",
                    accent: .cpuColor,
                    processes: topCPU,
                    selectedProcess: $selectedProcess,
                    sparkline: cpuHistory
                ) { process in
                    String(format: "%.1f%%", process.cpuUsage)
                } ratio: { process in
                    let topValue = max(topCPU.first?.cpuUsage ?? 0, 1)
                    return process.cpuUsage / topValue
                }

                ProcessResourcePanel(
                    title: "Memory Anchors",
                    icon: "memorychip.fill",
                    accent: .ramColor,
                    processes: topMemory,
                    selectedProcess: $selectedProcess,
                    sparkline: memoryHistory
                ) { process in
                    process.memoryUsage.formattedBytesCompact
                } ratio: { process in
                    let topValue = Double(max(topMemory.first?.memoryUsage ?? 1, 1))
                    return Double(process.memoryUsage) / topValue
                }

                ProcessStatusPanel(statusGroups: statusGroups, totalCount: max(processes.count, 1))

                ProcessUserLoadPanel(
                    users: Array(userGroups.prefix(5)),
                    maxCPU: max(userGroups.map(\.cpuUsage).max() ?? 0, 1),
                    maxMemory: max(Double(userGroups.map(\.memoryUsage).max() ?? 1), 1)
                )
            }
        }
    }
}

struct ProcessMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.label)
                .foregroundStyle(.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.textTertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct ProcessResourcePanel: View {
    let title: String
    let icon: String
    let accent: Color
    let processes: [ProcessStats]
    @Binding var selectedProcess: ProcessStats?
    let sparkline: (ProcessStats) -> [Double]
    let valueText: (ProcessStats) -> String
    let ratio: (ProcessStats) -> Double

    var body: some View {
        SectionCardView(title: title, icon: icon, iconColor: accent) {
            VStack(spacing: 10) {
                ForEach(processes) { process in
                    Button {
                        selectedProcess = process
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(process.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(valueText(process))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(accent)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.backgroundTertiary)
                                    Capsule()
                                        .fill(accent.opacity(0.9))
                                        .frame(width: geo.size.width * max(0.06, min(ratio(process), 1.0)))
                                }
                            }
                            .frame(height: 8)

                            HStack {
                                Text("PID \(process.id)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.textTertiary)
                                Spacer()
                                Text("\(process.threads) threads")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.textTertiary)
                            }

                            SparklineView(
                                data: sparkline(process),
                                color: accent,
                                showArea: true,
                                height: 28
                            )
                        }
                        .padding(10)
                        .background(Color.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280)
    }
}

struct ProcessStatusPanel: View {
    let statusGroups: [ProcessStatusSummary]
    let totalCount: Int

    var body: some View {
        SectionCardView(title: "State Mix", icon: "chart.bar.xaxis", iconColor: .warning) {
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    HStack(spacing: 6) {
                        ForEach(statusGroups) { group in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(group.status.color)
                                .frame(width: max(18, geo.size.width * CGFloat(group.count) / CGFloat(totalCount)))
                        }
                    }
                }
                .frame(height: 24)

                ForEach(statusGroups) { group in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(group.status.color)
                            .frame(width: 8, height: 8)
                        Text(group.status.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text("\(group.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.textSecondary)
                        Text(String(format: "%.0f%% CPU", group.cpuUsage))
                            .font(.system(size: 10))
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
        .frame(width: 230)
    }
}

struct ProcessUserLoadPanel: View {
    let users: [ProcessUserSummary]
    let maxCPU: Double
    let maxMemory: Double

    var body: some View {
        SectionCardView(title: "User Load", icon: "person.2.fill", iconColor: .netColor) {
            VStack(spacing: 10) {
                ForEach(users) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(summary.user)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text("\(summary.processCount) procs")
                                .font(.system(size: 10))
                                .foregroundStyle(.textTertiary)
                        }

                        ProcessDualBar(
                            cpuRatio: summary.cpuUsage / maxCPU,
                            memoryRatio: Double(summary.memoryUsage) / maxMemory
                        )

                        HStack {
                            Text(String(format: "%.0f%% CPU", summary.cpuUsage))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.cpuColor)
                            Spacer()
                            Text(summary.memoryUsage.formattedBytesCompact)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.ramColor)
                        }
                    }
                    .padding(10)
                    .background(Color.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(width: 260)
    }
}

struct ProcessDetailPanel: View {
    let process: ProcessStats
    let summary: ProcessSummary
    let cpuHistory: [Double]
    let memoryHistory: [Double]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SectionCardView(title: "Selected Process", icon: "info.circle.fill", iconColor: .appAccent) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        if let icon = process.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.textSecondary)
                                .frame(width: 28, height: 28)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(process.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Text(summary.role)
                                .font(.system(size: 11))
                                .foregroundStyle(.appAccent)
                        }

                        Spacer()
                    }

                    Text(summary.purpose)
                        .font(.system(size: 12))
                        .foregroundStyle(.textPrimary)

                    Text(summary.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.textSecondary)

                    Divider()

                    ProcessDetailGrid(process: process)
                }
            }

            SectionCardView(title: "Behavior Over Time", icon: "chart.xyaxis.line", iconColor: .cpuColor) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CPU Trend")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.textSecondary)
                        SparklineView(data: cpuHistory, color: .cpuColor, showArea: true, height: 70)
                        Text("Current: \(String(format: "%.1f%%", process.cpuUsage))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Memory Trend")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.textSecondary)
                        SparklineView(data: memoryHistory, color: .ramColor, showArea: true, height: 70)
                        Text("Current: \(process.memoryUsage.formattedBytes)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
    }
}

struct ProcessDetailGrid: View {
    let process: ProcessStats

    var body: some View {
        VStack(spacing: 8) {
            detailRow("PID", "\(process.id)")
            detailRow("User", process.user)
            detailRow("Status", process.status.rawValue)
            detailRow("Threads", "\(process.threads)")
            detailRow("Memory", process.memoryUsage.formattedBytes)
            detailRow("Path", process.executablePath)
            if let bundleIdentifier = process.bundleIdentifier {
                detailRow("Bundle ID", bundleIdentifier)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.textTertiary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.textSecondary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct ProcessDualBar: View {
    let cpuRatio: Double
    let memoryRatio: Double

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.backgroundTertiary)
                    Capsule()
                        .fill(Color.cpuColor)
                        .frame(width: geo.size.width * max(0.04, min(cpuRatio, 1.0)))
                }
            }
            .frame(height: 7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.backgroundTertiary)
                    Capsule()
                        .fill(Color.ramColor)
                        .frame(width: geo.size.width * max(0.04, min(memoryRatio, 1.0)))
                }
            }
            .frame(height: 7)
        }
    }
}

struct ProcessUserSummary: Identifiable {
    var id: String { user }
    let user: String
    let processCount: Int
    let cpuUsage: Double
    let memoryUsage: UInt64
}

struct ProcessStatusSummary: Identifiable {
    var id: ProcessStatus { status }
    let status: ProcessStatus
    let count: Int
    let cpuUsage: Double
}

private extension ProcessStatus {
    var color: Color {
        switch self {
        case .running: return .success
        case .sleeping, .idle: return .textSecondary
        case .stopped: return .warning
        case .zombie, .unknown: return .danger
        }
    }
}

struct SortableHeader: View {
    let title: String
    let key: ProcessListView.SortKey
    @Binding var currentKey: ProcessListView.SortKey
    @Binding var ascending: Bool

    var body: some View {
        Button {
            if currentKey == key {
                ascending.toggle()
            } else {
                currentKey = key
                ascending = false
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.label)
                    .foregroundStyle(currentKey == key ? .textPrimary : .textSecondary)

                if currentKey == key {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProcessRow: View {
    let process: ProcessStats

    var cpuColor: Color {
        if process.cpuUsage > 50 { return .danger }
        if process.cpuUsage > 25 { return .warning }
        return .textPrimary
    }

    var memoryColor: Color {
        if process.memoryUsageGB > 4 { return .danger }
        if process.memoryUsageGB > 2 { return .warning }
        return .textSecondary
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                        .frame(width: 18, height: 18)
                }

                Text(process.name)
                    .font(.mono)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.id)")
                .font(.mono)
                .foregroundStyle(.textSecondary)
                .frame(width: 70, alignment: .trailing)

            Text(process.user)
                .font(.mono)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            Text(String(format: "%.1f%%", process.cpuUsage))
                .font(.mono)
                .foregroundStyle(cpuColor)
                .frame(width: 80, alignment: .trailing)

            Text(process.memoryUsage.formattedBytes)
                .font(.mono)
                .foregroundStyle(memoryColor)
                .frame(width: 90, alignment: .trailing)

            HStack(spacing: 4) {
                StatusDotView(status: statusLevel, size: 6)
                Text(process.status.rawValue)
                    .font(.label)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.backgroundPrimary)
        .contentShape(Rectangle())
    }

    var statusLevel: StatusLevel {
        switch process.status {
        case .running: return .good
        case .sleeping, .idle: return .inactive
        case .stopped: return .warning
        case .zombie, .unknown: return .critical
        }
    }
}

struct SankeyNodeItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let column: Int
    let weight: Double
    let color: Color
}

struct SankeyLinkItem: Identifiable {
    let id: String
    let from: String
    let to: String
    let weight: Double
    let color: Color
}

private struct SankeyLayoutNode {
    let item: SankeyNodeItem
    let rect: CGRect
}

struct SankeyDiagramView: View {
    let title: String
    let subtitle: String
    let columnTitles: [String]
    let nodes: [SankeyNodeItem]
    let links: [SankeyLinkItem]
    @State private var focusedNodeID: String?

    var body: some View {
        SectionCardView(title: title, icon: "arrow.left.arrow.right.square", iconColor: .appAccent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)

                    Spacer(minLength: 12)

                    if let focusedNodeID, let focusedNode = nodes.first(where: { $0.id == focusedNodeID }) {
                        Button {
                            self.focusedNodeID = nil
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(focusedNode.color)
                                    .frame(width: 7, height: 7)
                                Text("Focus: \(focusedNode.title)")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.backgroundTertiary)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.surfaceBorderMedium, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                GeometryReader { viewport in
                    let columns = (nodes.map(\.column).max() ?? 0) + 1
                    let boardWidth = max(viewport.size.width, minimumBoardWidth(for: columns))

                    ScrollView(.horizontal, showsIndicators: true) {
                        let boardSize = CGSize(width: boardWidth, height: viewport.size.height)
                        let layout = makeLayout(in: boardSize)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.backgroundTertiary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                                )

                            ForEach(0..<columns, id: \.self) { column in
                                let frame = columnFrame(for: column, in: boardSize, totalColumns: columns)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.backgroundHover.opacity(0.35))
                                    .frame(width: frame.width, height: boardSize.height - 18)
                                    .position(x: frame.midX, y: boardSize.height / 2)
                            }

                            ForEach(0..<columns, id: \.self) { column in
                                let frame = columnFrame(for: column, in: boardSize, totalColumns: columns)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(columnTitles.indices.contains(column) ? columnTitles[column] : "Stage \(column + 1)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.textPrimary)
                                    Text(stageCaption(for: column, totalColumns: columns))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.textTertiary)
                                        .tracking(0.2)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.backgroundSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color.surfaceBorderMedium, lineWidth: 1)
                                        )
                                )
                                .position(x: frame.midX, y: 26)
                            }

                            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                                Canvas { context, _ in
                                    let phase = timeline.date.timeIntervalSinceReferenceDate
                                    for link in links {
                                        guard
                                            let source = layout[link.from],
                                            let target = layout[link.to]
                                        else { continue }

                                        let sourcePoint = CGPoint(
                                            x: source.rect.maxX,
                                            y: source.rect.midY + outgoingOffset(for: link, layout: layout)
                                        )
                                        let targetPoint = CGPoint(
                                            x: target.rect.minX,
                                            y: target.rect.midY + incomingOffset(for: link, layout: layout)
                                        )
                                        let dx = max(150, (targetPoint.x - sourcePoint.x) * 0.46)

                                        var path = Path()
                                        path.move(to: sourcePoint)
                                        path.addCurve(
                                            to: targetPoint,
                                            control1: CGPoint(x: sourcePoint.x + dx, y: sourcePoint.y),
                                            control2: CGPoint(x: targetPoint.x - dx, y: targetPoint.y)
                                        )

                                    let isFocusedLink = highlighted(link: link)
                                    let isDimmedLink = dimmed(link: link)

                                    // Glow halo for focused links
                                    if isFocusedLink {
                                        context.stroke(
                                            path,
                                            with: .color(link.color.opacity(0.22)),
                                            style: StrokeStyle(lineWidth: max(20, CGFloat(link.weight) * 6.0), lineCap: .round)
                                        )
                                    }

                                    // Body fill (wide, soft)
                                    context.stroke(
                                        path,
                                        with: .color(link.color.opacity(isDimmedLink ? 0.04 : (isFocusedLink ? 0.22 : 0.15))),
                                        style: StrokeStyle(lineWidth: max(12, CGFloat(link.weight) * (isFocusedLink ? 5.0 : 4.2)), lineCap: .round)
                                    )

                                        // Bright line on top
                                        context.stroke(
                                            path,
                                            with: .linearGradient(
                                                Gradient(colors: [
                                                    link.color.opacity(isDimmedLink ? 0.14 : (isFocusedLink ? 0.98 : 0.90)),
                                                    link.color.opacity(isDimmedLink ? 0.05 : (isFocusedLink ? 0.52 : 0.38))
                                                ]),
                                                startPoint: sourcePoint,
                                                endPoint: targetPoint
                                            ),
                                            style: StrokeStyle(lineWidth: max(4, CGFloat(link.weight) * (isFocusedLink ? 3.4 : 2.8)), lineCap: .round)
                                        )

                                        let endpoint = CGRect(x: targetPoint.x - 4, y: targetPoint.y - 4, width: 8, height: 8)
                                        context.fill(Path(ellipseIn: endpoint), with: .color(link.color.opacity(isDimmedLink ? 0.18 : 0.92)))

                                        if isFocusedLink {
                                            let duration = max(1.1, 2.2 - min(link.weight * 0.05, 0.9))
                                            let normalized = phase.remainder(dividingBy: duration) / duration
                                            let travelCount = max(1, min(3, Int(link.weight / 8)))
                                            for index in 0..<travelCount {
                                                let shifted = (normalized + Double(index) / Double(travelCount)) .truncatingRemainder(dividingBy: 1)
                                                let point = cubicPoint(
                                                    from: sourcePoint,
                                                    control1: CGPoint(x: sourcePoint.x + dx, y: sourcePoint.y),
                                                    control2: CGPoint(x: targetPoint.x - dx, y: targetPoint.y),
                                                    to: targetPoint,
                                                    t: shifted
                                                )
                                                let size = max(6, min(12, CGFloat(link.weight) * 0.5))
                                                let packetRect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
                                                context.fill(Path(ellipseIn: packetRect), with: .color(.white.opacity(0.95)))
                                                context.fill(
                                                    Path(ellipseIn: packetRect.insetBy(dx: size * 0.18, dy: size * 0.18)),
                                                    with: .color(link.color.opacity(0.95))
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            ForEach(Array(layout.values), id: \.item.id) { node in
                                let isFocusedNode = focusedNodeID == node.item.id
                                let isConnectedNode = connected(nodeID: node.item.id)
                                let isDimmedNode = focusedNodeID != nil && !isConnectedNode

                                Button {
                                    focusedNodeID = focusedNodeID == node.item.id ? nil : node.item.id
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        // Colored left accent bar
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        node.item.color.opacity(isDimmedNode ? 0.3 : 1.0),
                                                        node.item.color.opacity(isDimmedNode ? 0.15 : 0.6)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 4)

                                        VStack(alignment: .leading, spacing: 6) {
                                            // Title + weight badge
                                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                                Text(node.item.title)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(isDimmedNode ? Color.textTertiary.opacity(0.62) : Color.textPrimary)
                                                    .lineLimit(2)

                                                Spacer(minLength: 0)

                                                // Weight badge
                                                Text(weightLabel(node.item.weight))
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundStyle(node.item.color.opacity(isDimmedNode ? 0.4 : 0.95))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                            .fill(node.item.color.opacity(isDimmedNode ? 0.07 : 0.15))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                                    .strokeBorder(node.item.color.opacity(isDimmedNode ? 0.12 : 0.30), lineWidth: 1)
                                                            )
                                                    )
                                            }

                                            // Subtitle
                                            if let subtitle = node.item.subtitle {
                                                Text(subtitle)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(isDimmedNode ? Color.textTertiary.opacity(0.45) : Color.textSecondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 11)
                                    .frame(width: node.rect.width, height: node.rect.height, alignment: .topLeading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(Color.backgroundSecondary.opacity(isDimmedNode ? 0.5 : 1.0))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .strokeBorder(
                                                        node.item.color.opacity(isFocusedNode ? 0.70 : (isDimmedNode ? 0.08 : 0.28)),
                                                        lineWidth: isFocusedNode ? 1.5 : 1
                                                    )
                                            )
                                    )
                                    .shadow(color: node.item.color.opacity(isFocusedNode ? 0.30 : (isDimmedNode ? 0.0 : 0.12)), radius: isFocusedNode ? 16 : 8, y: 4)
                                    .scaleEffect(isFocusedNode ? 1.03 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocusedNode)
                                }
                                .buttonStyle(.plain)
                                .position(x: node.rect.midX, y: node.rect.midY)
                            }
                        }
                        .frame(width: boardWidth, height: viewport.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedNodeID = nil
                        }
                    }
                }
                .frame(height: 540)
            }
        }
    }

    private func makeLayout(in size: CGSize) -> [String: SankeyLayoutNode] {
        guard !nodes.isEmpty else { return [:] }
        let columns = (nodes.map(\.column).max() ?? 0) + 1
        let leftPadding: CGFloat = 24
        let topPadding: CGFloat = 62
        let bottomPadding: CGFloat = 18
        let columnWidth = max(190, (size.width - leftPadding * 2) / CGFloat(max(columns, 1)) - 110)
        let columnGap = max(120, (size.width - leftPadding * 2 - CGFloat(columns) * columnWidth) / CGFloat(max(columns - 1, 1)))
        let availableHeight = max(size.height - topPadding - bottomPadding, 260)

        var result: [String: SankeyLayoutNode] = [:]

        for column in 0..<columns {
            let columnNodes = nodes.filter { $0.column == column }
            let totalWeight = max(columnNodes.reduce(0) { $0 + max($1.weight, 1) }, 1)
            let gap: CGFloat = 12
            let totalGap = gap * CGFloat(max(columnNodes.count - 1, 0))
            let usableHeight = max(availableHeight - totalGap, 160)
            var y = topPadding
            let x = leftPadding + CGFloat(column) * (columnWidth + columnGap)

            let orderedNodes = columnNodes.sorted { lhs, rhs in
                let lhsConnected = connected(nodeID: lhs.id)
                let rhsConnected = connected(nodeID: rhs.id)
                if focusedNodeID != nil && lhsConnected != rhsConnected {
                    return lhsConnected && !rhsConnected
                }
                return lhs.weight > rhs.weight
            }

            for node in orderedNodes {
                let height = max(72, min(100, usableHeight * CGFloat(max(node.weight, 1) / totalWeight)))
                let rect = CGRect(x: x, y: y, width: columnWidth, height: height)
                result[node.id] = SankeyLayoutNode(item: node, rect: rect)
                y += height + gap
            }
        }

        return result
    }

    private func columnFrame(for column: Int, in size: CGSize, totalColumns: Int) -> CGRect {
        let leftPadding: CGFloat = 24
        let columnWidth = max(190, (size.width - leftPadding * 2) / CGFloat(max(totalColumns, 1)) - 110)
        let columnGap = max(120, (size.width - leftPadding * 2 - CGFloat(totalColumns) * columnWidth) / CGFloat(max(totalColumns - 1, 1)))
        let x = leftPadding + CGFloat(column) * (columnWidth + columnGap)
        return CGRect(x: x, y: 8, width: columnWidth, height: size.height - 16)
    }

    private func minimumBoardWidth(for columns: Int) -> CGFloat {
        let horizontalPadding: CGFloat = 48
        let preferredColumnWidth: CGFloat = 220
        let preferredGap: CGFloat = 230
        return horizontalPadding + CGFloat(columns) * preferredColumnWidth + CGFloat(max(columns - 1, 0)) * preferredGap
    }

    private func outgoingOffset(for link: SankeyLinkItem, layout: [String: SankeyLayoutNode]) -> CGFloat {
        let related = links
            .filter { $0.from == link.from }
            .sorted { lhs, rhs in
                let lhsY = layout[lhs.to]?.rect.midY ?? 0
                let rhsY = layout[rhs.to]?.rect.midY ?? 0
                return lhsY < rhsY
            }
        guard let index = related.firstIndex(where: { $0.id == link.id }) else { return 0 }
        let center = CGFloat(related.count - 1) / 2
        return (CGFloat(index) - center) * 11
    }

    private func incomingOffset(for link: SankeyLinkItem, layout: [String: SankeyLayoutNode]) -> CGFloat {
        let related = links
            .filter { $0.to == link.to }
            .sorted { lhs, rhs in
                let lhsY = layout[lhs.from]?.rect.midY ?? 0
                let rhsY = layout[rhs.from]?.rect.midY ?? 0
                return lhsY < rhsY
            }
        guard let index = related.firstIndex(where: { $0.id == link.id }) else { return 0 }
        let center = CGFloat(related.count - 1) / 2
        return (CGFloat(index) - center) * 11
    }

    private func stageCaption(for column: Int, totalColumns: Int) -> String {
        if column == 0 { return "where it starts" }
        if column == totalColumns - 1 { return "where it lands" }
        return "how it moves"
    }

    private func weightLabel(_ weight: Double) -> String {
        if weight >= 100 { return String(format: "%.0f", weight) }
        if weight >= 10 { return String(format: "%.1f", weight) }
        return String(format: "%.1f", weight)
    }

    private func cubicPoint(from: CGPoint, control1: CGPoint, control2: CGPoint, to: CGPoint, t: Double) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        let x = uuu * from.x + 3 * uu * t * control1.x + 3 * u * tt * control2.x + ttt * to.x
        let y = uuu * from.y + 3 * uu * t * control1.y + 3 * u * tt * control2.y + ttt * to.y
        return CGPoint(x: x, y: y)
    }

    private func connected(nodeID: String) -> Bool {
        guard let focusedNodeID else { return true }
        if nodeID == focusedNodeID { return true }
        return links.contains {
            ($0.from == focusedNodeID && $0.to == nodeID) ||
            ($0.to == focusedNodeID && $0.from == nodeID)
        }
    }

    private func highlighted(link: SankeyLinkItem) -> Bool {
        guard let focusedNodeID else { return false }
        return link.from == focusedNodeID || link.to == focusedNodeID
    }

    private func dimmed(link: SankeyLinkItem) -> Bool {
        guard focusedNodeID != nil else { return false }
        return !highlighted(link: link)
    }
}

struct SankeyInsightCard: View {
    let title: String
    let lines: [String]
    let color: Color
    let icon: String

    var body: some View {
        SectionCardView(title: title, icon: icon, iconColor: color) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.85))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(line)
                            .font(.system(size: 12))
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct ProcessLoadFlowView: View {
    let processes: [ProcessStats]
    let processSummary: (ProcessStats) -> ProcessSummary
    @Binding var selectedProcess: ProcessStats?

    private var topProcesses: [ProcessStats] {
        Array(processes.sorted {
            ($0.cpuUsage + $0.memoryUsageGB * 12) > ($1.cpuUsage + $1.memoryUsageGB * 12)
        }.prefix(6))
    }

    private var nodes: [SankeyNodeItem] {
        let sources = topProcesses.map { process in
            SankeyNodeItem(
                id: "src-\(process.id)",
                title: process.name,
                subtitle: "PID \(process.id)",
                column: 0,
                weight: max(process.cpuUsage + process.memoryUsageGB * 8, 6),
                color: .appAccent
            )
        }

        let resources: [SankeyNodeItem] = [
            .init(id: "cpu", title: "CPU Time", subtitle: "active execution", column: 1, weight: max(totalCPU, 8), color: .cpuColor),
            .init(id: "memory", title: "Memory Footprint", subtitle: totalMemory.formattedBytesCompact, column: 1, weight: max(totalMemoryGB * 10, 8), color: .ramColor),
            .init(id: "threads", title: "Thread Pressure", subtitle: "\(totalThreads) threads", column: 1, weight: max(Double(totalThreads) * 0.6, 8), color: .warning)
        ]

        let impacts: [SankeyNodeItem] = [
            .init(id: "ui", title: "UI Pressure", subtitle: "foreground responsiveness", column: 2, weight: max(totalCPU * 0.42, 10), color: .appAccent),
            .init(id: "background", title: "Background Load", subtitle: "services and helpers", column: 2, weight: max(Double(backgroundCount) * 5, 10), color: .netColor),
            .init(id: "thermal", title: "Thermal Risk", subtitle: "fan and heat tendency", column: 2, weight: max(totalCPU * 0.25 + totalMemoryGB * 4, 8), color: .warning)
        ]
        return sources + resources + impacts
    }

    private var links: [SankeyLinkItem] {
        var flow: [SankeyLinkItem] = []
        for process in topProcesses {
            let dominant = dominantResource(for: process)
            let baseWeight = max(process.cpuUsage * 0.22 + process.memoryUsageGB * 3.5, 3)
            flow.append(.init(id: "s-\(process.id)-\(dominant)", from: "src-\(process.id)", to: dominant, weight: baseWeight, color: dominantColor(for: dominant)))
            if dominant != "cpu" {
                flow.append(.init(id: "s2-\(process.id)-cpu", from: "src-\(process.id)", to: "cpu", weight: max(process.cpuUsage * 0.12, 2), color: .cpuColor))
            }
            if dominant != "memory" {
                flow.append(.init(id: "s2-\(process.id)-memory", from: "src-\(process.id)", to: "memory", weight: max(process.memoryUsageGB * 2.2, 2), color: .ramColor))
            }
        }

        flow.append(.init(id: "cpu-ui", from: "cpu", to: "ui", weight: max(totalCPU * 0.34, 5), color: .cpuColor))
        flow.append(.init(id: "cpu-thermal", from: "cpu", to: "thermal", weight: max(totalCPU * 0.22, 4), color: .warning))
        flow.append(.init(id: "memory-background", from: "memory", to: "background", weight: max(totalMemoryGB * 4, 4), color: .ramColor))
        flow.append(.init(id: "memory-thermal", from: "memory", to: "thermal", weight: max(totalMemoryGB * 2.2, 3), color: .warning))
        flow.append(.init(id: "threads-background", from: "threads", to: "background", weight: max(Double(backgroundCount) * 4, 4), color: .netColor))
        flow.append(.init(id: "threads-ui", from: "threads", to: "ui", weight: max(Double(interactiveCount) * 3, 3), color: .appAccent))
        return flow
    }

    private var totalCPU: Double { processes.reduce(0) { $0 + $1.cpuUsage } }
    private var totalMemory: UInt64 { processes.reduce(0) { $0 + $1.memoryUsage } }
    private var totalMemoryGB: Double { Double(totalMemory) / 1_073_741_824 }
    private var totalThreads: Int { processes.reduce(0) { $0 + $1.threads } }
    private var backgroundCount: Int { processes.filter { isBackground($0) }.count }
    private var interactiveCount: Int { processes.filter { !isBackground($0) }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SankeyDiagramView(
                    title: "System Load Flow",
                    subtitle: "Von den wichtigsten Prozessen über Ressourcen bis zu den sichtbaren Auswirkungen auf das System.",
                    columnTitles: ["Processes", "Resources", "Impact"],
                    nodes: nodes,
                    links: links
                )

                HStack(alignment: .top, spacing: 16) {
                    SankeyInsightCard(
                        title: "Dominant Driver",
                        lines: topProcesses.prefix(3).map {
                            let summary = processSummary($0)
                            return "\($0.name) lenkt aktuell vor allem \(dominantResourceLabel(for: $0)) und wirkt als \(summary.role.lowercased())."
                        },
                        color: .cpuColor,
                        icon: "speedometer"
                    )

                    SankeyInsightCard(
                        title: "Interpretation",
                        lines: [
                            "Hoher Zufluss in UI Pressure deutet auf direkte Vordergrundarbeit hin.",
                            "Background Load wächst vor allem mit Helferprozessen, Daemons und vielen Threads.",
                            "Thermal Risk ist eine kombinierte Sicht aus CPU-Spitzen und großem Memory-Footprint."
                        ],
                        color: .warning,
                        icon: "lightbulb"
                    )
                }
                .padding(.bottom, 16)
            }
            .padding(16)
        }
        .background(Color.backgroundPrimary)
    }

    private func dominantResource(for process: ProcessStats) -> String {
        let cpu = process.cpuUsage * 1.1
        let memory = process.memoryUsageGB * 15
        let threads = Double(process.threads) * 0.45
        if memory >= cpu && memory >= threads { return "memory" }
        if threads >= cpu { return "threads" }
        return "cpu"
    }

    private func dominantResourceLabel(for process: ProcessStats) -> String {
        switch dominantResource(for: process) {
        case "memory": return "Memory Footprint"
        case "threads": return "Thread Pressure"
        default: return "CPU Time"
        }
    }

    private func dominantColor(for resource: String) -> Color {
        switch resource {
        case "memory": return .ramColor
        case "threads": return .warning
        default: return .cpuColor
        }
    }

    private func isBackground(_ process: ProcessStats) -> Bool {
        let lower = process.name.lowercased()
        return lower.hasSuffix("d") || lower.contains("helper") || lower.contains("agent") || lower.contains("service")
    }
}

struct MemoryFlowView: View {
    @State private var monitor = ProcessMonitorService()

    private var topMemoryProcesses: [ProcessStats] {
        Array(monitor.processes.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(7))
    }

    private var totalMemoryGB: Double {
        Double(monitor.processes.reduce(0) { $0 + $1.memoryUsage }) / 1_073_741_824
    }

    private var nodes: [SankeyNodeItem] {
        let left = topMemoryProcesses.map {
            SankeyNodeItem(
                id: "p-\($0.id)",
                title: $0.name,
                subtitle: $0.memoryUsage.formattedBytesCompact,
                column: 0,
                weight: max($0.memoryUsageGB * 7, 5),
                color: .ramColor
            )
        }

        let middle: [SankeyNodeItem] = [
            .init(id: "active", title: "Active Working Set", subtitle: "foreground + hot pages", column: 1, weight: max(totalMemoryGB * 0.45, 8), color: .ramColor),
            .init(id: "compressed", title: "Compressed Memory", subtitle: "pressure buffer", column: 1, weight: max(totalMemoryGB * 0.18, 6), color: .warning),
            .init(id: "cached", title: "File Cache", subtitle: "reusable pages", column: 1, weight: max(totalMemoryGB * 0.22, 6), color: .netColor),
            .init(id: "swap", title: "Swap Risk", subtitle: "spillover tendency", column: 1, weight: max(totalMemoryGB * 0.12, 5), color: .danger)
        ]

        let right: [SankeyNodeItem] = [
            .init(id: "responsive", title: "Responsive", subtitle: "apps stay snappy", column: 2, weight: max(totalMemoryGB * 0.35, 8), color: .success),
            .init(id: "pressure", title: "Memory Pressure", subtitle: "compression + reclaim", column: 2, weight: max(totalMemoryGB * 0.24, 8), color: .warning),
            .init(id: "retained", title: "Background Retained", subtitle: "resident but inactive", column: 2, weight: max(Double(backgroundHeavy.count) * 4, 6), color: .textSecondary),
            .init(id: "swap-heavy", title: "Swap Heavy", subtitle: "disk-backed pressure", column: 2, weight: max(totalMemoryGB * 0.1, 5), color: .danger)
        ]
        return left + middle + right
    }

    private var links: [SankeyLinkItem] {
        var result: [SankeyLinkItem] = []
        for process in topMemoryProcesses {
            let target = memoryChannel(for: process)
            result.append(.init(id: "m-\(process.id)-\(target)", from: "p-\(process.id)", to: target, weight: max(process.memoryUsageGB * 2.4, 3), color: colorForMemoryChannel(target)))
        }

        result.append(.init(id: "active-responsive", from: "active", to: "responsive", weight: max(totalMemoryGB * 0.4, 5), color: .success))
        result.append(.init(id: "active-retained", from: "active", to: "retained", weight: max(Double(backgroundHeavy.count) * 2.6, 3), color: .textSecondary))
        result.append(.init(id: "compressed-pressure", from: "compressed", to: "pressure", weight: max(totalMemoryGB * 0.2, 4), color: .warning))
        result.append(.init(id: "cached-responsive", from: "cached", to: "responsive", weight: max(totalMemoryGB * 0.18, 3), color: .netColor))
        result.append(.init(id: "swap-swapheavy", from: "swap", to: "swap-heavy", weight: max(totalMemoryGB * 0.12, 3), color: .danger))
        result.append(.init(id: "swap-pressure", from: "swap", to: "pressure", weight: max(totalMemoryGB * 0.09, 3), color: .warning))
        return result
    }

    private var backgroundHeavy: [ProcessStats] {
        monitor.processes.filter { $0.status != .running && $0.memoryUsageGB >= 0.5 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SankeyDiagramView(
                    title: "Memory Flow",
                    subtitle: "Welche Prozesse den RAM binden und in welche Speicherzustände und Systemfolgen das typischerweise kippt.",
                    columnTitles: ["Processes", "Memory States", "Outcomes"],
                    nodes: nodes,
                    links: links
                )

                HStack(alignment: .top, spacing: 16) {
                    SankeyInsightCard(
                        title: "Largest Anchors",
                        lines: topMemoryProcesses.prefix(4).map { "\($0.name) hält \($0.memoryUsage.formattedBytesCompact) resident." },
                        color: .ramColor,
                        icon: "memorychip"
                    )
                    SankeyInsightCard(
                        title: "Reading Guide",
                        lines: [
                            "Active Working Set steht für unmittelbar gebrauchte Seiten.",
                            "Compressed Memory ist der Puffer, bevor echtes Swapping notwendig wird.",
                            "Swap Risk steigt vor allem dann, wenn große ruhende Prozesse zusätzlich CPU-aktive Lastspitzen treffen."
                        ],
                        color: .warning,
                        icon: "book"
                    )
                }
                .padding(.bottom, 16)
            }
            .padding(16)
        }
        .background(Color.backgroundPrimary)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func memoryChannel(for process: ProcessStats) -> String {
        if process.status == .running && process.cpuUsage > 10 { return "active" }
        if process.memoryUsageGB > 1.5 { return "compressed" }
        if process.status == .sleeping || process.status == .idle { return "cached" }
        return "swap"
    }

    private func colorForMemoryChannel(_ channel: String) -> Color {
        switch channel {
        case "active": return .ramColor
        case "compressed": return .warning
        case "cached": return .netColor
        default: return .danger
        }
    }
}

struct ActivityStoryView: View {
    @State private var monitor = ProcessMonitorService()

    private var storyProcesses: [ProcessStats] {
        Array(monitor.processes.sorted {
            ($0.cpuUsage + $0.memoryUsageGB * 6) > ($1.cpuUsage + $1.memoryUsageGB * 6)
        }.prefix(8))
    }

    private var nodes: [SankeyNodeItem] {
        let left = storyProcesses.map {
            SankeyNodeItem(
                id: "a-\($0.id)",
                title: $0.name,
                subtitle: activityRole(for: $0),
                column: 0,
                weight: max($0.cpuUsage * 0.35 + $0.memoryUsageGB * 4, 4),
                color: .appAccent
            )
        }

        let middle: [SankeyNodeItem] = [
            .init(id: "render", title: "Rendering", subtitle: "windows, graphics, UI", column: 1, weight: max(Double(renderingProcesses.count) * 5, 6), color: .appAccent),
            .init(id: "networking", title: "Networking", subtitle: "sync and sockets", column: 1, weight: max(Double(networkingProcesses.count) * 5, 6), color: .netColor),
            .init(id: "helpers", title: "Helpers", subtitle: "agents and support", column: 1, weight: max(Double(helperProcesses.count) * 5, 6), color: .warning),
            .init(id: "files", title: "File I/O", subtitle: "indexing and disk churn", column: 1, weight: max(Double(fileProcesses.count) * 5, 6), color: .ramColor)
        ]

        let right: [SankeyNodeItem] = [
            .init(id: "ui-motion", title: "UI Motion", subtitle: "visible foreground activity", column: 2, weight: max(Double(renderingProcesses.count) * 5, 6), color: .appAccent),
            .init(id: "sync-burst", title: "Sync Burst", subtitle: "network and cloud work", column: 2, weight: max(Double(networkingProcesses.count) * 5, 6), color: .netColor),
            .init(id: "build-churn", title: "Build Churn", subtitle: "tools and helper cascades", column: 2, weight: max(Double(helperProcesses.count + fileProcesses.count) * 4, 6), color: .warning),
            .init(id: "quiet-idle", title: "Quiet Idle", subtitle: "retained but calm", column: 2, weight: max(Double(idleProcesses.count) * 4, 6), color: .textSecondary)
        ]
        return left + middle + right
    }

    private var links: [SankeyLinkItem] {
        var result: [SankeyLinkItem] = []
        for process in storyProcesses {
            let channel = activityChannel(for: process)
            result.append(.init(id: "story-\(process.id)-\(channel)", from: "a-\(process.id)", to: channel, weight: max(process.cpuUsage * 0.2 + process.memoryUsageGB * 2, 3), color: channelColor(channel)))
        }

        result.append(.init(id: "render-ui", from: "render", to: "ui-motion", weight: max(Double(renderingProcesses.count) * 4, 4), color: .appAccent))
        result.append(.init(id: "networking-sync", from: "networking", to: "sync-burst", weight: max(Double(networkingProcesses.count) * 4, 4), color: .netColor))
        result.append(.init(id: "helpers-build", from: "helpers", to: "build-churn", weight: max(Double(helperProcesses.count) * 4, 4), color: .warning))
        result.append(.init(id: "files-build", from: "files", to: "build-churn", weight: max(Double(fileProcesses.count) * 3.5, 4), color: .ramColor))
        result.append(.init(id: "helpers-idle", from: "helpers", to: "quiet-idle", weight: max(Double(idleProcesses.count) * 2.5, 3), color: .textSecondary))
        return result
    }

    private var renderingProcesses: [ProcessStats] { monitor.processes.filter { activityChannel(for: $0) == "render" } }
    private var networkingProcesses: [ProcessStats] { monitor.processes.filter { activityChannel(for: $0) == "networking" } }
    private var helperProcesses: [ProcessStats] { monitor.processes.filter { activityChannel(for: $0) == "helpers" } }
    private var fileProcesses: [ProcessStats] { monitor.processes.filter { activityChannel(for: $0) == "files" } }
    private var idleProcesses: [ProcessStats] { monitor.processes.filter { $0.status == .idle || $0.status == .sleeping } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SankeyDiagramView(
                    title: "App Activity Story",
                    subtitle: "Vom sichtbaren Prozess über die Aktivitätsart bis zu dem Muster, das du gerade auf dem System beobachtest.",
                    columnTitles: ["Actors", "Activity", "Pattern"],
                    nodes: nodes,
                    links: links
                )

                HStack(alignment: .top, spacing: 16) {
                    SankeyInsightCard(
                        title: "Current Story",
                        lines: storyProcesses.prefix(4).map {
                            "\($0.name) verhält sich gerade wie \(activityRole(for: $0).lowercased()) und treibt vor allem \(storyEffect(for: $0))."
                        },
                        color: .netColor,
                        icon: "text.book.closed"
                    )
                    SankeyInsightCard(
                        title: "Why It Helps",
                        lines: [
                            "Die View erklärt Systemzustand als Ablauf statt nur als Liste von Messwerten.",
                            "Sie ist besonders nützlich, wenn viele mittelgroße Prozesse zusammen ein Muster bilden.",
                            "So lassen sich UI-Arbeit, Sync-Wellen und Tool-Kaskaden schneller voneinander unterscheiden."
                        ],
                        color: .appAccent,
                        icon: "sparkles.rectangle.stack"
                    )
                }
                .padding(.bottom, 16)
            }
            .padding(16)
        }
        .background(Color.backgroundPrimary)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func activityChannel(for process: ProcessStats) -> String {
        let lowerName = process.name.lowercased()
        let path = process.executablePath.lowercased()
        if lowerName.contains("window") || lowerName.contains("render") || lowerName.contains("chrome") || lowerName.contains("safari") {
            return "render"
        }
        if lowerName.contains("cloud") || lowerName.contains("sync") || lowerName.contains("network") || lowerName.contains("mail") || lowerName.contains("ssh") {
            return "networking"
        }
        if lowerName.contains("helper") || lowerName.contains("agent") || lowerName.hasSuffix("d") || lowerName.contains("service") {
            return "helpers"
        }
        if lowerName.contains("mds") || lowerName.contains("backup") || lowerName.contains("photo") || path.contains("/library/") {
            return "files"
        }
        return process.status == .running ? "render" : "helpers"
    }

    private func activityRole(for process: ProcessStats) -> String {
        switch activityChannel(for: process) {
        case "render": return "visible foreground work"
        case "networking": return "sync or connection work"
        case "files": return "storage-oriented activity"
        default: return "support and helper activity"
        }
    }

    private func storyEffect(for process: ProcessStats) -> String {
        switch activityChannel(for: process) {
        case "render": return "UI Motion"
        case "networking": return "Sync Burst"
        case "files": return "Build Churn"
        default: return process.status == .running ? "Build Churn" : "Quiet Idle"
        }
    }

    private func channelColor(_ channel: String) -> Color {
        switch channel {
        case "render": return .appAccent
        case "networking": return .netColor
        case "files": return .ramColor
        default: return .warning
        }
    }
}

#Preview {
    ProcessListView()
        .frame(width: 800, height: 500)
}
