import Foundation
import Network
import Darwin

@Observable
final class NetworkMonitorService {
    var interfaces: [NetworkInterface] = []
    var connections: [NetworkConnection] = []
    var isMonitoring = false

    private var timer: Timer?
    private var previousBytes: [String: (in: UInt64, out: UInt64)] = [:]
    private var lastUpdate: Date?

    init() {
        updateInterfaces()
    }

    func start(interval: TimeInterval = 2.0) {
        isMonitoring = true
        timer?.invalidate()

        // Initial update async
        refreshAsync()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
    }

    private func refreshAsync() {
        updateInterfaces()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newConnections = Self.fetchConnectionsSync()
            DispatchQueue.main.async {
                self?.connections = newConnections
            }
        }
    }

    private static func fetchConnectionsSync() -> [NetworkConnection] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", "-n", "-P"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return SystemCommandParsers.parseLsofConnections(output)
            }
        } catch {}

        return []
    }

    func stop() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Interfaces
    func updateInterfaces() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var interfaceMap: [String: NetworkInterface] = [:]
        let now = Date()
        let timeDiff = lastUpdate.map { now.timeIntervalSince($0) } ?? 1.0

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            // Skip loopback
            guard name != "lo0" else {
                if let next = interface.ifa_next {
                    ptr = next
                    continue
                } else {
                    break
                }
            }

            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0

            // Get or create interface entry
            if interfaceMap[name] == nil {
                interfaceMap[name] = NetworkInterface(
                    name: name,
                    displayName: getInterfaceDisplayName(name),
                    ipAddress: "",
                    subnet: "",
                    macAddress: "",
                    isUp: isUp,
                    isWifi: name.hasPrefix("en") && (name == "en0" || name == "en1"),
                    bytesIn: 0,
                    bytesOut: 0,
                    bytesInPerSec: 0,
                    bytesOutPerSec: 0
                )
            }

            // Get IP address (AF_INET)
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var addr = interface.ifa_addr.pointee
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                interfaceMap[name]?.ipAddress = String(cString: hostname)

                // Get subnet mask
                if let netmask = interface.ifa_netmask {
                    var mask = netmask.pointee
                    var maskHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&mask, socklen_t(mask.sa_len), &maskHost, socklen_t(maskHost.count), nil, 0, NI_NUMERICHOST)
                    interfaceMap[name]?.subnet = String(cString: maskHost)
                }
            }

            // Get MAC address and traffic stats (AF_LINK)
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                // MAC address
                let sdl = interface.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                if sdl.sdl_alen == 6 {
                    let macBytes = withUnsafePointer(to: sdl.sdl_data) { ptr in
                        ptr.withMemoryRebound(to: UInt8.self, capacity: Int(sdl.sdl_nlen + sdl.sdl_alen)) { dataPtr in
                            let offset = Int(sdl.sdl_nlen)
                            return (0..<6).map { dataPtr[offset + $0] }
                        }
                    }
                    interfaceMap[name]?.macAddress = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                }

                // Traffic stats
                if let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    let bytesIn = UInt64(networkData.ifi_ibytes)
                    let bytesOut = UInt64(networkData.ifi_obytes)

                    interfaceMap[name]?.bytesIn = bytesIn
                    interfaceMap[name]?.bytesOut = bytesOut

                    // Calculate speed
                    if let prev = previousBytes[name], timeDiff > 0 {
                        let inDiff = bytesIn > prev.in ? bytesIn - prev.in : 0
                        let outDiff = bytesOut > prev.out ? bytesOut - prev.out : 0
                        interfaceMap[name]?.bytesInPerSec = UInt64(Double(inDiff) / timeDiff)
                        interfaceMap[name]?.bytesOutPerSec = UInt64(Double(outDiff) / timeDiff)
                    }

                    previousBytes[name] = (bytesIn, bytesOut)
                }
            }

            if let next = interface.ifa_next {
                ptr = next
            } else {
                break
            }
        }

        lastUpdate = now

        // Filter and sort
        interfaces = interfaceMap.values
            .filter { !$0.ipAddress.isEmpty || $0.isUp }
            .sorted { $0.name < $1.name }
    }

    private static var hardwarePortCache: [String: String] = [:]
    private static var cacheLoaded = false

    private func getInterfaceDisplayName(_ name: String) -> String {
        // Load hardware ports once
        if !Self.cacheLoaded {
            Self.loadHardwarePorts()
            Self.cacheLoaded = true
        }

        // Check cache first
        if let cached = Self.hardwarePortCache[name] {
            return cached
        }

        // Fallback names
        switch name {
        case "bridge0": return "Bridge"
        case "awdl0": return "AWDL"
        case "llw0": return "Low Latency WLAN"
        default:
            if name.hasPrefix("utun") { return "VPN Tunnel" }
            if name.hasPrefix("en") { return "Ethernet" }
            return name
        }
    }

    private static func loadHardwarePorts() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listallhardwareports"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                hardwarePortCache = SystemCommandParsers.parseHardwarePorts(output)
            }
        } catch {}
    }

    private static func getConnectionsFromNetstat() -> [NetworkConnection] {
        // Simplified fallback using netstat
        return []
    }
}
