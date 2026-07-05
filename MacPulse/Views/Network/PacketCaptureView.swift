import SwiftUI
import UniformTypeIdentifiers

struct PacketCaptureView: View {
    @State private var captureService = PacketCaptureService()
    @State private var selectedPacket: PacketInfo?
    @State private var showExportDialog = false
    @State private var filterProtocol: PacketProtocol?

    var filteredPackets: [PacketInfo] {
        if let proto = filterProtocol {
            return captureService.packets.filter { $0.protocol == proto }
        }
        return captureService.packets
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                // Interface picker
                Picker("Interface", selection: $captureService.selectedInterface) {
                    ForEach(PacketCaptureService.availableInterfaces(), id: \.self) { iface in
                        Text(iface).tag(iface)
                    }
                }
                .frame(width: 120)

                // BPF Filter
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.textSecondary)
                    TextField("BPF Filter (e.g., tcp port 443)", text: $captureService.bpfFilter)
                        .textFieldStyle(.plain)
                        .font(.mono)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 300)

                Spacer()

                // Stats
                if captureService.isCapturing {
                    HStack(spacing: 16) {
                        Label("\(Int(captureService.packetsPerSecond))/s", systemImage: "arrow.down.circle")
                            .foregroundStyle(.success)
                        Label(formatBytes(captureService.bytesPerSecond) + "/s", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(.netColor)
                    }
                    .font(.label)
                }

                // Start/Stop button
                Button {
                    if captureService.isCapturing {
                        captureService.stopCapture()
                    } else {
                        captureService.startCapture()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(captureService.isCapturing ? Color.danger : Color.success)
                            .frame(width: 8, height: 8)
                        Text(captureService.isCapturing ? "Stop" : "Start")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(captureService.isCapturing ? Color.danger.opacity(0.2) : Color.success.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Export button
                Button {
                    showExportDialog = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .padding(8)
                        .background(Color.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(captureService.packets.isEmpty)
            }
            .padding(12)
            .background(Color.backgroundSecondary)

            // Error message
            if let error = captureService.errorMessage {
                BPFPermissionBanner(
                    errorMessage: error,
                    onDismiss: { captureService.errorMessage = nil },
                    onRetry: { captureService.startCapture() }
                )
            }

            // Filter bar
            HStack(spacing: 8) {
                Text("Filter:")
                    .font(.label)
                    .foregroundStyle(.textSecondary)

                FilterButton(title: "All", isSelected: filterProtocol == nil) {
                    filterProtocol = nil
                }
                FilterButton(title: "TCP", isSelected: filterProtocol == .tcp) {
                    filterProtocol = .tcp
                }
                FilterButton(title: "UDP", isSelected: filterProtocol == .udp) {
                    filterProtocol = .udp
                }
                FilterButton(title: "ICMP", isSelected: filterProtocol == .icmp) {
                    filterProtocol = .icmp
                }
                FilterButton(title: "ARP", isSelected: filterProtocol == .arp) {
                    filterProtocol = .arp
                }
                FilterButton(title: "IPv6", isSelected: filterProtocol == .ipv6) {
                    filterProtocol = .ipv6
                }

                Spacer()

                Text("\(filteredPackets.count) packets")
                    .font(.label)
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.backgroundTertiary.opacity(0.5))

            // Split view: packet list and detail
            HSplitView {
                // Packet list
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("Time")
                            .frame(width: 80, alignment: .leading)
                        Text("Source")
                            .frame(width: 150, alignment: .leading)
                        Text("Destination")
                            .frame(width: 150, alignment: .leading)
                        Text("Proto")
                            .frame(width: 50, alignment: .center)
                        Text("Length")
                            .frame(width: 60, alignment: .trailing)
                        Text("Info")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.label)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.backgroundTertiary)

                    // Packet rows
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredPackets) { packet in
                                    PacketRow(packet: packet, isSelected: selectedPacket?.id == packet.id)
                                        .onTapGesture {
                                            selectedPacket = packet
                                        }
                                        .id(packet.id)
                                }
                            }
                        }
                        .onChange(of: captureService.packets.count) { _, _ in
                            if let lastPacket = filteredPackets.last {
                                proxy.scrollTo(lastPacket.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(minWidth: 500)

                // Packet detail
                if let packet = selectedPacket {
                    PacketDetailView(packet: packet)
                        .frame(minWidth: 300)
                } else {
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.textTertiary)
                        Text("Select a packet to view details")
                            .font(.label)
                            .foregroundStyle(.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .fileExporter(
            isPresented: $showExportDialog,
            document: PcapDocument(captureService: captureService),
            contentType: .data,
            defaultFilename: "capture_\(Date().ISO8601Format()).pcap"
        ) { result in
            // Handle result
        }
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB", bytes / 1_000)
        }
        return String(format: "%.0f B", bytes)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.appAccent.opacity(0.3) : Color.backgroundTertiary)
                .foregroundStyle(isSelected ? .appAccent : .textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

struct PacketRow: View {
    let packet: PacketInfo
    let isSelected: Bool

    var protocolColor: Color {
        switch packet.protocol {
        case .tcp: return .netColor
        case .udp: return .success
        case .icmp: return .warning
        case .arp: return .diskColor
        case .ipv6: return .gpuColor
        case .other: return .textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(packet.timestamp.formatted(.dateTime.hour().minute().second()))
                .frame(width: 80, alignment: .leading)

            Text("\(packet.sourceIP):\(packet.sourcePort)")
                .frame(width: 150, alignment: .leading)

            Text("\(packet.destinationIP):\(packet.destinationPort)")
                .frame(width: 150, alignment: .leading)

            Text(packet.protocol.rawValue)
                .foregroundStyle(protocolColor)
                .frame(width: 50, alignment: .center)

            Text("\(packet.length)")
                .frame(width: 60, alignment: .trailing)

            Text(packet.summary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.monoSmall)
        .foregroundStyle(isSelected ? .textPrimary : .textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.appAccent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct PacketDetailView: View {
    let packet: PacketInfo
    @State private var showHex = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Packet Details")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("View", selection: $showHex) {
                    Text("Hex").tag(true)
                    Text("ASCII").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(12)
            .background(Color.backgroundSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Summary
                    GroupBox("Summary") {
                        VStack(alignment: .leading, spacing: 6) {
                            DetailField(label: "Time", value: packet.timestamp.formatted())
                            DetailField(label: "Protocol", value: packet.protocol.rawValue)
                            DetailField(label: "Length", value: "\(packet.length) bytes")
                        }
                    }

                    // Addresses
                    GroupBox("Addresses") {
                        VStack(alignment: .leading, spacing: 6) {
                            DetailField(label: "Source", value: "\(packet.sourceIP):\(packet.sourcePort)")
                            DetailField(label: "Destination", value: "\(packet.destinationIP):\(packet.destinationPort)")
                        }
                    }

                    // Raw data
                    GroupBox(showHex ? "Hex Dump" : "ASCII") {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(showHex ? packet.hexDump : asciiDump(packet.rawData))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color.backgroundPrimary)
    }

    private func asciiDump(_ data: Data) -> String {
        let bytes = [UInt8](data)
        return bytes.map { (0x20...0x7E).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
    }
}

struct DetailField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundStyle(.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundStyle(.textPrimary)
                .textSelection(.enabled)
        }
        .font(.mono)
    }
}

// PCAP Document for export
struct PcapDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let captureService: PacketCaptureService

    init(captureService: PacketCaptureService) {
        self.captureService = captureService
    }

    init(configuration: ReadConfiguration) throws {
        self.captureService = PacketCaptureService()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("temp.pcap")
        try captureService.exportToPcap(url: url)
        let data = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    PacketCaptureView()
        .frame(width: 1000, height: 600)
}
