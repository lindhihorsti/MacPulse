import SwiftUI

@main
struct MacPulseApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var monitor = SystemMonitorService()
    @State private var showOnboarding = !MacPulseSettings.bool(
        forKey: MacPulseSettings.Key.hasCompletedOnboarding,
        defaultValue: MacPulseSettings.Default.hasCompletedOnboarding
    )
    @AppStorage(MacPulseSettings.Key.showMenuBarIcon)
    private var showMenuBarIcon = MacPulseSettings.Default.showMenuBarIcon
    @AppStorage(MacPulseSettings.Key.refreshInterval)
    private var refreshInterval = MacPulseSettings.Default.refreshInterval

    var body: some Scene {
        // MARK: Main Window
        WindowGroup(id: AppWindowID.main) {
            ContentView()
                .frame(minWidth: 1020, minHeight: 720)
                .environment(monitor)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onAppear {
                    if let window = NSApp.mainWindow ?? NSApp.keyWindow {
                        window.identifier = NSUserInterfaceItemIdentifier(AppWindowID.main)
                        window.title = "MacPulse"
                    }
                    monitor.start(interval: refreshInterval)
                    setupAlertMonitoring()
                }
                .onChange(of: refreshInterval) { _, newValue in
                    monitor.start(interval: max(newValue, 0.5))
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") { openWindow(id: AppWindowID.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        // MARK: Settings
        Window("Settings", id: AppWindowID.settings) {
            SettingsView()
                .frame(width: 560, height: 380)
        }
        .windowResizability(.contentSize)

        // MARK: Menu Bar
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(monitor: monitor) { openMainWindow() }
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == AppWindowID.main }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            openWindow(id: AppWindowID.main)
        }
    }

    private func setupAlertMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let memUsage = Double(monitor.memoryStats.used) / Double(max(monitor.memoryStats.total, 1)) * 100
            AlertService.shared.checkThresholds(
                cpuUsage: monitor.cpuStats.usage,
                memoryUsage: memUsage
            )
        }
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let monitor: SystemMonitorService
    @AppStorage(MacPulseSettings.Key.menuBarShowCPU)
    private var showCPU = MacPulseSettings.Default.menuBarShowCPU
    @AppStorage(MacPulseSettings.Key.menuBarShowMemory)
    private var showMemory = MacPulseSettings.Default.menuBarShowMemory

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .semibold))
            if showCPU {
                HStack(spacing: 2) {
                    MiniBarView(value: monitor.cpuStats.usage / 100, color: cpuBarColor)
                    Text(String(format: "%.0f", monitor.cpuStats.usage))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
            if showMemory {
                let pct = Double(monitor.memoryStats.used) / Double(max(monitor.memoryStats.total, 1)) * 100
                HStack(spacing: 2) {
                    MiniBarView(value: pct / 100, color: memBarColor(pct))
                    Text(String(format: "%.0f", pct))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
        }
    }

    private var cpuBarColor: Color {
        if monitor.cpuStats.usage > 80 { return .danger }
        if monitor.cpuStats.usage > 50 { return .warning }
        return .success
    }

    private func memBarColor(_ pct: Double) -> Color {
        if pct > 85 { return .danger }
        if pct > 70 { return .warning }
        return .success
    }
}

struct MiniBarView: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color.gray.opacity(0.25))
                Rectangle()
                    .fill(color)
                    .frame(height: geo.size.height * min(value, 1.0))
            }
        }
        .frame(width: 4, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 1))
    }
}

// MARK: - Onboarding / Landing View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var appeared  = false
    @State private var orbAnimate = false

    private let features: [(icon: String, title: String, desc: String, color: Color)] = [
        ("chart.bar.xaxis",                "System Intelligence",   "CPU, GPU, memory & disk — all in real-time",           .appAccent),
        ("network",                        "Network Radar",         "Discover devices, trace connections, capture packets",  .netColor),
        ("bell.badge",                     "Smart Alerts",          "Threshold monitoring with instant notifications",        .warning),
        ("menubar.rectangle",              "Always-On Status",      "Live metrics in the menu bar, always accessible",       .ramColor),
    ]

    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary.ignoresSafeArea()

            // Ambient glow orbs
            Circle()
                .fill(Color.appAccent.opacity(0.16))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: orbAnimate ? -50 : -110, y: orbAnimate ? -130 : -60)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: orbAnimate)

            Circle()
                .fill(Color.gpuColor.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: orbAnimate ? 110 : 50, y: orbAnimate ? 120 : 50)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: orbAnimate)

            Circle()
                .fill(Color.netColor.opacity(0.09))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: orbAnimate ? -20 : 80, y: orbAnimate ? 160 : 80)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: orbAnimate)

            // Main content
            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appAccent.opacity(0.3), .clear],
                                center: .center, startRadius: 10, endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 28)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.appAccent.opacity(0.55), radius: 28, y: 8)
                        .overlay {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
                .scaleEffect(appeared ? 1 : 0.55)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.75, dampingFraction: 0.58), value: appeared)

                Spacer().frame(height: 22)

                // App name + tagline
                VStack(spacing: 7) {
                    Text("MacPulse")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.textPrimary)

                    Text("Intelligent System Monitor")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.textSecondary)
                        .tracking(0.3)
                }
                .fadeSlideIn(appeared: appeared, delay: 0.28)

                Spacer().frame(height: 32)

                // Feature list
                VStack(spacing: 10) {
                    ForEach(0..<features.count, id: \.self) { i in
                        OnboardingFeatureRow(
                            icon: features[i].icon,
                            title: features[i].title,
                            description: features[i].desc,
                            color: features[i].color
                        )
                        .fadeSlideIn(appeared: appeared, delay: 0.46 + Double(i) * 0.1)
                    }
                }
                .padding(.horizontal, 34)

                Spacer()

                // Permissions note + CTA
                VStack(spacing: 14) {
                    Text("Some features require network & notification permissions")
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            UserDefaults.standard.set(true, forKey: MacPulseSettings.Key.hasCompletedOnboarding)
                            isPresented = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: Color.appAccent.opacity(0.45), radius: 16, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 34)
                    .hoverScale(1.02)
                }
                .fadeSlideIn(appeared: appeared, delay: 0.9)

                Spacer().frame(height: 32)
            }
        }
        .frame(width: 520, height: 660)
        .onAppear {
            withAnimation { appeared = true }
            orbAnimate = true
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.backgroundSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isHovered ? Color.surfaceBorderMedium : Color.surfaceBorder, lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
