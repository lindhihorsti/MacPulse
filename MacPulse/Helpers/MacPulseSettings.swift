import Foundation

enum MacPulseSettings {
    enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let menuBarShowCPU = "menuBarShowCPU"
        static let menuBarShowMemory = "menuBarShowMemory"
        static let launchAtLogin = "launchAtLogin"
        static let privacyMode = "privacyMode"
        static let refreshInterval = "refreshInterval"
        static let alertsEnabled = "alertsEnabled"
        static let cpuAlertThreshold = "cpuAlertThreshold"
        static let memoryAlertThreshold = "memoryAlertThreshold"
        static let appTheme = "appTheme"
    }

    enum Default {
        static let hasCompletedOnboarding = false
        static let showMenuBarIcon = true
        static let menuBarShowCPU = true
        static let menuBarShowMemory = false
        static let launchAtLogin = false
        static let privacyMode = false
        static let refreshInterval = 1.0
        static let alertsEnabled = true
        static let cpuAlertThreshold = 90.0
        static let memoryAlertThreshold = 85.0
        static let appTheme = MacPulseTheme.dark.rawValue
    }

    static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    static func double(forKey key: String, defaultValue: Double) -> Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        let value = defaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }
}

enum MacPulseTheme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    static var current: MacPulseTheme {
        let rawValue = UserDefaults.standard.string(forKey: MacPulseSettings.Key.appTheme) ?? MacPulseSettings.Default.appTheme
        return MacPulseTheme(rawValue: rawValue) ?? .dark
    }
}
