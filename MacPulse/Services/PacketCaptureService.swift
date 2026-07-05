import Foundation

@Observable
final class PacketCaptureService {
    var packets: [PacketInfo] = []
    var isCapturing = false
    var selectedInterface: String = "en0"
    var bpfFilter: String = ""
    var packetsPerSecond: Double = 0
    var bytesPerSecond: Double = 0
    var errorMessage: String?

    private var pcapHandle: OpaquePointer?
    private var captureQueue: DispatchQueue?
    private var packetCount = 0
    private var byteCount = 0
    private var lastStatsUpdate = Date()

    static func availableInterfaces() -> [String] {
        var interfaces: [String] = []
        var alldevsp: UnsafeMutablePointer<pcap_if_t>?
        var errbuf = [CChar](repeating: 0, count: Int(PCAP_ERRBUF_SIZE))

        if pcap_findalldevs(&alldevsp, &errbuf) == 0 {
            var device = alldevsp
            while device != nil {
                if let name = device?.pointee.name {
                    interfaces.append(String(cString: name))
                }
                device = device?.pointee.next
            }
            pcap_freealldevs(alldevsp)
        }

        return interfaces.filter { !$0.hasPrefix("lo") && !$0.hasPrefix("gif") && !$0.hasPrefix("stf") }
    }

    func startCapture() {
        guard !isCapturing else { return }

        packets.removeAll()
        errorMessage = nil
        packetCount = 0
        byteCount = 0
        lastStatsUpdate = Date()

        var errbuf = [CChar](repeating: 0, count: Int(PCAP_ERRBUF_SIZE))

        // Open device for capture
        pcapHandle = pcap_open_live(
            selectedInterface,
            65535,      // snaplen - capture full packets
            1,          // promiscuous mode
            100,        // timeout in ms
            &errbuf
        )

        guard pcapHandle != nil else {
            errorMessage = "Failed to open interface: \(String(cString: errbuf))"
            return
        }

        // Apply BPF filter if specified
        let trimmedFilter = bpfFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFilter.isEmpty {
            var fp = bpf_program()
            // Use 0xffffffff for PCAP_NETMASK_UNKNOWN
            let compileResult = trimmedFilter.withCString { filterCString in
                pcap_compile(pcapHandle, &fp, filterCString, 1, 0xffffffff)
            }

            if compileResult == 0 {
                if pcap_setfilter(pcapHandle, &fp) != 0 {
                    if let errPtr = pcap_geterr(pcapHandle) {
                        errorMessage = "Filter error: \(String(cString: errPtr))"
                    } else {
                        errorMessage = "Failed to apply filter"
                    }
                    pcap_freecode(&fp)
                    pcap_close(pcapHandle)
                    pcapHandle = nil
                    return
                }
                pcap_freecode(&fp)
            } else {
                if let errPtr = pcap_geterr(pcapHandle) {
                    errorMessage = "Invalid filter: \(String(cString: errPtr))"
                } else {
                    errorMessage = "Invalid BPF filter syntax"
                }
                pcap_close(pcapHandle)
                pcapHandle = nil
                return
            }
        }

        isCapturing = true

        // Start capture loop in background
        captureQueue = DispatchQueue(label: "com.macpulse.packetcapture", qos: .userInitiated)
        captureQueue?.async { [weak self] in
            self?.captureLoop()
        }
    }

    func stopCapture() {
        isCapturing = false

        if let handle = pcapHandle {
            pcap_breakloop(handle)
            pcap_close(handle)
            pcapHandle = nil
        }
    }

    private func captureLoop() {
        guard let handle = pcapHandle else { return }

        var header: UnsafeMutablePointer<pcap_pkthdr>?
        var packetData: UnsafePointer<u_char>?

        while isCapturing {
            let result = pcap_next_ex(handle, &header, &packetData)

            if result == 1, let hdr = header, let data = packetData {
                let length = Int(hdr.pointee.len)
                let capturedLength = Int(hdr.pointee.caplen)

                // Safely copy packet data before pcap reuses the buffer
                guard capturedLength > 0, capturedLength <= 65535 else { continue }

                // Create an independent copy of the packet data
                var rawData = Data(count: capturedLength)
                _ = rawData.withUnsafeMutableBytes { destPtr in
                    memcpy(destPtr.baseAddress!, data, capturedLength)
                }

                if let packet = PacketParser.parse(rawData: rawData, length: length, timestamp: Date()) {
                    DispatchQueue.main.async { [weak self] in
                        self?.addPacket(packet)
                    }
                }
            } else if result == -1 {
                // Error
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Capture error"
                    self?.stopCapture()
                }
                break
            }
            // result == 0 means timeout, continue
        }
    }

    private func addPacket(_ packet: PacketInfo) {
        packets.append(packet)
        packetCount += 1
        byteCount += packet.length

        // Keep only last 1000 packets
        if packets.count > 1000 {
            packets.removeFirst()
        }

        // Update stats every second
        let now = Date()
        let elapsed = now.timeIntervalSince(lastStatsUpdate)
        if elapsed >= 1.0 {
            packetsPerSecond = Double(packetCount) / elapsed
            bytesPerSecond = Double(byteCount) / elapsed
            packetCount = 0
            byteCount = 0
            lastStatsUpdate = now
        }
    }

    func exportToPcap(url: URL) throws {
        guard !packets.isEmpty else {
            throw NSError(domain: "PacketCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No packets to export"])
        }

        var data = Data()

        // PCAP Global Header
        var globalHeader = Data(count: 24)
        globalHeader.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: UInt32(0xa1b2c3d4), toByteOffset: 0, as: UInt32.self)  // Magic number
            ptr.storeBytes(of: UInt16(2), toByteOffset: 4, as: UInt16.self)           // Major version
            ptr.storeBytes(of: UInt16(4), toByteOffset: 6, as: UInt16.self)           // Minor version
            ptr.storeBytes(of: Int32(0), toByteOffset: 8, as: Int32.self)             // Timezone
            ptr.storeBytes(of: UInt32(0), toByteOffset: 12, as: UInt32.self)          // Sigfigs
            ptr.storeBytes(of: UInt32(65535), toByteOffset: 16, as: UInt32.self)      // Snaplen
            ptr.storeBytes(of: UInt32(1), toByteOffset: 20, as: UInt32.self)          // Network (Ethernet)
        }
        data.append(globalHeader)

        // Packet records
        for packet in packets {
            let timestamp = packet.timestamp.timeIntervalSince1970
            let seconds = UInt32(timestamp)
            let microseconds = UInt32((timestamp - Double(seconds)) * 1_000_000)

            var packetHeader = Data(count: 16)
            packetHeader.withUnsafeMutableBytes { ptr in
                ptr.storeBytes(of: seconds, toByteOffset: 0, as: UInt32.self)
                ptr.storeBytes(of: microseconds, toByteOffset: 4, as: UInt32.self)
                ptr.storeBytes(of: UInt32(packet.rawData.count), toByteOffset: 8, as: UInt32.self)
                ptr.storeBytes(of: UInt32(packet.length), toByteOffset: 12, as: UInt32.self)
            }
            data.append(packetHeader)
            data.append(packet.rawData)
        }

        try data.write(to: url)
    }
}
