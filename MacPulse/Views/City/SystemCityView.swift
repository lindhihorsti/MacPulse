import SwiftUI
import SceneKit

struct SystemCityView: View {
    @State private var processMonitor = ProcessMonitorService()
    @State private var selectedProcess: ProcessStats?
    @State private var searchText = ""
    @State private var districtScale: CGFloat = 1.0
    @State private var cityProcessCache: [Int32: CachedCityProcess] = [:]
    @State private var showDataLines = true
    @State private var showFlowLabels = true
    @State private var showAtmosphere = true
    @State private var visualMode: CityVisualMode = .live
    @State private var cameraPreset: CityCameraPreset = .skyline

    private let cityRetentionInterval: TimeInterval = 45

    private var filteredProcesses: [ProcessStats] {
        let base = stableProcesses
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.user.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var stableProcesses: [ProcessStats] {
        cityProcessCache.values
            .sorted {
                if $0.process.name.localizedCaseInsensitiveCompare($1.process.name) != .orderedSame {
                    return $0.process.name.localizedCaseInsensitiveCompare($1.process.name) == .orderedAscending
                }
                return $0.process.id < $1.process.id
            }
            .map(\.process)
    }

    private var districts: [CityDistrictSnapshot] {
        ProcessCityDistrict.allCases.compactMap { district in
            let matches = filteredProcesses.filter { district.matches($0) }
            guard !matches.isEmpty else { return nil }
            return CityDistrictSnapshot(
                district: district,
                processes: matches.sorted {
                    if $0.name.localizedCaseInsensitiveCompare($1.name) != .orderedSame {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.id < $1.id
                }
            )
        }
    }

    private var totalCPU: Double {
        filteredProcesses.reduce(0) { $0 + $1.cpuUsage }
    }

    private var totalMemory: UInt64 {
        filteredProcesses.reduce(0) { $0 + $1.memoryUsage }
    }

    private var runningCount: Int {
        filteredProcesses.filter { $0.status == .running }.count
    }

    private var activeAlarms: Int {
        filteredProcesses.filter { $0.cpuUsage >= 25 || $0.memoryUsageGB >= 1.5 }.count
    }

    private var currentSelectedProcess: ProcessStats? {
        guard let selectedProcess else { return nil }
        return processMonitor.processes.first(where: { $0.id == selectedProcess.id }) ?? selectedProcess
    }

    private var currentPreset: CityPreset {
        if showDataLines && showFlowLabels && showAtmosphere { return .analysis }
        if !showDataLines && !showFlowLabels && !showAtmosphere { return .clean }
        if showDataLines && !showFlowLabels && showAtmosphere { return .cinematic }
        return .custom
    }

    var body: some View {
        VStack(spacing: 0) {
            cityToolbar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    cityOverview
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if let process = currentSelectedProcess {
                        CitySelectionPanel(
                            process: process,
                            summary: processMonitor.summary(for: process),
                            district: ProcessCityDistrict.forProcess(process),
                            cpuHistory: processMonitor.cpuHistory(for: process.id),
                            memoryHistory: processMonitor.memoryHistory(for: process.id)
                        )
                        .padding(.horizontal, 16)
                    }

                    cityLegend
                        .padding(.horizontal, 16)

                    SystemCitySceneView(
                        districts: districts,
                        selectedProcessID: currentSelectedProcess?.id,
                        districtScale: districtScale,
                        showDataLines: showDataLines,
                        showFlowLabels: showFlowLabels,
                        showAtmosphere: showAtmosphere,
                        visualMode: visualMode,
                        cameraPreset: cameraPreset
                    ) { pid in
                        guard let pid else {
                            selectedProcess = nil
                            return
                        }
                        selectedProcess = processMonitor.processes.first(where: { $0.id == pid })
                    }
                    .frame(maxWidth: .infinity, minHeight: 720, maxHeight: 720)
                    .background(Color.black.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            processMonitor.start()
            refreshCityCache(with: processMonitor.processes)
        }
        .onChange(of: processMonitor.processes) { _, _ in
            refreshCityCache(with: processMonitor.processes)
            if let selectedProcess {
                self.selectedProcess = stableProcesses.first(where: { $0.id == selectedProcess.id }) ?? selectedProcess
            }
        }
        .onDisappear {
            processMonitor.stop()
        }
    }

    private var cityToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Label("System as a City", systemImage: "building.2.crop.circle")
                    .font(.system(size: 15, weight: .semibold))

                Divider()
                    .frame(height: 20)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.textSecondary)
                    TextField("Search buildings, users or bundle IDs...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                HStack(spacing: 8) {
                    Label("\(runningCount) active", systemImage: "bolt.fill")
                        .foregroundStyle(.cpuColor)
                    Label("\(activeAlarms) hotspots", systemImage: "flame.fill")
                        .foregroundStyle(.warning)
                }
                .font(.system(size: 11, weight: .medium))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    cityControlGroup("Presets") {
                        HStack(spacing: 6) {
                            ForEach(CityPreset.allCases) { preset in
                                presetButton(preset)
                            }
                        }
                    }

                    cityControlGroup("Layers") {
                        HStack(spacing: 6) {
                            cityToggle("Data", systemImage: "point.3.connected", isOn: $showDataLines)
                            cityToggle("Labels", systemImage: "text.line.first.and.arrowtriangle.forward", isOn: $showFlowLabels)
                            cityToggle("Atmos", systemImage: "sparkles", isOn: $showAtmosphere)
                        }
                    }

                    cityControlGroup("Mode") {
                        HStack(spacing: 6) {
                            ForEach(CityVisualMode.allCases) { mode in
                                visualModeButton(mode)
                            }
                        }
                    }

                    cityControlGroup("Camera") {
                        HStack(spacing: 6) {
                            ForEach(CityCameraPreset.allCases) { preset in
                                cameraPresetButton(preset)
                            }
                        }
                    }

                    cityControlGroup("Density") {
                        HStack(spacing: 10) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.textSecondary)
                            Slider(value: $districtScale, in: 0.85...1.25)
                                .frame(width: 140)
                                .tint(.appAccent)
                            Text(String(format: "%.2fx", districtScale))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(12)
        .background(Color.backgroundSecondary)
    }

    private func cityControlGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.textTertiary)
                .padding(.leading, 2)
            content()
        }
    }

    private func cityToggle(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isOn.wrappedValue ? Color.white : Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isOn.wrappedValue ? Color.appAccent.opacity(0.8) : Color.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func presetButton(_ preset: CityPreset) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            Text(preset.rawValue)
                .lineLimit(1)
                .fixedSize()
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(currentPreset == preset ? Color.white : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(currentPreset == preset ? Color.netColor.opacity(0.82) : Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func visualModeButton(_ mode: CityVisualMode) -> some View {
        Button {
            visualMode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.rawValue)
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(visualMode == mode ? Color.white : Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(visualMode == mode ? mode.accentColor.opacity(0.84) : Color.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func cameraPresetButton(_ preset: CityCameraPreset) -> some View {
        Button {
            cameraPreset = preset
        } label: {
            Image(systemName: preset.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(cameraPreset == preset ? Color.white : Color.textSecondary)
                .frame(width: 32, height: 30)
                .background(cameraPreset == preset ? Color.appAccent.opacity(0.84) : Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .help(preset.rawValue)
        }
        .buttonStyle(.plain)
    }

    private var cityLegend: some View {
        HStack(alignment: .center, spacing: 18) {
            legendChip("System Core", color: ProcessCityDistrict.systemCore.color)
            legendChip("App Downtown", color: ProcessCityDistrict.userApps.color)
            legendChip("Network Harbor", color: ProcessCityDistrict.networkSync.color)
            legendChip("Builder Quarter", color: ProcessCityDistrict.developerTools.color)
            legendChip("Service Belt", color: ProcessCityDistrict.backgroundAgents.color)
            legendChip("Hotspot", color: .warning)

            Divider()
                .frame(height: 18)

            Label("Data line = district flow", systemImage: "point.3.connected")
                .font(.system(size: 11))
                .foregroundStyle(.textSecondary)
            Label("Beacon = high CPU/RAM", systemImage: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11))
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
        )
    }

    private func legendChip(_ title: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.textSecondary)
        }
    }

    private func applyPreset(_ preset: CityPreset) {
        switch preset {
        case .clean:
            showDataLines = false
            showFlowLabels = false
            showAtmosphere = false
        case .analysis:
            showDataLines = true
            showFlowLabels = true
            showAtmosphere = true
        case .cinematic:
            showDataLines = true
            showFlowLabels = false
            showAtmosphere = true
        case .custom:
            break
        }
    }

    private var cityOverview: some View {
        HStack(alignment: .top, spacing: 14) {
            CityMetricCard(
                title: "Population",
                value: "\(filteredProcesses.count)",
                detail: "\(districts.count) districts",
                color: .appAccent
            )
            CityMetricCard(
                title: "Energy Demand",
                value: String(format: "%.0f%%", totalCPU),
                detail: "\(runningCount) buildings lit",
                color: .cpuColor
            )
            CityMetricCard(
                title: "Footprint",
                value: totalMemory.formattedBytesCompact,
                detail: "RAM used by visible city",
                color: .ramColor
            )
            CityMetricCard(
                title: "Most Intense Block",
                value: districts.max(by: { $0.totalCPU < $1.totalCPU })?.district.title ?? "None",
                detail: "Highest district load",
                color: .netColor
            )
        }
    }

    private func refreshCityCache(with processes: [ProcessStats]) {
        let now = Date()

        for process in processes {
            cityProcessCache[process.id] = CachedCityProcess(process: process, lastSeen: now)
        }

        cityProcessCache = cityProcessCache.filter { _, cached in
            now.timeIntervalSince(cached.lastSeen) <= cityRetentionInterval
        }
    }
}

private struct CachedCityProcess {
    let process: ProcessStats
    let lastSeen: Date
}

private enum CityPreset: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case analysis = "Analysis"
    case cinematic = "Cinematic"
    case custom = "Custom"

    var id: String { rawValue }
}

private struct CityMetricCard: View {
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
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private final class CitySceneView: SCNView {
    weak var interactionCoordinator: SystemCitySceneView.Coordinator?

    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            interactionCoordinator?.handleTrackpadPan(deltaX: Float(event.scrollingDeltaX), deltaY: Float(event.scrollingDeltaY))
        } else {
            super.scrollWheel(with: event)
        }
    }
}

private struct SystemCitySceneView: NSViewRepresentable {
    private static let citySurfaceY: Float = 0
    private static let districtBaseHeight: Float = 2.8
    private static let roadHeight: Float = 0.4
    private static let buildingClearance: Float = 1.2
    private static let buildingInteractionMask = 1 << 4

    let districts: [CityDistrictSnapshot]
    let selectedProcessID: Int32?
    let districtScale: CGFloat
    let showDataLines: Bool
    let showFlowLabels: Bool
    let showAtmosphere: Bool
    let visualMode: CityVisualMode
    let cameraPreset: CityCameraPreset
    let onSelect: (Int32?) -> Void

    private struct DistrictFootprint {
        let columns: Int
        let rows: Int
        let spacing: Float
        let width: Float
        let depth: Float
        let roadWidth: Float
        let roadDepth: Float
    }

    private struct CityLayout {
        let positions: [ProcessCityDistrict: SIMD2<Float>]
        let footprints: [ProcessCityDistrict: DistrictFootprint]
        let floorWidth: Float
        let floorDepth: Float
    }

    private struct DistrictFlow {
        let from: ProcessCityDistrict
        let to: ProcessCityDistrict
        let strength: Float
        let color: NSColor
        let label: String
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> SCNView {
        let view = CitySceneView()
        view.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.16, alpha: 1.0)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.rendersContinuously = true
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.autoresizingMask = [.width, .height]
        let scene = buildScene(preservedPointOfView: nil)
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "cityCamera", recursively: true)
        configureCameraController(for: view)

        let panRecognizer = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panRecognizer.buttonMask = 0x2
        view.addGestureRecognizer(panRecognizer)

        let clickRecognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(clickRecognizer)
        context.coordinator.view = view
        view.interactionCoordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        let preserved = nsView.pointOfView
        let scene = buildScene(preservedPointOfView: preserved)
        nsView.scene = scene
        nsView.pointOfView = scene.rootNode.childNode(withName: "cityCamera", recursively: true)
        configureCameraController(for: nsView)
    }

    private func configureCameraController(for view: SCNView) {
        let controller = view.defaultCameraController
        controller.interactionMode = .orbitTurntable
        controller.inertiaEnabled = true
        controller.automaticTarget = false
        controller.worldUp = SCNVector3(0, 1, 0)
        controller.target = SCNVector3(0, Self.citySurfaceY + Self.districtBaseHeight + 18, 0)
        controller.minimumVerticalAngle = 8
        controller.maximumVerticalAngle = 82
    }

    private func buildScene(preservedPointOfView: SCNNode?) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.15, alpha: 1.0)
        let cityLayout = makeCityLayout()

        let cameraNode = SCNNode()
        cameraNode.name = "cityCamera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = cameraFieldOfView
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 2000
        let cameraPose = makeCameraPose(for: cityLayout)
        cameraNode.position = cameraPose.position
        cameraNode.eulerAngles = cameraPose.eulerAngles
        scene.rootNode.addChildNode(cameraNode)

        if let preservedPointOfView {
            cameraNode.transform = preservedPointOfView.transform
        }

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = ambientLightColor
        scene.rootNode.addChildNode(ambientLight)

        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .omni
        sunLight.light?.intensity = keyLightIntensity
        sunLight.position = SCNVector3(40, 260, 150)
        scene.rootNode.addChildNode(sunLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .omni
        fillLight.light?.intensity = 1200
        fillLight.position = SCNVector3(-180, 120, -120)
        scene.rootNode.addChildNode(fillLight)

        let floor = SCNBox(width: CGFloat(cityLayout.floorWidth), height: 24, length: CGFloat(cityLayout.floorDepth), chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.20, alpha: 1.0)
        floorMaterial.emission.contents = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.06, alpha: 1.0)
        floorMaterial.roughness.contents = 0.96
        floorMaterial.transparency = 1.0
        floorMaterial.writesToDepthBuffer = true
        floorMaterial.readsFromDepthBuffer = true
        floorMaterial.isDoubleSided = false
        floor.materials = Array(repeating: floorMaterial, count: 6)
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, Self.citySurfaceY - 12, 0)
        scene.rootNode.addChildNode(floorNode)

        addReferenceMonolith(in: scene)
        addGroundGrid(in: scene, width: cityLayout.floorWidth, depth: cityLayout.floorDepth)
        addCityArteries(layout: cityLayout, in: scene)

        for snapshot in districts {
            let center = cityLayout.positions[snapshot.district] ?? SIMD2<Float>(0, 0)
            let footprint = cityLayout.footprints[snapshot.district] ?? footprint(for: snapshot)
            addDistrictBase(for: snapshot, footprint: footprint, at: center, in: scene)
            addBuildings(for: snapshot, footprint: footprint, center: center, in: scene)
            addDistrictLabel(for: snapshot, footprint: footprint, at: center, in: scene)
            if snapshot.district == .networkSync {
                addNetworkHarbor(for: snapshot, footprint: footprint, at: center, in: scene)
            }
        }

        if showDataLines {
            addDataLines(flows: makeDistrictFlows(), layout: cityLayout, in: scene)
        }

        if showAtmosphere {
            addStreetTraffic(layout: cityLayout, in: scene)
        }

        return scene
    }

    private var cameraFieldOfView: CGFloat {
        switch cameraPreset {
        case .skyline: return 45
        case .orbit: return 50
        case .street: return 58
        }
    }

    private var ambientLightColor: NSColor {
        switch visualMode {
        case .live: return NSColor(calibratedWhite: 0.62, alpha: 1.0)
        case .thermal: return NSColor(calibratedRed: 0.72, green: 0.50, blue: 0.38, alpha: 1.0)
        case .memory: return NSColor(calibratedRed: 0.48, green: 0.58, blue: 0.80, alpha: 1.0)
        case .network: return NSColor(calibratedRed: 0.38, green: 0.70, blue: 0.68, alpha: 1.0)
        case .risk: return NSColor(calibratedRed: 0.68, green: 0.42, blue: 0.42, alpha: 1.0)
        }
    }

    private var keyLightIntensity: CGFloat {
        switch visualMode {
        case .live: return 2600
        case .thermal: return 3100
        case .memory: return 2750
        case .network: return 2900
        case .risk: return 3300
        }
    }

    private func makeCameraPose(for layout: CityLayout) -> (position: SCNVector3, eulerAngles: SCNVector3) {
        switch cameraPreset {
        case .skyline:
            return (SCNVector3(-80, 150, 250), SCNVector3(-0.50, -0.18, 0))
        case .orbit:
            return (SCNVector3(0, 188, 270), SCNVector3(-0.56, 0, 0))
        case .street:
            return (SCNVector3(-layout.floorWidth * 0.34, 38, layout.floorDepth * 0.42), SCNVector3(-0.18, -0.55, 0))
        }
    }

    private func addReferenceMonolith(in scene: SCNScene) {
        let geometry = SCNBox(width: 18, height: 52, length: 18, chamferRadius: 1.8)
        geometry.firstMaterial?.diffuse.contents = NSColor.white
        geometry.firstMaterial?.emission.contents = NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.95, alpha: 1.0)
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, 26, 0)
        scene.rootNode.addChildNode(node)
    }

    private func addGroundGrid(in scene: SCNScene, width: Float, depth: Float) {
        let lineColor = NSColor.white.withAlphaComponent(0.09)
        let halfWidth = Int(ceil(width / 2))
        let halfDepth = Int(ceil(depth / 2))
        for offset in stride(from: -halfDepth, through: halfDepth, by: 20) {
            let horizontal = SCNBox(width: CGFloat(width), height: 0.06, length: 0.5, chamferRadius: 0)
            horizontal.firstMaterial?.diffuse.contents = lineColor
            let horizontalNode = SCNNode(geometry: horizontal)
            horizontalNode.position = SCNVector3(0, 0.05, Float(offset))
            scene.rootNode.addChildNode(horizontalNode)
        }

        for offset in stride(from: -halfWidth, through: halfWidth, by: 20) {
            let vertical = SCNBox(width: 0.5, height: 0.06, length: CGFloat(depth), chamferRadius: 0)
            vertical.firstMaterial?.diffuse.contents = lineColor
            let verticalNode = SCNNode(geometry: vertical)
            verticalNode.position = SCNVector3(Float(offset), 0.05, 0)
            scene.rootNode.addChildNode(verticalNode)
        }
    }

    private func addCityArteries(layout: CityLayout, in scene: SCNScene) {
        let roadY = Self.citySurfaceY + Self.districtBaseHeight + 0.08
        let roadMaterial = SCNMaterial()
        roadMaterial.diffuse.contents = cityRoadColor
        roadMaterial.emission.contents = cityRoadEmission
        roadMaterial.roughness.contents = 0.9

        let orderedDistricts: [ProcessCityDistrict] = [.systemCore, .userApps, .networkSync, .developerTools, .backgroundAgents, .other]
        let centers = orderedDistricts.compactMap { district -> SIMD2<Float>? in
            layout.positions[district]
        }
        guard centers.count > 1 else { return }

        let rows = [Array(centers.prefix(3)), Array(centers.suffix(3))]
        for row in rows where row.count > 1 {
            let start = row[0]
            let end = row[row.count - 1]
            let road = SCNBox(width: CGFloat(abs(end.x - start.x) + 48), height: 0.34, length: 7.2, chamferRadius: 1.6)
            road.materials = [roadMaterial]
            let node = SCNNode(geometry: road)
            node.position = SCNVector3((start.x + end.x) / 2, roadY, start.y)
            scene.rootNode.addChildNode(node)

            addLaneMarkers(from: SIMD2(start.x - 24, start.y), to: SIMD2(end.x + 24, end.y), in: scene)
        }

        for column in 0..<3 where centers.count >= 6 {
            let start = centers[column]
            let end = centers[column + 3]
            let road = SCNBox(width: 7.2, height: 0.34, length: CGFloat(abs(end.y - start.y) + 42), chamferRadius: 1.6)
            road.materials = [roadMaterial]
            let node = SCNNode(geometry: road)
            node.position = SCNVector3(start.x, roadY, (start.y + end.y) / 2)
            scene.rootNode.addChildNode(node)

            addLaneMarkers(from: SIMD2(start.x, start.y - 20), to: SIMD2(end.x, end.y + 20), in: scene)
        }

        let plaza = SCNCylinder(radius: 13, height: 0.42)
        plaza.radialSegmentCount = 48
        plaza.firstMaterial?.diffuse.contents = cityRoadColor.blended(withFraction: 0.18, of: .white) ?? cityRoadColor
        plaza.firstMaterial?.emission.contents = cityRoadEmission
        let plazaNode = SCNNode(geometry: plaza)
        plazaNode.position = SCNVector3(0, roadY + 0.04, 0)
        scene.rootNode.addChildNode(plazaNode)
    }

    private var cityRoadColor: NSColor {
        switch visualMode {
        case .thermal: return NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.10, alpha: 1.0)
        case .memory: return NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.22, alpha: 1.0)
        case .network: return NSColor(calibratedRed: 0.07, green: 0.18, blue: 0.17, alpha: 1.0)
        case .risk: return NSColor(calibratedRed: 0.19, green: 0.09, blue: 0.10, alpha: 1.0)
        case .live: return NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.15, alpha: 1.0)
        }
    }

    private var cityRoadEmission: NSColor {
        switch visualMode {
        case .thermal: return NSColor(calibratedRed: 0.44, green: 0.15, blue: 0.06, alpha: 0.08)
        case .memory: return NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.85, alpha: 0.07)
        case .network: return NSColor(calibratedRed: 0.10, green: 0.70, blue: 0.62, alpha: 0.10)
        case .risk: return NSColor(calibratedRed: 0.85, green: 0.12, blue: 0.16, alpha: 0.09)
        case .live: return NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.58, alpha: 0.05)
        }
    }

    private func addLaneMarkers(from start: SIMD2<Float>, to end: SIMD2<Float>, in scene: SCNScene) {
        let delta = end - start
        let distance = simd_length(delta)
        guard distance > 8 else { return }

        let direction = simd_normalize(delta)
        let markerCount = min(max(Int(distance / 14), 3), 24)
        let markerColor = NSColor.white.withAlphaComponent(visualMode == .network ? 0.22 : 0.13)

        for index in 0..<markerCount {
            let t = Float(index + 1) / Float(markerCount + 1)
            let position = start + delta * t
            let marker = SCNBox(width: 4.2, height: 0.08, length: 0.42, chamferRadius: 0.04)
            marker.firstMaterial?.diffuse.contents = markerColor
            marker.firstMaterial?.emission.contents = markerColor
            let markerNode = SCNNode(geometry: marker)
            markerNode.position = SCNVector3(position.x, Self.citySurfaceY + Self.districtBaseHeight + 0.34, position.y)
            markerNode.eulerAngles.y = CGFloat(atan2(direction.x, direction.y))
            scene.rootNode.addChildNode(markerNode)
        }
    }

    private func addNetworkHarbor(for snapshot: CityDistrictSnapshot, footprint: DistrictFootprint, at center: SIMD2<Float>, in scene: SCNScene) {
        let water = SCNBox(width: CGFloat(footprint.width * 0.88), height: 0.18, length: CGFloat(max(footprint.depth * 0.24, 18)), chamferRadius: 2.4)
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = NSColor(calibratedRed: 0.02, green: 0.26, blue: 0.30, alpha: 0.86)
        waterMaterial.emission.contents = NSColor(calibratedRed: 0.02, green: 0.62, blue: 0.68, alpha: visualMode == .network ? 0.22 : 0.09)
        waterMaterial.metalness.contents = 0.18
        waterMaterial.roughness.contents = 0.18
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        waterNode.position = SCNVector3(center.x, Self.citySurfaceY + Self.districtBaseHeight + 0.48, center.y + footprint.depth * 0.39)
        scene.rootNode.addChildNode(waterNode)

        let pierMaterial = SCNMaterial()
        pierMaterial.diffuse.contents = snapshot.district.sceneColor.blended(withFraction: 0.62, of: .black) ?? snapshot.district.sceneColor
        pierMaterial.emission.contents = snapshot.district.sceneColor.withAlphaComponent(0.08)

        for offset in [-0.28, 0.0, 0.28] {
            let pier = SCNBox(width: 4.0, height: 0.7, length: CGFloat(footprint.depth * 0.28), chamferRadius: 0.4)
            pier.materials = [pierMaterial]
            let node = SCNNode(geometry: pier)
            node.position = SCNVector3(center.x + footprint.width * Float(offset), Self.citySurfaceY + Self.districtBaseHeight + 0.9, center.y + footprint.depth * 0.31)
            scene.rootNode.addChildNode(node)
        }
    }

    private func addStreetTraffic(layout: CityLayout, in scene: SCNScene) {
        let route: [ProcessCityDistrict] = [.systemCore, .userApps, .networkSync, .other, .backgroundAgents, .developerTools, .systemCore]
        let points = route.compactMap { layout.positions[$0] }
        guard points.count > 2 else { return }

        let color: NSColor
        switch visualMode {
        case .thermal: color = NSColor(calibratedRed: 1.0, green: 0.46, blue: 0.18, alpha: 1.0)
        case .memory: color = NSColor(calibratedRed: 0.50, green: 0.74, blue: 1.0, alpha: 1.0)
        case .network: color = NSColor(calibratedRed: 0.40, green: 1.0, blue: 0.88, alpha: 1.0)
        case .risk: color = NSColor(calibratedRed: 1.0, green: 0.26, blue: 0.28, alpha: 1.0)
        case .live: color = NSColor(calibratedRed: 0.68, green: 0.88, blue: 1.0, alpha: 1.0)
        }

        let vehicleCount = visualMode == .network ? 14 : 9
        for index in 0..<vehicleCount {
            let vehicle = SCNSphere(radius: 0.72)
            vehicle.firstMaterial?.diffuse.contents = NSColor.white
            vehicle.firstMaterial?.emission.contents = color
            let node = SCNNode(geometry: vehicle)
            node.position = SCNVector3(points[0].x, Self.citySurfaceY + Self.districtBaseHeight + 1.6, points[0].y)
            scene.rootNode.addChildNode(node)

            var actions: [SCNAction] = [.wait(duration: Double(index) * 0.22)]
            for point in points.dropFirst() {
                actions.append(.move(to: SCNVector3(point.x, Self.citySurfaceY + Self.districtBaseHeight + 1.6, point.y), duration: visualMode == .network ? 1.25 : 1.85))
            }
            actions.append(.run { node in
                node.position = SCNVector3(points[0].x, Self.citySurfaceY + Self.districtBaseHeight + 1.6, points[0].y)
            })
            node.runAction(.repeatForever(.sequence(actions)))
        }
    }

    private func addDistrictBase(for snapshot: CityDistrictSnapshot, footprint: DistrictFootprint, at center: SIMD2<Float>, in scene: SCNScene) {
        let base = SCNBox(width: CGFloat(footprint.width), height: CGFloat(Self.districtBaseHeight), length: CGFloat(footprint.depth), chamferRadius: 5)
        let color = snapshot.district.sceneColor
        let lighting = snapshot.district.lightingProfile
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = color.blended(withFraction: 0.78, of: .black) ?? color
        baseMaterial.emission.contents = lighting.baseGlow
        baseMaterial.roughness.contents = 0.92
        baseMaterial.transparency = 1.0
        baseMaterial.writesToDepthBuffer = true
        baseMaterial.readsFromDepthBuffer = true
        baseMaterial.isDoubleSided = false
        base.materials = [baseMaterial]

        let node = SCNNode(geometry: base)
        let districtCenterY = Self.citySurfaceY + Self.districtBaseHeight / 2
        node.position = SCNVector3(center.x, districtCenterY, center.y)
        scene.rootNode.addChildNode(node)

        let plaza = SCNBox(width: CGFloat(max(footprint.width - 10, 28)), height: 0.5, length: CGFloat(max(footprint.depth - 10, 28)), chamferRadius: 3)
        plaza.firstMaterial?.diffuse.contents = lighting.plazaColor
        plaza.firstMaterial?.emission.contents = lighting.plazaEmission
        plaza.firstMaterial?.roughness.contents = 0.94
        let plazaNode = SCNNode(geometry: plaza)
        plazaNode.position = SCNVector3(center.x, Self.citySurfaceY + Self.districtBaseHeight + 0.25, center.y)
        scene.rootNode.addChildNode(plazaNode)
        if showAtmosphere {
            addDistrictAtmosphere(for: snapshot, footprint: footprint, at: center, in: scene)
        }

        let road = SCNBox(width: CGFloat(footprint.roadWidth), height: CGFloat(Self.roadHeight), length: 10, chamferRadius: 1)
        road.firstMaterial?.diffuse.contents = lighting.roadColor
        road.firstMaterial?.emission.contents = lighting.roadEmission
        let horizontalRoad = SCNNode(geometry: road)
        let roadCenterY = Self.citySurfaceY + Self.districtBaseHeight + Self.roadHeight / 2
        horizontalRoad.position = SCNVector3(center.x, roadCenterY, center.y)
        scene.rootNode.addChildNode(horizontalRoad)

        let verticalRoad = SCNNode(geometry: road)
        verticalRoad.geometry = SCNBox(width: 10, height: CGFloat(Self.roadHeight), length: CGFloat(footprint.roadDepth), chamferRadius: 1)
        verticalRoad.geometry?.firstMaterial?.diffuse.contents = lighting.roadColor
        verticalRoad.geometry?.firstMaterial?.emission.contents = lighting.roadEmission
        verticalRoad.position = SCNVector3(center.x, roadCenterY, center.y)
        scene.rootNode.addChildNode(verticalRoad)
    }

    private func addDistrictLabel(for snapshot: CityDistrictSnapshot, footprint: DistrictFootprint, at center: SIMD2<Float>, in scene: SCNScene) {
        let text = SCNText(string: snapshot.district.title, extrusionDepth: 0.5)
        text.font = NSFont.systemFont(ofSize: 5.5, weight: .semibold)
        text.flatness = 0.3
        text.firstMaterial?.diffuse.contents = snapshot.district.sceneColor
        text.firstMaterial?.emission.contents = snapshot.district.sceneColor.withAlphaComponent(0.2)

        let node = SCNNode(geometry: text)
        let (minBound, maxBound) = text.boundingBox
        let width = Float(maxBound.x - minBound.x)
        node.scale = SCNVector3(0.9, 0.9, 0.9)
        node.position = SCNVector3(center.x - width * 0.45, 4.5, center.y - (footprint.depth / 2 + 16))
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(node)
    }

    private func addBuildings(for snapshot: CityDistrictSnapshot, footprint: DistrictFootprint, center: SIMD2<Float>, in scene: SCNScene) {
        let visibleProcesses = Array(snapshot.processes.prefix(24))
        let columns = footprint.columns
        let spacing = footprint.spacing
        let startX = center.x - Float(columns - 1) * spacing / 2
        let startZ = center.y - Float(footprint.rows - 1) * spacing / 2
        let buildingBaseY = Self.citySurfaceY + Self.districtBaseHeight + Self.roadHeight

        for (index, process) in visibleProcesses.enumerated() {
            let row = index / columns
            let column = index % columns

            let cpuRatio = Float(min(max(process.cpuUsage / 90, 0.06), 1.0))
            let memoryRatio = Float(min(max(process.memoryUsageGB / 4.0, 0.12), 1.0))
            let width = 7 + memoryRatio * 9
            let length = 7 + memoryRatio * 11
            let height = 8 + cpuRatio * 70
            let node = makeBuildingNode(
                processID: process.id,
                district: snapshot.district,
                districtColor: snapshot.district.sceneColor,
                width: width,
                length: length,
                height: height,
                styleSeed: index,
                isActive: process.status == .running,
                hotspotLevel: max(cpuRatio, memoryRatio),
                cpuRatio: cpuRatio,
                memoryRatio: memoryRatio
            )
            node.position = SCNVector3(
                startX + Float(column) * spacing,
                buildingBaseY + Self.buildingClearance,
                startZ + Float(row) * spacing
            )
            scene.rootNode.addChildNode(node)

            if max(cpuRatio, memoryRatio) >= 0.62 {
                let emphasis = min(max(cpuRatio, memoryRatio), 1.0)
                let pulse = SCNAction.sequence([
                    .scale(to: CGFloat(1.0 + emphasis * 0.045), duration: 0.7),
                    .scale(to: 1.0, duration: 0.9)
                ])
                node.runAction(.repeatForever(pulse))
            }

            if selectedProcessID == process.id {
                let ring = SCNTorus(ringRadius: CGFloat(max(width, length) * 0.78), pipeRadius: 0.55)
                ring.firstMaterial?.diffuse.contents = NSColor.white
                ring.firstMaterial?.emission.contents = snapshot.district.sceneColor
                let ringNode = SCNNode(geometry: ring)
                ringNode.simdPosition = SIMD3<Float>(node.simdPosition.x, buildingBaseY + 0.45, node.simdPosition.z)
                ringNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                scene.rootNode.addChildNode(ringNode)
            }
        }
    }

    private func makeBuildingNode(
        processID: Int32,
        district: ProcessCityDistrict,
        districtColor: NSColor,
        width: Float,
        length: Float,
        height: Float,
        styleSeed: Int,
        isActive: Bool,
        hotspotLevel: Float,
        cpuRatio: Float,
        memoryRatio: Float
    ) -> SCNNode {
        let wrapper = SCNNode()
        wrapper.name = "building-\(processID)"
        let lighting = district.lightingProfile

        let darkFacade = districtColor.blended(withFraction: 0.64, of: .black) ?? districtColor
        let midFacade = districtColor.blended(withFraction: 0.36, of: .black) ?? districtColor
        let glassFacade = districtColor.blended(withFraction: 0.46, of: .white) ?? districtColor
        let trimColor = NSColor(calibratedWhite: 0.18, alpha: 1.0)

        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = darkFacade
        baseMaterial.metalness.contents = 0.08
        baseMaterial.roughness.contents = 0.88
        baseMaterial.emission.contents = modeEmission(base: isActive ? lighting.facadeGlowActive : lighting.facadeGlowIdle, district: district, cpuRatio: cpuRatio, memoryRatio: memoryRatio, districtColor: districtColor)

        let accentMaterial = SCNMaterial()
        accentMaterial.diffuse.contents = midFacade
        accentMaterial.metalness.contents = 0.06
        accentMaterial.roughness.contents = 0.78
        accentMaterial.emission.contents = modeEmission(base: isActive ? lighting.accentGlowActive : lighting.accentGlowIdle, district: district, cpuRatio: cpuRatio, memoryRatio: memoryRatio, districtColor: districtColor)

        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = glassFacade
        glassMaterial.metalness.contents = 0.18
        glassMaterial.roughness.contents = 0.3
        glassMaterial.emission.contents = modeEmission(base: isActive ? lighting.glassGlowActive : lighting.glassGlowIdle, district: district, cpuRatio: cpuRatio, memoryRatio: memoryRatio, districtColor: districtColor)

        let trimMaterial = SCNMaterial()
        trimMaterial.diffuse.contents = trimColor
        trimMaterial.roughness.contents = 0.92

        switch district {
        case .systemCore:
            addSteppedCivicTower(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                baseMaterial: baseMaterial,
                accentMaterial: accentMaterial,
                trimMaterial: trimMaterial
            )
        case .userApps:
            addCurtainWallTower(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                baseMaterial: accentMaterial,
                glassMaterial: glassMaterial,
                trimMaterial: trimMaterial
            )
        case .networkSync:
            addHarborCampus(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                baseMaterial: baseMaterial,
                accentMaterial: accentMaterial,
                trimMaterial: trimMaterial,
                styleSeed: styleSeed
            )
        case .developerTools:
            addTechCampusTower(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                accentMaterial: accentMaterial,
                glassMaterial: glassMaterial,
                trimMaterial: trimMaterial
            )
        case .backgroundAgents:
            addServiceBlock(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                baseMaterial: baseMaterial,
                accentMaterial: accentMaterial,
                trimMaterial: trimMaterial
            )
        case .other:
            addMasonryMidrise(
                to: wrapper,
                width: width,
                length: length,
                height: height,
                baseMaterial: baseMaterial,
                glassMaterial: glassMaterial,
                trimMaterial: trimMaterial
            )
        }

        addWindowBands(to: wrapper, district: district, width: width, length: length, height: height, color: districtColor, active: isActive)
        addSideWindowBands(to: wrapper, district: district, width: width, length: length, height: height, color: districtColor, active: isActive)
        addFacadeStripes(to: wrapper, width: width, length: length, height: height)
        addEntranceGlow(to: wrapper, district: district, width: width, length: length, active: isActive)
        addRooftopStatusPanel(to: wrapper, color: modeStatusColor(cpuRatio: cpuRatio, memoryRatio: memoryRatio, districtColor: districtColor), height: height, hotspotLevel: hotspotLevel)
        if hotspotLevel >= 0.62 {
            addHotspotBeacon(to: wrapper, color: modeStatusColor(cpuRatio: cpuRatio, memoryRatio: memoryRatio, districtColor: districtColor), height: height, intensity: hotspotLevel)
        }

        let hitbox = SCNBox(width: CGFloat(max(width * 1.8, 18)), height: CGFloat(max(height + 8, 20)), length: CGFloat(max(length * 1.8, 18)), chamferRadius: 2.6)
        let hitboxMaterial = SCNMaterial()
        hitboxMaterial.diffuse.contents = NSColor.clear
        hitboxMaterial.transparency = 0.001
        hitboxMaterial.writesToDepthBuffer = false
        hitboxMaterial.readsFromDepthBuffer = false
        hitboxMaterial.isDoubleSided = false
        hitbox.materials = [hitboxMaterial]
        let hitboxNode = SCNNode(geometry: hitbox)
        hitboxNode.name = "building-hitbox-\(processID)"
        hitboxNode.position = SCNVector3(0, max(height + 8, 20) / 2, 0)
        wrapper.addChildNode(hitboxNode)
        applyInteractionMask(Self.buildingInteractionMask, to: wrapper)

        return wrapper
    }

    private func modeEmission(base: NSColor, district: ProcessCityDistrict, cpuRatio: Float, memoryRatio: Float, districtColor: NSColor) -> NSColor {
        switch visualMode {
        case .live:
            return base
        case .thermal:
            let alpha = CGFloat(0.04 + min(cpuRatio, 1) * 0.22)
            return NSColor(calibratedRed: 1.0, green: 0.28 + CGFloat(cpuRatio) * 0.18, blue: 0.06, alpha: alpha)
        case .memory:
            let alpha = CGFloat(0.04 + min(memoryRatio, 1) * 0.22)
            return NSColor(calibratedRed: 0.34, green: 0.58, blue: 1.0, alpha: alpha)
        case .network:
            let alpha: CGFloat = district == .networkSync ? 0.28 : 0.08
            return NSColor(calibratedRed: 0.18, green: 0.95, blue: 0.78, alpha: alpha)
        case .risk:
            let risk = max(cpuRatio, memoryRatio)
            let alpha = CGFloat(0.04 + risk * 0.25)
            return NSColor(calibratedRed: 1.0, green: 0.16, blue: 0.20, alpha: alpha)
        }
    }

    private func modeStatusColor(cpuRatio: Float, memoryRatio: Float, districtColor: NSColor) -> NSColor {
        switch visualMode {
        case .live: return districtColor
        case .thermal: return NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.10, alpha: 1.0)
        case .memory: return NSColor(calibratedRed: 0.44, green: 0.68, blue: 1.0, alpha: 1.0)
        case .network: return NSColor(calibratedRed: 0.32, green: 1.0, blue: 0.86, alpha: 1.0)
        case .risk:
            return max(cpuRatio, memoryRatio) >= 0.62
                ? NSColor(calibratedRed: 1.0, green: 0.16, blue: 0.20, alpha: 1.0)
                : districtColor
        }
    }

    private func applyInteractionMask(_ mask: Int, to node: SCNNode) {
        node.categoryBitMask = mask
        for child in node.childNodes {
            applyInteractionMask(mask, to: child)
        }
    }

    private func addSteppedCivicTower(to parent: SCNNode, width: Float, length: Float, height: Float, baseMaterial: SCNMaterial, accentMaterial: SCNMaterial, trimMaterial: SCNMaterial) {
        let podiumHeight = max(height * 0.22, 8)
        let podium = SCNBox(width: CGFloat(width * 1.18), height: CGFloat(podiumHeight), length: CGFloat(length * 1.18), chamferRadius: 1.8)
        podium.materials = [baseMaterial]
        let podiumNode = SCNNode(geometry: podium)
        podiumNode.position = SCNVector3(0, podiumHeight / 2, 0)
        parent.addChildNode(podiumNode)

        let lowerHeight = max(height * 0.38, 11)
        let lower = SCNBox(width: CGFloat(width * 0.92), height: CGFloat(lowerHeight), length: CGFloat(length * 0.92), chamferRadius: 1.2)
        lower.materials = [accentMaterial]
        let lowerNode = SCNNode(geometry: lower)
        lowerNode.position = SCNVector3(0, podiumHeight + lowerHeight / 2, 0)
        parent.addChildNode(lowerNode)

        let upperHeight = max(height - podiumHeight - lowerHeight + 4, 10)
        let upper = SCNBox(width: CGFloat(width * 0.7), height: CGFloat(upperHeight), length: CGFloat(length * 0.7), chamferRadius: 0.9)
        upper.materials = [baseMaterial]
        let upperNode = SCNNode(geometry: upper)
        upperNode.position = SCNVector3(0, podiumHeight + lowerHeight + upperHeight / 2, 0)
        parent.addChildNode(upperNode)

        addCornerPiers(to: parent, width: width * 0.92, length: length * 0.92, height: podiumHeight + lowerHeight, material: trimMaterial)
        addRooftopMechanical(to: parent, width: width * 0.28, length: length * 0.28, y: podiumHeight + lowerHeight + upperHeight + 1.1, material: trimMaterial)
        addSpire(to: parent, baseY: podiumHeight + lowerHeight + upperHeight + 2.2, height: min(max(height * 0.14, 4), 10), material: trimMaterial)
    }

    private func addCurtainWallTower(to parent: SCNNode, width: Float, length: Float, height: Float, baseMaterial: SCNMaterial, glassMaterial: SCNMaterial, trimMaterial: SCNMaterial) {
        let podiumHeight = max(height * 0.18, 6)
        let podium = SCNBox(width: CGFloat(width * 1.2), height: CGFloat(podiumHeight), length: CGFloat(length * 1.2), chamferRadius: 1.4)
        podium.materials = [baseMaterial]
        let podiumNode = SCNNode(geometry: podium)
        podiumNode.position = SCNVector3(0, podiumHeight / 2, 0)
        parent.addChildNode(podiumNode)

        let towerHeight = max(height - podiumHeight + 2, 14)
        let shaft = SCNBox(width: CGFloat(width * 0.82), height: CGFloat(towerHeight), length: CGFloat(length * 0.82), chamferRadius: 1.6)
        shaft.materials = [glassMaterial]
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(0, podiumHeight + towerHeight / 2, 0)
        parent.addChildNode(shaftNode)

        let crown = SCNBox(width: CGFloat(width * 0.88), height: 1.2, length: CGFloat(length * 0.88), chamferRadius: 0.2)
        crown.materials = [trimMaterial]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, podiumHeight + towerHeight + 0.6, 0)
        parent.addChildNode(crownNode)

        addVerticalFins(to: parent, width: width * 0.8, length: length * 0.8, height: towerHeight, baseY: podiumHeight, material: trimMaterial)
        addRooftopMechanical(to: parent, width: width * 0.18, length: length * 0.18, y: podiumHeight + towerHeight + 1.8, material: trimMaterial)
    }

    private func addHarborCampus(to parent: SCNNode, width: Float, length: Float, height: Float, baseMaterial: SCNMaterial, accentMaterial: SCNMaterial, trimMaterial: SCNMaterial, styleSeed: Int) {
        let hallHeight = max(height * 0.4, 8)
        let hall = SCNBox(width: CGFloat(width * 1.28), height: CGFloat(hallHeight), length: CGFloat(length * 1.38), chamferRadius: 0.8)
        hall.materials = [baseMaterial]
        let hallNode = SCNNode(geometry: hall)
        hallNode.position = SCNVector3(0, hallHeight / 2, 0)
        parent.addChildNode(hallNode)

        let adminHeight = max(height * 0.34, 7)
        let admin = SCNBox(width: CGFloat(width * 0.42), height: CGFloat(adminHeight), length: CGFloat(length * 0.52), chamferRadius: 0.5)
        admin.materials = [accentMaterial]
        let adminNode = SCNNode(geometry: admin)
        adminNode.position = SCNVector3(width * 0.24, adminHeight / 2, -length * 0.18)
        parent.addChildNode(adminNode)

        addRooftopMechanical(to: parent, width: width * 0.7, length: length * 0.24, y: hallHeight + 0.9, material: trimMaterial)
        if styleSeed.isMultiple(of: 2) {
            addAntennaMast(to: parent, baseX: -width * 0.34, baseZ: length * 0.26, baseY: hallHeight, material: trimMaterial)
        }
    }

    private func addTechCampusTower(to parent: SCNNode, width: Float, length: Float, height: Float, accentMaterial: SCNMaterial, glassMaterial: SCNMaterial, trimMaterial: SCNMaterial) {
        let campusHeight = max(height * 0.24, 7)
        let campus = SCNBox(width: CGFloat(width * 1.24), height: CGFloat(campusHeight), length: CGFloat(length * 1.08), chamferRadius: 1.0)
        campus.materials = [accentMaterial]
        let campusNode = SCNNode(geometry: campus)
        campusNode.position = SCNVector3(0, campusHeight / 2, 0)
        parent.addChildNode(campusNode)

        let slabHeight = max(height * 0.42, 10)
        let slab = SCNBox(width: CGFloat(width * 0.88), height: CGFloat(slabHeight), length: CGFloat(length * 0.52), chamferRadius: 0.7)
        slab.materials = [glassMaterial]
        let slabNode = SCNNode(geometry: slab)
        slabNode.position = SCNVector3(-width * 0.1, campusHeight + slabHeight / 2, 0)
        parent.addChildNode(slabNode)

        let towerHeight = max(height - campusHeight - slabHeight + 5, 9)
        let tower = SCNBox(width: CGFloat(width * 0.48), height: CGFloat(towerHeight), length: CGFloat(length * 0.48), chamferRadius: 0.6)
        tower.materials = [glassMaterial]
        let towerNode = SCNNode(geometry: tower)
        towerNode.position = SCNVector3(width * 0.18, campusHeight + slabHeight + towerHeight / 2, 0)
        parent.addChildNode(towerNode)

        addSkybridge(to: parent, width: width * 0.24, baseY: campusHeight + slabHeight * 0.72, z: 0, material: trimMaterial)
        addRooftopMechanical(to: parent, width: width * 0.22, length: length * 0.16, y: campusHeight + slabHeight + towerHeight + 0.9, material: trimMaterial)
    }

    private func addServiceBlock(to parent: SCNNode, width: Float, length: Float, height: Float, baseMaterial: SCNMaterial, accentMaterial: SCNMaterial, trimMaterial: SCNMaterial) {
        let baseHeight = max(height * 0.72, 14)
        let base = SCNBox(width: CGFloat(width), height: CGFloat(baseHeight), length: CGFloat(length * 0.78), chamferRadius: 0.8)
        base.materials = [baseMaterial]
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, baseHeight / 2, 0)
        parent.addChildNode(baseNode)

        let shoulderHeight = max(height - baseHeight + 4, 6)
        let shoulder = SCNBox(width: CGFloat(width * 0.72), height: CGFloat(shoulderHeight), length: CGFloat(length * 0.62), chamferRadius: 0.5)
        shoulder.materials = [accentMaterial]
        let shoulderNode = SCNNode(geometry: shoulder)
        shoulderNode.position = SCNVector3(0, baseHeight + shoulderHeight / 2, 0)
        parent.addChildNode(shoulderNode)

        addRooftopMechanical(to: parent, width: width * 0.42, length: length * 0.22, y: baseHeight + shoulderHeight + 0.9, material: trimMaterial)
    }

    private func addMasonryMidrise(to parent: SCNNode, width: Float, length: Float, height: Float, baseMaterial: SCNMaterial, glassMaterial: SCNMaterial, trimMaterial: SCNMaterial) {
        let body = SCNBox(width: CGFloat(width * 1.02), height: CGFloat(height), length: CGFloat(length * 0.82), chamferRadius: 0.6)
        body.materials = [baseMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, height / 2, 0)
        parent.addChildNode(bodyNode)

        let insetHeight = max(height * 0.24, 6)
        let inset = SCNBox(width: CGFloat(width * 0.58), height: CGFloat(insetHeight), length: CGFloat(length * 0.48), chamferRadius: 0.4)
        inset.materials = [glassMaterial]
        let insetNode = SCNNode(geometry: inset)
        insetNode.position = SCNVector3(0, height - insetHeight / 2, 0)
        parent.addChildNode(insetNode)

        addCornerPiers(to: parent, width: width * 0.96, length: length * 0.76, height: height, material: trimMaterial)
    }

    private func addRooftopMechanical(to parent: SCNNode, width: Float, length: Float, y: Float, material: SCNMaterial) {
        let unit = SCNBox(width: CGFloat(max(width, 2.2)), height: 1.4, length: CGFloat(max(length, 2.2)), chamferRadius: 0.15)
        unit.materials = [material]
        let unitNode = SCNNode(geometry: unit)
        unitNode.position = SCNVector3(0, y, 0)
        parent.addChildNode(unitNode)
    }

    private func addAntennaMast(to parent: SCNNode, baseX: Float, baseZ: Float, baseY: Float, material: SCNMaterial) {
        let mast = SCNCylinder(radius: 0.12, height: 7.2)
        mast.materials = [material]
        let mastNode = SCNNode(geometry: mast)
        mastNode.position = SCNVector3(baseX, baseY + 3.6, baseZ)
        parent.addChildNode(mastNode)
    }

    private func addSpire(to parent: SCNNode, baseY: Float, height: Float, material: SCNMaterial) {
        let spire = SCNCone(topRadius: 0, bottomRadius: 0.42, height: CGFloat(height))
        spire.materials = [material]
        let spireNode = SCNNode(geometry: spire)
        spireNode.position = SCNVector3(0, baseY + height / 2, 0)
        parent.addChildNode(spireNode)
    }

    private func addCornerPiers(to parent: SCNNode, width: Float, length: Float, height: Float, material: SCNMaterial) {
        let pier = SCNBox(width: 0.34, height: CGFloat(height), length: 0.34, chamferRadius: 0.06)
        pier.materials = [material]
        let offsets: [SIMD2<Float>] = [
            SIMD2(-width / 2, -length / 2),
            SIMD2(width / 2, -length / 2),
            SIMD2(-width / 2, length / 2),
            SIMD2(width / 2, length / 2),
        ]
        for offset in offsets {
            let node = SCNNode(geometry: pier)
            node.position = SCNVector3(offset.x, height / 2, offset.y)
            parent.addChildNode(node)
        }
    }

    private func addVerticalFins(to parent: SCNNode, width: Float, length: Float, height: Float, baseY: Float, material: SCNMaterial) {
        let fin = SCNBox(width: 0.22, height: CGFloat(height), length: CGFloat(max(length * 0.92, 3)), chamferRadius: 0.04)
        fin.materials = [material]
        let offsets: [Float] = [-width / 2, -width / 6, width / 6, width / 2]
        for offset in offsets {
            let front = SCNNode(geometry: fin)
            front.position = SCNVector3(offset, baseY + height / 2, 0)
            parent.addChildNode(front)
        }
    }

    private func addSkybridge(to parent: SCNNode, width: Float, baseY: Float, z: Float, material: SCNMaterial) {
        let bridge = SCNBox(width: CGFloat(max(width, 2.4)), height: 1.0, length: 1.2, chamferRadius: 0.16)
        bridge.materials = [material]
        let bridgeNode = SCNNode(geometry: bridge)
        bridgeNode.position = SCNVector3(0, baseY, z)
        parent.addChildNode(bridgeNode)
    }

    private func addWindowBands(to parent: SCNNode, district: ProcessCityDistrict, width: Float, length: Float, height: Float, color: NSColor, active: Bool) {
        let bandCount = min(max(Int(height / 10), 2), 7)
        let glow = district.windowGlow(active: active, side: false)

        for index in 0..<bandCount {
            let y = Float(index + 1) * height / Float(bandCount + 1)
            let frontBand = SCNBox(width: CGFloat(max(width * 0.74, 3)), height: 0.42, length: 0.28, chamferRadius: 0.08)
            frontBand.firstMaterial?.diffuse.contents = glow
            frontBand.firstMaterial?.emission.contents = glow
            let frontNode = SCNNode(geometry: frontBand)
            frontNode.position = SCNVector3(0, y, length / 2 + 0.16)
            parent.addChildNode(frontNode)

            let backNode = SCNNode(geometry: frontBand)
            backNode.position = SCNVector3(0, y, -length / 2 - 0.16)
            parent.addChildNode(backNode)
        }
    }

    private func addSideWindowBands(to parent: SCNNode, district: ProcessCityDistrict, width: Float, length: Float, height: Float, color: NSColor, active: Bool) {
        let bandCount = min(max(Int(height / 12), 2), 6)
        let glow = district.windowGlow(active: active, side: true)

        for index in 0..<bandCount {
            let y = Float(index + 1) * height / Float(bandCount + 1)
            let sideBand = SCNBox(width: 0.28, height: 0.4, length: CGFloat(max(length * 0.68, 3)), chamferRadius: 0.06)
            sideBand.firstMaterial?.diffuse.contents = glow
            sideBand.firstMaterial?.emission.contents = glow

            let leftNode = SCNNode(geometry: sideBand)
            leftNode.position = SCNVector3(-width / 2 - 0.16, y, 0)
            parent.addChildNode(leftNode)

            let rightNode = SCNNode(geometry: sideBand)
            rightNode.position = SCNVector3(width / 2 + 0.16, y, 0)
            parent.addChildNode(rightNode)
        }
    }

    private func addFacadeStripes(to parent: SCNNode, width: Float, length: Float, height: Float) {
        let stripeColor = NSColor(calibratedWhite: 0.08, alpha: 0.92)
        let count = min(max(Int(height / 16), 1), 4)
        for index in 0..<count {
            let y = Float(index + 1) * height / Float(count + 1)
            let stripe = SCNBox(width: CGFloat(max(width * 0.94, 4)), height: 0.34, length: CGFloat(max(length * 0.94, 4)), chamferRadius: 0.04)
            stripe.firstMaterial?.diffuse.contents = stripeColor
            stripe.firstMaterial?.roughness.contents = 0.96
            let stripeNode = SCNNode(geometry: stripe)
            stripeNode.position = SCNVector3(0, y, 0)
            parent.addChildNode(stripeNode)
        }
    }

    private func addEntranceGlow(to parent: SCNNode, district: ProcessCityDistrict, width: Float, length: Float, active: Bool) {
        let lighting = district.lightingProfile
        let entrance = SCNBox(width: CGFloat(max(width * 0.28, 2.2)), height: 2.2, length: 0.24, chamferRadius: 0.06)
        let material = SCNMaterial()
        material.diffuse.contents = active ? lighting.frontWindowActive : lighting.frontWindowIdle
        material.emission.contents = active ? lighting.frontWindowActive : lighting.frontWindowIdle
        entrance.materials = [material]

        let node = SCNNode(geometry: entrance)
        node.position = SCNVector3(0, 1.35, length / 2 + 0.22)
        parent.addChildNode(node)

        let canopy = SCNBox(width: CGFloat(max(width * 0.36, 3.0)), height: 0.26, length: 1.2, chamferRadius: 0.12)
        canopy.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.16, alpha: 1.0)
        canopy.firstMaterial?.emission.contents = district.sceneColor.withAlphaComponent(active ? 0.08 : 0.02)
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.position = SCNVector3(0, 2.6, length / 2 + 0.72)
        parent.addChildNode(canopyNode)
    }

    private func addRooftopStatusPanel(to parent: SCNNode, color: NSColor, height: Float, hotspotLevel: Float) {
        let panel = SCNCylinder(radius: CGFloat(0.8 + hotspotLevel * 0.6), height: 0.34)
        panel.radialSegmentCount = 28
        panel.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.78)
        panel.firstMaterial?.emission.contents = color.withAlphaComponent(0.55 + CGFloat(hotspotLevel) * 0.35)

        let node = SCNNode(geometry: panel)
        node.position = SCNVector3(0, height + 0.38, 0)
        parent.addChildNode(node)

        if visualMode == .thermal || visualMode == .risk {
            let pulse = SCNAction.sequence([
                .scale(to: CGFloat(1.0 + hotspotLevel * 0.10), duration: 0.55),
                .scale(to: 1.0, duration: 0.8)
            ])
            node.runAction(.repeatForever(pulse))
        }
    }

    private func addHotspotBeacon(to parent: SCNNode, color: NSColor, height: Float, intensity: Float) {
        let beacon = SCNSphere(radius: CGFloat(0.9 + intensity * 0.8))
        beacon.firstMaterial?.diffuse.contents = NSColor.white
        beacon.firstMaterial?.emission.contents = color.withAlphaComponent(0.9)
        let beaconNode = SCNNode(geometry: beacon)
        beaconNode.position = SCNVector3(0, height + 2.2, 0)
        let pulse = SCNAction.sequence([
            .fadeOpacity(to: 0.45, duration: 0.5),
            .fadeOpacity(to: 1.0, duration: 0.8)
        ])
        beaconNode.runAction(.repeatForever(pulse))
        parent.addChildNode(beaconNode)
    }

    private func addDistrictAtmosphere(for snapshot: CityDistrictSnapshot, footprint: DistrictFootprint, at center: SIMD2<Float>, in scene: SCNScene) {
        let lighting = snapshot.district.lightingProfile
        let park = SCNBox(
            width: CGFloat(max(footprint.width * 0.2, 10)),
            height: 0.22,
            length: CGFloat(max(footprint.depth * 0.2, 10)),
            chamferRadius: 1.4
        )
        park.firstMaterial?.diffuse.contents = lighting.parkColor
        park.firstMaterial?.emission.contents = lighting.parkEmission
        let parkNode = SCNNode(geometry: park)
        parkNode.position = SCNVector3(center.x - footprint.width * 0.28, Self.citySurfaceY + Self.districtBaseHeight + 0.13, center.y + footprint.depth * 0.28)
        scene.rootNode.addChildNode(parkNode)

        let lampColor = lighting.lampColor
        let lampOffsets: [SIMD2<Float>] = [
            SIMD2(-footprint.width * 0.34, -footprint.depth * 0.34),
            SIMD2(footprint.width * 0.34, -footprint.depth * 0.34),
            SIMD2(-footprint.width * 0.34, footprint.depth * 0.34),
            SIMD2(footprint.width * 0.34, footprint.depth * 0.34),
        ]

        for offset in lampOffsets {
            let pole = SCNCylinder(radius: 0.18, height: 3.1)
            pole.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.28, alpha: 1.0)
            let poleNode = SCNNode(geometry: pole)
            poleNode.position = SCNVector3(center.x + offset.x, Self.citySurfaceY + Self.districtBaseHeight + 1.55, center.y + offset.y)
            scene.rootNode.addChildNode(poleNode)

            let lamp = SCNSphere(radius: 0.42)
            lamp.firstMaterial?.diffuse.contents = NSColor.white
            lamp.firstMaterial?.emission.contents = lampColor
            let lampNode = SCNNode(geometry: lamp)
            lampNode.position = SCNVector3(center.x + offset.x, Self.citySurfaceY + Self.districtBaseHeight + 3.35, center.y + offset.y)
            scene.rootNode.addChildNode(lampNode)
        }
    }

    private func makeDistrictFlows() -> [DistrictFlow] {
        let snapshots = districts
        guard snapshots.count > 1 else { return [] }

        let maxCPU = max(snapshots.map(\.totalCPU).max() ?? 1, 1)
        let maxMemory = max(Double(snapshots.map(\.totalMemory).max() ?? 1), 1)
        var flows: [DistrictFlow] = []

        for leftIndex in snapshots.indices {
            let left = snapshots[leftIndex]
            for right in snapshots[(leftIndex + 1)...] {
                let cpuSignal = Float(((left.totalCPU / maxCPU) + (right.totalCPU / maxCPU)) / 2)
                let memorySignal = Float(((Double(left.totalMemory) / maxMemory) + (Double(right.totalMemory) / maxMemory)) / 2)
                var strength = cpuSignal * 0.62 + memorySignal * 0.38

                let districts = [left.district, right.district]
                if districts.contains(.networkSync) { strength += 0.16 }
                if districts.contains(.systemCore) { strength += 0.08 }
                if districts.contains(.developerTools) && districts.contains(.userApps) { strength += 0.08 }
                if districts.contains(.backgroundAgents) && districts.contains(.systemCore) { strength += 0.06 }

                guard strength >= 0.22 else { continue }
                let ordered = orderedFlowEndpoints(left: left, right: right)
                let color = blendColor(ordered.from.sceneColor, ordered.to.sceneColor)
                flows.append(DistrictFlow(
                    from: ordered.from,
                    to: ordered.to,
                    strength: min(strength, 1.0),
                    color: color,
                    label: flowLabel(from: ordered.from, to: ordered.to)
                ))
            }
        }

        return flows
            .sorted { $0.strength > $1.strength }
            .prefix(7)
            .map { $0 }
    }

    private func addDataLines(flows: [DistrictFlow], layout: CityLayout, in scene: SCNScene) {
        for flow in flows {
            guard
                let fromCenter = layout.positions[flow.from],
                let toCenter = layout.positions[flow.to]
            else { continue }

            let start = SIMD3<Float>(fromCenter.x, Self.citySurfaceY + Self.districtBaseHeight + 4.4, fromCenter.y)
            let end = SIMD3<Float>(toCenter.x, Self.citySurfaceY + Self.districtBaseHeight + 4.4, toCenter.y)
            let vector = end - start
            let distance = simd_length(vector)
            guard distance > 1 else { continue }

            let line = SCNCylinder(radius: CGFloat(0.18 + flow.strength * 0.85), height: CGFloat(distance))
            line.radialSegmentCount = 12
            line.firstMaterial?.diffuse.contents = flow.color.withAlphaComponent(0.42)
            line.firstMaterial?.emission.contents = flow.color.withAlphaComponent(0.72)
            line.firstMaterial?.roughness.contents = 0.28
            let lineNode = SCNNode(geometry: line)
            lineNode.simdPosition = (start + end) / 2
            let direction = simd_normalize(vector)
            lineNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
            scene.rootNode.addChildNode(lineNode)

            let arrow = SCNCone(topRadius: 0, bottomRadius: CGFloat(0.9 + flow.strength * 1.2), height: CGFloat(3.2 + flow.strength * 2.4))
            arrow.radialSegmentCount = 14
            arrow.firstMaterial?.diffuse.contents = flow.color.withAlphaComponent(0.88)
            arrow.firstMaterial?.emission.contents = flow.color
            let arrowNode = SCNNode(geometry: arrow)
            let arrowOffset = min(max(distance * 0.14, 10), 22)
            arrowNode.simdPosition = end - direction * arrowOffset
            arrowNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
            scene.rootNode.addChildNode(arrowNode)

            if showFlowLabels {
                let labelText = SCNText(string: flow.label, extrusionDepth: 0.22)
                labelText.font = NSFont.systemFont(ofSize: 4.4, weight: .semibold)
                labelText.flatness = 0.25
                labelText.firstMaterial?.diffuse.contents = NSColor.white
                labelText.firstMaterial?.emission.contents = flow.color.withAlphaComponent(0.92)
                let labelNode = SCNNode(geometry: labelText)
                let (minBound, maxBound) = labelText.boundingBox
                let labelWidth = Float(maxBound.x - minBound.x)
                labelNode.scale = SCNVector3(0.72, 0.72, 0.72)
                labelNode.position = SCNVector3(
                    (start.x + end.x) / 2 - labelWidth * 0.36,
                    max(start.y, end.y) + 4.8 + flow.strength * 2.2,
                    (start.z + end.z) / 2
                )
                labelNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                scene.rootNode.addChildNode(labelNode)
            }

            let packetCount = max(2, Int(ceil(Double(flow.strength * 3.5))))
            for packetIndex in 0..<packetCount {
                let packet = SCNSphere(radius: CGFloat(0.45 + flow.strength * 0.55))
                packet.firstMaterial?.diffuse.contents = NSColor.white
                packet.firstMaterial?.emission.contents = flow.color
                let packetNode = SCNNode(geometry: packet)
                packetNode.simdPosition = start
                scene.rootNode.addChildNode(packetNode)

                let travelDuration = max(0.9, 2.6 - Double(flow.strength) * 1.3)
                let delay = Double(packetIndex) * 0.34
                let animation = SCNAction.sequence([
                    .wait(duration: delay),
                    .move(to: SCNVector3(end.x, end.y, end.z), duration: travelDuration),
                    .fadeOut(duration: 0.12),
                    .run { node in
                        node.opacity = 1.0
                        node.position = SCNVector3(start.x, start.y, start.z)
                    }
                ])
                packetNode.runAction(.repeatForever(animation))
            }
        }
    }

    private func blendColor(_ lhs: NSColor, _ rhs: NSColor) -> NSColor {
        let left = lhs.usingColorSpace(.deviceRGB) ?? lhs
        let right = rhs.usingColorSpace(.deviceRGB) ?? rhs
        return NSColor(
            calibratedRed: (left.redComponent + right.redComponent) / 2,
            green: (left.greenComponent + right.greenComponent) / 2,
            blue: (left.blueComponent + right.blueComponent) / 2,
            alpha: 1.0
        )
    }

    private func orderedFlowEndpoints(left: CityDistrictSnapshot, right: CityDistrictSnapshot) -> (from: ProcessCityDistrict, to: ProcessCityDistrict) {
        let leftScore = districtPriority(left.district) + Float(left.totalCPU * 0.55) + Float(Double(left.totalMemory) / 1_000_000_000) * 0.35
        let rightScore = districtPriority(right.district) + Float(right.totalCPU * 0.55) + Float(Double(right.totalMemory) / 1_000_000_000) * 0.35
        return leftScore >= rightScore ? (left.district, right.district) : (right.district, left.district)
    }

    private func districtPriority(_ district: ProcessCityDistrict) -> Float {
        switch district {
        case .systemCore: return 3.2
        case .networkSync: return 2.8
        case .developerTools: return 2.4
        case .backgroundAgents: return 2.0
        case .userApps: return 1.7
        case .other: return 1.2
        }
    }

    private func flowLabel(from: ProcessCityDistrict, to: ProcessCityDistrict) -> String {
        switch (from, to) {
        case (.systemCore, .networkSync), (.networkSync, .systemCore):
            return "sync traffic"
        case (.developerTools, .userApps), (.userApps, .developerTools):
            return "build pressure"
        case (.systemCore, .backgroundAgents), (.backgroundAgents, .systemCore):
            return "memory churn"
        case (.networkSync, .userApps), (.userApps, .networkSync):
            return "session flow"
        default:
            return "cpu pressure"
        }
    }

    private func makeCityLayout() -> CityLayout {
        let order: [ProcessCityDistrict] = [
            .systemCore, .userApps, .networkSync,
            .developerTools, .backgroundAgents, .other,
        ]
        let footprints = Dictionary(uniqueKeysWithValues: districts.map { ($0.district, footprint(for: $0)) })
        let rows = [[order[0], order[1], order[2]], [order[3], order[4], order[5]]]
        let columnGap = Float(22 * districtScale)
        let rowGap = Float(28 * districtScale)

        var columnWidths = Array(repeating: Float(84), count: 3)
        var rowDepths = Array(repeating: Float(84), count: 2)

        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, district) in row.enumerated() {
                if let footprint = footprints[district] {
                    columnWidths[columnIndex] = max(columnWidths[columnIndex], footprint.width)
                    rowDepths[rowIndex] = max(rowDepths[rowIndex], footprint.depth)
                }
            }
        }

        let totalWidth = columnWidths.reduce(0, +) + columnGap * Float(columnWidths.count - 1)
        let totalDepth = rowDepths.reduce(0, +) + rowGap * Float(rowDepths.count - 1)

        var positions: [ProcessCityDistrict: SIMD2<Float>] = [:]
        var currentZ = -totalDepth / 2
        for (rowIndex, row) in rows.enumerated() {
            let rowCenter = currentZ + rowDepths[rowIndex] / 2
            var currentX = -totalWidth / 2
            for (columnIndex, district) in row.enumerated() {
                let columnCenter = currentX + columnWidths[columnIndex] / 2
                positions[district] = SIMD2<Float>(columnCenter, rowCenter)
                currentX += columnWidths[columnIndex] + columnGap
            }
            currentZ += rowDepths[rowIndex] + rowGap
        }

        return CityLayout(
            positions: positions,
            footprints: footprints,
            floorWidth: max(totalWidth + 64, 220),
            floorDepth: max(totalDepth + 88, 220)
        )
    }

    private func footprint(for snapshot: CityDistrictSnapshot) -> DistrictFootprint {
        let processCount = max(1, min(snapshot.processes.count, 24))
        let spacing = Float(18 * districtScale)
        let columns = min(5, max(2, Int(ceil(sqrt(Double(processCount))))))
        let rows = max(1, Int(ceil(Double(processCount) / Double(columns))))
        let contentWidth = Float(columns - 1) * spacing + 20
        let contentDepth = Float(rows - 1) * spacing + 20
        let width = max(72, contentWidth + 24)
        let depth = max(72, contentDepth + 24)

        return DistrictFootprint(
            columns: columns,
            rows: rows,
            spacing: spacing,
            width: width,
            depth: depth,
            roadWidth: width + 12,
            roadDepth: depth + 12
        )
    }

    final class Coordinator: NSObject {
        weak var view: SCNView?
        var onSelect: (Int32?) -> Void

        init(onSelect: @escaping (Int32?) -> Void) {
            self.onSelect = onSelect
        }

        func handleTrackpadPan(deltaX: Float, deltaY: Float) {
            applyPan(deltaX: deltaX, deltaY: deltaY, speedMultiplier: 0.34)
        }

        @objc func handlePan(_ recognizer: NSPanGestureRecognizer) {
            let translation = recognizer.translation(in: view)
            recognizer.setTranslation(.zero, in: view)
            applyPan(deltaX: Float(translation.x), deltaY: Float(translation.y), speedMultiplier: 1.0)
        }

        private func applyPan(deltaX: Float, deltaY: Float, speedMultiplier: Float) {
            guard let view, let pointOfView = view.pointOfView else { return }
            guard abs(deltaX) > 0.01 || abs(deltaY) > 0.01 else { return }

            let transform = pointOfView.presentation.simdWorldTransform
            let right = normalizedXZ(SIMD3<Float>(transform.columns.0.x, 0, transform.columns.0.z))
            let forward = normalizedXZ(SIMD3<Float>(-transform.columns.2.x, 0, -transform.columns.2.z))

            let target = view.defaultCameraController.target
            let currentTarget = SIMD3<Float>(Float(target.x), Float(target.y), Float(target.z))
            let cameraPosition = pointOfView.presentation.simdWorldPosition
            let distance = simd_length(cameraPosition - currentTarget)
            let sensitivity = max(distance * 0.0011, 0.18) * speedMultiplier

            let movement = right * (-deltaX * sensitivity) + forward * (deltaY * sensitivity)

            pointOfView.simdPosition += SIMD3<Float>(movement.x, 0, movement.z)
            view.defaultCameraController.target = SCNVector3(
                target.x + CGFloat(movement.x),
                target.y,
                target.z + CGFloat(movement.z)
            )
        }

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let view else { return }
            let point = recognizer.location(in: view)
            let hits = view.hitTest(point, options: [
                SCNHitTestOption.categoryBitMask: SystemCitySceneView.buildingInteractionMask,
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
                SCNHitTestOption.ignoreHiddenNodes: true,
                SCNHitTestOption.boundingBoxOnly: false,
            ])
            guard let hit = hits.first else {
                onSelect(nil)
                return
            }

            var node: SCNNode? = hit.node
            while let current = node {
                if let name = current.name, name.hasPrefix("building-") {
                    let pidText = String(name.dropFirst("building-".count))
                    if let pid = Int32(pidText) {
                        focusCamera(on: current)
                        onSelect(pid)
                        return
                    }
                }
                node = current.parent
            }

            onSelect(nil)
        }

        private func normalizedXZ(_ vector: SIMD3<Float>) -> SIMD3<Float> {
            let flattened = SIMD3<Float>(vector.x, 0, vector.z)
            let length = simd_length(flattened)
            guard length > 0.0001 else { return SIMD3<Float>(0, 0, 0) }
            return flattened / length
        }

        private func focusCamera(on node: SCNNode) {
            guard let view, let pointOfView = view.pointOfView else { return }
            let target = node.presentation.worldPosition
            let camera = pointOfView.presentation.worldPosition
            let offset = SCNVector3(camera.x - target.x, max(camera.y - target.y, 48), camera.z - target.z)
            let length = max(sqrt(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z), 1)
            let direction = SCNVector3(offset.x / length, offset.y / length, offset.z / length)
            let distance: CGFloat = 96

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            view.defaultCameraController.target = SCNVector3(target.x, target.y + 22, target.z)
            pointOfView.position = SCNVector3(
                target.x + direction.x * distance,
                target.y + max(direction.y * distance, 42),
                target.z + direction.z * distance
            )
            SCNTransaction.commit()
        }
    }
}

private struct CitySelectionPanel: View {
    let process: ProcessStats
    let summary: ProcessSummary
    let district: ProcessCityDistrict
    let cpuHistory: [Double]
    let memoryHistory: [Double]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SectionCardView(title: "Selected Building", icon: district.icon, iconColor: district.color) {
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
                            Text(district.title)
                                .font(.system(size: 11))
                                .foregroundStyle(district.color)
                        }

                        Spacer()
                    }

                    Text(summary.role)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(summary.purpose)
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                    Text(summary.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)

                    Divider()

                    VStack(spacing: 8) {
                        cityInfoRow("PID", "\(process.id)")
                        cityInfoRow("User", process.user)
                        cityInfoRow("Status", process.status.rawValue)
                        cityInfoRow("Threads", "\(process.threads)")
                        cityInfoRow("Footprint", process.memoryUsage.formattedBytes)
                    }
                }
            }

            SectionCardView(title: "District Pulse", icon: "waveform.path.ecg", iconColor: .cpuColor) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CPU skyline")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.textSecondary)
                        SparklineView(data: cpuHistory, color: .cpuColor, showArea: true, height: 74)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Memory skyline")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.textSecondary)
                        SparklineView(data: memoryHistory, color: .ramColor, showArea: true, height: 74)
                    }
                }
            }
        }
    }

    private func cityInfoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.textTertiary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.textSecondary)
            Spacer()
        }
    }
}

private struct CityDistrictSnapshot: Identifiable {
    var id: ProcessCityDistrict { district }
    let district: ProcessCityDistrict
    let processes: [ProcessStats]

    var totalCPU: Double {
        processes.reduce(0) { $0 + $1.cpuUsage }
    }

    var totalMemory: UInt64 {
        processes.reduce(0) { $0 + $1.memoryUsage }
    }
}

private struct DistrictLightingProfile {
    let facadeGlowActive: NSColor
    let facadeGlowIdle: NSColor
    let accentGlowActive: NSColor
    let accentGlowIdle: NSColor
    let glassGlowActive: NSColor
    let glassGlowIdle: NSColor
    let baseGlow: NSColor
    let plazaColor: NSColor
    let plazaEmission: NSColor
    let roadColor: NSColor
    let roadEmission: NSColor
    let parkColor: NSColor
    let parkEmission: NSColor
    let lampColor: NSColor
    let frontWindowActive: NSColor
    let frontWindowIdle: NSColor
    let sideWindowActive: NSColor
    let sideWindowIdle: NSColor
}

private enum ProcessCityDistrict: String, CaseIterable, Identifiable {
    case systemCore
    case userApps
    case networkSync
    case developerTools
    case backgroundAgents
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemCore: return "System Core"
        case .userApps: return "App Downtown"
        case .networkSync: return "Network Harbor"
        case .developerTools: return "Builder Quarter"
        case .backgroundAgents: return "Service Belt"
        case .other: return "Outer Edge"
        }
    }

    var icon: String {
        switch self {
        case .systemCore: return "shield.lefthalf.filled"
        case .userApps: return "macwindow"
        case .networkSync: return "antenna.radiowaves.left.and.right"
        case .developerTools: return "hammer.fill"
        case .backgroundAgents: return "gearshape.2.fill"
        case .other: return "square.3.layers.3d"
        }
    }

    var color: Color {
        switch self {
        case .systemCore: return .warning
        case .userApps: return .appAccent
        case .networkSync: return .netColor
        case .developerTools: return .cpuColor
        case .backgroundAgents: return .ramColor
        case .other: return .textSecondary
        }
    }

    var sceneColor: NSColor {
        switch self {
        case .systemCore: return NSColor(calibratedRed: 0.95, green: 0.63, blue: 0.22, alpha: 1.0)
        case .userApps: return NSColor(calibratedRed: 0.18, green: 0.65, blue: 0.95, alpha: 1.0)
        case .networkSync: return NSColor(calibratedRed: 0.16, green: 0.86, blue: 0.74, alpha: 1.0)
        case .developerTools: return NSColor(calibratedRed: 0.97, green: 0.35, blue: 0.25, alpha: 1.0)
        case .backgroundAgents: return NSColor(calibratedRed: 0.43, green: 0.71, blue: 0.99, alpha: 1.0)
        case .other: return NSColor(calibratedWhite: 0.62, alpha: 1.0)
        }
    }

    var lightingProfile: DistrictLightingProfile {
        switch self {
        case .systemCore:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.05),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.015),
                accentGlowActive: NSColor(calibratedRed: 0.98, green: 0.64, blue: 0.24, alpha: 0.08),
                accentGlowIdle: NSColor(calibratedRed: 0.98, green: 0.64, blue: 0.24, alpha: 0.025),
                glassGlowActive: NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.52, alpha: 0.075),
                glassGlowIdle: NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.52, alpha: 0.022),
                baseGlow: sceneColor.withAlphaComponent(0.06),
                plazaColor: NSColor(calibratedRed: 0.23, green: 0.19, blue: 0.15, alpha: 1.0),
                plazaEmission: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.12, alpha: 0.08),
                roadColor: NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.12, alpha: 1.0),
                roadEmission: NSColor(calibratedRed: 0.62, green: 0.34, blue: 0.12, alpha: 0.04),
                parkColor: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.11, alpha: 1.0),
                parkEmission: sceneColor.withAlphaComponent(0.03),
                lampColor: NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.38, alpha: 0.92),
                frontWindowActive: NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.66, alpha: 0.9),
                frontWindowIdle: NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.66, alpha: 0.3),
                sideWindowActive: NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.56, alpha: 0.74),
                sideWindowIdle: NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.56, alpha: 0.2)
            )
        case .userApps:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.04),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.012),
                accentGlowActive: NSColor(calibratedRed: 0.28, green: 0.71, blue: 0.98, alpha: 0.075),
                accentGlowIdle: NSColor(calibratedRed: 0.28, green: 0.71, blue: 0.98, alpha: 0.02),
                glassGlowActive: NSColor(calibratedRed: 0.52, green: 0.86, blue: 1.0, alpha: 0.085),
                glassGlowIdle: NSColor(calibratedRed: 0.52, green: 0.86, blue: 1.0, alpha: 0.026),
                baseGlow: sceneColor.withAlphaComponent(0.045),
                plazaColor: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.23, alpha: 1.0),
                plazaEmission: NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.82, alpha: 0.06),
                roadColor: NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.17, alpha: 1.0),
                roadEmission: NSColor(calibratedRed: 0.14, green: 0.48, blue: 0.76, alpha: 0.03),
                parkColor: NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.14, alpha: 1.0),
                parkEmission: sceneColor.withAlphaComponent(0.018),
                lampColor: NSColor(calibratedRed: 0.68, green: 0.90, blue: 1.0, alpha: 0.9),
                frontWindowActive: NSColor(calibratedRed: 0.72, green: 0.92, blue: 1.0, alpha: 0.88),
                frontWindowIdle: NSColor(calibratedRed: 0.72, green: 0.92, blue: 1.0, alpha: 0.26),
                sideWindowActive: NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.98, alpha: 0.7),
                sideWindowIdle: NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.98, alpha: 0.18)
            )
        case .networkSync:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.045),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.014),
                accentGlowActive: NSColor(calibratedRed: 0.20, green: 0.90, blue: 0.78, alpha: 0.08),
                accentGlowIdle: NSColor(calibratedRed: 0.20, green: 0.90, blue: 0.78, alpha: 0.024),
                glassGlowActive: NSColor(calibratedRed: 0.50, green: 0.98, blue: 0.88, alpha: 0.08),
                glassGlowIdle: NSColor(calibratedRed: 0.50, green: 0.98, blue: 0.88, alpha: 0.02),
                baseGlow: sceneColor.withAlphaComponent(0.05),
                plazaColor: NSColor(calibratedRed: 0.11, green: 0.18, blue: 0.17, alpha: 1.0),
                plazaEmission: NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.46, alpha: 0.06),
                roadColor: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.13, alpha: 1.0),
                roadEmission: NSColor(calibratedRed: 0.10, green: 0.50, blue: 0.44, alpha: 0.035),
                parkColor: NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.12, alpha: 1.0),
                parkEmission: sceneColor.withAlphaComponent(0.022),
                lampColor: NSColor(calibratedRed: 0.50, green: 0.98, blue: 0.88, alpha: 0.92),
                frontWindowActive: NSColor(calibratedRed: 0.70, green: 1.0, blue: 0.92, alpha: 0.88),
                frontWindowIdle: NSColor(calibratedRed: 0.70, green: 1.0, blue: 0.92, alpha: 0.28),
                sideWindowActive: NSColor(calibratedRed: 0.58, green: 0.96, blue: 0.86, alpha: 0.72),
                sideWindowIdle: NSColor(calibratedRed: 0.58, green: 0.96, blue: 0.86, alpha: 0.2)
            )
        case .developerTools:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.05),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.016),
                accentGlowActive: NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.28, alpha: 0.08),
                accentGlowIdle: NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.28, alpha: 0.024),
                glassGlowActive: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.48, alpha: 0.08),
                glassGlowIdle: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.48, alpha: 0.024),
                baseGlow: sceneColor.withAlphaComponent(0.055),
                plazaColor: NSColor(calibratedRed: 0.22, green: 0.15, blue: 0.14, alpha: 1.0),
                plazaEmission: NSColor(calibratedRed: 0.70, green: 0.22, blue: 0.14, alpha: 0.065),
                roadColor: NSColor(calibratedRed: 0.15, green: 0.10, blue: 0.10, alpha: 1.0),
                roadEmission: NSColor(calibratedRed: 0.68, green: 0.20, blue: 0.12, alpha: 0.04),
                parkColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.10, alpha: 1.0),
                parkEmission: sceneColor.withAlphaComponent(0.02),
                lampColor: NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.40, alpha: 0.92),
                frontWindowActive: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.62, alpha: 0.9),
                frontWindowIdle: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.62, alpha: 0.28),
                sideWindowActive: NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.54, alpha: 0.72),
                sideWindowIdle: NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.54, alpha: 0.2)
            )
        case .backgroundAgents:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.038),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.012),
                accentGlowActive: NSColor(calibratedRed: 0.50, green: 0.76, blue: 1.0, alpha: 0.07),
                accentGlowIdle: NSColor(calibratedRed: 0.50, green: 0.76, blue: 1.0, alpha: 0.02),
                glassGlowActive: NSColor(calibratedRed: 0.72, green: 0.88, blue: 1.0, alpha: 0.07),
                glassGlowIdle: NSColor(calibratedRed: 0.72, green: 0.88, blue: 1.0, alpha: 0.022),
                baseGlow: sceneColor.withAlphaComponent(0.042),
                plazaColor: NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.20, alpha: 1.0),
                plazaEmission: NSColor(calibratedRed: 0.24, green: 0.40, blue: 0.62, alpha: 0.05),
                roadColor: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1.0),
                roadEmission: NSColor(calibratedRed: 0.22, green: 0.36, blue: 0.54, alpha: 0.03),
                parkColor: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.15, alpha: 1.0),
                parkEmission: sceneColor.withAlphaComponent(0.018),
                lampColor: NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.0, alpha: 0.88),
                frontWindowActive: NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.84),
                frontWindowIdle: NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.24),
                sideWindowActive: NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.98, alpha: 0.66),
                sideWindowIdle: NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.98, alpha: 0.18)
            )
        case .other:
            return DistrictLightingProfile(
                facadeGlowActive: sceneColor.withAlphaComponent(0.028),
                facadeGlowIdle: sceneColor.withAlphaComponent(0.008),
                accentGlowActive: NSColor(calibratedWhite: 0.78, alpha: 0.05),
                accentGlowIdle: NSColor(calibratedWhite: 0.62, alpha: 0.016),
                glassGlowActive: NSColor(calibratedWhite: 0.82, alpha: 0.055),
                glassGlowIdle: NSColor(calibratedWhite: 0.72, alpha: 0.016),
                baseGlow: sceneColor.withAlphaComponent(0.03),
                plazaColor: NSColor(calibratedWhite: 0.18, alpha: 1.0),
                plazaEmission: NSColor(calibratedWhite: 0.42, alpha: 0.025),
                roadColor: NSColor(calibratedWhite: 0.11, alpha: 1.0),
                roadEmission: NSColor(calibratedWhite: 0.34, alpha: 0.015),
                parkColor: NSColor(calibratedWhite: 0.10, alpha: 1.0),
                parkEmission: NSColor(calibratedWhite: 0.34, alpha: 0.012),
                lampColor: NSColor(calibratedWhite: 0.86, alpha: 0.82),
                frontWindowActive: NSColor(calibratedWhite: 0.9, alpha: 0.78),
                frontWindowIdle: NSColor(calibratedWhite: 0.82, alpha: 0.2),
                sideWindowActive: NSColor(calibratedWhite: 0.88, alpha: 0.58),
                sideWindowIdle: NSColor(calibratedWhite: 0.78, alpha: 0.14)
            )
        }
    }

    func windowGlow(active: Bool, side: Bool) -> NSColor {
        let lighting = lightingProfile
        if side {
            return active ? lighting.sideWindowActive : lighting.sideWindowIdle
        }
        return active ? lighting.frontWindowActive : lighting.frontWindowIdle
    }

    static var layoutPositions: [ProcessCityDistrict: SIMD2<Float>] {
        [
            .systemCore: SIMD2(-92, -64),
            .userApps: SIMD2(0, -64),
            .networkSync: SIMD2(92, -64),
            .developerTools: SIMD2(-92, 64),
            .backgroundAgents: SIMD2(0, 64),
            .other: SIMD2(92, 64),
        ]
    }

    static func forProcess(_ process: ProcessStats) -> ProcessCityDistrict {
        let lowerName = process.name.lowercased()
        let path = process.executablePath.lowercased()
        let bundle = process.bundleIdentifier?.lowercased() ?? ""

        if ["kernel_task", "windowserver", "launchd", "logind", "sysmond", "runningboardd"].contains(lowerName) {
            return .systemCore
        }

        if lowerName.contains("xcode") || lowerName.contains("swift") || lowerName.contains("code") || lowerName.contains("clang") || lowerName.contains("git") || path.contains("/developer/") || bundle.contains("xcode") {
            return .developerTools
        }

        if lowerName.contains("cloud") || lowerName.contains("sync") || lowerName.contains("urlsession") || lowerName.contains("network") || lowerName.contains("vpn") || lowerName.contains("ssh") || lowerName.contains("mail") || lowerName.contains("bird") || lowerName.contains("backup") {
            return .networkSync
        }

        if path.contains("/applications/") || bundle.hasPrefix("com.") {
            return .userApps
        }

        if lowerName.hasSuffix("d") || lowerName.contains("agent") || lowerName.contains("helper") || lowerName.contains("service") {
            return .backgroundAgents
        }

        return .other
    }

    func matches(_ process: ProcessStats) -> Bool {
        Self.forProcess(process) == self
    }
}

#Preview {
    SystemCityView()
        .frame(width: 1280, height: 820)
}
