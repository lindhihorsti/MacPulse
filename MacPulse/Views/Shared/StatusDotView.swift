import SwiftUI

enum StatusLevel {
    case good
    case warning
    case critical
    case inactive

    var color: Color {
        switch self {
        case .good: return .success
        case .warning: return .warning
        case .critical: return .danger
        case .inactive: return .textTertiary
        }
    }
}

struct StatusDotView: View {
    let status: StatusLevel
    let size: CGFloat
    let animated: Bool

    @State private var isAnimating = false

    init(status: StatusLevel, size: CGFloat = 8, animated: Bool = false) {
        self.status = status
        self.size = size
        self.animated = animated
    }

    var body: some View {
        ZStack {
            if animated && status != .inactive {
                Circle()
                    .fill(status.color.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 0 : 0.8)
            }

            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
                .shadow(color: status.color.opacity(0.5), radius: 2)
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        StatusDotView(status: .good)
        StatusDotView(status: .warning)
        StatusDotView(status: .critical, animated: true)
        StatusDotView(status: .inactive)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
