import Foundation
import Network

@Observable
final class PortScannerService {
    var results: [PortScanResult] = []
    var isScanning = false
    var progress: Double = 0
    var currentPort: UInt16 = 0
    var openPorts: Int = 0
    var scanSpeed: Double = 0 // ports per second
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private var startTime: Date?
    private var scannedCount = 0

    enum ScanProfile: String, CaseIterable {
        case quick = "Quick (Top 100)"
        case standard = "Standard (Top 1000)"
        case full = "Full (1-65535)"

        var ports: [UInt16] {
            switch self {
            case .quick:
                return Self.top100Ports
            case .standard:
                return Self.top1000Ports
            case .full:
                return Array(1...65535).map { UInt16($0) }
            }
        }

        static let top100Ports: [UInt16] = [
            21, 22, 23, 25, 53, 80, 110, 111, 135, 139,
            143, 443, 445, 993, 995, 1723, 3306, 3389, 5432, 5900,
            8080, 8443, 20, 69, 123, 137, 138, 161, 162, 389,
            636, 873, 1433, 1521, 2049, 2082, 2083, 2086, 2087, 2095,
            2096, 3000, 3128, 3268, 3269, 5000, 5001, 5060, 5061, 5357,
            5666, 5800, 5985, 5986, 6000, 6001, 6379, 6443, 6667, 7001,
            7002, 8000, 8008, 8081, 8088, 8181, 8888, 9000, 9001, 9090,
            9091, 9200, 9300, 9443, 10000, 10443, 11211, 27017, 27018, 28017,
            50000, 50070, 50075, 50090, 60000, 60010, 60020, 60030, 179, 264,
            512, 513, 514, 515, 548, 554, 587, 631, 646, 1099
        ]

        static let top1000Ports: [UInt16] = {
            var ports = Set(top100Ports)
            // Add more common ports
            for p: UInt16 in [
                1, 7, 9, 13, 17, 19, 26, 37, 49, 79, 81, 82, 83, 84, 85, 88, 89, 90,
                99, 100, 106, 113, 119, 125, 144, 146, 163, 199, 211, 212, 222, 254,
                255, 256, 259, 280, 301, 306, 311, 340, 366, 406, 407, 416, 417, 425,
                427, 444, 458, 464, 465, 481, 497, 500, 502, 512, 513, 514, 515, 524,
                541, 543, 544, 545, 554, 555, 563, 593, 616, 617, 625, 666, 683, 687,
                691, 700, 705, 711, 714, 720, 722, 726, 749, 765, 777, 783, 787, 800,
                801, 808, 843, 880, 888, 898, 900, 901, 902, 903, 911, 912, 981, 987,
                990, 992, 999, 1000, 1001, 1002, 1007, 1009, 1010, 1011, 1021, 1022,
                1023, 1024, 1025, 1026, 1027, 1028, 1029, 1030, 1031, 1032, 1033, 1034,
                1035, 1036, 1037, 1038, 1039, 1040, 1041, 1042, 1043, 1044, 1045, 1046,
                1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054, 1055, 1056, 1057, 1058,
                1059, 1060, 1070, 1080, 1090, 1100, 1234, 1241, 1311, 1352, 1434, 1500,
                1501, 1503, 1524, 1533, 1556, 1580, 1583, 1594, 1600, 1641, 1658, 1666,
                1687, 1688, 1700, 1717, 1718, 1719, 1720, 1721, 1755, 1761, 1782, 1783,
                1801, 1805, 1812, 1839, 1840, 1862, 1863, 1864, 1875, 1900, 1914, 1935,
                1947, 1971, 1972, 1974, 1984, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
                2005, 2006, 2007, 2008, 2009, 2010, 2013, 2020, 2021, 2022, 2030, 2033,
                2034, 2035, 2038, 2040, 2041, 2042, 2043, 2045, 2046, 2047, 2048, 2065,
                2068, 2099, 2100, 2103, 2105, 2106, 2107, 2111, 2119, 2121, 2126, 2135,
                2144, 2160, 2161, 2170, 2179, 2190, 2191, 2196, 2200, 2222, 2251, 2260,
                2288, 2301, 2323, 2366, 2381, 2382, 2383, 2393, 2394, 2399, 2401, 2492,
                2500, 2522, 2525, 2557, 2601, 2602, 2604, 2605, 2607, 2608, 2638, 2701,
                2702, 2710, 2717, 2718, 2725, 2800, 2809, 2811, 2869, 2875, 2909, 2910,
                2920, 2967, 2968, 2998, 3001, 3003, 3005, 3006, 3007, 3011, 3013, 3017,
                3030, 3031, 3052, 3071, 3077, 3128, 3168, 3211, 3221, 3260, 3261, 3283,
                3300, 3301, 3323, 3325, 3333, 3351, 3367, 3369, 3370, 3371, 3372, 3389,
                3390, 3404, 3476, 3493, 3517, 3527, 3546, 3551, 3580, 3659, 3689, 3690,
                3703, 3737, 3766, 3784, 3800, 3801, 3809, 3814, 3826, 3827, 3828, 3851,
                3869, 3871, 3878, 3880, 3889, 3905, 3914, 3918, 3920, 3945, 3971, 3986,
                3995, 3998, 4000, 4001, 4002, 4003, 4004, 4005, 4006, 4045, 4111, 4125,
                4126, 4129, 4224, 4242, 4279, 4321, 4343, 4443, 4444, 4445, 4446, 4449,
                4550, 4567, 4662, 4848, 4899, 4900, 4998, 5000, 5001, 5002, 5003, 5004,
                5009, 5030, 5033, 5050, 5051, 5054, 5060, 5061, 5080, 5087, 5100, 5101,
                5102, 5120, 5190, 5200, 5214, 5221, 5222, 5225, 5226, 5269, 5280, 5298,
                5357, 5405, 5414, 5431, 5432, 5440, 5500, 5510, 5544, 5550, 5555, 5560,
                5566, 5631, 5633, 5666, 5678, 5679, 5718, 5730, 5800, 5801, 5802, 5810,
                5811, 5815, 5822, 5825, 5850, 5859, 5862, 5877, 5900, 5901, 5902, 5903,
                5904, 5906, 5907, 5910, 5911, 5915, 5922, 5925, 5950, 5952, 5959, 5960,
                5961, 5962, 5963, 5987, 5988, 5989, 5998, 5999, 6000, 6001, 6002, 6003,
                6004, 6005, 6006, 6007, 6009, 6025, 6059, 6100, 6101, 6106, 6112, 6123,
                6129, 6156, 6346, 6389, 6502, 6510, 6543, 6547, 6565, 6566, 6567, 6580,
                6646, 6666, 6667, 6668, 6669, 6689, 6692, 6699, 6779, 6788, 6789, 6792,
                6839, 6881, 6901, 6969, 7000, 7001, 7002, 7004, 7007, 7019, 7025, 7070,
                7100, 7103, 7106, 7200, 7201, 7402, 7435, 7443, 7496, 7512, 7625, 7627,
                7676, 7741, 7777, 7778, 7800, 7911, 7920, 7921, 7937, 7938, 7999, 8000,
                8001, 8002, 8007, 8008, 8009, 8010, 8011, 8021, 8022, 8031, 8042, 8045,
                8080, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090, 8093,
                8099, 8100, 8180, 8181, 8192, 8193, 8194, 8200, 8222, 8254, 8290, 8291,
                8292, 8300, 8333, 8383, 8400, 8402, 8443, 8500, 8600, 8649, 8651, 8652,
                8654, 8701, 8800, 8873, 8888, 8899, 8994, 9000, 9001, 9002, 9003, 9009,
                9010, 9011, 9040, 9050, 9071, 9080, 9081, 9090, 9091, 9099, 9100, 9101,
                9102, 9103, 9110, 9111, 9200, 9207, 9220, 9290, 9415, 9418, 9485, 9500,
                9502, 9503, 9535, 9575, 9593, 9594, 9595, 9618, 9666, 9876, 9877, 9878,
                9898, 9900, 9917, 9929, 9943, 9944, 9968, 9998, 9999, 10000, 10001, 10002,
                10003, 10004, 10009, 10010, 10012, 10024, 10025, 10082, 10180, 10215, 10243,
                10566, 10616, 10617, 10621, 10626, 10628, 10629, 10778, 11110, 11111, 11967,
                12000, 12174, 12265, 12345, 13456, 13722, 13782, 13783, 14000, 14238, 14441,
                14442, 15000, 15002, 15003, 15004, 15660, 15742, 16000, 16001, 16012, 16016,
                16018, 16080, 16113, 16992, 16993, 17877, 17988, 18040, 18101, 18988, 19101,
                19283, 19315, 19350, 19780, 19801, 19842, 20000, 20005, 20031, 20221, 20222,
                20828, 21571, 22939, 23502, 24444, 24800, 25734, 25735, 26214, 27000, 27352,
                27353, 27355, 27356, 27715, 28201, 30000, 30718, 30951, 31038, 31337, 32768,
                32769, 32770, 32771, 32772, 32773, 32774, 32775, 32776, 32777, 32778, 32779,
                32780, 32781, 32782, 32783, 32784, 32785, 33354, 33899, 34571, 34572, 34573,
                35500, 38292, 40193, 40911, 41511, 42510, 44176, 44442, 44443, 44501, 45100,
                48080, 49152, 49153, 49154, 49155, 49156, 49157, 49158, 49159, 49160, 49161,
                49163, 49165, 49167, 49175, 49176, 49400, 49999, 50000, 50001, 50002, 50003,
                50006, 50300, 50389, 50500, 50636, 50800, 51103, 51493, 52673, 52822, 52848,
                52869, 54045, 54328, 55055, 55056, 55555, 55600, 56737, 56738, 57294, 57797,
                58080, 60020, 60443, 61532, 61900, 62078, 63331, 64623, 64680, 65000, 65129,
                65389
            ] {
                ports.insert(p)
            }
            return Array(ports).sorted()
        }()
    }

    func startScan(target: String, profile: ScanProfile) {
        guard !isScanning else { return }

        guard let targetHost = PortScanTargetValidator.normalizedTarget(target) else {
            errorMessage = PortScanTargetValidator.validationMessage(for: target)
            results.removeAll()
            progress = 0
            currentPort = 0
            openPorts = 0
            scanSpeed = 0
            return
        }

        results.removeAll()
        errorMessage = nil
        isScanning = true
        progress = 0
        openPorts = 0
        scannedCount = 0
        startTime = Date()

        let ports = profile.ports

        let totalPorts = ports.count

        scanTask = Task {
            await withTaskGroup(of: PortScanResult?.self) { group in
                let maxConcurrent = 100

                for (index, port) in ports.enumerated() {
                    if Task.isCancelled { break }

                    group.addTask {
                        await self.scanPort(host: targetHost, port: port)
                    }

                    // Limit concurrent tasks
                    if index >= maxConcurrent - 1 {
                        if let result = await group.next() {
                            await MainActor.run {
                                self.scannedCount += 1
                                self.currentPort = port
                                self.progress = Double(self.scannedCount) / Double(totalPorts)

                                if let elapsed = self.startTime?.timeIntervalSinceNow {
                                    self.scanSpeed = Double(self.scannedCount) / abs(elapsed)
                                }

                                if let r = result, r.state == .open {
                                    self.results.append(r)
                                    self.results.sort { $0.port < $1.port }
                                    self.openPorts += 1
                                }
                            }
                        }
                    }
                }

                // Collect remaining results
                for await result in group {
                    await MainActor.run {
                        self.scannedCount += 1
                        self.progress = Double(self.scannedCount) / Double(totalPorts)

                        if let elapsed = self.startTime?.timeIntervalSinceNow {
                            self.scanSpeed = Double(self.scannedCount) / abs(elapsed)
                        }

                        if let r = result, r.state == .open {
                            self.results.append(r)
                            self.results.sort { $0.port < $1.port }
                            self.openPorts += 1
                        }
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.progress = 1.0
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func scanPort(host: String, port: UInt16) async -> PortScanResult? {
        let startTime = Date()

        let hostEndpoint = NWEndpoint.Host(host)
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            return nil
        }

        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let connection = NWConnection(to: endpoint, using: parameters)

        return await withCheckedContinuation { continuation in
            final class ResumeState {
                var hasResumed = false
            }

            let resumeState = ResumeState()
            let lock = NSLock()

            @Sendable func safeResume(with result: PortScanResult) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumeState.hasResumed else { return }
                resumeState.hasResumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            let timeout = DispatchWorkItem {
                safeResume(with: PortScanResult(
                    port: port,
                    state: .filtered,
                    service: PortScanResult.serviceName(for: port),
                    responseTime: nil
                ))
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0, execute: timeout)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeout.cancel()
                    let responseTime = Date().timeIntervalSince(startTime)
                    safeResume(with: PortScanResult(
                        port: port,
                        state: .open,
                        service: PortScanResult.serviceName(for: port),
                        responseTime: responseTime
                    ))

                case .failed, .cancelled:
                    timeout.cancel()
                    safeResume(with: PortScanResult(
                        port: port,
                        state: .closed,
                        service: PortScanResult.serviceName(for: port),
                        responseTime: nil
                    ))

                case .waiting(let error):
                    // Connection refused = port closed
                    if case .posix(let code) = error, code == .ECONNREFUSED {
                        timeout.cancel()
                        safeResume(with: PortScanResult(
                            port: port,
                            state: .closed,
                            service: PortScanResult.serviceName(for: port),
                            responseTime: nil
                        ))
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }
}
