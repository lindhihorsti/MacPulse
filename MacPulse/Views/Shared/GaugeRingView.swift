import SwiftUI

struct GaugeRingView: View {
    let value: Double
    let maxValue: Double
    let lineWidth: CGFloat
    let color: Color
    let label: String?
    let showPercentage: Bool

    @State private var animatedValue: Double = 0

    init(
        value: Double,
        maxValue: Double = 100,
        lineWidth: CGFloat = 10,
        color: Color = .appAccent,
        label: String? = nil,
        showPercentage: Bool = true
    ) {
        self.value = value
        self.maxValue = maxValue
        self.lineWidth = lineWidth
        self.color = color
        self.label = label
        self.showPercentage = showPercentage
    }

    private var progress: Double {
        min(max(animatedValue / maxValue, 0), 1)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    // Dynamically shift color toward warning/danger at high load
    private var dynamicColor: Color {
        if progress >= 0.9 { return .danger }
        if progress >= 0.72 { return .warning }
        return color
    }

    private var glowRadius: CGFloat {
        progress > 0.8 ? 10 : (progress > 0.5 ? 5 : 3)
    }

    var body: some View {
        GeometryReader { geometry in
            let size        = min(geometry.size.width, geometry.size.height)
            let valueFSize  = size * 0.30
            let labelFSize  = size * 0.115

            ZStack {
                // Track ring
                Circle()
                    .stroke(dynamicColor.opacity(0.11), lineWidth: lineWidth)

                // Inner ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [dynamicColor.opacity(progress > 0.5 ? 0.06 : 0.02), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.4
                        )
                    )
                    .padding(lineWidth * 0.5)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        dynamicColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: dynamicColor.opacity(0.6), radius: glowRadius)
                    .animation(.spring(response: 0.5, dampingFraction: 0.72), value: dynamicColor)

                // Center labels
                VStack(spacing: 1) {
                    if showPercentage {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(percentage)")
                                .font(.system(size: valueFSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.textPrimary)
                            Text("%")
                                .font(.system(size: labelFSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    if let label {
                        Text(label)
                            .font(.system(size: labelFSize, weight: .medium))
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.65)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                animatedValue = newValue
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        GaugeRingView(value: 38, color: .cpuColor)
            .frame(width: 80, height: 80)
        GaugeRingView(value: 74, color: .ramColor)
            .frame(width: 100, height: 100)
        GaugeRingView(value: 93, color: .danger)
            .frame(width: 120, height: 120)
    }
    .padding(24)
    .background(Color.backgroundPrimary)
}
