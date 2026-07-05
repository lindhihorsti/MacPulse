import SwiftUI

struct BPFPermissionBanner: View {
    let errorMessage: String
    var onDismiss: (() -> Void)?
    var onRetry: (() -> Void)?

    @State private var isFixing = false
    @State private var fixResult: String?
    @State private var showPermanentOption = false

    var isBPFError: Bool {
        BPFPermissionHelper.isBPFPermissionError(errorMessage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main error row
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.warning)

                VStack(alignment: .leading, spacing: 2) {
                    if isBPFError {
                        Text("Packet capture requires BPF device access")
                            .font(.system(size: 13, weight: .medium))
                        Text("MacPulse needs read access to /dev/bpf* to capture network traffic.")
                            .font(.system(size: 11))
                            .foregroundStyle(.textSecondary)
                    } else {
                        Text(errorMessage)
                            .font(.system(size: 13))
                    }
                }

                Spacer()

                if isBPFError {
                    if isFixing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 4)
                    } else {
                        HStack(spacing: 8) {
                            Button("Fix Now") {
                                applyFix()
                            }
                            .buttonStyle(AccentButtonStyle())

                            Button {
                                showPermanentOption.toggle()
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.textSecondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            // Fix result feedback
            if let result = fixResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundStyle(result.contains("successfully") ? .success : .danger)
            }

            // Permanent fix option
            if showPermanentOption && isBPFError {
                Divider()
                    .background(Color.warning.opacity(0.3))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Permanent Fix")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Text("\"Fix Now\" grants access until the next reboot. Install a system daemon to make this permanent.")
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)

                    HStack(spacing: 8) {
                        Button("Install LaunchDaemon (permanent)") {
                            installDaemon()
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(isFixing)

                        Text("Requires admin password")
                            .font(.system(size: 10))
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.warning.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(.warning),
            alignment: .leading
        )
    }

    private func applyFix() {
        isFixing = true
        fixResult = nil
        BPFPermissionHelper.grantPermission { success, error in
            isFixing = false
            if success {
                fixResult = "Access granted successfully. Starting capture..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onRetry?()
                    onDismiss?()
                }
            } else {
                fixResult = "Failed: \(error ?? "Unknown error")"
            }
        }
    }

    private func installDaemon() {
        isFixing = true
        fixResult = nil
        BPFPermissionHelper.installLaunchDaemon { success, error in
            isFixing = false
            if success {
                fixResult = "LaunchDaemon installed. BPF access will persist across reboots."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onRetry?()
                    onDismiss?()
                }
            } else {
                fixResult = "Failed: \(error ?? "Unknown error")"
            }
        }
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appAccent.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
