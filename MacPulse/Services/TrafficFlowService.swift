import Foundation

@Observable
final class TrafficFlowService {
    var flows: [String: TrafficFlow] = [:]
    var isCapturing = false
    var localIP: String = ""
    var stats = FlowStats()
    var errorMessage: String?

    private var pcapHandle: OpaquePointer?
    private var captureQueue: DispatchQueue?
    private var statsTimer: Timer?
    private var previousBytes: [String: UInt64] = [:]
    private var lastStatsUpdate = Date()

    var activeFlows: [TrafficFlow] {
        flows.values.filter { $0.isActive }.sorted { $0.bytesPerSecond > $1.bytesPerSecond }
    }

    var allFlows: [TrafficFlow] {
        Array(flows.values).sorted { $0.bytesTransferred > $1.bytesTransferred }
    }

    func startCapture(interface: String = "en0", localIP: String) {
        guard !isCapturing else { return }

        self.localIP = localIP
        flows.removeAll()
        previousBytes.removeAll()
        errorMessage = nil

        var errbuf = [CChar](repeating: 0, count: Int(PCAP_ERRBUF_SIZE))

        pcapHandle = pcap_open_live(
            interface,
            256,        // Only need headers, not full payload
            1,          // Promiscuous mode
            50,         // 50ms timeout for faster updates
            &errbuf
        )

        guard pcapHandle != nil else {
            errorMessage = "Failed to open interface: \(String(cString: errbuf))"
            return
        }

        // Only capture IP traffic
        var fp = bpf_program()
        let filter = "ip or ip6"
        let compileResult = filter.withCString { filterCString in
            pcap_compile(pcapHandle, &fp, filterCString, 1, 0xffffffff)
        }

        if compileResult == 0 {
            pcap_setfilter(pcapHandle, &fp)
            pcap_freecode(&fp)
        }

        isCapturing = true

        // Start capture loop
        captureQueue = DispatchQueue(label: "com.macpulse.trafficflow", qos: .userInitiated)
        captureQueue?.async { [weak self] in
            self?.captureLoop()
        }

        // Start stats update timer
        DispatchQueue.main.async {
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateStats()
            }
        }
    }

    func stopCapture() {
        isCapturing = false
        statsTimer?.invalidate()
        statsTimer = nil

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
                let capturedLength = Int(hdr.pointee.caplen)
                let originalLength = Int(hdr.pointee.len)
                processPacket(data: data, capturedLength: capturedLength, originalLength: originalLength)
            } else if result == -1 {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Capture error"
                    self?.stopCapture()
                }
                break
            }
        }
    }

    private func processPacket(data: UnsafePointer<u_char>, capturedLength: Int, originalLength: Int) {
        guard capturedLength >= 14 else { return }

        let rawData = Data(bytes: data, count: capturedLength)
        guard let packet = PacketParser.parse(rawData: rawData, length: originalLength, timestamp: Date()) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.record(packet: packet)
        }
    }

    func record(packet: PacketInfo) {
        guard let key = TrafficFlowKey(packet: packet) else { return }
        recordFlow(key: key, bytes: UInt64(packet.length))
    }

    private func recordFlow(key: TrafficFlowKey, bytes: UInt64) {
        if var flow = flows[key.id] {
            flow.bytesTransferred += bytes
            flow.packetCount += 1
            flow.lastSeen = Date()
            flows[key.id] = flow
        } else {
            var flow = TrafficFlow(key: key)
            flow.bytesTransferred = bytes
            flow.packetCount = 1
            flows[key.id] = flow
        }
    }

    private func updateStats() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastStatsUpdate)
        guard elapsed > 0 else { return }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var activeCount = 0
        var byIP: [String: UInt64] = [:]

        for (id, var flow) in flows {
            // Calculate bytes per second
            let prevBytes = previousBytes[id] ?? 0
            let byteDiff = flow.bytesTransferred > prevBytes ? flow.bytesTransferred - prevBytes : 0
            flow.bytesPerSecond = Double(byteDiff) / elapsed
            flows[id] = flow
            previousBytes[id] = flow.bytesTransferred

            if flow.isActive {
                activeCount += 1

                // Track in/out based on local IP
                if flow.sourceIP == localIP {
                    totalOut += byteDiff
                    byIP[flow.destinationIP, default: 0] += byteDiff
                } else if flow.destinationIP == localIP {
                    totalIn += byteDiff
                    byIP[flow.sourceIP, default: 0] += byteDiff
                }
            }
        }

        stats.totalBytesIn = totalIn
        stats.totalBytesOut = totalOut
        stats.activeFlows = activeCount
        stats.topTalkers = byIP.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        lastStatsUpdate = now

        // Clean up old flows (older than 60 seconds)
        let cutoff = Date().addingTimeInterval(-60)
        flows = flows.filter { $0.value.lastSeen > cutoff }
    }
}

private extension TrafficFlowKey {
    init?(packet: PacketInfo) {
        guard packet.protocol == .tcp || packet.protocol == .udp || packet.protocol == .icmp else {
            return nil
        }
        guard !packet.sourceIP.isEmpty,
              !packet.destinationIP.isEmpty,
              packet.sourceIP != "N/A",
              packet.destinationIP != "N/A",
              !IPAddressClassifier.isLocalOrNonRoutable(packet.sourceIP),
              !IPAddressClassifier.isLocalOrNonRoutable(packet.destinationIP) else {
            return nil
        }

        self.init(
            sourceIP: packet.sourceIP,
            sourcePort: packet.sourcePort,
            destinationIP: packet.destinationIP,
            destinationPort: packet.destinationPort,
            protocol: packet.protocol
        )
    }

}
