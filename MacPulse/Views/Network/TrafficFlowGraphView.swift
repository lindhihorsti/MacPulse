import SwiftUI
import simd
import Darwin

struct TrafficFlowGraphView: View {
    let devices: [NetworkDevice]
    let localIP: String
    let gatewayIP: String

    @State private var flowService = TrafficFlowService()
    @State private var selectedInterface = "en0"
    @State private var selectedNodeId: String?
    @State private var is3DMode = false

    // Persistent node storage - never removed
    @State private var knownIPs: [String] = []
    @State private var nodePositions2D: [String: CGPoint] = [:]
    @State private var nodePositions3D: [String: SIMD3<Double>] = [:]
    @State private var nodeScale2D: CGFloat = 1.0
    @State private var zoom2D: CGFloat = 1.0
    @State private var panOffset2D: CGSize = .zero
    @State private var panStartOffset2D: CGSize = .zero
    @State private var resolvedDNSNames: [String: String] = [:]
    @State private var attemptedDNSLookups: Set<String> = []

    // 3D interaction
    @State private var rotation: SIMD2<Double> = .zero
    @State private var zoom: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Interface picker
                HStack(spacing: 8) {
                    Text("Interface:")
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                    Picker("", selection: $selectedInterface) {
                        ForEach(PacketCaptureService.availableInterfaces(), id: \.self) { iface in
                            Text(iface).tag(iface)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Start/Stop
                Button {
                    if flowService.isCapturing {
                        flowService.stopCapture()
                    } else {
                        flowService.startCapture(interface: selectedInterface, localIP: localIP)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(flowService.isCapturing ? Color.danger : Color.success)
                            .frame(width: 8, height: 8)
                        Text(flowService.isCapturing ? "Stop" : "Start")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(flowService.isCapturing ? Color.danger.opacity(0.2) : Color.success.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Divider().frame(height: 24)

                // 2D/3D Toggle
                HStack(spacing: 0) {
                    Button { is3DMode = false } label: {
                        Text("2D")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(is3DMode ? .textSecondary : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(is3DMode ? Color.clear : Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button { is3DMode = true } label: {
                        Text("3D")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(is3DMode ? .white : .textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(is3DMode ? Color.appAccent : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if is3DMode {
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            rotation = .zero
                            zoom = 1.0
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(Color.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer()

                // Stats
                if flowService.isCapturing {
                    HStack(spacing: 16) {
                        Label("\(flowService.stats.activeFlows)", systemImage: "arrow.triangle.swap")
                            .foregroundStyle(.netColor)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .foregroundStyle(.green)
                            Text(formatSpeed(flowService.stats.totalBytesIn))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .foregroundStyle(.cyan)
                            Text(formatSpeed(flowService.stats.totalBytesOut))
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
            }
            .padding(12)
            .background(Color.backgroundSecondary)

            // Error
            if let error = flowService.errorMessage {
                BPFPermissionBanner(
                    errorMessage: error,
                    onDismiss: { flowService.errorMessage = nil },
                    onRetry: { flowService.startCapture(interface: selectedInterface, localIP: localIP) }
                )
            }

            // Graph View
            GeometryReader { geo in
                ZStack {
                    Color.backgroundPrimary

                    // Update known IPs
                    Color.clear
                        .onAppear { updateKnownIPs(size: geo.size) }
                        .onChange(of: flowService.allFlows.count) { _, _ in
                            updateKnownIPs(size: geo.size)
                        }

                    if is3DMode {
                        // 3D: Canvas for edges + SwiftUI nodes
                        Graph3DContent(
                            knownIPs: knownIPs,
                            nodePositions: nodePositions3D,
                            flowService: flowService,
                            devices: devices,
                            localIP: localIP,
                            gatewayIP: gatewayIP,
                            rotation: rotation,
                            zoom: zoom,
                            selectedNodeId: $selectedNodeId,
                            size: geo.size
                        )
                        .contentShape(Rectangle())
                        .clipped()

                        // 3D drag gesture
                        Color.clear
                            .contentShape(Rectangle())
                            .clipped()
                            .gesture(drag3DGesture)
                            .gesture(MagnificationGesture().onChanged { v in zoom = max(0.5, min(2.0, v)) })
                    } else {
                        ZStack {
                            // 2D: Canvas for edges
                            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                                Canvas { context, size in
                                    draw2DEdges(
                                        context: context,
                                        phase: timeline.date.timeIntervalSinceReferenceDate,
                                        size: size
                                    )
                                }
                            }

                            // 2D: SwiftUI nodes
                            ForEach(knownIPs, id: \.self) { ip in
                                if let pos = nodePositions2D[ip] {
                                    nodeView(for: ip)
                                        .scaleEffect(nodeScale2D * zoom2D)
                                        .position(transformed2DPoint(pos, in: geo.size))
                                        .onTapGesture {
                                            selectNode(ip)
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation == .zero {
                                        panStartOffset2D = panOffset2D
                                    }
                                    let rawOffset = CGSize(
                                        width: panStartOffset2D.width + value.translation.width,
                                        height: panStartOffset2D.height + value.translation.height
                                    )
                                    panOffset2D = clampedPanOffset2D(rawOffset, in: geo.size)
                                }
                                .onEnded { _ in
                                    panStartOffset2D = panOffset2D
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoom2D = min(2.5, max(0.75, value))
                                    panOffset2D = clampedPanOffset2D(panOffset2D, in: geo.size)
                                }
                        )
                    }

                    // Legend
                    VStack {
                        Spacer()
                        legendView
                            .padding(.bottom, 12)
                    }

                    // Info panel
                    if let nodeId = selectedNodeId {
                        infoPanel(for: nodeId)
                            .position(x: 130, y: 120)
                    }

                    // 3D hint
                    if is3DMode {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Drag to rotate • Scroll to zoom")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.textTertiary)
                                    .padding(8)
                                    .background(Color.backgroundSecondary.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding([.bottom, .trailing], 12)
                            }
                        }
                    } else {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            zoom2D = min(2.5, zoom2D * 1.2)
                                            panOffset2D = clampedPanOffset2D(panOffset2D, in: geo.size)
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            zoom2D = max(0.75, zoom2D / 1.2)
                                            panOffset2D = clampedPanOffset2D(panOffset2D, in: geo.size)
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            zoom2D = 1.0
                                            panOffset2D = .zero
                                        }
                                    } label: {
                                        Image(systemName: "arrow.counterclockwise")
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .foregroundStyle(.textPrimary)
                                .padding(16)
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            flowService.stopCapture()
        }
    }

    // MARK: - Update Known IPs

    private func updateKnownIPs(size: CGSize) {
        // Collect all IPs from flows and discovered devices
        var newIPs = Set<String>()
        for flow in flowService.allFlows {
            newIPs.insert(flow.sourceIP)
            newIPs.insert(flow.destinationIP)
        }
        for device in devices where !device.ipAddress.isEmpty {
            newIPs.insert(device.ipAddress)
        }

        // Add new IPs to known list (never remove)
        for ip in newIPs {
            if !knownIPs.contains(ip) {
                knownIPs.append(ip)
            }
        }

        // Ensure local and gateway are always first
        knownIPs.removeAll { $0 == localIP || $0 == gatewayIP }
        var ordered: [String] = []
        ordered.append(localIP)
        if !gatewayIP.isEmpty && gatewayIP != localIP {
            ordered.append(gatewayIP)
        }
        ordered.append(contentsOf: knownIPs)
        knownIPs = ordered

        // Position 2D nodes
        position2DNodes(size: size)

        // Position 3D nodes
        position3DNodes(size: size)
    }

    private func position2DNodes(size: CGSize) {
        let baseNodeWidth: CGFloat = 122
        let baseNodeHeight: CGFloat = 112
        let compactWidth = size.width < 900
        let compactHeight = size.height < 620
        let horizontalPadding: CGFloat = compactWidth ? 18 : 28
        let topMargin: CGFloat = compactHeight ? 58 : 72
        let pinnedRowHeight: CGFloat = compactHeight ? 92 : 106
        let gridTopSpacing: CGFloat = compactHeight ? 20 : 34
        let bottomPadding: CGFloat = compactHeight ? 64 : 92

        let otherIPs = knownIPs.filter { $0 != localIP && $0 != gatewayIP }

        let effectiveNodeWidth = compactWidth ? baseNodeWidth * 0.88 : baseNodeWidth
        let effectiveNodeHeight = compactHeight ? baseNodeHeight * 0.86 : baseNodeHeight
        let preferredColumns = max(1, Int((size.width - horizontalPadding * 2) / effectiveNodeWidth))
        let gridColumns = min(max(preferredColumns, 1), max(otherIPs.count, 1))
        let gridRows = max(1, Int(ceil(Double(max(otherIPs.count, 1)) / Double(gridColumns))))
        let availableGridWidth = max(size.width - horizontalPadding * 2, baseNodeWidth)
        let gridStartY = topMargin + pinnedRowHeight * 2 + gridTopSpacing
        let availableGridHeight = max(size.height - gridStartY - bottomPadding, baseNodeHeight)
        let gridCellWidth = availableGridWidth / CGFloat(gridColumns)
        let gridCellHeight = availableGridHeight / CGFloat(gridRows)

        let scaleCandidates = [
            gridCellWidth / effectiveNodeWidth,
            gridCellHeight / effectiveNodeHeight,
            1.0
        ]
        let scalePadding: CGFloat = compactWidth || compactHeight ? 0.82 : 0.9
        nodeScale2D = min(1.0, max(0.48, (scaleCandidates.min() ?? 1.0) * scalePadding))

        var nextPositions: [String: CGPoint] = [:]

        let centerX = size.width / 2

        if !gatewayIP.isEmpty {
            nextPositions[gatewayIP] = CGPoint(x: centerX, y: topMargin)
        }

        nextPositions[localIP] = CGPoint(x: centerX, y: topMargin + pinnedRowHeight)

        for (index, ip) in otherIPs.enumerated() {
            let row = index / gridColumns
            let column = index % gridColumns
            let rowItemCount = min(gridColumns, otherIPs.count - row * gridColumns)
            let rowWidth = CGFloat(rowItemCount) * gridCellWidth
            let rowStartX = (size.width - rowWidth) / 2
            let x = rowStartX + gridCellWidth * (CGFloat(column) + 0.5)
            let y = gridStartY + gridCellHeight * (CGFloat(row) + 0.5)
            nextPositions[ip] = CGPoint(x: x, y: y)
        }

        nodePositions2D = nextPositions
    }

    private func position3DNodes(size: CGSize) {
        let viewportBase = Double(max(320, min(size.width, size.height)))
        let sphereRadius = max(140, viewportBase * 0.26)
        let gatewayOffset = sphereRadius + 110

        nodePositions3D[localIP] = SIMD3(0, 0, 0)

        if !gatewayIP.isEmpty && gatewayIP != localIP {
            nodePositions3D[gatewayIP] = SIMD3(0, -gatewayOffset, 0)
        }

        let otherIPs = knownIPs.filter { $0 != localIP && $0 != gatewayIP }
        guard !otherIPs.isEmpty else { return }

        let goldenAngle = Double.pi * (3 - sqrt(5.0))
        let topCap: Double = 0.72
        let bottomCap: Double = -0.82

        for (idx, ip) in otherIPs.enumerated() {
            let progress = Double(idx) + 0.5
            let count = Double(otherIPs.count)
            let t = progress / count
            let y = topCap - (topCap - bottomCap) * t
            let radial = sqrt(max(0.18, 1 - y * y))
            let theta = goldenAngle * Double(idx)

            nodePositions3D[ip] = SIMD3(
                cos(theta) * sphereRadius * radial,
                y * sphereRadius,
                sin(theta) * sphereRadius * radial
            )
        }
    }

    // MARK: - 2D Drawing

    private func draw2DEdges(context: GraphicsContext, phase: Double, size: CGSize) {
        let maxTraffic = max(flowService.allFlows.map(\.bytesPerSecond).max() ?? 0, 1)

        for flow in flowService.allFlows {
            guard let srcPos = nodePositions2D[flow.sourceIP],
                  let dstPos = nodePositions2D[flow.destinationIP] else { continue }

            let transformedSrc = transformed2DPoint(srcPos, in: size)
            let transformedDst = transformed2DPoint(dstPos, in: size)

            let isActive = flow.isActive
            let isOut = flow.sourceIP == localIP
            let color: Color = isActive ? (isOut ? .cyan : .green) : .gray
            let trafficRatio = sqrt(min(flow.bytesPerSecond / maxTraffic, 1.0))
            let activeBaseWidth: CGFloat = 2.6
            let thickness: CGFloat = isActive
                ? (activeBaseWidth + CGFloat(trafficRatio) * 6.4) * max(0.9, sqrt(zoom2D))
                : 1.2

            var path = Path()
            path.move(to: transformedSrc)
            path.addLine(to: transformedDst)
            context.stroke(
                path,
                with: .color(color.opacity(isActive ? (0.6 + Double(trafficRatio) * 0.25) : 0.2)),
                lineWidth: thickness
            )

            if isActive && flow.bytesPerSecond > 50 {
                let count = max(1, min(5, Int(ceil(trafficRatio * 5))))
                for i in 0..<count {
                    let t = (phase * 0.35 + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1.0)
                    let x = transformedSrc.x + (transformedDst.x - transformedSrc.x) * t
                    let y = transformedSrc.y + (transformedDst.y - transformedSrc.y) * t
                    let r = 2.5 + thickness * 0.28
                    let particle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    context.fill(particle, with: .color(color))
                }
            }
        }
    }

    // MARK: - Node View (shared between 2D and 3D)

    @ViewBuilder
    private func nodeView(for ip: String) -> some View {
        let device = devices.first { $0.ipAddress == ip }
        let isLocal = ip == localIP
        let isGateway = ip == gatewayIP
        let isSelected = selectedNodeId == ip
        let activeFlows = flowService.activeFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let allFlows = flowService.allFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let isActive = !activeFlows.isEmpty

        let baseColor: Color = isLocal ? .success : (isGateway ? .warning : .netColor)
        let color: Color = isActive ? baseColor : .gray

        let label: String = {
            if isLocal { return "This Mac" }
            if isGateway { return "Router" }
            if let h = device?.hostname, !h.isEmpty {
                return String((h.components(separatedBy: ".").first ?? h).prefix(14))
            }
            if let v = device?.vendor { return String(v.prefix(14)) }
            return ip
        }()

        let icon: String = {
            if isLocal { return "desktopcomputer" }
            if isGateway { return "wifi.router" }
            guard let v = device?.vendor?.lowercased() else { return "laptopcomputer" }
            if v.contains("apple") { return "apple.logo" }
            if v.contains("amazon") { return "homepod" }
            if v.contains("samsung") || v.contains("lg") { return "tv" }
            if v.contains("phone") { return "iphone" }
            return "laptopcomputer"
        }()

        let currentTraffic = activeFlows.reduce(0.0) { $0 + $1.bytesPerSecond }
        let totalTraffic = allFlows.reduce(UInt64(0)) { $0 + $1.bytesTransferred }

        VStack(spacing: 4) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(baseColor.opacity(0.15))
                        .frame(width: 65, height: 65)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(color.opacity(isActive ? 0.9 : 0.35))
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(isSelected ? Color.white : color, lineWidth: isSelected ? 3 : 2)
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                .lineLimit(1)
                .frame(maxWidth: 110)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if isActive && currentTraffic > 50 {
                Text(formatBytes(currentTraffic) + "/s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(baseColor.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else if totalTraffic > 0 {
                Text(formatBytes(Double(totalTraffic)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    // MARK: - Gestures

    private func selectNode(_ ip: String) {
        if selectedNodeId == ip {
            selectedNodeId = nil
            return
        }

        selectedNodeId = ip
        lookupDNSNameIfNeeded(for: ip)
    }

    @State private var lastDragLocation: CGPoint = .zero

    private var drag3DGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if lastDragLocation != .zero {
                    let dx = value.location.x - lastDragLocation.x
                    let dy = value.location.y - lastDragLocation.y
                    rotation.y += dx * 0.01
                    rotation.x = max(-.pi/3, min(.pi/3, rotation.x + dy * 0.01))
                }
                lastDragLocation = value.location
            }
            .onEnded { _ in
                lastDragLocation = .zero
            }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Circle().fill(Color.success).frame(width: 8, height: 8)
                Text("This Mac").foregroundStyle(.textSecondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.warning).frame(width: 8, height: 8)
                Text("Router").foregroundStyle(.textSecondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.netColor).frame(width: 8, height: 8)
                Text("Device").foregroundStyle(.textSecondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.gray).frame(width: 8, height: 8)
                Text("Idle").foregroundStyle(.textSecondary)
            }
            Divider().frame(height: 12)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(Color.cyan).frame(width: 12, height: 3)
                Text("Out").foregroundStyle(.textSecondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(Color.green).frame(width: 12, height: 3)
                Text("In").foregroundStyle(.textSecondary)
            }
        }
        .font(.system(size: 10))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.backgroundSecondary.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Info Panel

    @ViewBuilder
    private func infoPanel(for ip: String) -> some View {
        let device = devices.first { $0.ipAddress == ip }
        let isLocal = ip == localIP
        let isGateway = ip == gatewayIP
        let activeFlows = flowService.activeFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let totalFlows = flowService.allFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let dnsName = resolvedDNSNames[ip] ?? device?.hostname

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isLocal ? "This Mac" : (isGateway ? "Router" : (device?.hostname ?? device?.vendor ?? ip)))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button { selectedNodeId = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.textTertiary)
            }

            Divider()

            Text(ip)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.textSecondary)

            if let mac = device?.macAddress, !mac.isEmpty {
                Text(mac)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.textTertiary)
            }

            HStack(alignment: .top, spacing: 6) {
                Text("DNS:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.textTertiary)
                Text(dnsName ?? "Not resolved")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(dnsName == nil ? .textTertiary : .textSecondary)
                    .textSelection(.enabled)
            }

            if let vendor = device?.vendor {
                Text(vendor)
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
            }

            Divider()

            let inB = activeFlows.filter { $0.destinationIP == ip }.reduce(0.0) { $0 + $1.bytesPerSecond }
            let outB = activeFlows.filter { $0.sourceIP == ip }.reduce(0.0) { $0 + $1.bytesPerSecond }

            HStack(spacing: 12) {
                Label(formatBytes(inB) + "/s", systemImage: "arrow.down")
                    .foregroundStyle(inB > 0 ? .green : .textTertiary)
                Label(formatBytes(outB) + "/s", systemImage: "arrow.up")
                    .foregroundStyle(outB > 0 ? .cyan : .textTertiary)
            }
            .font(.system(size: 11, design: .monospaced))

            let totalIn = totalFlows.filter { $0.destinationIP == ip }.reduce(UInt64(0)) { $0 + $1.bytesTransferred }
            let totalOut = totalFlows.filter { $0.sourceIP == ip }.reduce(UInt64(0)) { $0 + $1.bytesTransferred }

            if totalIn > 0 || totalOut > 0 {
                Text("Total: \(formatBytes(Double(totalIn))) ↓ / \(formatBytes(Double(totalOut))) ↑")
                    .font(.system(size: 10))
                    .foregroundStyle(.textTertiary)
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(Color.backgroundSecondary.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 5)
        .onAppear {
            lookupDNSNameIfNeeded(for: ip)
        }
    }

    // MARK: - Helpers

    private func formatSpeed(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b >= 1_000_000 { return String(format: "%.1fMB/s", b / 1_000_000) }
        if b >= 1_000 { return String(format: "%.1fKB/s", b / 1_000) }
        return String(format: "%.0fB/s", b)
    }

    private func formatBytes(_ b: Double) -> String {
        if b >= 1_000_000_000 { return String(format: "%.1fGB", b / 1_000_000_000) }
        if b >= 1_000_000 { return String(format: "%.1fMB", b / 1_000_000) }
        if b >= 1_000 { return String(format: "%.1fKB", b / 1_000) }
        return String(format: "%.0fB", b)
    }

    private func transformed2DPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let contentCenter = contentCenter2D()
        return CGPoint(
            x: contentCenter.x + (point.x - contentCenter.x) * zoom2D + panOffset2D.width,
            y: contentCenter.y + (point.y - contentCenter.y) * zoom2D + panOffset2D.height
        )
    }

    private func contentCenter2D() -> CGPoint {
        guard !nodePositions2D.isEmpty else { return .zero }
        let xs = nodePositions2D.values.map(\.x)
        let ys = nodePositions2D.values.map(\.y)
        return CGPoint(
            x: (xs.min()! + xs.max()!) / 2,
            y: (ys.min()! + ys.max()!) / 2
        )
    }

    private func clampedPanOffset2D(_ proposedOffset: CGSize, in size: CGSize) -> CGSize {
        guard !nodePositions2D.isEmpty else { return proposedOffset }

        let margin: CGFloat = 20
        let visibleMinX = margin
        let visibleMaxX = size.width - margin
        let visibleMinY = margin
        let visibleMaxY = size.height - margin

        guard let contentBounds = graphContentBounds2D(in: proposedOffset) else {
            return proposedOffset
        }

        var clamped = proposedOffset

        if contentBounds.width <= (visibleMaxX - visibleMinX) {
            clamped.width += ((visibleMinX + visibleMaxX) / 2) - contentBounds.midX
        } else {
            if contentBounds.minX > visibleMinX {
                clamped.width -= contentBounds.minX - visibleMinX
            }
            if contentBounds.maxX < visibleMaxX {
                clamped.width += visibleMaxX - contentBounds.maxX
            }
        }

        guard let adjustedBounds = graphContentBounds2D(in: clamped) else {
            return clamped
        }

        if adjustedBounds.height <= (visibleMaxY - visibleMinY) {
            clamped.height += ((visibleMinY + visibleMaxY) / 2) - adjustedBounds.midY
        } else {
            if adjustedBounds.minY > visibleMinY {
                clamped.height -= adjustedBounds.minY - visibleMinY
            }
            if adjustedBounds.maxY < visibleMaxY {
                clamped.height += visibleMaxY - adjustedBounds.maxY
            }
        }

        return clamped
    }

    private func graphContentBounds2D(in offset: CGSize) -> CGRect? {
        let contentCenter = contentCenter2D()
        let baseScale = nodeScale2D * zoom2D
        let nodeHalfWidth = max(54, 72 * baseScale)
        let nodeHalfHeight = max(52, 86 * baseScale)

        let transformedRects = nodePositions2D.values.map { point in
            let transformed = CGPoint(
                x: contentCenter.x + (point.x - contentCenter.x) * zoom2D + offset.width,
                y: contentCenter.y + (point.y - contentCenter.y) * zoom2D + offset.height
            )
            return CGRect(
                x: transformed.x - nodeHalfWidth,
                y: transformed.y - nodeHalfHeight,
                width: nodeHalfWidth * 2,
                height: nodeHalfHeight * 2
            )
        }

        guard var bounds = transformedRects.first else { return nil }
        for rect in transformedRects.dropFirst() {
            bounds = bounds.union(rect)
        }

        let edgePadding = max(14, 20 * baseScale)
        return bounds.insetBy(dx: -edgePadding, dy: -edgePadding)
    }

    private func lookupDNSNameIfNeeded(for ip: String) {
        guard !ip.isEmpty else { return }

        if let deviceHostname = devices.first(where: { $0.ipAddress == ip })?.hostname,
           !deviceHostname.isEmpty {
            resolvedDNSNames[ip] = deviceHostname
            attemptedDNSLookups.insert(ip)
            return
        }

        guard !attemptedDNSLookups.contains(ip) else { return }
        attemptedDNSLookups.insert(ip)

        DispatchQueue.global(qos: .utility).async {
            let resolvedName = Self.reverseDNSName(for: ip)
            guard let resolvedName, !resolvedName.isEmpty else { return }

            DispatchQueue.main.async {
                resolvedDNSNames[ip] = resolvedName
            }
        }
    }

    private static func reverseDNSName(for ip: String) -> String? {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)

        let conversionResult = ip.withCString { cString in
            inet_pton(AF_INET, cString, &address.sin_addr)
        }
        guard conversionResult == 1 else { return nil }
        let addressLength = socklen_t(address.sin_len)

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getnameinfo(
                    sockaddrPointer,
                    addressLength,
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NAMEREQD
                )
            }
        }

        guard result == 0 else { return nil }
        return String(cString: hostBuffer).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

// MARK: - 3D Content View

struct Graph3DContent: View {
    let knownIPs: [String]
    let nodePositions: [String: SIMD3<Double>]
    let flowService: TrafficFlowService
    let devices: [NetworkDevice]
    let localIP: String
    let gatewayIP: String
    let rotation: SIMD2<Double>
    let zoom: Double
    @Binding var selectedNodeId: String?
    let size: CGSize

    var body: some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let projected = projectNodes(center: center)

        ZStack {
            // Edges
            TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                let maxTraffic = max(flowService.allFlows.map(\.bytesPerSecond).max() ?? 0, 1)

                Canvas { context, _ in
                    let phase = timeline.date.timeIntervalSinceReferenceDate

                    for flow in flowService.allFlows {
                        guard let src = projected.first(where: { $0.ip == flow.sourceIP }),
                              let dst = projected.first(where: { $0.ip == flow.destinationIP }) else { continue }

                        let isActive = flow.isActive
                        let isOut = flow.sourceIP == localIP
                        let color: Color = isActive ? (isOut ? .cyan : .green) : .gray
                        let trafficRatio = sqrt(min(flow.bytesPerSecond / maxTraffic, 1.0))
                        let activeBaseWidth: CGFloat = 2.0
                        let thickness: CGFloat = isActive
                            ? (activeBaseWidth + CGFloat(trafficRatio) * 4.8)
                            : 1.0

                        var path = Path()
                        path.move(to: src.point)
                        path.addLine(to: dst.point)
                        context.stroke(
                            path,
                            with: .color(color.opacity(isActive ? (0.5 + Double(trafficRatio) * 0.25) : 0.15)),
                            lineWidth: thickness
                        )

                        if isActive && flow.bytesPerSecond > 50 {
                            let t = (phase * 0.3).truncatingRemainder(dividingBy: 1.0)
                            let px = src.point.x + (dst.point.x - src.point.x) * t
                            let py = src.point.y + (dst.point.y - src.point.y) * t
                            let particleRadius = 2 + CGFloat(trafficRatio) * 2.5
                            let particle = Path(
                                ellipseIn: CGRect(
                                    x: px - particleRadius,
                                    y: py - particleRadius,
                                    width: particleRadius * 2,
                                    height: particleRadius * 2
                                )
                            )
                            context.fill(particle, with: .color(color))
                        }
                    }
                }
            }

            // Nodes (sorted by depth, back to front)
            ForEach(projected.sorted(by: { $0.depth > $1.depth }), id: \.ip) { node in
                node3DView(for: node)
                    .scaleEffect(node.scale)
                    .opacity(node.opacity)
                    .position(node.point)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedNodeId == node.ip {
                            selectedNodeId = nil
                        } else {
                            selectedNodeId = node.ip
                        }
                    }
            }
        }
    }

    private func projectNodes(center: CGPoint) -> [ProjectedNode] {
        let cam: Double = 400
        let safeRect = CGRect(origin: .zero, size: size).insetBy(dx: 56, dy: 56)

        let rawNodes = knownIPs.compactMap { ip -> ProjectedNode? in
            guard let pos = nodePositions[ip] else { return nil }
            let device = devices.first { $0.ipAddress == ip }
            let isLocal = ip == localIP
            let isGateway = ip == gatewayIP
            let isSelected = selectedNodeId == ip
            let activeFlows = flowService.activeFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
            let isActive = !activeFlows.isEmpty
            let radialDistance = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            let emphasisMultiplier: Double = {
                if isLocal { return 0.0 }
                if isGateway { return 1.0 }
                if isSelected { return 1.18 }
                if isActive { return 1.12 }
                return 0.92
            }()
            let emphasizedPos: SIMD3<Double> = radialDistance > 0.001
                ? pos * emphasisMultiplier
                : pos

            // Rotate Y
            let cosY = cos(rotation.y), sinY = sin(rotation.y)
            let x1 = emphasizedPos.x * cosY - emphasizedPos.z * sinY
            let z1 = emphasizedPos.x * sinY + emphasizedPos.z * cosY

            // Rotate X
            let cosX = cos(rotation.x), sinX = sin(rotation.x)
            let y2 = emphasizedPos.y * cosX - z1 * sinX
            let z2 = emphasizedPos.y * sinX + z1 * cosX

            let depth = cam + z2
            let scale = (cam / max(depth, 150)) * zoom
            let opacity = min(1, max(0.42, (cam + z2 + 120) / 520))
            let basePriority = isSelected ? 100 : (isGateway ? 90 : (isLocal ? 80 : (isActive ? 60 : 10)))
            let fallbackLabel = {
                if isLocal { return "This Mac" }
                if isGateway { return "Router" }
                if let h = device?.hostname, !h.isEmpty {
                    return String((h.components(separatedBy: ".").first ?? h).prefix(12))
                }
                if let v = device?.vendor, !v.isEmpty {
                    return String(v.prefix(12))
                }
                return "." + (ip.components(separatedBy: ".").last ?? ip)
            }()

            return ProjectedNode(
                ip: ip,
                point: CGPoint(x: center.x + x1 * scale, y: center.y + y2 * scale),
                scale: scale,
                depth: z2,
                opacity: opacity,
                label: fallbackLabel,
                priority: basePriority,
                isSelected: isSelected,
                isActive: isActive,
                isLocal: isLocal,
                isGateway: isGateway,
                showsLabel: false
            )
        }

        guard !rawNodes.isEmpty else { return [] }

        let pointBounds = rawNodes.reduce(into: CGRect.null) { partial, node in
            let visualRadius = max(22, 36 * node.scale)
            let rect = CGRect(
                x: node.point.x - visualRadius,
                y: node.point.y - visualRadius,
                width: visualRadius * 2,
                height: visualRadius * 2
            )
            partial = partial.union(rect)
        }

        let fitScaleX = pointBounds.width > 0 ? min(1.0, safeRect.width / pointBounds.width) : 1.0
        let fitScaleY = pointBounds.height > 0 ? min(1.0, safeRect.height / pointBounds.height) : 1.0
        let fitScale = min(fitScaleX, fitScaleY)

        let fittedNodes = rawNodes.map { node -> ProjectedNode in
            guard fitScale < 0.999 else { return node }

            let dx = node.point.x - center.x
            let dy = node.point.y - center.y
            return ProjectedNode(
                ip: node.ip,
                point: CGPoint(x: center.x + dx * fitScale, y: center.y + dy * fitScale),
                scale: node.scale * fitScale,
                depth: node.depth,
                opacity: node.opacity,
                label: node.label,
                priority: node.priority,
                isSelected: node.isSelected,
                isActive: node.isActive,
                isLocal: node.isLocal,
                isGateway: node.isGateway,
                showsLabel: node.showsLabel
            )
        }

        var acceptedLabelFrames: [CGRect] = []
        var protectedNodeFrames: [CGRect] = []
        let sortedForLabels = fittedNodes.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.depth != $1.depth { return $0.depth > $1.depth }
            return $0.scale > $1.scale
        }

        var labelVisibility: [String: Bool] = [:]
        var activeLabelCount = 0
        for node in sortedForLabels {
            let mustShow = node.isSelected || node.isLocal || node.isGateway
            let canShow = mustShow || node.isActive

            guard canShow else {
                labelVisibility[node.ip] = false
                continue
            }

            if node.isActive && !mustShow && activeLabelCount >= 6 {
                labelVisibility[node.ip] = false
                continue
            }

            let width = max(58, CGFloat(node.label.count) * 6.5)
            let height: CGFloat = 20
            let frame = CGRect(
                x: node.point.x - width / 2,
                y: node.point.y + 16,
                width: width,
                height: height
            )

            let nodeFrame = CGRect(
                x: node.point.x - max(18, 20 * node.scale),
                y: node.point.y - max(18, 20 * node.scale),
                width: max(36, 40 * node.scale),
                height: max(36, 40 * node.scale)
            )
            let overlapsLabel = acceptedLabelFrames.contains { $0.intersects(frame.insetBy(dx: -10, dy: -6)) }
            let overlapsNode = protectedNodeFrames.contains { $0.intersects(frame.insetBy(dx: -8, dy: -4)) }
            let exceedsViewport = !safeRect.contains(frame)

            if mustShow || (!overlapsLabel && !overlapsNode && !exceedsViewport) {
                labelVisibility[node.ip] = true
                acceptedLabelFrames.append(frame)
                protectedNodeFrames.append(nodeFrame)
                if node.isActive && !mustShow {
                    activeLabelCount += 1
                }
            } else {
                labelVisibility[node.ip] = false
            }
        }

        return fittedNodes.map { node in
            var updated = node
            updated.showsLabel = labelVisibility[node.ip] ?? false
            return updated
        }
    }

    @ViewBuilder
    private func node3DView(for node: ProjectedNode) -> some View {
        let ip = node.ip
        let device = devices.first { $0.ipAddress == ip }
        let isLocal = node.isLocal
        let isGateway = node.isGateway
        let isSelected = node.isSelected
        let activeFlows = flowService.activeFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let allFlows = flowService.allFlows.filter { $0.sourceIP == ip || $0.destinationIP == ip }
        let isActive = node.isActive

        let baseColor: Color = isLocal ? .success : (isGateway ? .warning : .netColor)
        let color: Color = isActive ? baseColor : .gray

        let icon: String = {
            if isLocal { return "desktopcomputer" }
            if isGateway { return "wifi.router" }
            guard let v = device?.vendor?.lowercased() else { return "laptopcomputer" }
            if v.contains("apple") { return "apple.logo" }
            if v.contains("amazon") { return "homepod" }
            if v.contains("samsung") || v.contains("lg") { return "tv" }
            return "laptopcomputer"
        }()

        let currentTraffic = activeFlows.reduce(0.0) { $0 + $1.bytesPerSecond }
        let totalTraffic = allFlows.reduce(UInt64(0)) { $0 + $1.bytesTransferred }

        VStack(spacing: 4) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(baseColor.opacity(0.15))
                        .frame(width: 54, height: 54)
                        .blur(radius: 6)
                }

                Circle()
                    .fill(color.opacity(isActive ? 0.9 : 0.35))
                    .frame(width: 34, height: 34)

                Circle()
                    .stroke(isSelected ? Color.white : color, lineWidth: isSelected ? 3 : 2)
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            }

            if node.showsLabel {
                Text(node.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isActive || isSelected || isLocal || isGateway ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 92)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if (isSelected || isLocal || isGateway || isActive) && currentTraffic > 50 {
                Text(formatBytes(currentTraffic) + "/s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(baseColor.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else if isSelected && totalTraffic > 0 {
                Text(formatBytes(Double(totalTraffic)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(minWidth: 104, minHeight: 104)
    }

    private func formatBytes(_ b: Double) -> String {
        if b >= 1_000_000_000 { return String(format: "%.1fGB", b / 1_000_000_000) }
        if b >= 1_000_000 { return String(format: "%.1fMB", b / 1_000_000) }
        if b >= 1_000 { return String(format: "%.1fKB", b / 1_000) }
        return String(format: "%.0fB", b)
    }
}

struct ProjectedNode: Identifiable {
    var id: String { ip }
    let ip: String
    let point: CGPoint
    let scale: Double
    let depth: Double
    let opacity: Double
    let label: String
    let priority: Int
    let isSelected: Bool
    let isActive: Bool
    let isLocal: Bool
    let isGateway: Bool
    var showsLabel: Bool
}

#Preview {
    TrafficFlowGraphView(devices: [], localIP: "192.168.1.100", gatewayIP: "192.168.1.1")
        .frame(width: 900, height: 600)
}
