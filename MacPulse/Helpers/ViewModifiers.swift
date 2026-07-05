import SwiftUI

// MARK: - Card Style (legacy, kept for compatibility)
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Glass Card
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 16
    var showBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.backgroundSecondary)
                    .overlay {
                        if showBorder {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.surfaceBorder, lineWidth: 1)
                        }
                    }
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 14, padding: CGFloat = 16, showBorder: Bool = true) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding, showBorder: showBorder))
    }
}

// MARK: - Hover Scale Effect
struct HoverScaleEffect: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.015

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.015) -> some View {
        modifier(HoverScaleEffect(scale: scale))
    }
}

// MARK: - Glow Effect
struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.55), radius: radius)
            .shadow(color: color.opacity(0.25), radius: radius * 2.2)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 6) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Pulse Animation
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 0.7)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulseEffect(color: Color) -> some View {
        modifier(PulseAnimation(color: color))
    }
}

// MARK: - Status Color
struct StatusColorModifier: ViewModifier {
    let value: Double
    let warningThreshold: Double
    let dangerThreshold: Double

    var statusColor: Color {
        if value >= dangerThreshold { return .danger }
        if value >= warningThreshold { return .warning }
        return .success
    }

    func body(content: Content) -> some View {
        content.foregroundStyle(statusColor)
    }
}

extension View {
    func statusColor(value: Double, warning: Double = 70, danger: Double = 90) -> some View {
        modifier(StatusColorModifier(value: value, warningThreshold: warning, dangerThreshold: danger))
    }
}

// MARK: - Slide-in Entrance
struct FadeSlideIn: ViewModifier {
    let appeared: Bool
    let delay: Double
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : offsetY)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(delay), value: appeared)
    }
}

extension View {
    func fadeSlideIn(appeared: Bool, delay: Double = 0, offsetY: CGFloat = 18) -> some View {
        modifier(FadeSlideIn(appeared: appeared, delay: delay, offsetY: offsetY))
    }
}
