import Observation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct NetworkView: View {
    @State private var networkMonitor = NetworkMonitorService()
    let deviceDiscovery: DeviceDiscoveryService
    @State private var selectedTab = 0
    @State private var reportDocument: NetworkReportDocument?
    @State private var showReportExporter = false
    @State private var reportExportError: String?

    private let networkTabs: [SubTabBar.Tab] = [
        .init(id: 0, icon: "circle.grid.cross",          title: "Graph"),
        .init(id: 1, icon: "network",                    title: "Interfaces"),
        .init(id: 2, icon: "desktopcomputer",            title: "Devices"),
        .init(id: 3, icon: "link",                       title: "Connections"),
        .init(id: 4, icon: "waveform",                   title: "Capture"),
        .init(id: 5, icon: "magnifyingglass",            title: "Port Scan"),
        .init(id: 6, icon: "point.3.connected.trianglepath.dotted", title: "Traffic Flow"),
        .init(id: 7, icon: "arrow.left.arrow.right",     title: "Conv. Flow"),
        .init(id: 8, icon: "globe.europe.africa.fill",   title: "World Map"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page header with Re-Scan action
            PageHeaderView(
                title: "Network",
                subtitle: "Interfaces, devices & traffic",
                icon: "network",
                iconColor: .netColor
            ) {
                HStack(spacing: 10) {
                    if let lastScanDate = deviceDiscovery.lastScanDate {
                        Text(lastScanDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.textTertiary)
                    }
                    Menu {
                        Button {
                            prepareReportExport(format: .json)
                        } label: {
                            Label("JSON", systemImage: "curlybraces")
                        }

                        Button {
                            prepareReportExport(format: .markdown)
                        } label: {
                            Label("Markdown", systemImage: "doc.plaintext")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .medium))
                            Text("Export")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.backgroundTertiary)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                                }
                        )
                    }
                    .menuStyle(.borderlessButton)

                    HeaderActionButton(
                        title: "Re-Scan",
                        icon: "arrow.clockwise",
                        isLoading: deviceDiscovery.isScanning
                    ) {
                        deviceDiscovery.refresh()
                    }
                }
            }

            if let reportExportError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.warning)
                    Text(reportExportError)
                        .font(.label)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Button {
                        self.reportExportError = nil
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

            // Sub-tab bar (horizontally scrollable)
            SubTabBar(tabs: networkTabs, selectedIndex: $selectedTab)

            // Content
            switch selectedTab {
            case 0:
                DeviceGraphView(
                    devices: deviceDiscovery.devices,
                    localIP: deviceDiscovery.localIP,
                    gatewayIP: deviceDiscovery.gatewayIP
                )
            case 1:
                ScrollView {
                    InterfacesTabView(interfaces: networkMonitor.interfaces)
                        .padding(16)
                }
            case 2:
                ScrollView {
                    DevicesTabView(
                        devices: deviceDiscovery.devices,
                        localIP: deviceDiscovery.localIP,
                        gatewayIP: deviceDiscovery.gatewayIP
                    )
                    .padding(16)
                }
            case 3:
                ScrollView {
                    ConnectionsTabView(connections: networkMonitor.connections)
                        .padding(16)
                }
            case 4:
                PacketCaptureView()
            case 5:
                PortScanView()
            case 6:
                TrafficFlowGraphView(
                    devices: deviceDiscovery.devices,
                    localIP: deviceDiscovery.localIP,
                    gatewayIP: deviceDiscovery.gatewayIP
                )
            case 7:
                NetworkConversationFlowView(
                    connections: networkMonitor.connections,
                    devices: deviceDiscovery.devices,
                    localIP: deviceDiscovery.localIP,
                    gatewayIP: deviceDiscovery.gatewayIP
                )
            case 8:
                NetworkWorldMapView(
                    connections: networkMonitor.connections,
                    localIP: deviceDiscovery.localIP,
                    gatewayIP: deviceDiscovery.gatewayIP
                )
            default:
                EmptyView()
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            networkMonitor.start()
            deviceDiscovery.start()
        }
        .onDisappear {
            networkMonitor.stop()
        }
        .fileExporter(
            isPresented: $showReportExporter,
            document: reportDocument,
            contentType: reportDocument?.contentType ?? .json,
            defaultFilename: reportDocument?.defaultFilename ?? "macpulse-report.json"
        ) { result in
            if case .failure(let error) = result {
                reportExportError = error.localizedDescription
            }
        }
    }

    private func prepareReportExport(format: NetworkReportFormat) {
        let input = ReportExportInput(
            generatedAt: Date(),
            interfaces: networkMonitor.interfaces,
            devices: deviceDiscovery.devices,
            connections: networkMonitor.connections,
            diagnostics: DiagnosticsService().runChecks(),
            privacyMode: MacPulseSettings.bool(
                forKey: MacPulseSettings.Key.privacyMode,
                defaultValue: MacPulseSettings.Default.privacyMode
            )
        )

        do {
            reportDocument = try NetworkReportDocument(format: format, input: input)
            reportExportError = nil
            showReportExporter = true
        } catch {
            reportExportError = error.localizedDescription
        }
    }
}

enum NetworkReportFormat {
    case json
    case markdown
}

struct NetworkReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }

    let data: Data
    let contentType: UTType
    let defaultFilename: String

    init(format: NetworkReportFormat, input: ReportExportInput) throws {
        let timestamp = ISO8601DateFormatter()
            .string(from: input.generatedAt)
            .replacingOccurrences(of: ":", with: "-")

        switch format {
        case .json:
            self.data = try ReportExportService.jsonData(from: input)
            self.contentType = .json
            self.defaultFilename = "macpulse-report-\(timestamp).json"
        case .markdown:
            self.data = Data(ReportExportService.markdown(from: input).utf8)
            self.contentType = .plainText
            self.defaultFilename = "macpulse-report-\(timestamp).md"
        }
    }

    init(configuration: ReadConfiguration) throws {
        data = Data()
        contentType = .json
        defaultFilename = "macpulse-report.json"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct NetworkConversationFlowView: View {
    let connections: [NetworkConnection]
    let devices: [NetworkDevice]
    let localIP: String
    let gatewayIP: String

    private var topProcesses: [(String, Int)] {
        Dictionary(grouping: connections) { $0.processName ?? "System" }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(7)
            .map { $0 }
    }

    private var topDestinations: [(String, Int)] {
        Dictionary(grouping: connections) { classifyDestination($0.remoteAddress) }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map { $0 }
    }

    private var nodes: [SankeyNodeItem] {
        let left = topProcesses.map {
            SankeyNodeItem(id: "proc-\($0.0)", title: $0.0, subtitle: "\($0.1) sockets", column: 0, weight: Double($0.1), color: .appAccent)
        }

        let middle: [SankeyNodeItem] = [
            .init(id: "tcp", title: "TCP Sessions", subtitle: "\(tcpCount) active", column: 1, weight: Double(max(tcpCount, 1)), color: .netColor),
            .init(id: "udp", title: "UDP Traffic", subtitle: "\(udpCount) active", column: 1, weight: Double(max(udpCount, 1)), color: .warning),
            .init(id: "gateway", title: "Gateway / LAN", subtitle: gatewayIP.isEmpty ? "local paths" : gatewayIP, column: 1, weight: Double(max(localAndGatewayCount, 1)), color: .success)
        ]

        let right = topDestinations.map {
            SankeyNodeItem(id: "dst-\($0.0)", title: $0.0, subtitle: "\($0.1) flows", column: 2, weight: Double($0.1), color: destinationColor($0.0))
        }
        return left + middle + right
    }

    private var links: [SankeyLinkItem] {
        var result: [SankeyLinkItem] = []
        for (processName, count) in topProcesses {
            let related = connections.filter { ($0.processName ?? "System") == processName }
            let lane = preferredLane(for: related)
            result.append(.init(id: "proc-lane-\(processName)", from: "proc-\(processName)", to: lane, weight: Double(max(count, 1)), color: laneColor(lane)))
        }

        for (destination, count) in topDestinations {
            let related = connections.filter { classifyDestination($0.remoteAddress) == destination }
            let lane = preferredLane(for: related)
            result.append(.init(id: "lane-dst-\(destination)", from: lane, to: "dst-\(destination)", weight: Double(max(count, 1)), color: destinationColor(destination)))
        }

        return result
    }

    private var tcpCount: Int {
        connections.filter { $0.protocol == .tcp || $0.protocol == .tcp6 }.count
    }

    private var udpCount: Int {
        connections.filter { $0.protocol == .udp || $0.protocol == .udp6 }.count
    }

    private var localAndGatewayCount: Int {
        connections.filter {
            let destination = classifyDestination($0.remoteAddress)
            return destination == "Gateway" || destination == "LAN Device"
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SankeyDiagramView(
                    title: "Conversation Flow",
                    subtitle: "Von Prozessen über Transportpfade bis zu den derzeit wichtigsten Zielen im Netz.",
                    columnTitles: ["Processes", "Transport", "Destinations"],
                    nodes: nodes,
                    links: links
                )

                HStack(alignment: .top, spacing: 16) {
                    SankeyInsightCard(
                        title: "Current Traffic Story",
                        lines: topProcesses.prefix(4).map { "\($0.0) hält aktuell \($0.1) sichtbare Verbindungen offen." },
                        color: .netColor,
                        icon: "network"
                    )
                    SankeyInsightCard(
                        title: "Destination Readout",
                        lines: topDestinations.prefix(4).map { "\($0.0) empfängt \($0.1) aktuelle Flows." },
                        color: .success,
                        icon: "point.3.filled.connected.trianglepath.dotted"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
        }
        .background(Color.backgroundPrimary)
    }

    private func preferredLane(for connections: [NetworkConnection]) -> String {
        let tcp = connections.filter { $0.protocol == .tcp || $0.protocol == .tcp6 }.count
        let udp = connections.count - tcp
        let localish = connections.filter {
            let destination = classifyDestination($0.remoteAddress)
            return destination == "Gateway" || destination == "LAN Device"
        }.count
        if localish >= max(tcp, udp) { return "gateway" }
        return tcp >= udp ? "tcp" : "udp"
    }

    private func classifyDestination(_ address: String) -> String {
        if !gatewayIP.isEmpty && address == gatewayIP { return "Gateway" }
        if devices.contains(where: { $0.ipAddress == address }) { return "LAN Device" }
        if address == localIP { return "This Mac" }
        if address.hasPrefix("127.") || address == "::1" { return "Loopback" }
        let octets = address.split(separator: ".")
        if octets.count == 4, address.hasPrefix("192.168.") || address.hasPrefix("10.") || address.hasPrefix("172.") {
            return "Private Remote"
        }
        return address.isEmpty ? "Unresolved" : address
    }

    private func destinationColor(_ destination: String) -> Color {
        switch destination {
        case "Gateway", "LAN Device", "Private Remote": return .success
        case "Loopback": return .warning
        default: return .netColor
        }
    }

    private func laneColor(_ lane: String) -> Color {
        switch lane {
        case "tcp": return .netColor
        case "udp": return .warning
        default: return .success
        }
    }
}

struct NetworkWorldMapView: View {
    let connections: [NetworkConnection]
    let localIP: String
    let gatewayIP: String

    @State private var geoService = NetworkGeoMapService()
    @State private var grouping: NetworkGeoGrouping = .ip
    @State private var protocolFilter: NetworkGeoProtocolFilter = .all
    @State private var directionFilter: NetworkGeoDirectionFilter = .all
    @State private var density: NetworkGeoDensity = .balanced
    @State private var routeMode: NetworkGeoRouteMode = .current
    @State private var selectedProcessFilter = "All Processes"
    @State private var selectedPointID: String?

    private var refreshKey: String {
        connections
            .filter { $0.state != .listen }
            .map { "\($0.remoteAddress)|\($0.localPort)|\($0.remotePort)|\($0.protocol.rawValue)|\($0.processName ?? "-")" }
            .sorted()
            .prefix(120)
            .joined(separator: "|")
    }

    private var filteredEndpoints: [NetworkGeoResolvedEndpoint] {
        let endpoints = routeMode == .current
            ? (geoService.snapshot?.endpoints ?? [])
            : (geoService.snapshot?.historicalEndpoints ?? [])
        return endpoints.filter { endpoint in
            protocolFilter.matches(endpoint.protocols)
                && directionFilter.matches(endpoint.dominantDirection)
                && (selectedProcessFilter == "All Processes" || endpoint.processNames.contains(selectedProcessFilter))
        }
    }

    private var availableProcesses: [String] {
        let endpoints = routeMode == .current
            ? (geoService.snapshot?.endpoints ?? [])
            : (geoService.snapshot?.historicalEndpoints ?? [])
        return ["All Processes"] + Array(Set(endpoints.flatMap(\.processNames))).sorted()
    }

    private var displayPoints: [NetworkGeoDisplayPoint] {
        let base: [NetworkGeoDisplayPoint]
        switch grouping {
        case .ip:
            base = filteredEndpoints.map { endpoint in
                NetworkGeoDisplayPoint(
                    id: endpoint.ip,
                    title: endpoint.ip,
                    subtitle: endpoint.cityCountryLabel,
                    detail: endpoint.organization.isEmpty ? endpoint.country : endpoint.organization,
                    latitude: endpoint.latitude,
                    longitude: endpoint.longitude,
                    socketCount: endpoint.socketCount,
                    processCount: endpoint.processCount,
                    portCount: endpoint.portCount,
                    countryCode: endpoint.countryCode,
                    direction: endpoint.dominantDirection,
                    protocols: endpoint.protocols,
                    ips: [endpoint.ip],
                    processes: endpoint.processNames,
                    ports: endpoint.ports,
                    countries: [endpoint.country],
                    firstSeen: endpoint.firstSeen,
                    lastSeen: endpoint.lastSeen
                )
            }
        case .country:
            base = Dictionary(grouping: filteredEndpoints) { "\($0.countryCode)|\($0.country)" }
                .values
                .map { endpoints in
                    let totalSockets = endpoints.reduce(0) { $0 + $1.socketCount }
                    let totalProcesses = Set(endpoints.flatMap(\.processNames)).count
                    let totalPorts = Set(endpoints.flatMap(\.ports)).count
                    let lat = weightedAverage(values: endpoints.map { ($0.latitude, Double($0.socketCount)) })
                    let lon = weightedAverage(values: endpoints.map { ($0.longitude, Double($0.socketCount)) })
                    let topOrgs = endpoints
                        .map(\.organization)
                        .filter { !$0.isEmpty }
                        .frequencySorted()
                        .prefix(2)
                        .joined(separator: ", ")
                    return NetworkGeoDisplayPoint(
                        id: "country-\(endpoints.first?.countryCode ?? "XX")",
                        title: endpoints.first?.country.isEmpty == false ? endpoints.first?.country ?? "Unknown" : "Unknown Country",
                        subtitle: "\(endpoints.count) IPs",
                        detail: topOrgs.isEmpty ? "\(totalProcesses) processes" : topOrgs,
                        latitude: lat,
                        longitude: lon,
                        socketCount: totalSockets,
                        processCount: totalProcesses,
                        portCount: totalPorts,
                        countryCode: endpoints.first?.countryCode ?? "XX",
                        direction: dominantDirection(for: endpoints.map(\.dominantDirection)),
                        protocols: Set(endpoints.flatMap(\.protocols)),
                        ips: endpoints.map(\.ip),
                        processes: Array(Set(endpoints.flatMap(\.processNames))).sorted(),
                        ports: Array(Set(endpoints.flatMap(\.ports))).sorted(),
                        countries: Array(Set(endpoints.map(\.country))).sorted(),
                        firstSeen: endpoints.map(\.firstSeen).min(),
                        lastSeen: endpoints.map(\.lastSeen).max()
                    )
                }
        case .organization:
            base = Dictionary(grouping: filteredEndpoints) { endpoint in
                let normalized = endpoint.organization.trimmingCharacters(in: .whitespacesAndNewlines)
                if normalized.isEmpty { return "Unknown Org" }
                return normalized
            }
            .values
            .map { endpoints in
                let totalSockets = endpoints.reduce(0) { $0 + $1.socketCount }
                let totalProcesses = Set(endpoints.flatMap(\.processNames)).count
                let totalPorts = Set(endpoints.flatMap(\.ports)).count
                let lat = weightedAverage(values: endpoints.map { ($0.latitude, Double($0.socketCount)) })
                let lon = weightedAverage(values: endpoints.map { ($0.longitude, Double($0.socketCount)) })
                return NetworkGeoDisplayPoint(
                    id: "org-\(endpoints.first?.organization ?? "unknown")",
                    title: endpoints.first?.organization.isEmpty == false ? endpoints.first?.organization ?? "Unknown Org" : "Unknown Org",
                    subtitle: "\(Array(Set(endpoints.map(\.countryCode))).count) countries",
                    detail: "\(endpoints.count) IPs",
                    latitude: lat,
                    longitude: lon,
                    socketCount: totalSockets,
                    processCount: totalProcesses,
                    portCount: totalPorts,
                    countryCode: endpoints.first?.countryCode ?? "XX",
                    direction: dominantDirection(for: endpoints.map(\.dominantDirection)),
                    protocols: Set(endpoints.flatMap(\.protocols)),
                    ips: endpoints.map(\.ip),
                    processes: Array(Set(endpoints.flatMap(\.processNames))).sorted(),
                    ports: Array(Set(endpoints.flatMap(\.ports))).sorted(),
                    countries: Array(Set(endpoints.map(\.country))).sorted(),
                    firstSeen: endpoints.map(\.firstSeen).min(),
                    lastSeen: endpoints.map(\.lastSeen).max()
                )
            }
        }

        return base
            .sorted {
                if $0.socketCount == $1.socketCount {
                    return $0.title < $1.title
                }
                return $0.socketCount > $1.socketCount
            }
            .prefix(density.limit)
            .map { $0 }
    }

    private var selectedPoint: NetworkGeoDisplayPoint? {
        displayPoints.first { $0.id == selectedPointID } ?? displayPoints.first
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            worldMetricCard(
                title: "Visible Routes",
                value: "\(displayPoints.count)",
                detail: "\(filteredEndpoints.reduce(0) { $0 + $1.socketCount }) sockets mapped",
                color: .netColor
            )
            worldMetricCard(
                title: "Countries",
                value: "\(Set(filteredEndpoints.map(\.countryCode)).count)",
                detail: "reachable in current filter",
                color: .success
            )
            worldMetricCard(
                title: "Orgs",
                value: "\(Set(filteredEndpoints.map(\.organization)).filter { !$0.isEmpty }.count)",
                detail: "providers / services",
                color: .warning
            )
            worldMetricCard(
                title: "Local Origin",
                value: geoService.snapshot?.localLocation?.cityCountryLabel ?? "Resolving...",
                detail: geoService.snapshot?.localLocation?.ip ?? "public egress lookup",
                color: .appAccent
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCards
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 12) {
                        filterCard(title: "View") {
                            ForEach(NetworkGeoGrouping.allCases) { item in
                                miniToggle(title: item.rawValue, isSelected: grouping == item) {
                                    grouping = item
                                }
                            }
                        }
                        filterCard(title: "Routes") {
                            ForEach(NetworkGeoRouteMode.allCases) { item in
                                miniToggle(title: item.rawValue, isSelected: routeMode == item) {
                                    routeMode = item
                                }
                            }
                        }
                        filterCard(title: "Protocol") {
                            ForEach(NetworkGeoProtocolFilter.allCases) { item in
                                miniToggle(title: item.rawValue, isSelected: protocolFilter == item) {
                                    protocolFilter = item
                                }
                            }
                        }
                        filterCard(title: "Direction") {
                            ForEach(NetworkGeoDirectionFilter.allCases) { item in
                                miniToggle(title: item.rawValue, isSelected: directionFilter == item) {
                                    directionFilter = item
                                }
                            }
                        }
                        filterCard(title: "Density") {
                            ForEach(NetworkGeoDensity.allCases) { item in
                                miniToggle(title: item.rawValue, isSelected: density == item) {
                                    density = item
                                }
                            }
                        }
                        filterCard(title: "Process") {
                            Picker("Process", selection: $selectedProcessFilter) {
                                ForEach(availableProcesses, id: \.self) { process in
                                    Text(process).tag(process)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 190)
                        }
                        if let lastUpdated = geoService.lastUpdated {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.textTertiary)
                                Text("Geo refresh: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .fixedSize()
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)

                HStack(alignment: .top, spacing: 16) {
                    SectionCardView(title: "Global Communication Map", icon: "globe.europe.africa.fill", iconColor: .netColor) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(routeMode == .current
                                 ? "Der Mac wird aus dem aktuellen Egress-Standort verortet. Jede Route zeigt einen aktuell sichtbaren Kommunikationspfad zu IP-, Länder- oder Organisations-Clustern."
                                 : "Die Historie hält kurzzeitig sichtbare Routen fest. So erkennst du auch Ziele, die gerade nicht mehr aktiv sind, aber vor wenigen Minuten noch angesprochen wurden.")
                                .font(.system(size: 12))
                                .foregroundStyle(.textSecondary)

                            NetworkWorldTrafficCanvas(
                                localLocation: geoService.snapshot?.localLocation,
                                points: displayPoints,
                                routeMode: routeMode,
                                selectedPointID: $selectedPointID
                            )
                            .frame(minHeight: 560)

                            HStack(spacing: 18) {
                                legendDot(color: .success, text: "This Mac")
                                legendDot(color: .netColor, text: "Outbound heavy")
                                legendDot(color: .warning, text: "Inbound heavy")
                                legendDot(color: .appAccent, text: "Mixed traffic")
                                intensityLegend
                                if geoService.isResolving {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Updating geolocation cache")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.textTertiary)
                                    }
                                }
                            }

                            continentLegend
                        }
                    }
                    .frame(maxWidth: .infinity)

                    SectionCardView(title: selectedPoint == nil ? "Top Routes" : "Route Detail", icon: "point.3.connected.trianglepath.dotted", iconColor: .appAccent) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let selectedPoint {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(selectedPoint.title)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.textPrimary)

                                    Text(selectedPoint.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.textSecondary)

                                    if !selectedPoint.detail.isEmpty {
                                        Text(selectedPoint.detail)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.textTertiary)
                                    }

                                    HStack(spacing: 10) {
                                        detailBadge(text: "\(selectedPoint.socketCount) sockets", color: .netColor)
                                        detailBadge(text: "\(selectedPoint.processCount) processes", color: .success)
                                        detailBadge(text: "\(selectedPoint.portCount) ports", color: .warning)
                                    }

                                    Divider()
                                        .overlay(Color.white.opacity(0.08))

                                    detailLine(label: "Direction", value: selectedPoint.direction.readableTitle)
                                    if routeMode == .historical {
                                        detailLine(label: "Timeline", value: selectedPoint.historyWindow)
                                    }
                                    detailLine(label: "Protocols", value: selectedPoint.protocolSummary)
                                    detailLine(label: "Countries", value: selectedPoint.countries.prefix(4).joined(separator: ", "))
                                    detailLine(label: "IPs", value: selectedPoint.ips.prefix(5).joined(separator: ", "))
                                    detailLine(label: "Processes", value: selectedPoint.processes.prefix(5).joined(separator: ", "))
                                }
                            } else {
                                Text("No resolvable public destinations in the current filter.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.textSecondary)
                            }

                            Divider()
                                .overlay(Color.white.opacity(0.08))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Top Visible Routes")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.textSecondary)
                                ForEach(displayPoints.prefix(8)) { point in
                                    Button {
                                        selectedPointID = point.id
                                    } label: {
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(point.direction.color)
                                                .frame(width: 8, height: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(point.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.textPrimary)
                                                    .lineLimit(1)
                                                Text(point.subtitle)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.textTertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text("\(point.socketCount)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.netColor)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedPointID == point.id ? Color.backgroundTertiary : Color.backgroundPrimary.opacity(0.55))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if let message = geoService.errorMessage {
                                Divider()
                                    .overlay(Color.white.opacity(0.08))
                                Text(message)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.warning)
                            }
                        }
                    }
                    .frame(width: 320)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.backgroundPrimary)
        .task(id: refreshKey) {
            geoService.refresh(connections: connections, localIP: localIP, gatewayIP: gatewayIP)
        }
        .onChange(of: displayPoints.map(\.id)) { _, newValue in
            guard let selectedPointID else { return }
            if !newValue.contains(selectedPointID) {
                self.selectedPointID = newValue.first
            }
        }
        .onChange(of: availableProcesses) { _, newValue in
            if !newValue.contains(selectedProcessFilter) {
                selectedProcessFilter = "All Processes"
            }
        }
    }

    private func worldMetricCard(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.label)
                .foregroundStyle(.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
                        .stroke(color.opacity(0.32), lineWidth: 1)
                )
        )
    }

    private func filterCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textTertiary)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }

    private func miniToggle(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : .textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.backgroundSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.textSecondary)
        }
    }

    private var intensityLegend: some View {
        HStack(spacing: 8) {
            Text("Intensity")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.textSecondary)
            HStack(spacing: 6) {
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 18, height: 4)
                Capsule().fill(Color.white.opacity(0.38)).frame(width: 26, height: 6)
                Capsule().fill(Color.white.opacity(0.58)).frame(width: 36, height: 8)
            }
            Text("low -> high")
                .font(.system(size: 10))
                .foregroundStyle(.textTertiary)
        }
    }

    private var continentLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(NetworkGeoContinent.allCases) { continent in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(continent.color)
                            .frame(width: 12, height: 12)
                        Text(continent.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func detailBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func detailLine(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value.isEmpty ? "None" : value)
                .font(.system(size: 11))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.leading)
        }
    }

    private func weightedAverage(values: [(Double, Double)]) -> Double {
        let totalWeight = values.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return 0 }
        return values.reduce(0) { $0 + ($1.0 * $1.1) } / totalWeight
    }

    private func dominantDirection(for directions: [NetworkGeoResolvedDirection]) -> NetworkGeoResolvedDirection {
        let counts = Dictionary(grouping: directions, by: { $0 }).mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value < rhs.value
        }?.key ?? .mixed
    }
}

private struct NetworkWorldTrafficCanvas: View {
    let localLocation: NetworkGeoPlace?
    let points: [NetworkGeoDisplayPoint]
    let routeMode: NetworkGeoRouteMode
    @Binding var selectedPointID: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x09111F),
                            Color(hex: 0x0B1B2C),
                            Color(hex: 0x13263C),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            NetworkWorldVectorMapView(
                localLocation: localLocation,
                points: points,
                routeMode: routeMode,
                selectedPointID: $selectedPointID
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(10)
        }
    }
}

private struct NetworkWorldVectorMapView: NSViewRepresentable {
    let localLocation: NetworkGeoPlace?
    let points: [NetworkGeoDisplayPoint]
    let routeMode: NetworkGeoRouteMode
    @Binding var selectedPointID: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPointID: $selectedPointID)
    }

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "selection")
        contentController.add(context.coordinator, name: "viewport")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.setValue(false, forKey: "drawsTransparentBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.enclosingScrollView?.drawsBackground = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let signature = dataSignature
        if context.coordinator.lastSignature != signature {
            guard let html = makeHTML() else { return }
            context.coordinator.lastSignature = signature
            context.coordinator.pendingSelection = selectedPointID
            webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        } else if context.coordinator.lastSelection != selectedPointID {
            context.coordinator.lastSelection = selectedPointID
            context.coordinator.pendingSelection = selectedPointID
            let selection = selectedPointID?.jsSingleQuoted ?? "null"
            webView.evaluateJavaScript("window.updateSelection(\(selection));", completionHandler: nil)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "selection")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "viewport")
    }

    private var dataSignature: String {
        let routeSignature = points
            .map {
                [
                    $0.id,
                    $0.ips.first ?? "",
                    String($0.socketCount),
                    $0.direction.rawValue,
                    String($0.latitude),
                    String($0.longitude),
                    $0.markerSize.svgNumber,
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        let localSignature = localLocation.map {
            "\($0.latitude)|\($0.longitude)|\($0.city)|\($0.country)"
        } ?? "no-local"

        return "\(routeMode.rawValue)#\(localSignature)#\(routeSignature)"
    }

    private func makeHTML() -> String? {
        guard let svgURL = Bundle.main.url(forResource: "world-map", withExtension: "svg"),
              let svgString = try? String(contentsOf: svgURL, encoding: .utf8) else {
            return nil
        }

        let overlay = overlayMarkup()
        let mergedSVG = svgString.replacingOccurrences(of: "</svg>", with: overlay + "\n</svg>")

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        :root {
          color-scheme: dark;
        }
        html, body {
          margin: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: transparent;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
        }
        body {
          position: relative;
          background:
            radial-gradient(circle at top left, rgba(47, 95, 169, 0.18), transparent 34%),
            radial-gradient(circle at bottom right, rgba(19, 165, 132, 0.16), transparent 28%),
            linear-gradient(180deg, #07111E 0%, #0C1A2A 100%);
        }
        #viewport {
          position: absolute;
          inset: 0;
          overflow: hidden;
          touch-action: none;
          user-select: none;
          -webkit-user-select: none;
        }
        svg {
          display: block;
          width: 100%;
          height: 100%;
        }
        #toolbar {
          position: absolute;
          top: 14px;
          right: 14px;
          display: flex;
          gap: 8px;
          padding: 8px;
          border-radius: 14px;
          background: rgba(5, 10, 18, 0.68);
          border: 1px solid rgba(255,255,255,0.08);
          backdrop-filter: blur(14px);
          z-index: 20;
        }
        #toolbar button {
          width: 34px;
          height: 34px;
          border: 0;
          border-radius: 10px;
          background: rgba(255,255,255,0.08);
          color: #F4F8FF;
          font-size: 16px;
          font-weight: 700;
          cursor: pointer;
        }
        #toolbar button:hover {
          background: rgba(255,255,255,0.14);
        }
        #selection-badge {
          position: absolute;
          left: 14px;
          top: 14px;
          padding: 8px 12px;
          border-radius: 999px;
          background: rgba(5, 10, 18, 0.68);
          border: 1px solid rgba(255,255,255,0.08);
          color: #DFE8F8;
          font-size: 12px;
          font-weight: 600;
          backdrop-filter: blur(14px);
          z-index: 20;
        }
        </style>
        </head>
        <body>
          <div id="viewport">
            \(mergedSVG)
          </div>
          <div id="selection-badge">Drag to pan, wheel or pinch to zoom</div>
          <div id="toolbar">
            <button type="button" onclick="zoomBy(0.92)">+</button>
            <button type="button" onclick="zoomBy(1.08)">-</button>
            <button type="button" onclick="resetView()">&#8634;</button>
          </div>
          <script>
          (() => {
            const svg = document.querySelector('svg');
            const viewport = document.getElementById('viewport');
            const badge = document.getElementById('selection-badge');
            if (!svg || !viewport) { return; }

            svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
            svg.style.background = 'transparent';
            svg.style.cursor = 'grab';
            const baseViewBox = { x: 0, y: 0, width: 360, height: 180 };
            const initialViewBox = \(contextViewBoxJSON)
            let currentViewBox = initialViewBox ? { ...initialViewBox } : { ...baseViewBox };
            let dragState = null;
            const notifyViewport = (() => {
              const post = () => {
                window.webkit?.messageHandlers?.viewport?.postMessage(currentViewBox);
              };
              const debounced = (() => {
                let timeout = null;
                return () => {
                  clearTimeout(timeout);
                  timeout = setTimeout(post, 90);
                };
              })();
              return (immediate = false) => immediate ? post() : debounced();
            })();

            function clampViewBox(box) {
              const minWidth = 28;
              const maxWidth = 360;
              const width = Math.min(Math.max(box.width, minWidth), maxWidth);
              const height = width / 2;
              const maxX = baseViewBox.x + baseViewBox.width - width;
              const maxY = baseViewBox.y + baseViewBox.height - height;
              return {
                x: Math.min(Math.max(box.x, baseViewBox.x), maxX),
                y: Math.min(Math.max(box.y, baseViewBox.y), maxY),
                width,
                height
              };
            }

            function applyViewBox() {
              currentViewBox = clampViewBox(currentViewBox);
              svg.setAttribute(
                'viewBox',
                `${currentViewBox.x} ${currentViewBox.y} ${currentViewBox.width} ${currentViewBox.height}`
              );
              const zoomFraction = currentViewBox.width / baseViewBox.width;
              const routeScale = Math.max(0.12, Math.min(1, Math.pow(zoomFraction, 1.08)));
              const haloScale = Math.max(0.10, Math.min(1, Math.pow(zoomFraction, 1.20)));
              const packetScale = Math.max(0.30, Math.min(1.08, Math.pow(zoomFraction, 0.82) * 1.08));
              const markerScale = Math.max(0.22, Math.min(1, Math.pow(zoomFraction, 0.92)));
              const ringScale = Math.max(0.18, Math.min(1, Math.pow(zoomFraction, 1.02)));
              const labelScale = Math.max(0.48, Math.min(1, Math.pow(zoomFraction, 0.74)));
              const sublabelScale = Math.max(0.54, Math.min(1, Math.pow(zoomFraction, 0.66)));
              document.querySelectorAll('.route-line').forEach((element) => {
                const base = parseFloat(element.dataset.baseWidth || '1');
                const selected = parseFloat(element.dataset.selectedWidth || String(base * 1.48));
                const isSelected = element.closest('.route-group')?.classList.contains('is-selected');
                element.setAttribute('stroke-width', String((isSelected ? selected : base) * routeScale));
              });
              document.querySelectorAll('.route-halo').forEach((element) => {
                const base = parseFloat(element.dataset.baseWidth || '1');
                element.setAttribute('stroke-width', String(base * haloScale));
              });
              document.querySelectorAll('.route-packet').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '0.82');
                element.setAttribute('r', String(base * packetScale));
              });
              document.querySelectorAll('.route-marker-core').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '3');
                element.setAttribute('r', String(base * markerScale));
              });
              document.querySelectorAll('.route-marker-ring').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '4');
                element.setAttribute('r', String(base * ringScale));
              });
              document.querySelectorAll('.route-hitbox').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '5');
                element.setAttribute('r', String(base * Math.max(0.34, markerScale)));
              });
              document.querySelectorAll('.local-origin-core').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '2.6');
                element.setAttribute('r', String(base * markerScale));
              });
              document.querySelectorAll('.local-origin-ring').forEach((element) => {
                const base = parseFloat(element.dataset.baseRadius || '5.2');
                element.setAttribute('r', String(base * ringScale));
              });
              document.querySelectorAll('.zoom-label').forEach((element) => {
                const base = parseFloat(element.dataset.baseFont || '3');
                element.setAttribute('font-size', String(base * labelScale));
              });
              document.querySelectorAll('.zoom-sublabel').forEach((element) => {
                const base = parseFloat(element.dataset.baseFont || '2.4');
                element.setAttribute('font-size', String(base * sublabelScale));
              });
              document.querySelectorAll('.route-label-box').forEach((element) => {
                const baseWidth = parseFloat(element.dataset.baseWidth || '34');
                const baseHeight = parseFloat(element.dataset.baseHeight || '8.8');
                const centerX = parseFloat(element.dataset.centerX || '0');
                const topY = parseFloat(element.dataset.topY || '0');
                const width = Math.max(18, baseWidth * Math.max(0.62, labelScale));
                const height = Math.max(5.8, baseHeight * Math.max(0.70, sublabelScale));
                element.setAttribute('width', String(width));
                element.setAttribute('height', String(height));
                element.setAttribute('x', String(centerX - width / 2));
                element.setAttribute('y', String(topY));
              });
              notifyViewport();
            }

            function pointInSvg(clientX, clientY) {
              const rect = viewport.getBoundingClientRect();
              const rx = (clientX - rect.left) / rect.width;
              const ry = (clientY - rect.top) / rect.height;
              return {
                x: currentViewBox.x + rx * currentViewBox.width,
                y: currentViewBox.y + ry * currentViewBox.height
              };
            }

            window.zoomBy = function zoomBy(factor, centerX, centerY) {
              const origin = centerX == null || centerY == null
                ? {
                    x: currentViewBox.x + currentViewBox.width / 2,
                    y: currentViewBox.y + currentViewBox.height / 2
                  }
                : pointInSvg(centerX, centerY);
              const nextWidth = currentViewBox.width * factor;
              const nextHeight = nextWidth / 2;
              const ratioX = (origin.x - currentViewBox.x) / currentViewBox.width;
              const ratioY = (origin.y - currentViewBox.y) / currentViewBox.height;
              currentViewBox = clampViewBox({
                x: origin.x - nextWidth * ratioX,
                y: origin.y - nextHeight * ratioY,
                width: nextWidth,
                height: nextHeight
              });
              applyViewBox();
            };

            window.resetView = function resetView() {
              currentViewBox = { ...baseViewBox };
              applyViewBox();
              notifyViewport(true);
            };

            window.restoreViewBox = function restoreViewBox(box) {
              if (!box) { return; }
              currentViewBox = clampViewBox(box);
              svg.setAttribute(
                'viewBox',
                `${currentViewBox.x} ${currentViewBox.y} ${currentViewBox.width} ${currentViewBox.height}`
              );
              notifyViewport(true);
            };

            viewport.addEventListener('wheel', (event) => {
              event.preventDefault();
              const delta = Math.max(-120, Math.min(120, event.deltaY));
              const factor = Math.exp(delta * 0.0009);
              zoomBy(factor, event.clientX, event.clientY);
            }, { passive: false });

            viewport.addEventListener('pointerdown', (event) => {
              if (event.target.closest('[data-point-id]')) { return; }
              dragState = {
                pointerId: event.pointerId,
                startX: event.clientX,
                startY: event.clientY,
                originX: currentViewBox.x,
                originY: currentViewBox.y
              };
              viewport.setPointerCapture(event.pointerId);
              svg.style.cursor = 'grabbing';
            });

            viewport.addEventListener('pointermove', (event) => {
              if (!dragState || dragState.pointerId !== event.pointerId) { return; }
              const rect = viewport.getBoundingClientRect();
              const dx = ((event.clientX - dragState.startX) / rect.width) * currentViewBox.width;
              const dy = ((event.clientY - dragState.startY) / rect.height) * currentViewBox.height;
              currentViewBox = clampViewBox({
                x: dragState.originX - dx,
                y: dragState.originY - dy,
                width: currentViewBox.width,
                height: currentViewBox.height
              });
              applyViewBox();
            });

            function finishPointer(event) {
              if (dragState && dragState.pointerId === event.pointerId) {
                dragState = null;
                svg.style.cursor = 'grab';
              }
            }

            viewport.addEventListener('pointerup', finishPointer);
            viewport.addEventListener('pointercancel', finishPointer);
            viewport.addEventListener('click', (event) => {
              if (event.target.closest('[data-point-id]')) { return; }
              window.webkit?.messageHandlers?.selection?.postMessage('');
            });

            let pinchDistance = null;
            let pinchOrigin = null;
            viewport.addEventListener('touchstart', (event) => {
              if (event.touches.length === 2) {
                const [a, b] = event.touches;
                pinchDistance = Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
                pinchOrigin = {
                  x: (a.clientX + b.clientX) / 2,
                  y: (a.clientY + b.clientY) / 2
                };
              }
            }, { passive: true });

            viewport.addEventListener('touchmove', (event) => {
              if (event.touches.length !== 2 || pinchDistance == null || pinchOrigin == null) { return; }
              event.preventDefault();
              const [a, b] = event.touches;
              const nextDistance = Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
              const rawFactor = pinchDistance / nextDistance;
              const factor = Math.pow(rawFactor, 0.18);
              zoomBy(factor, pinchOrigin.x, pinchOrigin.y);
              pinchDistance = nextDistance;
              pinchOrigin = {
                x: (a.clientX + b.clientX) / 2,
                y: (a.clientY + b.clientY) / 2
              };
            }, { passive: false });

            viewport.addEventListener('touchend', () => {
              pinchDistance = null;
              pinchOrigin = null;
            });

            window.updateSelection = function updateSelection(id) {
              const hasSelection = id !== null && id !== '';
              document.querySelectorAll('[data-point-id]').forEach((node) => {
                const isTarget = node.getAttribute('data-point-id') === id;
                node.classList.toggle('is-selected', isTarget);
                node.classList.toggle('is-dimmed', hasSelection && !isTarget);
              });
              applyViewBox();
              const badgeText = hasSelection ? `Selected route: ${id}` : 'Drag to pan, wheel or pinch to zoom';
              badge.textContent = badgeText;
            };

            applyViewBox();
            window.updateSelection(\(selectedPointID?.jsSingleQuoted ?? "null"));
          })();
          </script>
        </body>
        </html>
        """
    }

    private func overlayMarkup() -> String {
        let local = localLocation ?? NetworkGeoPlace(
            ip: "",
            city: "Unknown",
            country: "Origin",
            countryCode: "--",
            organization: "",
            latitude: 0,
            longitude: 0
        )

        let origin = projectedPoint(latitude: local.latitude, longitude: local.longitude)
        let routeElements = points.enumerated().map { index, point in
            routeGroup(point: point, origin: origin, index: index)
        }.joined(separator: "\n")

        let localMarker = """
        <g class="local-origin">
          <circle class="local-origin-core" cx="\(origin.x.svgNumber)" cy="\(origin.y.svgNumber)" r="2.6" data-base-radius="2.6" fill="#5CE1B8" stroke="#E8FFF8" stroke-width="0.8"></circle>
          <circle class="local-origin-ring" cx="\(origin.x.svgNumber)" cy="\(origin.y.svgNumber)" r="5.2" data-base-radius="5.2" fill="none" stroke="#5CE1B8" stroke-opacity="0.36" stroke-width="0.9"></circle>
          <text class="zoom-label" x="\(origin.x.svgNumber)" y="\((origin.y - 5.5).svgNumber)" data-base-font="4.2" text-anchor="middle" fill="#F5FBFF" font-size="4.2" font-weight="700">This Mac</text>
          <text class="zoom-sublabel" x="\(origin.x.svgNumber)" y="\((origin.y - 2.3).svgNumber)" data-base-font="2.8" text-anchor="middle" fill="#8FA4C1" font-size="2.8">\(local.cityCountryLabel.xmlEscaped)</text>
        </g>
        """

        let countryLabels = countryLabels()
            .map { label in
                """
                <text class="zoom-sublabel" x="\(label.x.svgNumber)" y="\(label.y.svgNumber)" data-base-font="3.1" text-anchor="middle" fill="rgba(222,231,246,0.58)" font-size="3.1" font-weight="700" letter-spacing="0.5">\(label.country.uppercased().xmlEscaped)</text>
                """
            }
            .joined(separator: "\n")

        return """
        <style>
        #svg2 { background: transparent; }
        #svg2 path, #svg2 polygon, #svg2 rect, #svg2 circle, #svg2 text {
          transition: opacity 160ms ease, stroke-width 160ms ease, filter 160ms ease;
        }
        #svg2 .country {
          fill: #314355 !important;
          fill-opacity: 1 !important;
          stroke: #5A7087 !important;
          stroke-width: 0.22 !important;
          vector-effect: non-scaling-stroke;
        }
        #svg2 .country:hover {
          fill: #3A5167 !important;
        }
        .grid-line {
          stroke: rgba(255,255,255,0.06);
          stroke-width: 0.22;
          stroke-dasharray: 1.2 2.0;
          vector-effect: non-scaling-stroke;
        }
        .route-halo {
          fill: none;
          stroke-linecap: round;
          opacity: 0.22;
          mix-blend-mode: screen;
        }
        .route-line {
          fill: none;
          stroke-linecap: round;
          opacity: 0.94;
        }
        .route-marker {
          cursor: pointer;
          transition: opacity 160ms ease, transform 160ms ease, filter 160ms ease;
        }
        .route-marker.is-dimmed,
        .route-group.is-dimmed .route-line,
        .route-group.is-dimmed .route-halo,
        .route-group.is-dimmed .route-label,
        .route-group.is-dimmed .route-packet {
          opacity: 0.14 !important;
        }
        .route-group.is-selected .route-line {
          filter: drop-shadow(0 0 0.95px rgba(255,255,255,0.28));
        }
        .route-group.is-selected .route-halo {
          opacity: 0.42 !important;
        }
        .route-group.is-selected .route-marker circle:last-child {
          stroke-width: 1.1 !important;
        }
        .route-label {
          pointer-events: none;
        }
        </style>
        <g id="map-grid">
          \(gridMarkup())
        </g>
        <g id="route-overlay">
          \(countryLabels)
          \(routeElements)
          \(localMarker)
        </g>
        """
    }

    private func routeGroup(point: NetworkGeoDisplayPoint, origin: CGPoint, index: Int) -> String {
        let destination = projectedPoint(latitude: point.latitude, longitude: point.longitude)
        let path = arcPath(from: origin, to: destination)
        let isSelected = selectedPointID == point.id
        let isDimmed = selectedPointID != nil && !isSelected
        let baseWidth = max(0.42, min(Double(point.socketCount) * 0.11, 1.36))
        let haloWidth = baseWidth + (routeMode == .historical ? 1.5 : 2.4)
        let markerRadius = max(2.2, min(Double(point.markerSize) * 0.20, 4.2))
        let opacity = isDimmed ? 0.16 : (routeMode == .historical ? 0.68 : 0.92)
        let packetCount = max(1, min(point.socketCount / 3, routeMode == .historical ? 2 : 4))
        let label = routeLabel(for: point, at: destination, selected: isSelected, dimmed: isDimmed)
        let packets = routePackets(for: point, path: path, color: point.direction.colorHex, count: packetCount, groupIndex: index, dimmed: isDimmed)
        let classNames = [
            "route-group",
            isSelected ? "is-selected" : "",
            isDimmed ? "is-dimmed" : "",
        ].filter { !$0.isEmpty }.joined(separator: " ")

        return """
        <g class="\(classNames)" data-point-id="\(point.id.xmlEscaped)">
          <path class="route-halo" d="\(path)" stroke="\(point.continent.hexColor)" stroke-width="\(haloWidth.svgNumber)" data-base-width="\(haloWidth.svgNumber)"></path>
          <path class="route-line" d="\(path)" stroke="\(point.continent.hexColor)" stroke-opacity="\(opacity.svgNumber)" stroke-width="\(baseWidth.svgNumber)" data-base-width="\(baseWidth.svgNumber)" data-selected-width="\((baseWidth * 1.48).svgNumber)"></path>
          \(packets)
          \(label)
          <g class="route-marker" data-point-id="\(point.id.xmlEscaped)" onclick="window.webkit.messageHandlers.selection.postMessage('\(point.id.jsSingleQuotedLiteral)')">
            <circle class="route-hitbox" cx="\(destination.x.svgNumber)" cy="\(destination.y.svgNumber)" r="\((markerRadius + 1.9).svgNumber)" data-base-radius="\((markerRadius + 1.9).svgNumber)" fill="transparent"></circle>
            <circle class="route-marker-core" cx="\(destination.x.svgNumber)" cy="\(destination.y.svgNumber)" r="\(markerRadius.svgNumber)" data-base-radius="\(markerRadius.svgNumber)" fill="\(point.continent.hexColor)" fill-opacity="\(isDimmed ? "0.32" : "0.94")" stroke="#F7FBFF" stroke-opacity="0.88" stroke-width="0.46"></circle>
            <circle class="route-marker-ring" cx="\(destination.x.svgNumber)" cy="\(destination.y.svgNumber)" r="\((markerRadius + 1.2).svgNumber)" data-base-radius="\((markerRadius + 1.2).svgNumber)" fill="none" stroke="#FFFFFF" stroke-opacity="\(isSelected ? "0.56" : "0.0")" stroke-width="0.72"></circle>
          </g>
        </g>
        """
    }

    private func routePackets(
        for point: NetworkGeoDisplayPoint,
        path: String,
        color: String,
        count: Int,
        groupIndex: Int,
        dimmed: Bool
    ) -> String {
        (0..<count).map { packetIndex in
            let duration = max(2.8, 5.8 - Double(min(point.socketCount, 18)) * 0.12 + Double(packetIndex) * 0.18)
            let begin = -(Double(groupIndex) * 0.34 + Double(packetIndex) * 0.54)
            return """
            <circle class="route-packet" r="1.04" data-base-radius="1.04" fill="\(color)" fill-opacity="\(dimmed ? "0.18" : (routeMode == .historical ? "0.46" : "0.92"))">
              <animateMotion dur="\(duration.svgNumber)s" begin="\(begin.svgNumber)s" repeatCount="indefinite" path="\(path)"></animateMotion>
            </circle>
            """
        }
        .joined(separator: "\n")
    }

    private func routeLabel(for point: NetworkGeoDisplayPoint, at destination: CGPoint, selected: Bool, dimmed: Bool) -> String {
        guard selected || point.socketCount >= max(points.first?.socketCount ?? 0, 1) / 2 else { return "" }
        let titleY = destination.y - 4.2
        let subtitleY = destination.y - 1.3
        let boxTopY = destination.y - 7.9
        return """
        <g class="route-label">
          <rect class="route-label-box" x="\((destination.x - 17).svgNumber)" y="\(boxTopY.svgNumber)" width="34" height="8.8" rx="2.4" data-base-width="34" data-base-height="8.8" data-center-x="\(destination.x.svgNumber)" data-top-y="\(boxTopY.svgNumber)" fill="rgba(4,10,18,\(dimmed ? "0.22" : "0.52"))" stroke="rgba(255,255,255,0.08)" stroke-width="0.3"></rect>
          <text class="zoom-label" x="\(destination.x.svgNumber)" y="\(titleY.svgNumber)" data-base-font="3.1" text-anchor="middle" fill="\(dimmed ? "#8A99AE" : "#F6FAFF")" font-size="3.1" font-weight="700">\(point.title.xmlEscaped)</text>
          <text class="zoom-sublabel" x="\(destination.x.svgNumber)" y="\(subtitleY.svgNumber)" data-base-font="2.45" text-anchor="middle" fill="#8EA2BF" font-size="2.45">\(point.subtitle.xmlEscaped)</text>
        </g>
        """
    }

    private func countryLabels() -> [(country: String, x: Double, y: Double, weight: Int)] {
        let grouped = Dictionary(grouping: points) { point in
            point.countries.first ?? "Unknown"
        }

        return grouped.compactMap { country, entries in
            guard !entries.isEmpty else { return nil }
            let count = Double(entries.count)
            let longitude = entries.reduce(0.0) { $0 + $1.longitude } / count
            let latitude = entries.reduce(0.0) { $0 + $1.latitude } / count
            let totalWeight = entries.reduce(0) { $0 + $1.socketCount }
            let projected = projectedPoint(latitude: latitude, longitude: longitude)
            return (country, Double(projected.x), Double(projected.y + 6), totalWeight)
        }
        .sorted { $0.weight > $1.weight }
        .prefix(8)
        .map { $0 }
    }

    private func projectedPoint(latitude: Double, longitude: Double) -> CGPoint {
        CGPoint(x: (longitude + 180.0), y: (90.0 - latitude))
    }

    private func arcPath(from start: CGPoint, to end: CGPoint) -> String {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let lift = max(10.0, min(distance * 0.22, 34.0))
        let controlX = (start.x + end.x) / 2
        let controlY = min(start.y, end.y) - lift
        return "M \(start.x.svgNumber) \(start.y.svgNumber) Q \(controlX.svgNumber) \(controlY.svgNumber) \(end.x.svgNumber) \(end.y.svgNumber)"
    }

    private func gridMarkup() -> String {
        var lines: [String] = []
        for x in stride(from: 30.0, to: 360.0, by: 30.0) {
            lines.append(#"<line class="grid-line" x1="\#(x.svgNumber)" y1="0" x2="\#(x.svgNumber)" y2="180"></line>"#)
        }
        for y in stride(from: 30.0, to: 180.0, by: 30.0) {
            lines.append(#"<line class="grid-line" x1="0" y1="\#(y.svgNumber)" x2="360" y2="\#(y.svgNumber)"></line>"#)
        }
        return lines.joined(separator: "\n")
    }

    private var contextViewBoxJSON: String { "null" }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var selectedPointID: String?
        var lastSignature = ""
        var lastSelection: String?
        var pendingSelection: String?
        var currentViewBox: CGRect?

        init(selectedPointID: Binding<String?>) {
            _selectedPointID = selectedPointID
            lastSelection = selectedPointID.wrappedValue
            pendingSelection = selectedPointID.wrappedValue
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            lastSelection = pendingSelection
            if let currentViewBox {
                let restoreScript = """
                window.restoreViewBox({
                  x: \(currentViewBox.origin.x.svgNumber),
                  y: \(currentViewBox.origin.y.svgNumber),
                  width: \(currentViewBox.size.width.svgNumber),
                  height: \(currentViewBox.size.height.svgNumber)
                });
                """
                webView.evaluateJavaScript(restoreScript, completionHandler: nil)
            }
            let selection = pendingSelection?.jsSingleQuoted ?? "null"
            webView.evaluateJavaScript("window.updateSelection(\(selection));", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "selection":
                if let selection = message.body as? String, !selection.isEmpty {
                    selectedPointID = selection
                    lastSelection = selection
                } else {
                    selectedPointID = nil
                    lastSelection = nil
                }
            case "viewport":
                if let body = message.body as? [String: Any],
                   let x = body["x"] as? Double,
                   let y = body["y"] as? Double,
                   let width = body["width"] as? Double,
                   let height = body["height"] as? Double {
                    currentViewBox = CGRect(x: x, y: y, width: width, height: height)
                }
            default:
                break
            }
        }
    }
}

@MainActor
@Observable
private final class NetworkGeoMapService {
    var snapshot: NetworkGeoSnapshot?
    var isResolving = false
    var errorMessage: String?
    var lastUpdated: Date?

    private var locationCache: [String: NetworkGeoPlace] = [:]
    private var localLocation: NetworkGeoPlace?
    private var currentSignature = ""
    private var resolveTask: Task<Void, Never>?
    private var historicalStore: [String: NetworkGeoHistoricalEndpoint] = [:]

    func refresh(connections: [NetworkConnection], localIP: String, gatewayIP: String) {
        let request = Self.buildRequest(connections: connections, localIP: localIP, gatewayIP: gatewayIP)
        guard !request.signature.isEmpty else {
            snapshot = nil
            errorMessage = "No public remote destinations are visible right now."
            return
        }

        guard request.signature != currentSignature || snapshot == nil else { return }
        currentSignature = request.signature
        errorMessage = nil
        isResolving = true

        let cachedLocations = locationCache
        let cachedLocal = localLocation

        resolveTask?.cancel()
        resolveTask = Task {
            var updatedCache = cachedLocations
            let resolvedLocal: NetworkGeoPlace?
            if let cachedLocal {
                resolvedLocal = cachedLocal
            } else {
                resolvedLocal = await Self.fetchCurrentLocation()
            }

            for endpoint in request.endpoints {
                guard !Task.isCancelled else { return }
                if updatedCache[endpoint.ip] == nil, let place = await Self.fetchLocation(for: endpoint.ip) {
                    updatedCache[endpoint.ip] = place
                }
            }

            guard !Task.isCancelled else { return }

            let endpoints = request.endpoints.compactMap { endpoint -> NetworkGeoResolvedEndpoint? in
                guard let place = updatedCache[endpoint.ip] else { return nil }
                return NetworkGeoResolvedEndpoint(
                    ip: endpoint.ip,
                    city: place.city,
                    country: place.country,
                    countryCode: place.countryCode,
                    organization: place.organization,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    socketCount: endpoint.socketCount,
                    processCount: endpoint.processNames.count,
                    portCount: endpoint.ports.count,
                    dominantDirection: endpoint.direction,
                    protocols: endpoint.protocols,
                    processNames: Array(endpoint.processNames).sorted(),
                    ports: Array(endpoint.ports).sorted()
                )
            }

            self.locationCache = updatedCache
            self.localLocation = resolvedLocal
            self.snapshot = NetworkGeoSnapshot(
                localLocation: resolvedLocal,
                endpoints: endpoints.sorted { $0.socketCount > $1.socketCount },
                historicalEndpoints: self.updatedHistoricalEndpoints(with: endpoints),
                unresolvedCount: max(request.endpoints.count - endpoints.count, 0)
            )
            self.lastUpdated = Date()
            self.isResolving = false

            if endpoints.isEmpty {
                self.errorMessage = "Public destinations were found, but none could be geolocated right now."
            } else if self.snapshot?.unresolvedCount ?? 0 > 0 {
                self.errorMessage = "\(self.snapshot?.unresolvedCount ?? 0) endpoints are still unresolved and may appear after the next refresh."
            } else {
                self.errorMessage = nil
            }
        }
    }

    private func updatedHistoricalEndpoints(with endpoints: [NetworkGeoResolvedEndpoint]) -> [NetworkGeoResolvedEndpoint] {
        let now = Date()
        let retention: TimeInterval = 15 * 60

        for endpoint in endpoints {
            if var existing = historicalStore[endpoint.ip] {
                existing.lastSeen = now
                existing.firstSeen = min(existing.firstSeen, now)
                existing.socketCount = max(existing.socketCount, endpoint.socketCount)
                existing.processNames.formUnion(endpoint.processNames)
                existing.ports.formUnion(endpoint.ports)
                existing.protocols.formUnion(endpoint.protocols)
                existing.dominantDirection = endpoint.dominantDirection
                existing.location = endpoint
                historicalStore[endpoint.ip] = existing
            } else {
                historicalStore[endpoint.ip] = NetworkGeoHistoricalEndpoint(
                    location: endpoint,
                    firstSeen: now,
                    lastSeen: now,
                    socketCount: endpoint.socketCount,
                    processNames: Set(endpoint.processNames),
                    ports: Set(endpoint.ports),
                    protocols: endpoint.protocols,
                    dominantDirection: endpoint.dominantDirection
                )
            }
        }

        historicalStore = historicalStore.filter { now.timeIntervalSince($0.value.lastSeen) <= retention }

        return historicalStore.values
            .map { item in
                NetworkGeoResolvedEndpoint(
                    ip: item.location.ip,
                    city: item.location.city,
                    country: item.location.country,
                    countryCode: item.location.countryCode,
                    organization: item.location.organization,
                    latitude: item.location.latitude,
                    longitude: item.location.longitude,
                    socketCount: item.socketCount,
                    processCount: item.processNames.count,
                    portCount: item.ports.count,
                    dominantDirection: item.dominantDirection,
                    protocols: item.protocols,
                    processNames: Array(item.processNames).sorted(),
                    ports: Array(item.ports).sorted(),
                    firstSeen: item.firstSeen,
                    lastSeen: item.lastSeen
                )
            }
            .sorted {
                if $0.lastSeen == $1.lastSeen {
                    return $0.socketCount > $1.socketCount
                }
                return $0.lastSeen > $1.lastSeen
            }
        }

    nonisolated private static func buildRequest(connections: [NetworkConnection], localIP: String, gatewayIP: String) -> NetworkGeoRequest {
        var buckets: [String: NetworkGeoRequestEndpoint] = [:]

        for connection in connections {
            guard connection.state != .listen else { continue }

            let remote = normalizeAddress(connection.remoteAddress)
            guard !remote.isEmpty, remote != "*", remote != gatewayIP, remote != localIP else { continue }
            guard isPublicRoutableAddress(remote) else { continue }

            let direction = inferDirection(for: connection)
            let key = remote

            if buckets[key] == nil {
                buckets[key] = NetworkGeoRequestEndpoint(
                    ip: remote,
                    socketCount: 0,
                    processNames: [],
                    ports: [],
                    protocols: [],
                    directionTallies: [.outbound: 0, .inbound: 0, .mixed: 0]
                )
            }

            buckets[key]?.socketCount += 1
            if let processName = connection.processName, !processName.isEmpty {
                buckets[key]?.processNames.insert(processName)
            }
            if connection.remotePort > 0 {
                buckets[key]?.ports.insert(connection.remotePort)
            }
            buckets[key]?.protocols.insert(connection.protocol)
            buckets[key]?.directionTallies[direction, default: 0] += 1
        }

        let endpoints = buckets.values
            .map { bucket -> NetworkGeoRequestEndpoint in
                var updated = bucket
                updated.direction = dominantDirection(from: bucket.directionTallies)
                return updated
            }
            .sorted { lhs, rhs in
                if lhs.socketCount == rhs.socketCount {
                    return lhs.ip < rhs.ip
                }
                return lhs.socketCount > rhs.socketCount
            }
            .prefix(28)
            .map { $0 }

        let signature = endpoints.map {
            "\($0.ip):\($0.socketCount):\($0.direction.rawValue):\($0.protocols.map(\.rawValue).sorted().joined(separator: ","))"
        }.joined(separator: "|")

        return NetworkGeoRequest(signature: signature, endpoints: endpoints)
    }

    nonisolated private static func fetchCurrentLocation() async -> NetworkGeoPlace? {
        await fetchLocation(for: nil)
    }

    nonisolated private static func fetchLocation(for ip: String?) async -> NetworkGeoPlace? {
        do {
            let url = try makeGeoURL(for: ip)
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NetworkGeoAPIResponse.self, from: data)
            guard response.success ?? true else { return nil }
            guard let latitude = response.latitude, let longitude = response.longitude else { return nil }
            return NetworkGeoPlace(
                ip: response.ip ?? ip ?? "",
                city: response.city?.nilIfEmpty ?? "Unknown City",
                country: response.country?.nilIfEmpty ?? "Unknown Country",
                countryCode: response.countryCode?.nilIfEmpty ?? "XX",
                organization: response.connection?.organization?.nilIfEmpty ?? response.connection?.isp?.nilIfEmpty ?? "",
                latitude: latitude,
                longitude: longitude
            )
        } catch {
            return nil
        }
    }

    nonisolated private static func makeGeoURL(for ip: String?) throws -> URL {
        var components = URLComponents(string: "https://ipwho.is")!
        if let ip, !ip.isEmpty {
            components.path = "/\(ip)"
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    nonisolated private static func normalizeAddress(_ address: String) -> String {
        address
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func inferDirection(for connection: NetworkConnection) -> NetworkGeoResolvedDirection {
        if connection.localPort >= 49152 && connection.remotePort < connection.localPort {
            return .outbound
        }
        if connection.remotePort >= 49152 && connection.localPort < connection.remotePort {
            return .inbound
        }
        if connection.protocol == .udp || connection.protocol == .udp6 {
            return .mixed
        }
        return .outbound
    }

    nonisolated private static func dominantDirection(from tallies: [NetworkGeoResolvedDirection: Int]) -> NetworkGeoResolvedDirection {
        tallies.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value < rhs.value
        }?.key ?? .mixed
    }

    nonisolated private static func isPublicRoutableAddress(_ address: String) -> Bool {
        if address.hasPrefix("127.") || address == "::1" { return false }
        if address.hasPrefix("10.") || address.hasPrefix("192.168.") || address.hasPrefix("169.254.") { return false }
        if address.hasPrefix("0.") || address == "255.255.255.255" { return false }
        if address.hasPrefix("fe80") || address.hasPrefix("fc") || address.hasPrefix("fd") { return false }

        let octets = address.split(separator: ".")
        if octets.count == 4 {
            if let first = Int(octets[0]), let second = Int(octets[1]) {
                if first == 172 && (16...31).contains(second) { return false }
                if (224...255).contains(first) { return false }
            }
            return true
        }

        return address.contains(":")
    }
}

private struct NetworkGeoSnapshot {
    let localLocation: NetworkGeoPlace?
    let endpoints: [NetworkGeoResolvedEndpoint]
    let historicalEndpoints: [NetworkGeoResolvedEndpoint]
    let unresolvedCount: Int
}

private struct NetworkGeoRequest {
    let signature: String
    let endpoints: [NetworkGeoRequestEndpoint]
}

private struct NetworkGeoRequestEndpoint {
    let ip: String
    var socketCount: Int
    var processNames: Set<String>
    var ports: Set<UInt16>
    var protocols: Set<ConnectionProtocol>
    var directionTallies: [NetworkGeoResolvedDirection: Int]
    var direction: NetworkGeoResolvedDirection = .mixed
}

private struct NetworkGeoPlace {
    let ip: String
    let city: String
    let country: String
    let countryCode: String
    let organization: String
    let latitude: Double
    let longitude: Double

    var cityCountryLabel: String {
        city == "Unknown City" ? country : "\(city), \(country)"
    }
}

private struct NetworkGeoResolvedEndpoint: Identifiable {
    var id: String { ip }
    let ip: String
    let city: String
    let country: String
    let countryCode: String
    let organization: String
    let latitude: Double
    let longitude: Double
    let socketCount: Int
    let processCount: Int
    let portCount: Int
    let dominantDirection: NetworkGeoResolvedDirection
    let protocols: Set<ConnectionProtocol>
    let processNames: [String]
    let ports: [UInt16]
    var firstSeen: Date = Date()
    var lastSeen: Date = Date()

    var cityCountryLabel: String {
        city == "Unknown City" ? country : "\(city), \(country)"
    }
}

private struct NetworkGeoHistoricalEndpoint {
    var location: NetworkGeoResolvedEndpoint
    var firstSeen: Date
    var lastSeen: Date
    var socketCount: Int
    var processNames: Set<String>
    var ports: Set<UInt16>
    var protocols: Set<ConnectionProtocol>
    var dominantDirection: NetworkGeoResolvedDirection
}

private struct NetworkGeoDisplayPoint: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let latitude: Double
    let longitude: Double
    let socketCount: Int
    let processCount: Int
    let portCount: Int
    let countryCode: String
    let direction: NetworkGeoResolvedDirection
    let protocols: Set<ConnectionProtocol>
    let ips: [String]
    let processes: [String]
    let ports: [UInt16]
    let countries: [String]
    var firstSeen: Date? = nil
    var lastSeen: Date? = nil

    var markerSize: CGFloat {
        CGFloat(min(max(12 + socketCount, 14), 34))
    }

    var protocolSummary: String {
        protocols
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }

    var historyWindow: String {
        guard let firstSeen, let lastSeen else { return "Current live route" }
        return "\(firstSeen.formatted(date: .omitted, time: .shortened)) -> \(lastSeen.formatted(date: .omitted, time: .shortened))"
    }

    var continent: NetworkGeoContinent {
        NetworkGeoContinent.from(countryCode: countryCode)
    }
}

private enum NetworkGeoRouteMode: String, CaseIterable, Identifiable {
    case current = "Current"
    case historical = "Historical"

    var id: String { rawValue }
}

private enum NetworkGeoContinent: String, CaseIterable, Identifiable {
    case northAmerica = "North America"
    case southAmerica = "South America"
    case europe = "Europe"
    case africa = "Africa"
    case asia = "Asia"
    case oceania = "Oceania"
    case unknown = "Unknown"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .northAmerica: return Color(hex: 0x36CFC9)
        case .southAmerica: return Color(hex: 0x7AD66D)
        case .europe: return Color(hex: 0x5E6EFF)
        case .africa: return Color(hex: 0xF0A500)
        case .asia: return Color(hex: 0xFF6B6B)
        case .oceania: return Color(hex: 0xC084FC)
        case .unknown: return Color.textSecondary
        }
    }

    var hexColor: String {
        switch self {
        case .northAmerica: return "#36CFC9"
        case .southAmerica: return "#7AD66D"
        case .europe: return "#5E6EFF"
        case .africa: return "#F0A500"
        case .asia: return "#FF6B6B"
        case .oceania: return "#C084FC"
        case .unknown: return "#8A99AE"
        }
    }

    static func from(countryCode: String) -> NetworkGeoContinent {
        let code = countryCode.uppercased()
        if ["US","CA","MX","GL","CU","DO","CR","GT","HN","JM","NI","PA","SV","BS","BB","TT"].contains(code) { return .northAmerica }
        if ["BR","AR","CL","CO","PE","UY","PY","BO","EC","VE","GY","SR"].contains(code) { return .southAmerica }
        if ["GB","IE","FR","DE","NL","BE","LU","CH","AT","IT","ES","PT","DK","SE","NO","FI","PL","CZ","SK","HU","RO","BG","GR","HR","SI","RS","BA","ME","MK","AL","EE","LV","LT","IS","UA","BY","MD"].contains(code) { return .europe }
        if ["ZA","NG","EG","MA","DZ","TN","KE","ET","GH","CI","SN","UG","TZ","CM","AO","ZW","ZM","BW","NA","LY"].contains(code) { return .africa }
        if ["CN","JP","KR","IN","SG","HK","TW","TH","VN","MY","ID","PH","AE","SA","IL","TR","PK","BD","KZ","QA"].contains(code) { return .asia }
        if ["AU","NZ","FJ","PG"].contains(code) { return .oceania }
        return .unknown
    }
}

private enum NetworkGeoGrouping: String, CaseIterable, Identifiable {
    case ip = "IPs"
    case country = "Countries"
    case organization = "Orgs"

    var id: String { rawValue }
}

private enum NetworkGeoProtocolFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case tcp = "TCP"
    case udp = "UDP"

    var id: String { rawValue }

    func matches(_ protocols: Set<ConnectionProtocol>) -> Bool {
        switch self {
        case .all:
            return true
        case .tcp:
            return protocols.contains(.tcp) || protocols.contains(.tcp6)
        case .udp:
            return protocols.contains(.udp) || protocols.contains(.udp6)
        }
    }
}

private enum NetworkGeoDirectionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case outbound = "Outbound"
    case inbound = "Inbound"
    case mixed = "Mixed"

    var id: String { rawValue }

    func matches(_ direction: NetworkGeoResolvedDirection) -> Bool {
        switch self {
        case .all: return true
        case .outbound: return direction == .outbound
        case .inbound: return direction == .inbound
        case .mixed: return direction == .mixed
        }
    }
}

private enum NetworkGeoDensity: String, CaseIterable, Identifiable {
    case focused = "Focus"
    case balanced = "Balanced"
    case wide = "Wide"

    var id: String { rawValue }

    var limit: Int {
        switch self {
        case .focused: return 10
        case .balanced: return 18
        case .wide: return 28
        }
    }
}

private enum NetworkGeoResolvedDirection: String, Hashable {
    case outbound
    case inbound
    case mixed

    var readableTitle: String {
        switch self {
        case .outbound: return "Outbound-heavy"
        case .inbound: return "Inbound-heavy"
        case .mixed: return "Mixed / unclear"
        }
    }

    var color: Color {
        switch self {
        case .outbound: return .netColor
        case .inbound: return .warning
        case .mixed: return .appAccent
        }
    }

    var colorHex: String {
        switch self {
        case .outbound: return "#36D6AE"
        case .inbound: return "#F5B14C"
        case .mixed: return "#6A7BFF"
        }
    }
}

private extension BinaryFloatingPoint {
    var svgNumber: String {
        String(format: "%.3f", Double(self))
    }
}

private extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    var jsSingleQuotedLiteral: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    var jsSingleQuoted: String {
        "'\(jsSingleQuotedLiteral)'"
    }
}

private struct NetworkGeoAPIResponse: Decodable {
    struct Connection: Decodable {
        let organization: String?
        let isp: String?

        enum CodingKeys: String, CodingKey {
            case organization = "org"
            case isp
        }
    }

    let success: Bool?
    let ip: String?
    let city: String?
    let country: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
    let connection: Connection?

    enum CodingKeys: String, CodingKey {
        case success
        case ip
        case city
        case country
        case countryCode = "country_code"
        case latitude
        case longitude
        case connection
    }
}

private extension Array where Element == String {
    func frequencySorted() -> [String] {
        Dictionary(grouping: self, by: { $0 })
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key < rhs.key
                }
                return lhs.value.count > rhs.value.count
            }
            .map(\.key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.backgroundTertiary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interfaces Tab
struct InterfacesTabView: View {
    let interfaces: [NetworkInterface]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(interfaces) { interface in
                InterfaceCard(interface: interface)
            }

            if interfaces.isEmpty {
                Text("No active interfaces found")
                    .font(.label)
                    .foregroundStyle(.textTertiary)
                    .padding(.vertical, 40)
            }
        }
    }
}

struct InterfaceCard: View {
    let interface: NetworkInterface
    @AppStorage(MacPulseSettings.Key.privacyMode)
    private var privacyMode = MacPulseSettings.Default.privacyMode

    var body: some View {
        SectionCardView(
            title: interface.displayName,
            icon: interface.isWifi ? "wifi" : "cable.connector.horizontal",
            iconColor: interface.isUp ? .netColor : .textTertiary
        ) {
            VStack(spacing: 12) {
                HStack {
                    StatusDotView(status: interface.isUp ? .good : .inactive, animated: interface.isUp)

                    Text(interface.name)
                        .font(.mono)
                        .foregroundStyle(.textSecondary)

                    Spacer()

                    Text(interface.isUp ? "Connected" : "Disconnected")
                        .font(.label)
                        .foregroundStyle(interface.isUp ? .success : .textTertiary)
                }

                if !interface.ipAddress.isEmpty {
                    HStack {
                        InfoLabel(label: "IP", value: PrivacyRedactor.ipAddress(interface.ipAddress, enabled: privacyMode))
                        Spacer()
                        InfoLabel(label: "Subnet", value: interface.subnet)
                    }

                    if !interface.macAddress.isEmpty {
                        InfoLabel(label: "MAC", value: PrivacyRedactor.macAddress(interface.macAddress, enabled: privacyMode))
                    }

                    BandwidthBarView(
                        downloadSpeed: Double(interface.bytesInPerSec),
                        uploadSpeed: Double(interface.bytesOutPerSec),
                        maxSpeed: max(Double(max(interface.bytesInPerSec, interface.bytesOutPerSec)) * 1.5, 1_000_000)
                    )

                    HStack {
                        Text("Total In: \(interface.bytesIn.formattedBytes)")
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                        Spacer()
                        Text("Total Out: \(interface.bytesOut.formattedBytes)")
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
    }
}

struct InfoLabel: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.label)
                .foregroundStyle(.textTertiary)
            Text(value)
                .font(.mono)
                .foregroundStyle(.textPrimary)
        }
    }
}

// MARK: - Devices Tab
struct DevicesTabView: View {
    let devices: [NetworkDevice]
    let localIP: String
    let gatewayIP: String

    var body: some View {
        VStack(spacing: 12) {
            // Summary
            HStack(spacing: 16) {
                SummaryBadge(count: devices.count, label: "Devices", color: .netColor)
                SummaryBadge(count: devices.filter { $0.vendor != nil }.count, label: "Identified", color: .success)

                Spacer()

                Text("Gateway: \(gatewayIP)")
                    .font(.mono)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.bottom, 8)

            ForEach(devices) { device in
                DeviceCard(device: device)
            }

            if devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 32))
                        .foregroundStyle(.textTertiary)
                    Text("Scanning for devices...")
                        .font(.label)
                        .foregroundStyle(.textTertiary)
                }
                .padding(.vertical, 40)
            }
        }
    }
}

struct SummaryBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.label)
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DeviceCard: View {
    let device: NetworkDevice
    @AppStorage(MacPulseSettings.Key.privacyMode)
    private var privacyMode = MacPulseSettings.Default.privacyMode

    var deviceIcon: String {
        if device.isRouter { return "wifi.router" }
        if device.isLocalDevice { return "desktopcomputer" }
        if let vendor = device.vendor?.lowercased() {
            if vendor.contains("apple") { return "apple.logo" }
            if vendor.contains("amazon") { return "dot.radiowaves.left.and.right" }
            if vendor.contains("google") { return "g.circle" }
            if vendor.contains("samsung") { return "tv" }
            if vendor.contains("sony") || vendor.contains("playstation") { return "gamecontroller" }
            if vendor.contains("raspberry") { return "cpu" }
            if vendor.contains("synology") || vendor.contains("qnap") { return "externaldrive.connected.to.line.below" }
            if vendor.contains("sonos") { return "hifispeaker" }
            if vendor.contains("philips") { return "lightbulb" }
        }
        return "laptopcomputer"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.system(size: 20))
                .foregroundStyle(device.isRouter ? .warning : (device.isLocalDevice ? .success : .netColor))
                .frame(width: 36, height: 36)
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(PrivacyRedactor.hostname(device.hostname, enabled: privacyMode) ?? device.vendor ?? "Unknown Device")
                        .font(.metricSmall)
                        .foregroundStyle(.textPrimary)

                    if device.isRouter {
                        Text("Router")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.warning.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if device.isLocalDevice {
                        Text("This Mac")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.success.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                HStack(spacing: 16) {
                    Text(PrivacyRedactor.ipAddress(device.ipAddress, enabled: privacyMode))
                        .font(.mono)
                        .foregroundStyle(.textSecondary)

                    if let vendor = device.vendor {
                        Text(vendor)
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }

            Spacer()

            Text(PrivacyRedactor.macAddress(device.macAddress, enabled: privacyMode))
                .font(.monoSmall)
                .foregroundStyle(.textTertiary)
        }
        .padding(12)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Connections Tab
struct ConnectionsTabView: View {
    let connections: [NetworkConnection]
    @State private var filter: ConnectionFilter = .all
    @State private var searchText = ""

    enum ConnectionFilter: String, CaseIterable {
        case all = "All"
        case established = "Established"
        case listening = "Listening"
    }

    var filteredConnections: [NetworkConnection] {
        var result = connections

        switch filter {
        case .established:
            result = result.filter { $0.state == .established }
        case .listening:
            result = result.filter { $0.state == .listen }
        case .all:
            break
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.processName?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.remoteAddress.contains(searchText) ||
                "\($0.remotePort)".contains(searchText)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            // Filters
            HStack {
                ForEach(ConnectionFilter.allCases, id: \.self) { filterOption in
                    FilterChip(
                        title: filterOption.rawValue,
                        isSelected: filter == filterOption
                    ) {
                        filter = filterOption
                    }
                }

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.textTertiary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Header
            HStack(spacing: 0) {
                Text("Process")
                    .frame(width: 120, alignment: .leading)
                Text("Local")
                    .frame(width: 160, alignment: .leading)
                Text("Remote")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("State")
                    .frame(width: 100, alignment: .center)
            }
            .font(.label)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Connections list
            LazyVStack(spacing: 2) {
                ForEach(filteredConnections) { connection in
                    ConnectionRow(connection: connection)
                }
            }

            if filteredConnections.isEmpty {
                Text("No connections found")
                    .font(.label)
                    .foregroundStyle(.textTertiary)
                    .padding(.vertical, 40)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.appAccent.opacity(0.2) : Color.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct ConnectionRow: View {
    let connection: NetworkConnection
    @AppStorage(MacPulseSettings.Key.privacyMode)
    private var privacyMode = MacPulseSettings.Default.privacyMode

    var stateColor: Color {
        switch connection.state {
        case .established: return .success
        case .listen: return .appAccent
        case .timeWait, .closeWait, .finWait1, .finWait2: return .warning
        case .closed: return .textTertiary
        default: return .textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "app.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.textTertiary)
                Text(PrivacyRedactor.processName(connection.processName, enabled: privacyMode) ?? "-")
                    .font(.mono)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)

            Text("\(PrivacyRedactor.ipAddress(connection.localAddress, enabled: privacyMode)):\(connection.localPort)")
                .font(.monoSmall)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            HStack(spacing: 4) {
                Text("\(PrivacyRedactor.ipAddress(connection.remoteAddress, enabled: privacyMode)):\(connection.remotePort)")
                    .font(.monoSmall)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                Text(connection.protocol.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.netColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.netColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(connection.state.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(stateColor)
                .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    NetworkView(deviceDiscovery: DeviceDiscoveryService())
        .frame(width: 900, height: 700)
}
