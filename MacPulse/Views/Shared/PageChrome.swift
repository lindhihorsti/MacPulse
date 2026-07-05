import SwiftUI

// MARK: - Page Header

struct PageHeaderView<Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(Color.backgroundSecondary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.surfaceBorder).frame(height: 1)
        }
    }
}

extension PageHeaderView where Trailing == EmptyView {
    init(title: String, subtitle: String = "", icon: String, iconColor: Color) {
        self.init(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor) {
            EmptyView()
        }
    }
}

// MARK: - Sub Tab Bar

struct SubTabBar: View {
    struct Tab: Identifiable {
        let id: Int
        let icon: String
        let title: String
    }

    let tabs: [Tab]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    SubTabButton(
                        icon: tab.icon,
                        title: tab.title,
                        isSelected: selectedIndex == tab.id
                    ) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            selectedIndex = tab.id
                        }
                    }
                }
            }
        }
        .frame(height: 40)
        .background(Color.backgroundPrimary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.surfaceBorder).frame(height: 1)
        }
    }
}

struct SubTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .appAccent : (isHovered ? .textPrimary : .textSecondary))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background {
                if isSelected {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.08))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.appAccent)
                                .frame(height: 2)
                        }
                } else if isHovered {
                    Rectangle()
                        .fill(Color.white.opacity(0.035))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Bottom Status Bar

struct BottomStatusBar: View {
    @Environment(SystemMonitorService.self) private var monitor: SystemMonitorService?

    var body: some View {
        HStack(spacing: 14) {
            // Live metrics
            HStack(spacing: 8) {
                MiniStatPill(
                    label: "CPU",
                    value: monitor?.cpuStats.usage ?? 0,
                    color: cpuPillColor
                )
                MiniStatPill(
                    label: "RAM",
                    value: ramPercent,
                    color: ramPillColor
                )
            }

            Spacer()

            // Live clock
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(ctx.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(Color.backgroundSecondary)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.surfaceBorder).frame(height: 1)
        }
    }

    private var ramPercent: Double {
        guard let m = monitor else { return 0 }
        return Double(m.memoryStats.used) / Double(max(m.memoryStats.total, 1)) * 100
    }
    private var cpuPillColor: Color {
        let v = monitor?.cpuStats.usage ?? 0
        if v > 85 { return .danger }
        if v > 65 { return .warning }
        return .cpuColor
    }
    private var ramPillColor: Color {
        if ramPercent > 85 { return .danger }
        if ramPercent > 70 { return .warning }
        return .ramColor
    }
}

struct MiniStatPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
            }
            .frame(width: 13, height: 13)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.textTertiary)

            Text(String(format: "%.0f%%", value))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Action Button Style (shared across page headers)

struct HeaderActionButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isLoading ? "arrow.trianglehead.2.clockwise.rotate.90" : icon)
                    .font(.system(size: 11, weight: .medium))
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                Text(isLoading ? "Scanning…" : title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isLoading ? .textTertiary : (isHovered ? .textPrimary : .textSecondary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.backgroundHover : Color.backgroundTertiary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
