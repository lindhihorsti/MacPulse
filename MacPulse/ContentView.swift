import SwiftUI

// MARK: - Navigation Model

enum NavigationGroup: String, CaseIterable {
    case monitor   = "Monitor"
    case network   = "Network"
    case visualize = "Visualize"
}

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard    = "Dashboard"
    case network      = "Network"
    case processes    = "Processes"
    case storage      = "Storage Flow"
    case memoryFlow   = "Memory Flow"
    case activityStory = "Activity Story"
    case city         = "City"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard:     return "Dashboard"
        case .network:       return "Network"
        case .processes:     return "Processes"
        case .storage:       return "Storage"
        case .memoryFlow:    return "Memory"
        case .activityStory: return "Activity"
        case .city:          return "City View"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:     return "System overview"
        case .network:       return "Interfaces, devices & traffic"
        case .processes:     return "Running processes & load"
        case .storage:       return "Disk usage & flow analysis"
        case .memoryFlow:    return "Memory allocation & pressure"
        case .activityStory: return "System activity timeline"
        case .city:          return "3D system visualization"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:     return "chart.bar.xaxis"
        case .network:       return "network"
        case .processes:     return "list.bullet.rectangle.portrait"
        case .storage:       return "internaldrive"
        case .memoryFlow:    return "memorychip"
        case .activityStory: return "waveform.path.ecg"
        case .city:          return "building.2"
        }
    }

    var accentColor: Color {
        switch self {
        case .dashboard:     return .appAccent
        case .network:       return .netColor
        case .processes:     return .cpuColor
        case .storage:       return .diskColor
        case .memoryFlow:    return .ramColor
        case .activityStory: return .warning
        case .city:          return .gpuColor
        }
    }

    var group: NavigationGroup {
        switch self {
        case .dashboard, .processes, .storage, .memoryFlow: return .monitor
        case .network:                                       return .network
        case .activityStory, .city:                         return .visualize
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var deviceDiscovery = DeviceDiscoveryService()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main layout
            HStack(spacing: 0) {
                SidebarView(selectedItem: $selectedItem)

                // Thin separator
                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(width: 1)

                // Detail pane
                VStack(spacing: 0) {
                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    BottomStatusBar()
                }
                .background(Color.backgroundPrimary)
            }
            .background(Color.backgroundPrimary)

            // Launch splash overlay
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.7)) {
                                showSplash = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .network:
            NetworkView(deviceDiscovery: deviceDiscovery)
        case .processes:
            ProcessListView()
        case .storage:
            StorageFlowView()
        case .memoryFlow:
            MemoryFlowView()
        case .activityStory:
            ActivityStoryView()
        case .city:
            SystemCityView()
        case .none:
            VStack(spacing: 12) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(.textTertiary)
                Text("Select a view")
                    .font(.system(size: 14))
                    .foregroundStyle(.textTertiary)
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem?

    var body: some View {
        VStack(spacing: 0) {
            // Traffic-light safe area + App header
            VStack(spacing: 0) {
                Color.clear.frame(height: 22) // space for window buttons

                HStack(spacing: 10) {
                    // App icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient.accentGradient)
                            .frame(width: 28, height: 28)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.appAccent.opacity(0.45), radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("MacPulse")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.textPrimary)
                        Text("System Monitor")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.textTertiary)
                            .tracking(0.3)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }

            // Subtle separator
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, 8)

            // Navigation groups
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    ForEach(NavigationGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.textTertiary)
                                .tracking(1.4)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 3)

                            ForEach(group.items) { item in
                                SidebarItemView(
                                    item: item,
                                    isSelected: selectedItem == item
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                        selectedItem = item
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
            }

            Spacer(minLength: 0)

            // Bottom separator + settings
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, 8)

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 195)
        .background(Color.backgroundSecondary)
    }
}

extension NavigationGroup {
    var items: [NavigationItem] {
        NavigationItem.allCases.filter { $0.group == self }
    }
}

// MARK: - Sidebar Item

struct SidebarItemView: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar
                Capsule()
                    .fill(isSelected ? item.accentColor : .clear)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 5)
                    .padding(.trailing, 8)

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isSelected
                                ? item.accentColor.opacity(0.18)
                                : (isHovered ? item.accentColor.opacity(0.09) : Color.clear)
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isSelected ? item.accentColor : (isHovered ? item.accentColor.opacity(0.75) : .textSecondary)
                        )
                }

                // Label
                Text(item.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .textPrimary : (isHovered ? .textPrimary : .textSecondary))
                    .padding(.leading, 9)

                Spacer()

                // Active dot
                if isSelected {
                    Circle()
                        .fill(item.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.trailing, 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 36)
            .background {
                if isSelected || isHovered {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? item.accentColor.opacity(0.07) : Color.white.opacity(0.03))
                        .padding(.horizontal, 7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.75), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var appeared = false
    @State private var pulseGlow = false
    @State private var orbAnimate = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color.appAccent.opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: orbAnimate ? -60 : -120, y: orbAnimate ? -80 : -20)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: orbAnimate)

            Circle()
                .fill(Color.gpuColor.opacity(0.13))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: orbAnimate ? 100 : 60, y: orbAnimate ? 80 : 20)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: orbAnimate)

            VStack(spacing: 0) {
                // Logo badge
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(pulseGlow ? 0.18 : 0.08))
                        .frame(width: 110, height: 110)
                        .blur(radius: 22)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseGlow)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 22, y: 6)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: appeared)

                Spacer().frame(height: 24)

                Text("MacPulse")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.textPrimary)
                    .fadeSlideIn(appeared: appeared, delay: 0.25)

                Spacer().frame(height: 8)

                Text("Intelligent System Monitor")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.textSecondary)
                    .tracking(0.2)
                    .fadeSlideIn(appeared: appeared, delay: 0.4)

                Spacer().frame(height: 32)

                // Loading indicator
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.appAccent.opacity(appeared ? 0.7 : 0.2))
                            .frame(width: 6, height: 6)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: appeared
                            )
                    }
                }
                .fadeSlideIn(appeared: appeared, delay: 0.55)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            orbAnimate = true
            pulseGlow = true
        }
    }
}

#Preview {
    ContentView()
}
