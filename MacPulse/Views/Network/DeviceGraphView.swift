import SwiftUI
import simd

struct DeviceGraphView: View {
    let devices: [NetworkDevice]
    let localIP: String
    let gatewayIP: String

    @State private var engine = ForceLayoutEngine()
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var draggedNodeId: String?
    @State private var hoveredNodeId: String?
    @State private var selectedDevice: NetworkDevice?
    @State private var physicsTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Graph canvas with animation
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)

                        // Sort nodes by depth (back to front)
                        let sortedNodes = engine.nodes.sorted {
                            engine.projectNode($0).depth < engine.projectNode($1).depth
                        }

                        // Draw edges first (behind nodes)
                        for edge in engine.edges {
                            drawEdge(context: context, edge: edge, center: center)
                        }

                        // Draw nodes back to front
                        for node in sortedNodes {
                            drawNode(context: context, node: node, center: center)
                        }
                    } symbols: {
                        // Provide SF Symbols for canvas rendering
                        ForEach(engine.nodes) { node in
                            Image(systemName: getNodeIcon(for: node.device))
                                .font(.system(size: 14 * scale))
                                .foregroundStyle(getNodeColor(for: node.device))
                                .tag(node.id)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                handleDrag(value: value, in: geometry.size)
                            }
                            .onEnded { _ in
                                handleDragEnd()
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                // Select node if we have a hovered node
                                if let nodeId = hoveredNodeId,
                                   let node = engine.nodes.first(where: { $0.id == nodeId }) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDevice = node.device
                                    }
                                    engine.setSelected(id: nodeId)
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDevice = nil
                                    }
                                    engine.setSelected(id: nil)
                                }
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, min(3.0, value))
                            }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            handleHover(at: location, in: geometry.size)
                        case .ended:
                            hoveredNodeId = nil
                            engine.setHovered(id: nil, hovered: false)
                        }
                    }
                }

                // Hover tooltip
                if let nodeId = hoveredNodeId,
                   let node = engine.nodes.first(where: { $0.id == nodeId }) {
                    NodeTooltip(device: node.device)
                        .position(
                            x: geometry.size.width / 2 + CGFloat(node.position.x) * scale + CGFloat(offset.width) + 120,
                            y: geometry.size.height / 2 + CGFloat(node.position.y) * scale + CGFloat(offset.height)
                        )
                        .allowsHitTesting(false)
                }

                // Selected device detail panel
                if let device = selectedDevice {
                    DeviceDetailPanel(device: device) {
                        selectedDevice = nil
                    }
                    .frame(width: 280)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(16)
                    .transition(.move(edge: .trailing))
                }

                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    LegendItem(color: .warning, label: "Router")
                    LegendItem(color: .success, label: "This Mac")
                    LegendItem(color: .netColor, label: "Device")
                }
                .padding(12)
                .background(Color.backgroundSecondary.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)

                // Device count & debug
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(engine.nodes.count) nodes")
                        .font(.label)
                        .foregroundStyle(.textSecondary)
                    Text("\(engine.edges.count) connections")
                        .font(.label)
                        .foregroundStyle(.netColor)
                }
                .padding(8)
                .background(Color.backgroundSecondary.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)

                // Zoom controls
                VStack(spacing: 8) {
                    Button {
                        withAnimation { scale = min(3.0, scale * 1.25) }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button {
                        withAnimation { scale = max(0.5, scale / 1.25) }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button {
                        withAnimation {
                            scale = 1.0
                            offset = .zero
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(16)
            }
        }
        .background(Color.backgroundPrimary)
        .onChange(of: devices) { _, newDevices in
            engine.updateFromDevices(newDevices, gatewayIP: gatewayIP, localIP: localIP)
        }
        .onChange(of: gatewayIP) { _, newGateway in
            // Re-process when gateway is discovered
            if !newGateway.isEmpty {
                engine.updateFromDevices(devices, gatewayIP: newGateway, localIP: localIP)
            }
        }
        .onAppear {
            engine.updateFromDevices(devices, gatewayIP: gatewayIP, localIP: localIP)
            startPhysicsTimer()
        }
        .onDisappear {
            stopPhysicsTimer()
        }
    }

    private func startPhysicsTimer() {
        physicsTimer?.invalidate()
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            if draggedNodeId == nil {
                engine.step(deltaTime: 1.0 / 60.0)
            }
            engine.updatePulseOffsets(deltaTime: 1.0 / 60.0)
        }
    }

    private func stopPhysicsTimer() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }

    @State private var lastDragPosition: CGPoint?
    @State private var isDraggingRotation = false

    private func handleDrag(value: DragGesture.Value, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let screenPos = SIMD2<Double>(
            Double(value.location.x) - Double(center.x),
            Double(value.location.y) - Double(center.y)
        )

        if draggedNodeId == nil && !isDraggingRotation {
            // Check if we're starting a drag on a node
            if let node = engine.nodeAt(screenPosition: screenPos, scale: scale, offset: offset) {
                draggedNodeId = node.id
                engine.autoRotate = false
            } else {
                // Start rotation drag
                isDraggingRotation = true
                engine.autoRotate = false
                lastDragPosition = value.location
            }
        }

        if let nodeId = draggedNodeId {
            engine.moveNode(id: nodeId, to: screenPos, scale: scale)
        } else if isDraggingRotation, let lastPos = lastDragPosition {
            let deltaX = Double(value.location.x - lastPos.x)
            let deltaY = Double(value.location.y - lastPos.y)
            engine.rotate(deltaX: deltaX, deltaY: deltaY)
            lastDragPosition = value.location
        }
    }

    private func handleDragEnd() {
        if let nodeId = draggedNodeId {
            engine.pinNode(id: nodeId, pinned: true)
        }
        draggedNodeId = nil
        isDraggingRotation = false
        lastDragPosition = nil
        // Resume auto-rotation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if draggedNodeId == nil && !isDraggingRotation {
                engine.autoRotate = true
            }
        }
    }

    private func handleHover(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let screenPos = SIMD2<Double>(
            Double(location.x) - Double(center.x),
            Double(location.y) - Double(center.y)
        )

        if let node = engine.nodeAt(screenPosition: screenPos, scale: scale, offset: offset) {
            hoveredNodeId = node.id
            engine.setHovered(id: node.id, hovered: true)
        } else {
            hoveredNodeId = nil
            engine.setHovered(id: nil, hovered: false)
        }
    }

    private func drawEdge(context: GraphicsContext, edge: GraphEdge, center: CGPoint) {
        guard let source = engine.nodes.first(where: { $0.id == edge.sourceId }),
              let target = engine.nodes.first(where: { $0.id == edge.targetId }) else { return }

        let sourceProj = engine.projectNode(source)
        let targetProj = engine.projectNode(target)

        let startX = center.x + CGFloat(sourceProj.x) * scale
        let startY = center.y + CGFloat(sourceProj.y) * scale
        let endX = center.x + CGFloat(targetProj.x) * scale
        let endY = center.y + CGFloat(targetProj.y) * scale

        let start = CGPoint(x: startX, y: startY)
        let end = CGPoint(x: endX, y: endY)

        // Line opacity based on average depth
        let avgDepth = (sourceProj.scale + targetProj.scale) / 2
        let lineOpacity = 0.4 + avgDepth * 0.4

        // Draw edge line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(.netColor.opacity(lineOpacity)),
            lineWidth: CGFloat(2.0 * avgDepth)
        )

        // Draw animated pulses going both directions
        let pulseSize: CGFloat = CGFloat(5 * avgDepth) * scale

        // Pulses going from device to router (outbound)
        for pulseIndex in 0..<2 {
            let pulseOffset = (edge.pulseOffset + Double(pulseIndex) * 0.5).truncatingRemainder(dividingBy: 1.0)
            let pulseX = startX + (endX - startX) * CGFloat(pulseOffset)
            let pulseY = startY + (endY - startY) * CGFloat(pulseOffset)

            let pulseRect = CGRect(
                x: pulseX - pulseSize / 2,
                y: pulseY - pulseSize / 2,
                width: pulseSize,
                height: pulseSize
            )

            let pulseFade = 0.6 + 0.4 * sin(pulseOffset * .pi)
            context.fill(
                Path(ellipseIn: pulseRect),
                with: .color(.netColor.opacity(pulseFade * avgDepth))
            )
        }

        // Pulses going from router to device (inbound) - offset by 0.25
        for pulseIndex in 0..<2 {
            let pulseOffset = (1.0 - (edge.pulseOffset * 1.3 + Double(pulseIndex) * 0.5).truncatingRemainder(dividingBy: 1.0))
            let pulseX = startX + (endX - startX) * CGFloat(pulseOffset)
            let pulseY = startY + (endY - startY) * CGFloat(pulseOffset)

            let pulseRect = CGRect(
                x: pulseX - pulseSize / 2,
                y: pulseY - pulseSize / 2,
                width: pulseSize,
                height: pulseSize
            )

            let pulseFade = 0.6 + 0.4 * sin(pulseOffset * .pi)
            context.fill(
                Path(ellipseIn: pulseRect),
                with: .color(.success.opacity(pulseFade * avgDepth * 0.8))
            )
        }
    }

    private func drawNode(context: GraphicsContext, node: GraphNode, center: CGPoint) {
        let proj = engine.projectNode(node)
        let x = center.x + CGFloat(proj.x) * scale
        let y = center.y + CGFloat(proj.y) * scale
        let radius = CGFloat(node.baseRadius * proj.scale) * scale

        let nodeRect = CGRect(
            x: x - radius,
            y: y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let nodeColor = getNodeColor(for: node.device)
        let depthOpacity = 0.5 + proj.scale * 0.5

        // Shadow for depth effect
        let shadowOffset = CGFloat((1.0 - proj.scale) * 10)
        let shadowRect = nodeRect.offsetBy(dx: shadowOffset, dy: shadowOffset)
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(.black.opacity(0.2 * proj.scale))
        )

        // Glow effect for hovered/selected
        if node.isHovered || node.isSelected {
            let glowRect = nodeRect.insetBy(dx: -6, dy: -6)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(nodeColor.opacity(0.4))
            )
        }

        // Node background with depth-based color
        context.fill(
            Path(ellipseIn: nodeRect),
            with: .color(Color.backgroundSecondary.opacity(depthOpacity))
        )

        // Node border
        context.stroke(
            Path(ellipseIn: nodeRect),
            with: .color(nodeColor.opacity(depthOpacity)),
            lineWidth: node.isHovered ? 3 : 2
        )

        // Draw icon from symbols
        if let resolved = context.resolveSymbol(id: node.id) {
            context.draw(resolved, at: CGPoint(x: x, y: y))
        }

        // Label below node (only if large enough)
        if radius > 15 {
            let labelY = y + radius + 10
            let displayName = node.device.hostname ?? node.device.vendor ?? shortenIP(node.device.ipAddress)

            let text = Text(displayName)
                .font(.system(size: max(9, 10 * proj.scale) * scale, weight: .medium))
                .foregroundColor(.textPrimary.opacity(depthOpacity))

            context.draw(text, at: CGPoint(x: x, y: labelY))
        }
    }

    private func getNodeColor(for device: NetworkDevice) -> Color {
        // Check both the flag and if this device is the identified router
        if device.isRouter || device.id == engine.routerNodeId || device.ipAddress == gatewayIP {
            return .warning
        }
        if device.isLocalDevice || device.ipAddress == localIP {
            return .success
        }
        return .netColor
    }

    private func getNodeIcon(for device: NetworkDevice) -> String {
        if device.isRouter { return "wifi.router" }
        if device.isLocalDevice { return "desktopcomputer" }
        if let vendor = device.vendor?.lowercased() {
            if vendor.contains("apple") { return "apple.logo" }
            if vendor.contains("amazon") { return "dot.radiowaves.left.and.right" }
            if vendor.contains("google") { return "g.circle" }
            if vendor.contains("samsung") { return "tv" }
            if vendor.contains("sonos") { return "hifispeaker" }
            if vendor.contains("philips") { return "lightbulb" }
        }
        return "laptopcomputer"
    }

    private func shortenIP(_ ip: String) -> String {
        let parts = ip.split(separator: ".")
        if parts.count == 4 {
            return ".\(parts[3])"
        }
        return ip
    }
}

struct NodeTooltip: View {
    let device: NetworkDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let hostname = device.hostname {
                Text(hostname)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.textPrimary)
            }

            HStack(spacing: 8) {
                Text("IP:")
                    .foregroundStyle(.textTertiary)
                Text(device.ipAddress)
                    .foregroundStyle(.textPrimary)
            }
            .font(.mono)

            HStack(spacing: 8) {
                Text("MAC:")
                    .foregroundStyle(.textTertiary)
                Text(device.macAddress)
                    .foregroundStyle(.textSecondary)
            }
            .font(.monoSmall)

            if let vendor = device.vendor {
                HStack(spacing: 8) {
                    Text("Vendor:")
                        .foregroundStyle(.textTertiary)
                    Text(vendor)
                        .foregroundStyle(.textSecondary)
                }
                .font(.label)
            }

            Text("Last seen: \(device.lastSeen.formatted(.relative(presentation: .named)))")
                .font(.label)
                .foregroundStyle(.textTertiary)
        }
        .padding(12)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.label)
                .foregroundStyle(.textSecondary)
        }
    }
}

struct DeviceDetailPanel: View {
    let device: NetworkDevice
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: deviceIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(deviceColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.hostname ?? device.vendor ?? "Unknown Device")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textPrimary)

                    if device.isRouter {
                        Text("Router / Gateway")
                            .font(.label)
                            .foregroundStyle(.warning)
                    } else if device.isLocalDevice {
                        Text("This Mac")
                            .font(.label)
                            .foregroundStyle(.success)
                    }
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "IP Address", value: device.ipAddress)
                DetailRow(label: "MAC Address", value: device.macAddress)

                if let vendor = device.vendor {
                    DetailRow(label: "Vendor", value: vendor)
                }

                if let hostname = device.hostname {
                    DetailRow(label: "Hostname", value: hostname)
                }

                DetailRow(label: "Last Seen", value: device.lastSeen.formatted(.relative(presentation: .named)))
            }

            Divider()

            // Actions
            VStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(device.ipAddress, forType: .string)
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy IP Address")
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(device.macAddress, forType: .string)
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy MAC Address")
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
            .foregroundStyle(.textSecondary)

            Spacer()
        }
        .padding(16)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    var deviceIcon: String {
        if device.isRouter { return "wifi.router" }
        if device.isLocalDevice { return "desktopcomputer" }
        if let vendor = device.vendor?.lowercased() {
            if vendor.contains("apple") { return "apple.logo" }
            if vendor.contains("amazon") { return "dot.radiowaves.left.and.right" }
            if vendor.contains("google") { return "g.circle" }
            if vendor.contains("samsung") { return "tv" }
            if vendor.contains("sonos") { return "hifispeaker" }
        }
        return "laptopcomputer"
    }

    var deviceColor: Color {
        if device.isRouter { return .warning }
        if device.isLocalDevice { return .success }
        return .netColor
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.label)
                .foregroundStyle(.textTertiary)
            Text(value)
                .font(.mono)
                .foregroundStyle(.textPrimary)
        }
    }
}

#Preview {
    DeviceGraphView(
        devices: [
            NetworkDevice(id: "00:11:22:33:44:55", ipAddress: "192.168.1.1", macAddress: "00:11:22:33:44:55", hostname: "Router", vendor: "Netgear", lastSeen: Date(), isRouter: true, isLocalDevice: false),
            NetworkDevice(id: "AA:BB:CC:DD:EE:FF", ipAddress: "192.168.1.100", macAddress: "AA:BB:CC:DD:EE:FF", hostname: "MacBook Pro", vendor: "Apple", lastSeen: Date(), isRouter: false, isLocalDevice: true),
            NetworkDevice(id: "11:22:33:44:55:66", ipAddress: "192.168.1.50", macAddress: "11:22:33:44:55:66", hostname: nil, vendor: "Samsung", lastSeen: Date(), isRouter: false, isLocalDevice: false)
        ],
        localIP: "192.168.1.100",
        gatewayIP: "192.168.1.1"
    )
    .frame(width: 800, height: 600)
}
