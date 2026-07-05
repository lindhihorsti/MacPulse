import SwiftUI

enum CityVisualMode: String, CaseIterable, Identifiable {
    case live = "Live"
    case thermal = "Thermal"
    case memory = "Memory"
    case network = "Network"
    case risk = "Risk"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .live: return "sparkles"
        case .thermal: return "flame.fill"
        case .memory: return "memorychip.fill"
        case .network: return "point.3.connected.trianglepath.dotted"
        case .risk: return "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .live: return .appAccent
        case .thermal: return .warning
        case .memory: return .ramColor
        case .network: return .netColor
        case .risk: return .danger
        }
    }
}

enum CityCameraPreset: String, CaseIterable, Identifiable {
    case skyline = "Skyline"
    case orbit = "Orbit"
    case street = "Street"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .skyline: return "building.2.fill"
        case .orbit: return "rotate.3d"
        case .street: return "road.lanes"
        }
    }
}
