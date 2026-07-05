import SwiftUI

struct BandwidthBarView: View {
    let downloadSpeed: Double
    let uploadSpeed: Double
    let maxSpeed: Double

    init(downloadSpeed: Double, uploadSpeed: Double, maxSpeed: Double = 100) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.maxSpeed = maxSpeed
    }

    private var downloadProgress: Double {
        min(downloadSpeed / maxSpeed, 1.0)
    }

    private var uploadProgress: Double {
        min(uploadSpeed / maxSpeed, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Download bar
            HStack(spacing: 8) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.success)
                    .frame(width: 16)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.success.opacity(0.2))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.success)
                            .frame(width: geometry.size.width * downloadProgress)
                            .animation(.spring(duration: 0.4), value: downloadProgress)
                    }
                }
                .frame(height: 6)

                Text(formatSpeed(downloadSpeed))
                    .font(.mono)
                    .foregroundStyle(.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }

            // Upload bar
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.appAccent)
                    .frame(width: 16)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appAccent.opacity(0.2))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appAccent)
                            .frame(width: geometry.size.width * uploadProgress)
                            .animation(.spring(duration: 0.4), value: uploadProgress)
                    }
                }
                .frame(height: 6)

                Text(formatSpeed(uploadSpeed))
                    .font(.mono)
                    .foregroundStyle(.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value < 10 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BandwidthBarView(
            downloadSpeed: 5_500_000,
            uploadSpeed: 1_200_000,
            maxSpeed: 10_000_000
        )

        BandwidthBarView(
            downloadSpeed: 125_000,
            uploadSpeed: 45_000,
            maxSpeed: 1_000_000
        )
    }
    .padding()
    .frame(width: 300)
    .background(Color.backgroundPrimary)
}
