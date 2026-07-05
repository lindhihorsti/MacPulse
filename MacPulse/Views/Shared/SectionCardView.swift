import SwiftUI

struct SectionCardView<Content: View>: View {
    let title: String
    let icon: String?
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = .appAccent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card header
            HStack(spacing: 9) {
                if let icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(iconColor.opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer()
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.backgroundSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isHovered ? Color.surfaceBorderMedium : Color.surfaceBorder,
                            lineWidth: 1
                        )
                }
        }
        .scaleEffect(isHovered ? 1.006 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    SectionCardView(title: "CPU", icon: "cpu", iconColor: .cpuColor) {
        Text("78%")
            .font(.metricLarge)
            .foregroundStyle(.textPrimary)
    }
    .frame(width: 320)
    .padding()
    .background(Color.backgroundPrimary)
}
