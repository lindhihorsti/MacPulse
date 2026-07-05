import SwiftUI

extension Font {
    // MARK: - Display / Hero
    static let displayHero   = Font.system(size: 52, weight: .bold,     design: .rounded)
    static let displayLarge  = Font.system(size: 34, weight: .bold,     design: .rounded)
    static let displayMedium = Font.system(size: 22, weight: .semibold, design: .rounded)

    // MARK: - Metric Fonts (SF Pro Rounded for numbers)
    static let metricLarge  = Font.system(size: 48, weight: .semibold, design: .rounded)
    static let metricMedium = Font.system(size: 24, weight: .medium,   design: .rounded)
    static let metricSmall  = Font.system(size: 14, weight: .medium,   design: .rounded)

    // MARK: - Label & UI
    static let label       = Font.system(size: 12, weight: .regular)
    static let labelMedium = Font.system(size: 12, weight: .medium)
    static let cardTitle   = Font.system(size: 13, weight: .semibold)
    static let sectionHeader = Font.system(size: 11, weight: .semibold)

    // MARK: - Monospace (IPs, Ports, Process names)
    static let mono      = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 10, design: .monospaced)
    static let monoMedium = Font.system(size: 13, weight: .medium, design: .monospaced)
}
