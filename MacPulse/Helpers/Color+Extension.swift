import SwiftUI

extension Color {
    // MARK: - Background Hierarchy
    static let backgroundPrimary   = Color(hex: 0x080B12)   // Deepest — near-black with blue undertone
    static let backgroundSecondary = Color(hex: 0x0D1321)   // Cards — dark navy
    static let backgroundTertiary  = Color(hex: 0x141C2E)   // Elevated — deep navy
    static let backgroundHover     = Color(hex: 0x1C2840)   // Hover/active state

    // MARK: - Surface Borders
    static let surfaceBorder       = Color.white.opacity(0.07)
    static let surfaceBorderMedium = Color.white.opacity(0.13)

    // MARK: - Accent Colors (Status-based)
    static let appAccent = Color(hex: 0x4F7AFF)   // Electric blue
    static let success   = Color(hex: 0x10B981)   // Emerald
    static let warning   = Color(hex: 0xF59E0B)   // Amber
    static let danger    = Color(hex: 0xEF4444)   // Red

    // MARK: - Component Colors
    static let cpuColor  = Color(hex: 0x4F7AFF)   // Blue
    static let ramColor  = Color(hex: 0x10B981)   // Emerald
    static let diskColor = Color(hex: 0xF59E0B)   // Amber
    static let gpuColor  = Color(hex: 0xA78BFA)   // Lavender
    static let netColor  = Color(hex: 0x06B6D4)   // Cyan

    // MARK: - Text Colors
    static let textPrimary   = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.50)
    static let textTertiary  = Color.white.opacity(0.28)

    // MARK: - Hex Initializer
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double( hex        & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - ShapeStyle convenience accessors
extension ShapeStyle where Self == Color {
    static var backgroundPrimary:   Color { .backgroundPrimary }
    static var backgroundSecondary: Color { .backgroundSecondary }
    static var backgroundTertiary:  Color { .backgroundTertiary }
    static var backgroundHover:     Color { .backgroundHover }
    static var surfaceBorder:       Color { .surfaceBorder }
    static var textPrimary:         Color { .textPrimary }
    static var textSecondary:       Color { .textSecondary }
    static var textTertiary:        Color { .textTertiary }
    static var appAccent:           Color { .appAccent }
    static var success:             Color { .success }
    static var warning:             Color { .warning }
    static var danger:              Color { .danger }
    static var cpuColor:            Color { .cpuColor }
    static var ramColor:            Color { .ramColor }
    static var diskColor:           Color { .diskColor }
    static var gpuColor:            Color { .gpuColor }
    static var netColor:            Color { .netColor }
}

// MARK: - Gradient Presets
extension LinearGradient {
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x4F7AFF), Color(hex: 0x7C5CF5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x10B981), Color(hex: 0x059669)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static var dangerGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xEF4444), Color(hex: 0xF97316)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
