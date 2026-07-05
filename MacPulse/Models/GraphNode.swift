import Foundation
import simd

struct GraphNode: Identifiable {
    let id: String
    var position: SIMD3<Double>  // x, y, z for 3D
    var velocity: SIMD3<Double> = .zero
    var isPinned: Bool = false

    // Device data
    let device: NetworkDevice

    // Visual properties
    var baseRadius: Double = 20
    var isHovered: Bool = false
    var isSelected: Bool = false

    init(device: NetworkDevice, position: SIMD3<Double>? = nil) {
        self.id = device.id
        self.device = device
        self.position = position ?? SIMD3<Double>(
            Double.random(in: -150...150),
            Double.random(in: -150...150),
            Double.random(in: -100...100)
        )

        // Larger radius for router
        if device.isRouter {
            self.baseRadius = 28
        } else if device.isLocalDevice {
            self.baseRadius = 24
        }
    }

    // Projected radius based on depth (perspective)
    func projectedRadius(cameraDistance: Double = 500) -> Double {
        let depth = cameraDistance / (cameraDistance + position.z)
        return baseRadius * depth
    }

    // Projected 2D position
    func projected2D(cameraDistance: Double = 500) -> SIMD2<Double> {
        let depth = cameraDistance / (cameraDistance + position.z)
        return SIMD2<Double>(position.x * depth, position.y * depth)
    }

    // Depth factor for opacity/effects (0 = far, 1 = close)
    func depthFactor(cameraDistance: Double = 500) -> Double {
        let normalizedZ = (position.z + 200) / 400  // Map -200...200 to 0...1
        return max(0.3, min(1.0, normalizedZ))
    }
}

struct GraphEdge: Identifiable {
    let id: String
    let sourceId: String
    let targetId: String
    var trafficIntensity: Double = 0.5 // 0-1 scale
    var pulseOffset: Double = 0

    init(from sourceId: String, to targetId: String) {
        self.id = "\(sourceId)-\(targetId)"
        self.sourceId = sourceId
        self.targetId = targetId
    }
}
