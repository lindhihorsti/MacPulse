import Foundation
import simd

@Observable
final class ForceLayoutEngine {
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []

    // Physics parameters
    var repulsionStrength: Double = 8000
    var attractionStrength: Double = 0.015
    var centeringStrength: Double = 0.01
    var damping: Double = 0.9
    var minDistance: Double = 100

    // 3D rotation
    var rotationX: Double = 0
    var rotationY: Double = 0
    var autoRotate: Bool = true

    // Router node ID (center of gravity)
    var routerNodeId: String?
    var localNodeId: String?

    func updateFromDevices(_ devices: [NetworkDevice], gatewayIP: String, localIP: String) {
        let existingPositions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
        let existingPinned = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.isPinned) })

        var newNodes: [GraphNode] = []
        var newEdges: [GraphEdge] = []

        // First pass: find router by isRouter flag OR by matching gatewayIP
        routerNodeId = nil
        localNodeId = nil
        for device in devices {
            if device.isRouter || device.ipAddress == gatewayIP {
                routerNodeId = device.id
            }
            if device.isLocalDevice || device.ipAddress == localIP {
                localNodeId = device.id
            }
        }

        // Second pass: create nodes with 3D sphere positioning
        let deviceCount = devices.count
        var nonRouterIndex = 0

        for device in devices {
            var node = GraphNode(device: device)
            let isThisRouter = (device.id == routerNodeId) || device.isRouter || device.ipAddress == gatewayIP

            // Preserve existing position if node existed
            if let existingPos = existingPositions[device.id] {
                node.position = existingPos
                if let pinned = existingPinned[device.id] {
                    node.isPinned = pinned
                }
            } else {
                // New node - position on a sphere around center
                if isThisRouter {
                    node.position = SIMD3<Double>(0, 0, 0)
                    node.isPinned = true
                    node.baseRadius = 30  // Make router bigger
                } else {
                    // Fibonacci sphere distribution for even spacing
                    let phi = .pi * (3.0 - sqrt(5.0)) // Golden angle
                    let totalNonRouter = max(deviceCount - 1, 1)
                    let y = 1.0 - (Double(nonRouterIndex) / Double(totalNonRouter)) * 2.0
                    let radiusAtY = sqrt(max(0, 1.0 - y * y))
                    let theta = phi * Double(nonRouterIndex)

                    let sphereRadius = 180.0 + Double.random(in: -20...20)
                    node.position = SIMD3<Double>(
                        cos(theta) * radiusAtY * sphereRadius,
                        y * sphereRadius,
                        sin(theta) * radiusAtY * sphereRadius
                    )
                    nonRouterIndex += 1
                }
            }

            newNodes.append(node)
        }

        // Third pass: create edges (after all nodes exist)
        if let routerId = routerNodeId {
            for node in newNodes {
                if node.id != routerId {
                    newEdges.append(GraphEdge(from: node.id, to: routerId))
                }
            }
        }

        nodes = newNodes
        edges = newEdges
    }

    func step(deltaTime: Double) {
        guard !nodes.isEmpty else { return }

        let dt = min(deltaTime, 0.05)

        // Auto-rotate
        if autoRotate {
            rotationY += dt * 0.3
        }

        // Calculate 3D forces
        var forces = [String: SIMD3<Double>]()
        for node in nodes {
            forces[node.id] = .zero
        }

        // Repulsion between all nodes (3D)
        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let nodeA = nodes[i]
                let nodeB = nodes[j]

                var delta = nodeA.position - nodeB.position
                var distance = simd_length(delta)

                if distance < 1 {
                    delta = SIMD3<Double>(
                        Double.random(in: -1...1),
                        Double.random(in: -1...1),
                        Double.random(in: -1...1)
                    )
                    distance = 1
                }

                let direction = delta / distance
                let force = repulsionStrength / (distance * distance)
                let forceVector = direction * force

                forces[nodeA.id]! += forceVector
                forces[nodeB.id]! -= forceVector
            }
        }

        // Attraction along edges (3D)
        for edge in edges {
            guard let sourceIndex = nodes.firstIndex(where: { $0.id == edge.sourceId }),
                  let targetIndex = nodes.firstIndex(where: { $0.id == edge.targetId }) else { continue }

            let source = nodes[sourceIndex]
            let target = nodes[targetIndex]

            let delta = target.position - source.position
            let distance = simd_length(delta)

            if distance > minDistance {
                let direction = delta / distance
                let force = (distance - minDistance) * attractionStrength
                let forceVector = direction * force

                forces[source.id]! += forceVector
                forces[target.id]! -= forceVector
            }
        }

        // Centering force (3D)
        for node in nodes {
            let distance = simd_length(node.position)
            if distance > 10 {
                let direction = -node.position / distance
                forces[node.id]! += direction * centeringStrength * distance
            }
        }

        // Apply forces and update positions
        for i in 0..<nodes.count {
            // Keep router at center
            if nodes[i].id == routerNodeId {
                nodes[i].position = SIMD3<Double>(0, 0, 0)
                nodes[i].velocity = .zero
                continue
            }

            guard !nodes[i].isPinned else { continue }

            let force = forces[nodes[i].id] ?? .zero
            nodes[i].velocity += force * dt
            nodes[i].velocity *= damping
            nodes[i].position += nodes[i].velocity * dt

            // Clamp velocity
            let speed = simd_length(nodes[i].velocity)
            if speed > 300 {
                nodes[i].velocity = nodes[i].velocity / speed * 300
            }
        }
    }

    // Apply 3D rotation and return 2D projected position
    func projectNode(_ node: GraphNode) -> (x: Double, y: Double, scale: Double, depth: Double) {
        // Apply rotation
        var pos = node.position

        // Rotate around Y axis
        let cosY = cos(rotationY)
        let sinY = sin(rotationY)
        let rotatedX = pos.x * cosY - pos.z * sinY
        let rotatedZ = pos.x * sinY + pos.z * cosY
        pos.x = rotatedX
        pos.z = rotatedZ

        // Rotate around X axis
        let cosX = cos(rotationX)
        let sinX = sin(rotationX)
        let rotatedY = pos.y * cosX - pos.z * sinX
        let rotatedZ2 = pos.y * sinX + pos.z * cosX
        pos.y = rotatedY
        pos.z = rotatedZ2

        // Perspective projection
        let cameraDistance: Double = 600
        let depth = cameraDistance / (cameraDistance + pos.z)
        let projectedX = pos.x * depth
        let projectedY = pos.y * depth

        return (projectedX, projectedY, depth, pos.z)
    }

    func updatePulseOffsets(deltaTime: Double) {
        for i in 0..<edges.count {
            edges[i].pulseOffset += deltaTime * 0.8 * (0.5 + edges[i].trafficIntensity)
            if edges[i].pulseOffset > 1 {
                edges[i].pulseOffset -= 1
            }
        }
    }

    func nodeAt(screenPosition: SIMD2<Double>, scale: CGFloat, offset: CGSize) -> GraphNode? {
        // Sort nodes by depth (front to back) for proper hit testing
        let sortedNodes = nodes.sorted { projectNode($0).depth > projectNode($1).depth }

        for node in sortedNodes {
            let proj = projectNode(node)
            let screenX = proj.x * Double(scale)
            let screenY = proj.y * Double(scale)
            let nodeScreenPos = SIMD2<Double>(screenX, screenY)

            let distance = simd_length(screenPosition - nodeScreenPos)
            let projectedRadius = node.baseRadius * proj.scale * Double(scale)

            if distance <= projectedRadius {
                return node
            }
        }
        return nil
    }

    func moveNode(id: String, to screenPosition: SIMD2<Double>, scale: CGFloat) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            // Convert screen position back to 3D (approximate, keep z)
            let currentZ = nodes[index].position.z
            nodes[index].position = SIMD3<Double>(
                screenPosition.x / Double(scale),
                screenPosition.y / Double(scale),
                currentZ
            )
            nodes[index].velocity = .zero
        }
    }

    func pinNode(id: String, pinned: Bool) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].isPinned = pinned
        }
    }

    func setHovered(id: String?, hovered: Bool) {
        for i in 0..<nodes.count {
            if nodes[i].id == id {
                nodes[i].isHovered = hovered
            } else {
                nodes[i].isHovered = false
            }
        }
    }

    func setSelected(id: String?) {
        for i in 0..<nodes.count {
            nodes[i].isSelected = (nodes[i].id == id)
        }
    }

    func rotate(deltaX: Double, deltaY: Double) {
        rotationY += deltaX * 0.01
        rotationX += deltaY * 0.01
        rotationX = max(-.pi / 3, min(.pi / 3, rotationX)) // Limit vertical rotation
    }
}
