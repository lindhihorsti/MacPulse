import SwiftUI

// MARK: - Settings Window

struct SettingsView: View {
    @AppStorage(MacPulseSettings.Key.refreshInterval)
    private var refreshInterval: Double = MacPulseSettings.Default.refreshInterval
    @AppStorage(MacPulseSettings.Key.cpuAlertThreshold)
    private var cpuAlertThreshold: Double = MacPulseSettings.Default.cpuAlertThreshold
    @AppStorage(MacPulseSettings.Key.memoryAlertThreshold)
    private var memoryAlertThreshold: Double = MacPulseSettings.Default.memoryAlertThreshold
    @AppStorage(MacPulseSettings.Key.alertsEnabled)
    private var alertsEnabled = MacPulseSettings.Default.alertsEnabled
    @AppStorage(MacPulseSettings.Key.showMenuBarIcon)
    private var showMenuBarIcon = MacPulseSettings.Default.showMenuBarIcon
    @AppStorage(MacPulseSettings.Key.menuBarShowCPU)
    private var menuBarShowCPU = MacPulseSettings.Default.menuBarShowCPU
    @AppStorage(MacPulseSettings.Key.menuBarShowMemory)
    private var menuBarShowMemory = MacPulseSettings.Default.menuBarShowMemory
    @AppStorage(MacPulseSettings.Key.launchAtLogin)
    private var launchAtLogin = MacPulseSettings.Default.launchAtLogin
    @AppStorage(MacPulseSettings.Key.privacyMode)
    private var privacyMode = MacPulseSettings.Default.privacyMode
    @AppStorage(MacPulseSettings.Key.appTheme)
    private var appTheme = MacPulseSettings.Default.appTheme

    @State private var selectedSection: SettingsSection = .general
    @State private var launchAtLoginError: String?
    @State private var isSyncingLaunchAtLogin = false

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general    = "General"
        case monitoring = "Monitoring"
        case alerts     = "Alerts"
        case diagnostics = "Diagnostics"
        case about      = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general:    return "gear"
            case .monitoring: return "chart.line.uptrend.xyaxis"
            case .alerts:     return "bell.badge"
            case .diagnostics: return "stethoscope"
            case .about:      return "info.circle"
            }
        }
        var color: Color {
            switch self {
            case .general:    return .appAccent
            case .monitoring: return .cpuColor
            case .alerts:     return .warning
            case .diagnostics: return .netColor
            case .about:      return .textSecondary
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(LinearGradient.accentGradient)
                            .frame(width: 24, height: 24)
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                }
                .padding(14)

                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(height: 1)

                // Nav items
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSidebarItem(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(8)

                Spacer()
            }
            .frame(width: 165)
            .background(Color.backgroundSecondary)

            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(width: 1)

            // Content pane
            ZStack {
                Color.backgroundPrimary
                Group {
                    switch selectedSection {
                    case .general:
                        GeneralSettingsContent(
                            appTheme: $appTheme,
                            showMenuBarIcon: $showMenuBarIcon,
                            menuBarShowCPU: $menuBarShowCPU,
                            menuBarShowMemory: $menuBarShowMemory,
                            launchAtLogin: $launchAtLogin,
                            privacyMode: $privacyMode,
                            launchAtLoginError: launchAtLoginError
                        )
                    case .monitoring:
                        MonitoringSettingsContent(refreshInterval: $refreshInterval)
                    case .alerts:
                        AlertSettingsContent(
                            alertsEnabled: $alertsEnabled,
                            cpuAlertThreshold: $cpuAlertThreshold,
                            memoryAlertThreshold: $memoryAlertThreshold
                        )
                    case .diagnostics:
                        DiagnosticsSettingsContent()
                    case .about:
                        AboutContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 560, height: 380)
        .background(Color.backgroundSecondary)
        .onAppear(perform: syncLaunchAtLoginState)
        .onChange(of: launchAtLogin) { _, enabled in
            updateLaunchAtLogin(enabled)
        }
    }

    private func syncLaunchAtLoginState() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = LaunchAtLoginManager.isEnabled
        isSyncingLaunchAtLogin = false
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard !isSyncingLaunchAtLogin else { return }

        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginError = nil
            isSyncingLaunchAtLogin = true
            launchAtLogin = LaunchAtLoginManager.isEnabled
            isSyncingLaunchAtLogin = false
        } catch {
            launchAtLoginError = error.localizedDescription
            isSyncingLaunchAtLogin = true
            launchAtLogin = LaunchAtLoginManager.isEnabled
            isSyncingLaunchAtLogin = false
        }
    }
}

// MARK: - Sidebar Item

private struct SettingsSidebarItem: View {
    let section: SettingsView.SettingsSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isSelected
                                ? section.color.opacity(0.18)
                                : (isHovered ? section.color.opacity(0.09) : Color.clear)
                        )
                        .frame(width: 26, height: 26)
                    Image(systemName: section.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isSelected ? section.color : (isHovered ? section.color.opacity(0.8) : .textSecondary)
                        )
                }
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .textPrimary : (isHovered ? .textPrimary : .textSecondary))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(section.color.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - General

private struct GeneralSettingsContent: View {
    @Binding var appTheme: String
    @Binding var showMenuBarIcon: Bool
    @Binding var menuBarShowCPU: Bool
    @Binding var menuBarShowMemory: Bool
    @Binding var launchAtLogin: Bool
    @Binding var privacyMode: Bool
    let launchAtLoginError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection(title: "Appearance") {
                    ThemePickerRow(selection: $appTheme)
                }

                SettingsSection(title: "Privacy") {
                    SettingsToggleRow(
                        icon: "eye.slash",
                        color: .netColor,
                        title: "Privacy Mode",
                        subtitle: "Mask IPs, MAC addresses, hostnames and process names where supported",
                        isOn: $privacyMode
                    )
                }

                SettingsSection(title: "Menu Bar") {
                    SettingsToggleRow(
                        icon: "menubar.rectangle",
                        color: .appAccent,
                        title: "Show in Menu Bar",
                        subtitle: "Display live metrics in the macOS menu bar",
                        isOn: $showMenuBarIcon
                    )
                    if showMenuBarIcon {
                        Divider().padding(.horizontal, 12)
                        SettingsToggleRow(
                            icon: "cpu",
                            color: .cpuColor,
                            title: "Show CPU Usage",
                            subtitle: "Display CPU % in the menu bar label",
                            isOn: $menuBarShowCPU
                        )
                        SettingsToggleRow(
                            icon: "memorychip",
                            color: .ramColor,
                            title: "Show Memory Usage",
                            subtitle: "Display RAM % in the menu bar label",
                            isOn: $menuBarShowMemory
                        )
                    }
                }

                SettingsSection(title: "Startup") {
                    SettingsToggleRow(
                        icon: "power",
                        color: .success,
                        title: "Launch at Login",
                        subtitle: "Start MacPulse automatically on login",
                        isOn: $launchAtLogin
                    )
                    if let launchAtLoginError {
                        Divider().padding(.horizontal, 12)
                        SettingsMessageRow(
                            icon: "exclamationmark.triangle.fill",
                            color: .warning,
                            text: launchAtLoginError
                        )
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Monitoring

private struct MonitoringSettingsContent: View {
    @Binding var refreshInterval: Double

    private let intervals: [(Double, String)] = [
        (0.5, "0.5 seconds — Fastest"),
        (1.0, "1 second — Default"),
        (2.0, "2 seconds — Balanced"),
        (5.0, "5 seconds — Low power"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection(title: "Refresh Rate") {
                    VStack(spacing: 0) {
                        ForEach(intervals, id: \.0) { value, label in
                            Button {
                                refreshInterval = value
                            } label: {
                                HStack {
                                    Text(label)
                                        .font(.system(size: 13))
                                        .foregroundStyle(refreshInterval == value ? .textPrimary : .textSecondary)
                                    Spacer()
                                    if refreshInterval == value {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.appAccent)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if value != intervals.last?.0 {
                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                }

                Text("Lower intervals give more responsive data but use slightly more CPU.")
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
    }
}

// MARK: - Alerts

private struct AlertSettingsContent: View {
    @Binding var alertsEnabled: Bool
    @Binding var cpuAlertThreshold: Double
    @Binding var memoryAlertThreshold: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection(title: "Notifications") {
                    SettingsToggleRow(
                        icon: "bell.badge",
                        color: .warning,
                        title: "Enable Alerts",
                        subtitle: "Show notification when thresholds are exceeded",
                        isOn: $alertsEnabled
                    )
                }

                if alertsEnabled {
                    SettingsSection(title: "Thresholds") {
                        VStack(spacing: 14) {
                            SettingsSliderRow(
                                icon: "cpu",
                                color: .cpuColor,
                                label: "CPU Alert",
                                value: $cpuAlertThreshold,
                                range: 50...100
                            )
                            Divider().padding(.horizontal, 12)
                            SettingsSliderRow(
                                icon: "memorychip",
                                color: .ramColor,
                                label: "Memory Alert",
                                value: $memoryAlertThreshold,
                                range: 50...100
                            )
                        }
                    }

                    Text("Alerts trigger after the threshold is exceeded for more than 10 seconds.")
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Diagnostics

private struct DiagnosticsSettingsContent: View {
    @State private var checks: [DiagnosticCheck] = []
    private let diagnosticsService = DiagnosticsService()

    private var issueCount: Int {
        checks.filter { $0.status != .ok }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsSection(title: "Health Checks") {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: issueCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(issueCount == 0 ? .success : .warning)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(issueCount == 0 ? "All checks passed" : "\(issueCount) checks need attention")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.textPrimary)
                                Text("Read-only diagnostics for capture access, system tools and settings")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.textTertiary)
                            }

                            Spacer()

                            Button {
                                refresh()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 26, height: 24)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.textSecondary)
                            .background(Color.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .help("Run diagnostics again")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        Divider().padding(.horizontal, 12)

                        if checks.isEmpty {
                            Text("No diagnostics have been run yet")
                                .font(.system(size: 12))
                                .foregroundStyle(.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(checks) { check in
                                DiagnosticCheckRow(check: check)
                                if check.id != checks.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }

                Text("Diagnostics only inspect local state. They do not install helpers, change permissions or run repair actions.")
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        checks = diagnosticsService.runChecks()
    }
}

private struct DiagnosticCheckRow: View {
    let check: DiagnosticCheck

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: check.status.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(check.status.color)
                .frame(width: 28, height: 28)
                .background(check.status.color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textPrimary)
                Text(check.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private extension DiagnosticStatus {
    var icon: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return .success
        case .warning: return .warning
        case .failed: return .danger
        }
    }
}

// MARK: - About

private struct AboutContent: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.appAccent.opacity(0.25), .clear],
                            center: .center, startRadius: 10, endRadius: 55
                        ))
                        .frame(width: 100, height: 100)
                        .blur(radius: 18)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 14)
                        .overlay {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }

                VStack(spacing: 5) {
                    Text("MacPulse")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.textPrimary)
                    Text("Version 1.0.0")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textTertiary)
                    Text("System & Network Monitor for macOS")
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                AboutLinkButton(title: "GitHub", icon: "arrow.up.right.square") {
                    // open GitHub
                }
                AboutLinkButton(title: "Report Issue", icon: "exclamationmark.bubble") {
                    // open issue
                }
            }
            .padding(.bottom, 20)
        }
    }
}

private struct AboutLinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isHovered ? .textPrimary : .textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isHovered ? Color.backgroundHover : Color.backgroundTertiary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared Settings Components

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.surfaceBorder, lineWidth: 1)
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ThemePickerRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.appAccent.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.appAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("App Theme")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textPrimary)
                Text("Switch between the bright and dark MacPulse design")
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(MacPulseTheme.allCases) { theme in
                    Button {
                        selection = theme.rawValue
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: theme.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(theme.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(selection == theme.rawValue ? Color.white : Color.textSecondary)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(selection == theme.rawValue ? Color.appAccent : Color.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(theme.title)
                }
            }
            .padding(3)
            .background(Color.backgroundTertiary.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct SettingsSliderRow: View {
    let icon: String
    let color: Color
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.14))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                    .frame(width: 40, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: 5)
                .tint(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsMessageRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.textSecondary)
                .lineLimit(3)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: Legacy tab items (kept for macOS Settings window compatibility)
struct GeneralSettingsTab: View {
    @AppStorage(MacPulseSettings.Key.appTheme)
    private var appTheme = MacPulseSettings.Default.appTheme
    @Binding var showMenuBarIcon: Bool
    @Binding var menuBarShowCPU: Bool
    @Binding var menuBarShowMemory: Bool
    @Binding var launchAtLogin: Bool
    @Binding var privacyMode: Bool
    var body: some View {
        GeneralSettingsContent(
            appTheme: $appTheme,
            showMenuBarIcon: $showMenuBarIcon,
            menuBarShowCPU: $menuBarShowCPU,
            menuBarShowMemory: $menuBarShowMemory,
            launchAtLogin: $launchAtLogin,
            privacyMode: $privacyMode,
            launchAtLoginError: nil
        )
    }
}
struct MonitoringSettingsTab: View {
    @Binding var refreshInterval: Double
    var body: some View { MonitoringSettingsContent(refreshInterval: $refreshInterval) }
}
struct AlertSettingsTab: View {
    @Binding var alertsEnabled: Bool
    @Binding var cpuAlertThreshold: Double
    @Binding var memoryAlertThreshold: Double
    var body: some View {
        AlertSettingsContent(
            alertsEnabled: $alertsEnabled,
            cpuAlertThreshold: $cpuAlertThreshold,
            memoryAlertThreshold: $memoryAlertThreshold
        )
    }
}
struct DiagnosticsSettingsTab: View {
    var body: some View { DiagnosticsSettingsContent() }
}
struct AboutTab: View {
    var body: some View { AboutContent() }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
