import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    let color: Color
    let showArea: Bool
    let height: CGFloat

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

    var body: some View {
        Chart(chartData, id: \.index) { item in
            if showArea {
                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
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
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...maxValue)
        .frame(height: height)
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
