import Foundation

@Observable
final class DeviceDiscoveryService: NSObject {
    var devices: [NetworkDevice] = []
    var isScanning = false
    var hasStarted = false
    var localIP: String = ""
    var gatewayIP: String = ""
    var gatewayMAC: String = ""
    var lastScanDate: Date?

    private var timer: Timer?
    private var netServiceBrowser: NetServiceBrowser?
    private var discoveredServices: [NetService] = []
    private let ouiLookup = OUILookup()

    override init() {
        super.init()
        updateLocalInfo()
    }

    func start(interval: TimeInterval = 10.0) {
        guard !hasStarted else { return }
        hasStarted = true

        refresh(updateGateway: true)
        startMDNS()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        refresh(updateGateway: false)
    }

    private func refresh(updateGateway: Bool) {
        guard !isScanning else { return }
        isScanning = true

        if updateGateway {
            DispatchQueue.global(qos: .background).async { [weak self] in
                let gateway = Self.fetchGateway()
                DispatchQueue.main.async {
                    self?.gatewayIP = gateway
                    self?.scanARPAsync()
                }
            }
        } else {
            scanARPAsync()
        }
    }

    private func scanARPAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let output = Self.fetchARP()
            DispatchQueue.main.async {
                self?.applyARPEntries(SystemCommandParsers.parseARPEntries(output))
                self?.lastScanDate = Date()
                self?.isScanning = false
            }
        }
    }

    private static func fetchARP() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        task.arguments = ["-a"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    func stop() {
        isScanning = false
        hasStarted = false
        timer?.invalidate()
        timer = nil
        stopMDNS()
    }

    // MARK: - Local Info
    private func updateLocalInfo() {
        // Get local IP
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            if name == "en0" && interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var addr = interface.ifa_addr.pointee
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                localIP = String(cString: hostname)
                break
            }

            if let next = interface.ifa_next {
                ptr = next
            } else {
                break
            }
        }

        // Get gateway
        getGateway()
    }

    private func getGateway() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let gateway = Self.fetchGateway()
            DispatchQueue.main.async {
                self?.gatewayIP = gateway
            }
        }
    }

    private static func fetchGateway() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-rn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return SystemCommandParsers.parseDefaultGateway(fromNetstat: output)
            }
        } catch {}
        return ""
    }

    // MARK: - ARP Parsing
    private func applyARPEntries(_ entries: [ParsedARPEntry]) {
        var newDevices: [String: NetworkDevice] = [:]

        // Keep existing devices
        for device in devices {
            newDevices[device.id] = device
        }

        for entry in entries {
            let isRouter = entry.ipAddress == gatewayIP
            let isLocal = entry.ipAddress == localIP
            let vendor = ouiLookup.lookup(mac: entry.macAddress)

            if var existing = newDevices[entry.macAddress] {
                existing.ipAddress = entry.ipAddress
                existing.hostname = entry.hostname ?? existing.hostname
                existing.lastSeen = Date()
                existing.vendor = vendor ?? existing.vendor
                newDevices[entry.macAddress] = existing
            } else {
                let device = NetworkDevice(
                    id: entry.macAddress,
                    ipAddress: entry.ipAddress,
                    macAddress: entry.macAddress,
                    hostname: entry.hostname,
                    vendor: vendor,
                    lastSeen: Date(),
                    isRouter: isRouter,
                    isLocalDevice: isLocal
                )
                newDevices[entry.macAddress] = device
            }
        }

        devices = Array(newDevices.values).sorted { d1, d2 in
            if d1.isRouter != d2.isRouter { return d1.isRouter }
            if d1.isLocalDevice != d2.isLocalDevice { return d1.isLocalDevice }
            return d1.ipAddress < d2.ipAddress
        }
    }

    // MARK: - mDNS
    private func startMDNS() {
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: "local.")
    }

    private func stopMDNS() {
        netServiceBrowser?.stop()
        netServiceBrowser = nil
        discoveredServices.removeAll()
    }
}

// MARK: - NetServiceBrowserDelegate
extension DeviceDiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        discoveredServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        discoveredServices.removeAll { $0 == service }
    }
}

// MARK: - NetServiceDelegate
extension DeviceDiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }

        for addressData in addresses {
            addressData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }

                if sockaddr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    var addr = sockaddr.pointee
                    getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)

                    // Update device with mDNS hostname
                    if let index = devices.firstIndex(where: { $0.ipAddress == ip }) {
                        if devices[index].hostname == nil {
                            devices[index].hostname = sender.name
                        }
                    }
                }
            }
        }
    }
}
