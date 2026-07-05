import Foundation
import Observation
import SwiftUI

struct StorageFlowView: View {
    @State private var analyzer = StorageFlowService()
    @State private var selectedMode: StorageFlowMode = .folders
    @State private var selectedScope: StorageScopeFilter = .all

    private var snapshot: StorageSnapshot? { analyzer.snapshot }
    private var visibleRoots: [StorageRootSummary] {
        guard let snapshot else { return [] }
        return snapshot.roots.filter { selectedScope.includes($0.category) }
    }

    var body: some View {
        VStack(spacing: 0) {
            storageToolbar

            if analyzer.isScanning && snapshot == nil {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Scanning storage layout...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            } else if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        storageSummary(snapshot)

                        SankeyDiagramView(
                            title: selectedMode.title,
                            subtitle: selectedMode.subtitle,
                            columnTitles: selectedMode.columnTitles,
                            nodes: makeNodes(from: snapshot),
                            links: makeLinks(from: snapshot)
                        )

                        HStack(alignment: .top, spacing: 16) {
                            SankeyInsightCard(
                                title: "Top Consumers",
                                lines: topConsumerLines(from: snapshot),
                                color: .diskColor,
                                icon: "internaldrive"
                            )

                            SankeyInsightCard(
                                title: "Readout",
                                lines: interpretationLines(from: snapshot),
                                color: .appAccent,
                                icon: "text.alignleft"
                            )
                        }

                        storageHotspotPanel(snapshot)
                    }
                    .padding(16)
                }
                .background(Color.backgroundPrimary)
            } else if let errorMessage = analyzer.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 30))
                        .foregroundStyle(.warning)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            } else {
                Color.backgroundPrimary
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            if analyzer.snapshot == nil {
                analyzer.scan()
            }
        }
    }

    // Map mode to tab index
    private var modeTabIndex: Binding<Int> {
        Binding(
            get: { StorageFlowMode.allCases.firstIndex(of: selectedMode) ?? 0 },
            set: { selectedMode = StorageFlowMode.allCases[$0] }
        )
    }

    private var modeTabs: [SubTabBar.Tab] {
        StorageFlowMode.allCases.enumerated().map { i, mode in
            SubTabBar.Tab(id: i, icon: mode.icon, title: mode.rawValue)
        }
    }

    private var storageToolbar: some View {
        VStack(spacing: 0) {
            // Page header
            PageHeaderView(
                title: "Storage",
                subtitle: "Disk usage & flow analysis",
                icon: "internaldrive",
                iconColor: .diskColor
            ) {
                HStack(spacing: 10) {
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(StorageScopeFilter.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)

                    if let lastScanDate = analyzer.lastScanDate {
                        Text(lastScanDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.textTertiary)
                    }

                    HeaderActionButton(
                        title: "Re-Scan",
                        icon: "arrow.clockwise",
                        isLoading: analyzer.isScanning
                    ) {
                        analyzer.scan()
                    }
                }
            }

            // Mode tabs
            SubTabBar(tabs: modeTabs, selectedIndex: modeTabIndex)
        }
    }

    private func storageSummary(_ snapshot: StorageSnapshot) -> some View {
        HStack(spacing: 12) {
            storageMetricCard(
                title: "Scanned",
                value: snapshot.totalScannedBytes.formattedBytesCompact,
                detail: "\(snapshot.totalFileCount) files indexed",
                color: .diskColor
            )

            storageMetricCard(
                title: "Visible Scope",
                value: visibleRoots.reduce(UInt64(0)) { $0 + $1.totalBytes }.formattedBytesCompact,
                detail: "\(visibleRoots.count) roots in \(selectedScope.rawValue.lowercased())",
                color: .appAccent
            )

            storageMetricCard(
                title: "Main Volume",
                value: snapshot.volumeUsedBytes.formattedBytesCompact,
                detail: "\(Int(snapshot.volumeUsedRatio * 100))% used",
                color: .warning
            )

            storageMetricCard(
                title: "Largest Root",
                value: visibleRoots.sorted { $0.totalBytes > $1.totalBytes }.first?.title ?? "None",
                detail: visibleRoots.sorted { $0.totalBytes > $1.totalBytes }.first.map { $0.totalBytes.formattedBytes } ?? "No data",
                color: .netColor
            )
        }
    }

    private func storageMetricCard(title: String, value: String, detail: String, color: Color) -> some View {
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
        .frame(width: 230, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func storageHotspotPanel(_ snapshot: StorageSnapshot) -> some View {
        SectionCardView(title: "Hotspots", icon: "folder.badge.questionmark", iconColor: .diskColor) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Largest folders")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    ForEach(snapshot.globalTopFolders.prefix(6), id: \.id) { folder in
                        HStack {
                            Text(folder.displayName)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(folder.bytes.formattedBytesCompact)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.diskColor)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Largest files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    ForEach(snapshot.topFiles.prefix(6), id: \.id) { file in
                        HStack {
                            Text(file.name)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(file.bytes.formattedBytesCompact)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.warning)
                        }
                    }
                }
            }
        }
    }

    private func makeNodes(from snapshot: StorageSnapshot) -> [SankeyNodeItem] {
        switch selectedMode {
        case .folders:
            return folderNodes(snapshot)
        case .types:
            return typeNodes(snapshot)
        case .age:
            return ageNodes(snapshot)
        case .sizes:
            return sizeNodes(snapshot)
        }
    }

    private func makeLinks(from snapshot: StorageSnapshot) -> [SankeyLinkItem] {
        switch selectedMode {
        case .folders:
            return folderLinks(snapshot)
        case .types:
            return typeLinks(snapshot)
        case .age:
            return ageLinks(snapshot)
        case .sizes:
            return sizeLinks(snapshot)
        }
    }

    private func folderNodes(_ snapshot: StorageSnapshot) -> [SankeyNodeItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let rootNodes = roots.map {
            SankeyNodeItem(id: "root-\($0.id)", title: $0.title, subtitle: $0.totalBytes.formattedBytesCompact, column: 0, weight: Double(max($0.totalBytes, 1)) / 1_073_741_824, color: $0.category.color)
        }

        let topFolders = roots.flatMap { root in
            root.topFolders.prefix(4).map { (root, $0) }
        }
        let folderNodes = topFolders.map { root, folder in
            SankeyNodeItem(
                id: "folder-\(root.id)-\(folder.name)",
                title: folder.name,
                subtitle: folder.bytes.formattedBytesCompact,
                column: 1,
                weight: Double(max(folder.bytes, 1)) / 1_073_741_824,
                color: root.category.color.opacity(0.85)
            )
        }

        let bands = StorageFolderBand.allCases.map {
            SankeyNodeItem(id: "band-\($0.id)", title: $0.title, subtitle: $0.subtitle, column: 2, weight: max(totalFolders(in: topFolders, for: $0), 1), color: $0.color)
        }
        return rootNodes + folderNodes + bands
    }

    private func folderLinks(_ snapshot: StorageSnapshot) -> [SankeyLinkItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let topFolders = roots.flatMap { root in
            root.topFolders.prefix(4).map { (root, $0) }
        }

        var result: [SankeyLinkItem] = []
        for (root, folder) in topFolders {
            let folderID = "folder-\(root.id)-\(folder.name)"
            result.append(.init(
                id: "root-folder-\(root.id)-\(folder.name)",
                from: "root-\(root.id)",
                to: folderID,
                weight: Double(max(folder.bytes, 1)) / 1_073_741_824,
                color: root.category.color
            ))
            let band = StorageFolderBand.forBytes(folder.bytes)
            result.append(.init(
                id: "folder-band-\(root.id)-\(folder.name)-\(band.id)",
                from: folderID,
                to: "band-\(band.id)",
                weight: Double(max(folder.bytes, 1)) / 1_073_741_824,
                color: band.color
            ))
        }
        return result
    }

    private func typeNodes(_ snapshot: StorageSnapshot) -> [SankeyNodeItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let rootNodes = roots.map {
            SankeyNodeItem(id: "root-\($0.id)", title: $0.title, subtitle: $0.totalBytes.formattedBytesCompact, column: 0, weight: Double(max($0.totalBytes, 1)) / 1_073_741_824, color: $0.category.color)
        }

        let kinds = StorageFileKind.allCases
            .compactMap { kind -> (StorageFileKind, UInt64)? in
                let total = roots.reduce(UInt64(0)) { $0 + ($1.kindTotals[kind] ?? 0) }
                return total > 0 ? (kind, total) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(7)

        let kindNodes = kinds.map {
            SankeyNodeItem(id: "kind-\($0.0.id)", title: $0.0.title, subtitle: $0.1.formattedBytesCompact, column: 1, weight: Double($0.1) / 1_073_741_824, color: $0.0.color)
        }

        let extensions = topExtensions(for: roots, kinds: kinds.map(\.0))
        let extensionNodes = extensions.map {
            SankeyNodeItem(id: "ext-\($0.extensionName)", title: $0.extensionName, subtitle: $0.bytes.formattedBytesCompact, column: 2, weight: Double($0.bytes) / 1_073_741_824, color: $0.kind.color)
        }

        return rootNodes + kindNodes + extensionNodes
    }

    private func typeLinks(_ snapshot: StorageSnapshot) -> [SankeyLinkItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let kinds = StorageFileKind.allCases
            .filter { kind in roots.reduce(UInt64(0)) { $0 + ($1.kindTotals[kind] ?? 0) } > 0 }
            .sorted { lhs, rhs in
                roots.reduce(UInt64(0)) { $0 + ($1.kindTotals[lhs] ?? 0) } > roots.reduce(UInt64(0)) { $0 + ($1.kindTotals[rhs] ?? 0) }
            }
            .prefix(7)

        let extensions = topExtensions(for: roots, kinds: Array(kinds))
        var result: [SankeyLinkItem] = []

        for root in roots {
            for kind in kinds {
                let bytes = root.kindTotals[kind] ?? 0
                guard bytes > 0 else { continue }
                result.append(.init(id: "root-kind-\(root.id)-\(kind.id)", from: "root-\(root.id)", to: "kind-\(kind.id)", weight: Double(bytes) / 1_073_741_824, color: kind.color))
            }
        }

        for entry in extensions {
            result.append(.init(id: "kind-ext-\(entry.kind.id)-\(entry.extensionName)", from: "kind-\(entry.kind.id)", to: "ext-\(entry.extensionName)", weight: Double(entry.bytes) / 1_073_741_824, color: entry.kind.color))
        }

        return result
    }

    private func ageNodes(_ snapshot: StorageSnapshot) -> [SankeyNodeItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let rootNodes = roots.map {
            SankeyNodeItem(id: "root-\($0.id)", title: $0.title, subtitle: $0.totalBytes.formattedBytesCompact, column: 0, weight: Double(max($0.totalBytes, 1)) / 1_073_741_824, color: $0.category.color)
        }

        let ageNodes = StorageAgeBucket.allCases.map { bucket in
            let total = roots.reduce(UInt64(0)) { $0 + ($1.ageTotals[bucket] ?? 0) }
            return SankeyNodeItem(id: "age-\(bucket.id)", title: bucket.title, subtitle: total.formattedBytesCompact, column: 1, weight: Double(max(total, 1)) / 1_073_741_824, color: bucket.color)
        }

        let kindNodes = StorageFileKind.allCases
            .compactMap { kind -> (StorageFileKind, UInt64)? in
                let total = roots.reduce(UInt64(0)) { partial, root in
                    partial + root.ageKindTotals.values.reduce(UInt64(0)) { $0 + ($1[kind] ?? 0) }
                }
                return total > 0 ? (kind, total) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(7)
            .map {
                SankeyNodeItem(id: "kind-\($0.0.id)", title: $0.0.title, subtitle: $0.1.formattedBytesCompact, column: 2, weight: Double($0.1) / 1_073_741_824, color: $0.0.color)
            }

        return rootNodes + ageNodes + kindNodes
    }

    private func ageLinks(_ snapshot: StorageSnapshot) -> [SankeyLinkItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        var result: [SankeyLinkItem] = []

        for root in roots {
            for bucket in StorageAgeBucket.allCases {
                let bytes = root.ageTotals[bucket] ?? 0
                guard bytes > 0 else { continue }
                result.append(.init(id: "root-age-\(root.id)-\(bucket.id)", from: "root-\(root.id)", to: "age-\(bucket.id)", weight: Double(bytes) / 1_073_741_824, color: bucket.color))
            }
        }

        for bucket in StorageAgeBucket.allCases {
            let kindTotals = roots.reduce(into: [StorageFileKind: UInt64]()) { partial, root in
                for (kind, bytes) in root.ageKindTotals[bucket] ?? [:] {
                    partial[kind, default: 0] += bytes
                }
            }
            for (kind, bytes) in kindTotals.sorted(by: { $0.value > $1.value }).prefix(6) {
                result.append(.init(id: "age-kind-\(bucket.id)-\(kind.id)", from: "age-\(bucket.id)", to: "kind-\(kind.id)", weight: Double(bytes) / 1_073_741_824, color: kind.color))
            }
        }

        return result
    }

    private func sizeNodes(_ snapshot: StorageSnapshot) -> [SankeyNodeItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        let rootNodes = roots.map {
            SankeyNodeItem(id: "root-\($0.id)", title: $0.title, subtitle: $0.totalBytes.formattedBytesCompact, column: 0, weight: Double(max($0.totalBytes, 1)) / 1_073_741_824, color: $0.category.color)
        }

        let sizeNodes = StorageSizeBand.allCases.map { bucket in
            let total = roots.reduce(UInt64(0)) { $0 + ($1.sizeBandTotals[bucket] ?? 0) }
            return SankeyNodeItem(id: "size-\(bucket.id)", title: bucket.title, subtitle: total.formattedBytesCompact, column: 1, weight: Double(max(total, 1)) / 1_073_741_824, color: bucket.color)
        }

        let kindNodes = StorageFileKind.allCases
            .compactMap { kind -> (StorageFileKind, UInt64)? in
                let total = roots.reduce(UInt64(0)) { partial, root in
                    partial + root.sizeBandKindTotals.values.reduce(UInt64(0)) { $0 + ($1[kind] ?? 0) }
                }
                return total > 0 ? (kind, total) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(7)
            .map {
                SankeyNodeItem(id: "kind-\($0.0.id)", title: $0.0.title, subtitle: $0.1.formattedBytesCompact, column: 2, weight: Double($0.1) / 1_073_741_824, color: $0.0.color)
            }

        return rootNodes + sizeNodes + kindNodes
    }

    private func sizeLinks(_ snapshot: StorageSnapshot) -> [SankeyLinkItem] {
        let roots = visibleRoots.sorted { $0.totalBytes > $1.totalBytes }
        var result: [SankeyLinkItem] = []

        for root in roots {
            for bucket in StorageSizeBand.allCases {
                let bytes = root.sizeBandTotals[bucket] ?? 0
                guard bytes > 0 else { continue }
                result.append(.init(id: "root-size-\(root.id)-\(bucket.id)", from: "root-\(root.id)", to: "size-\(bucket.id)", weight: Double(bytes) / 1_073_741_824, color: bucket.color))
            }
        }

        for bucket in StorageSizeBand.allCases {
            let kindTotals = roots.reduce(into: [StorageFileKind: UInt64]()) { partial, root in
                for (kind, bytes) in root.sizeBandKindTotals[bucket] ?? [:] {
                    partial[kind, default: 0] += bytes
                }
            }
            for (kind, bytes) in kindTotals.sorted(by: { $0.value > $1.value }).prefix(6) {
                result.append(.init(id: "size-kind-\(bucket.id)-\(kind.id)", from: "size-\(bucket.id)", to: "kind-\(kind.id)", weight: Double(bytes) / 1_073_741_824, color: kind.color))
            }
        }

        return result
    }

    private func topExtensions(for roots: [StorageRootSummary], kinds: [StorageFileKind]) -> [(extensionName: String, kind: StorageFileKind, bytes: UInt64)] {
        var totals: [(String, StorageFileKind, UInt64)] = []
        for kind in kinds {
            var extensionTotals: [String: UInt64] = [:]
            for root in roots {
                for (extensionName, bytes) in root.extensionTotals[kind] ?? [:] {
                    extensionTotals[extensionName, default: 0] += bytes
                }
            }
            totals.append(contentsOf: extensionTotals.sorted(by: { $0.value > $1.value }).prefix(3).map { ($0.key, kind, $0.value) })
        }
        return totals.sorted { $0.2 > $1.2 }.prefix(8).map { $0 }
    }

    private func totalFolders(in folders: [(StorageRootSummary, StorageFolderSummary)], for band: StorageFolderBand) -> Double {
        Double(folders.filter { StorageFolderBand.forBytes($0.1.bytes) == band }.reduce(UInt64(0)) { $0 + $1.1.bytes }) / 1_073_741_824
    }

    private func topConsumerLines(from snapshot: StorageSnapshot) -> [String] {
        switch selectedMode {
        case .folders:
            return snapshot.globalTopFolders.prefix(4).map { "\($0.displayName) bindet \($0.bytes.formattedBytes)." }
        case .types:
            return StorageFileKind.allCases.compactMap { kind in
                let total = visibleRoots.reduce(UInt64(0)) { $0 + ($1.kindTotals[kind] ?? 0) }
                return total > 0 ? "\(kind.title) belegt \(total.formattedBytes)." : nil
            }.prefix(4).map { $0 }
        case .age:
            return StorageAgeBucket.allCases.map { bucket in
                let total = visibleRoots.reduce(UInt64(0)) { partial, root in
                    partial + (root.ageTotals[bucket] ?? 0)
                }
                return "\(bucket.title): \(total.formattedBytes)"
            }.prefix(4).map { $0 }
        case .sizes:
            return StorageSizeBand.allCases.map { bucket in
                let total = visibleRoots.reduce(UInt64(0)) { partial, root in
                    partial + (root.sizeBandTotals[bucket] ?? 0)
                }
                return "\(bucket.title): \(total.formattedBytes)"
            }.prefix(4).map { $0 }
        }
    }

    private func interpretationLines(from snapshot: StorageSnapshot) -> [String] {
        switch selectedMode {
        case .folders:
            return [
                "Die mittlere Spalte zeigt die größten Unterordner innerhalb der sichtbaren Roots.",
                "Rechts siehst du, ob der Speicher in wenigen massiven Ordnern oder eher breit verteilt steckt.",
                "Besonders nützlich, um `Downloads`, `Library` oder Workspaces schnell einzuordnen."
            ]
        case .types:
            return [
                "Die Typen-Sicht zeigt, welche Dateiklassen den meisten Platz verbrauchen.",
                "Die letzte Spalte löst das in dominante Extensions auf.",
                "Gut geeignet für Fragen wie: Medien, Archive, Apps oder Code?"
            ]
        case .age:
            return [
                "Alter trennt frische Daten von historischer Last.",
                "Damit siehst du schnell, ob der Platz durch aktuellen Zufluss oder alte Bestände entsteht.",
                "Die rechte Spalte zeigt, welche Dateiklassen in jedem Altersfenster dominieren."
            ]
        case .sizes:
            return [
                "Größenbänder zeigen, ob viele kleine Dateien oder wenige große Brocken dominieren.",
                "Das ist besonders hilfreich bei Foto-/Video-Sammlungen, Archives und großen App-Bundles.",
                "Rechts siehst du, welche Dateiklassen die einzelnen Größenbänder treiben."
            ]
        }
    }
}

@MainActor
@Observable
private final class StorageFlowService {
    var snapshot: StorageSnapshot?
    var isScanning = false
    var errorMessage: String?
    var lastScanDate: Date?

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil

        Task.detached(priority: .utility) {
            do {
                let snapshot = try Self.performScan()
                await MainActor.run {
                    self.snapshot = snapshot
                    self.lastScanDate = Date()
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Storage scan failed: \(error.localizedDescription)"
                    self.isScanning = false
                }
            }
        }
    }

    nonisolated private static func performScan() throws -> StorageSnapshot {
        let fileManager = FileManager.default
        let descriptors = rootDescriptors(fileManager: fileManager)
        guard !descriptors.isEmpty else {
            throw NSError(domain: "StorageFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "No readable storage roots found."])
        }

        let rootSummaries = descriptors.compactMap { try? scanRoot($0, fileManager: fileManager) }
        let volumeValues = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let totalCapacity = UInt64(volumeValues?.volumeTotalCapacity ?? 0)
        let freeCapacity = UInt64(volumeValues?.volumeAvailableCapacity ?? 0)

        let topFolders = rootSummaries
            .flatMap { root in
                root.topFolders.map { StorageGlobalFolderSummary(id: "\(root.id)-\($0.name)", displayName: "\(root.title)/\($0.name)", bytes: $0.bytes) }
            }
            .sorted { $0.bytes > $1.bytes }

        let topFiles = rootSummaries
            .flatMap(\.topFiles)
            .sorted { $0.bytes > $1.bytes }
            .prefix(12)
            .map { $0 }

        return StorageSnapshot(
            roots: rootSummaries.sorted { $0.totalBytes > $1.totalBytes },
            totalScannedBytes: rootSummaries.reduce(0) { $0 + $1.totalBytes },
            totalFileCount: rootSummaries.reduce(0) { $0 + $1.fileCount },
            volumeTotalBytes: totalCapacity,
            volumeFreeBytes: freeCapacity,
            globalTopFolders: Array(topFolders.prefix(12)),
            topFiles: Array(topFiles)
        )
    }

    nonisolated private static func rootDescriptors(fileManager: FileManager) -> [StorageRootDescriptor] {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let personalRoots: [(String, String)] = [
            ("Desktop", "Desktop"),
            ("Documents", "Documents"),
            ("Downloads", "Downloads"),
            ("Pictures", "Pictures"),
            ("Movies", "Movies"),
            ("Music", "Music"),
        ]
        let workspaceRoots: [(String, String)] = [
            ("dev", "Workspaces"),
            ("Developer", "Developer"),
            ("Projects", "Projects"),
            ("Code", "Code"),
        ]

        var descriptors: [StorageRootDescriptor] = []
        for (pathComponent, title) in personalRoots {
            let url = home.appendingPathComponent(pathComponent)
            if fileManager.fileExists(atPath: url.path) {
                descriptors.append(.init(id: title.lowercased(), title: title, url: url, category: .personal))
            }
        }

        for (pathComponent, title) in workspaceRoots {
            let url = home.appendingPathComponent(pathComponent)
            if fileManager.fileExists(atPath: url.path) {
                descriptors.append(.init(id: title.lowercased(), title: title, url: url, category: .workspace))
            }
        }

        let libraryURL = home.appendingPathComponent("Library")
        if fileManager.fileExists(atPath: libraryURL.path) {
            descriptors.append(.init(id: "library", title: "Library", url: libraryURL, category: .library))
        }

        let appsURL = URL(fileURLWithPath: "/Applications")
        if fileManager.fileExists(atPath: appsURL.path) {
            descriptors.append(.init(id: "applications", title: "Applications", url: appsURL, category: .apps))
        }

        return descriptors
    }

    nonisolated private static func scanRoot(_ descriptor: StorageRootDescriptor, fileManager: FileManager) throws -> StorageRootSummary {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
        ]

        let enumerator = fileManager.enumerator(
            at: descriptor.url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )

        var totalBytes: UInt64 = 0
        var fileCount = 0
        var folderTotals: [String: UInt64] = [:]
        var kindTotals: [StorageFileKind: UInt64] = [:]
        var extensionTotals: [StorageFileKind: [String: UInt64]] = [:]
        var ageTotals: [StorageAgeBucket: UInt64] = [:]
        var ageKindTotals: [StorageAgeBucket: [StorageFileKind: UInt64]] = [:]
        var sizeBandTotals: [StorageSizeBand: UInt64] = [:]
        var sizeBandKindTotals: [StorageSizeBand: [StorageFileKind: UInt64]] = [:]
        var topFiles: [StorageFileSummary] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isDirectory != true else { continue }

            let size = UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            let ageBucket = StorageAgeBucket.forDate(values.contentModificationDate)
            let sizeBand = StorageSizeBand.forBytes(size)
            let kind = StorageFileKind.classify(url: fileURL)
            let topFolderName = topFolderName(for: fileURL, within: descriptor.url)
            let extensionName = fileURL.pathExtension.isEmpty ? "no extension" : ".\(fileURL.pathExtension.lowercased())"

            totalBytes += size
            fileCount += 1
            folderTotals[topFolderName, default: 0] += size
            kindTotals[kind, default: 0] += size
            extensionTotals[kind, default: [:]][extensionName, default: 0] += size
            ageTotals[ageBucket, default: 0] += size
            ageKindTotals[ageBucket, default: [:]][kind, default: 0] += size
            sizeBandTotals[sizeBand, default: 0] += size
            sizeBandKindTotals[sizeBand, default: [:]][kind, default: 0] += size

            if size > 64 * 1024 * 1024 {
                topFiles.append(.init(id: fileURL.path, name: fileURL.lastPathComponent, path: fileURL.path, bytes: size))
            }
        }

        return StorageRootSummary(
            id: descriptor.id,
            title: descriptor.title,
            path: descriptor.url.path,
            category: descriptor.category,
            totalBytes: totalBytes,
            fileCount: fileCount,
            topFolders: folderTotals
                .map { StorageFolderSummary(name: $0.key, bytes: $0.value) }
                .sorted { $0.bytes > $1.bytes }
                .prefix(12)
                .map { $0 },
            kindTotals: kindTotals,
            extensionTotals: extensionTotals,
            ageTotals: ageTotals,
            ageKindTotals: ageKindTotals,
            sizeBandTotals: sizeBandTotals,
            sizeBandKindTotals: sizeBandKindTotals,
            topFiles: topFiles.sorted { $0.bytes > $1.bytes }.prefix(10).map { $0 }
        )
    }

    nonisolated private static func topFolderName(for fileURL: URL, within rootURL: URL) -> String {
        let relative = fileURL.path.replacingOccurrences(of: rootURL.path, with: "")
        let components = relative.split(separator: "/").map(String.init)
        return components.first ?? rootURL.lastPathComponent
    }
}

private struct StorageSnapshot {
    let roots: [StorageRootSummary]
    let totalScannedBytes: UInt64
    let totalFileCount: Int
    let volumeTotalBytes: UInt64
    let volumeFreeBytes: UInt64
    let globalTopFolders: [StorageGlobalFolderSummary]
    let topFiles: [StorageFileSummary]

    var volumeUsedBytes: UInt64 {
        max(volumeTotalBytes - volumeFreeBytes, 0)
    }

    var volumeUsedRatio: Double {
        guard volumeTotalBytes > 0 else { return 0 }
        return Double(volumeUsedBytes) / Double(volumeTotalBytes)
    }
}

private struct StorageRootDescriptor {
    let id: String
    let title: String
    let url: URL
    let category: StorageRootCategory
}

private struct StorageRootSummary: Identifiable {
    let id: String
    let title: String
    let path: String
    let category: StorageRootCategory
    let totalBytes: UInt64
    let fileCount: Int
    let topFolders: [StorageFolderSummary]
    let kindTotals: [StorageFileKind: UInt64]
    let extensionTotals: [StorageFileKind: [String: UInt64]]
    let ageTotals: [StorageAgeBucket: UInt64]
    let ageKindTotals: [StorageAgeBucket: [StorageFileKind: UInt64]]
    let sizeBandTotals: [StorageSizeBand: UInt64]
    let sizeBandKindTotals: [StorageSizeBand: [StorageFileKind: UInt64]]
    let topFiles: [StorageFileSummary]
}

private struct StorageFolderSummary {
    let name: String
    let bytes: UInt64
}

private struct StorageGlobalFolderSummary: Identifiable {
    let id: String
    let displayName: String
    let bytes: UInt64
}

private struct StorageFileSummary: Identifiable {
    let id: String
    let name: String
    let path: String
    let bytes: UInt64
}

private enum StorageFlowMode: String, CaseIterable, Identifiable {
    case folders = "Folders"
    case types = "File Types"
    case age = "Age"
    case sizes = "Size Bands"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .folders: return "folder"
        case .types: return "doc.on.doc"
        case .age: return "clock"
        case .sizes: return "ruler"
        }
    }

    var title: String {
        switch self {
        case .folders: return "Folder Size Flow"
        case .types: return "File Type Flow"
        case .age: return "Storage Age Flow"
        case .sizes: return "File Size Flow"
        }
    }

    var subtitle: String {
        switch self {
        case .folders: return "Wie sich Speicher über Roots, dominante Unterordner und Größencluster verteilt."
        case .types: return "Welche Dateitypen wirklich Platz belegen und welche Extensions dahinterstehen."
        case .age: return "Wie aktuell oder historisch deine gespeicherten Daten tatsächlich sind."
        case .sizes: return "Ob der Speicher von vielen kleinen oder wenigen großen Dateien dominiert wird."
        }
    }

    var columnTitles: [String] {
        switch self {
        case .folders: return ["Roots", "Folders", "Folder Scale"]
        case .types: return ["Roots", "Kinds", "Extensions"]
        case .age: return ["Roots", "Age Buckets", "Kinds"]
        case .sizes: return ["Roots", "Size Buckets", "Kinds"]
        }
    }
}

private enum StorageScopeFilter: String, CaseIterable, Identifiable {
    case all = "All Content"
    case workspace = "Workspace"
    case personal = "Personal"
    case library = "Library"
    case apps = "Apps"

    var id: String { rawValue }

    func includes(_ category: StorageRootCategory) -> Bool {
        switch self {
        case .all: return true
        case .workspace: return category == .workspace
        case .personal: return category == .personal
        case .library: return category == .library
        case .apps: return category == .apps
        }
    }
}

private enum StorageRootCategory: String {
    case workspace
    case personal
    case library
    case apps

    var color: Color {
        switch self {
        case .workspace: return .cpuColor
        case .personal: return .appAccent
        case .library: return .warning
        case .apps: return .netColor
        }
    }
}

private enum StorageFolderBand: String, CaseIterable, Identifiable {
    case massive
    case heavy
    case moderate

    var id: String { rawValue }
    var title: String {
        switch self {
        case .massive: return "Massive Folders"
        case .heavy: return "Heavy Folders"
        case .moderate: return "Moderate Folders"
        }
    }
    var subtitle: String {
        switch self {
        case .massive: return "> 10 GB"
        case .heavy: return "1-10 GB"
        case .moderate: return "< 1 GB"
        }
    }
    var color: Color {
        switch self {
        case .massive: return .danger
        case .heavy: return .warning
        case .moderate: return .success
        }
    }

    static func forBytes(_ bytes: UInt64) -> StorageFolderBand {
        if bytes >= 10 * 1024 * 1024 * 1024 { return .massive }
        if bytes >= 1 * 1024 * 1024 * 1024 { return .heavy }
        return .moderate
    }
}

private enum StorageAgeBucket: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case last180Days
    case lastYear
    case older

    var id: String { rawValue }
    var title: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last180Days: return "Last 6 Months"
        case .lastYear: return "Last Year"
        case .older: return "Older"
        }
    }
    var color: Color {
        switch self {
        case .last7Days: return .success
        case .last30Days: return .appAccent
        case .last180Days: return .netColor
        case .lastYear: return .warning
        case .older: return .textSecondary
        }
    }

    static func forDate(_ date: Date?) -> StorageAgeBucket {
        guard let date else { return .older }
        let age = Date().timeIntervalSince(date)
        if age < 7 * 24 * 60 * 60 { return .last7Days }
        if age < 30 * 24 * 60 * 60 { return .last30Days }
        if age < 180 * 24 * 60 * 60 { return .last180Days }
        if age < 365 * 24 * 60 * 60 { return .lastYear }
        return .older
    }
}

private enum StorageSizeBand: String, CaseIterable, Identifiable {
    case tiny
    case medium
    case large
    case huge

    var id: String { rawValue }
    var title: String {
        switch self {
        case .tiny: return "< 1 MB"
        case .medium: return "1 MB - 100 MB"
        case .large: return "100 MB - 1 GB"
        case .huge: return "> 1 GB"
        }
    }
    var color: Color {
        switch self {
        case .tiny: return .success
        case .medium: return .appAccent
        case .large: return .warning
        case .huge: return .danger
        }
    }

    static func forBytes(_ bytes: UInt64) -> StorageSizeBand {
        if bytes < 1 * 1024 * 1024 { return .tiny }
        if bytes < 100 * 1024 * 1024 { return .medium }
        if bytes < 1 * 1024 * 1024 * 1024 { return .large }
        return .huge
    }
}

private enum StorageFileKind: String, CaseIterable, Identifiable {
    case documents
    case images
    case video
    case audio
    case archives
    case code
    case apps
    case data
    case other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .documents: return "Documents"
        case .images: return "Images"
        case .video: return "Video"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .code: return "Code"
        case .apps: return "Apps"
        case .data: return "Data"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .documents: return .appAccent
        case .images: return .success
        case .video: return .warning
        case .audio: return .netColor
        case .archives: return .danger
        case .code: return .cpuColor
        case .apps: return .diskColor
        case .data: return .ramColor
        case .other: return .textSecondary
        }
    }

    static func classify(url: URL) -> StorageFileKind {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()

        let documents = ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "rtf", "md", "pages", "numbers", "key"]
        let images = ["jpg", "jpeg", "png", "heic", "gif", "webp", "svg", "tiff", "raw", "psd"]
        let video = ["mov", "mp4", "mkv", "avi", "webm", "m4v", "mpg"]
        let audio = ["mp3", "wav", "m4a", "flac", "aac", "aiff"]
        let archives = ["zip", "tar", "gz", "tgz", "rar", "7z", "dmg", "iso"]
        let code = ["swift", "js", "ts", "tsx", "jsx", "py", "java", "kt", "go", "rs", "c", "cpp", "h", "hpp", "json", "yaml", "yml", "toml", "lock", "sql", "sh"]
        let apps = ["app", "pkg"]
        let data = ["sqlite", "db", "log", "cache", "xcarchive", "xcresult", "psafe3"]

        if documents.contains(ext) { return .documents }
        if images.contains(ext) { return .images }
        if video.contains(ext) { return .video }
        if audio.contains(ext) { return .audio }
        if archives.contains(ext) { return .archives }
        if code.contains(ext) { return .code }
        if apps.contains(ext) || name.hasSuffix(".app") || name.hasSuffix(".pkg") { return .apps }
        if data.contains(ext) { return .data }
        return .other
    }
}
