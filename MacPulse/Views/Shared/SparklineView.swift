import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    let color: Color
    let showArea: Bool
    let height: CGFloat
    @AppStorage(MacPulseSettings.Key.appTheme)
    private var appTheme = MacPulseSettings.Default.appTheme

    init(
        data: [Double],
        color: Color = .appAccent,
        showArea: Bool = true,
        height: CGFloat = 60
    ) {
        self.data = data
        self.color = color
        self.showArea = showArea
        self.height = height
    }

    private var chartData: [(index: Int, value: Double)] {
        data.enumerated().map { (index: $0.offset, value: $0.element) }
    }

    private var maxValue: Double {
        max(data.max() ?? 100, 1)
    }

    private var isLightTheme: Bool {
        MacPulseTheme(rawValue: appTheme) == .light
    }

    var body: some View {
        Chart(chartData, id: \.index) { item in
            if showArea {
                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            color.opacity(isLightTheme ? 0.22 : 0.3),
                            color.opacity(isLightTheme ? 0.04 : 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            LineMark(
                x: .value("Time", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: isLightTheme ? 2.4 : 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...maxValue)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.backgroundTertiary.opacity(isLightTheme ? 0.42 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: height)
        .id("sparkline-\(appTheme)")
    }
}

#Preview {
    VStack {
        SparklineView(
            data: [20, 35, 28, 45, 52, 38, 65, 72, 58, 45],
            color: .cpuColor
        )

        SparklineView(
            data: [60, 62, 58, 65, 70, 68, 72, 75, 73, 78],
            color: .ramColor,
            showArea: false
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
