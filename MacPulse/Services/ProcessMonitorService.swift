import Foundation
import AppKit
import Darwin

private let PROC_PIDPATHINFO_MAXSIZE = 4096

@Observable
final class ProcessMonitorService {
    var processes: [ProcessStats] = []
    var topCPUProcesses: [ProcessStats] = []
    var topMemoryProcesses: [ProcessStats] = []
    var cpuHistoryByPID: [Int32: [Double]] = [:]
    var memoryHistoryByPID: [Int32: [Double]] = [:]

    private var timer: Timer?
    private var previousCPUTimes: [Int32: (total: UInt64, timestamp: TimeInterval)] = [:]
    private let maxHistoryPoints = 24
    private let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    init() {
        updateProcesses()
    }

    func start(interval: TimeInterval = 2.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateProcesses()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateProcesses() {
        var processes: [ProcessStats] = []

        // Get all PIDs
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return }

        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, bufferSize)

        guard actualSize > 0 else { return }

        let pidCount = Int(actualSize) / MemoryLayout<Int32>.size

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            if let process = getProcessInfo(pid: pid) {
                processes.append(process)
            }
        }

        // Clean up stale entries from previousCPUTimes
        let activePids = Set(processes.map { $0.id })
        previousCPUTimes = previousCPUTimes.filter { activePids.contains($0.key) }
        cpuHistoryByPID = cpuHistoryByPID.filter { activePids.contains($0.key) }
        memoryHistoryByPID = memoryHistoryByPID.filter { activePids.contains($0.key) }

        for process in processes {
            appendHistory(value: process.cpuUsage, to: &cpuHistoryByPID[process.id])
            appendHistory(value: Double(process.memoryUsage), to: &memoryHistoryByPID[process.id])
        }

        self.processes = processes.sorted { $0.cpuUsage > $1.cpuUsage }
        self.topCPUProcesses = Array(self.processes.prefix(5))
        self.topMemoryProcesses = processes.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(5).map { $0 }
    }

    private func getProcessInfo(pid: Int32) -> ProcessStats? {
        var taskInfo = proc_taskallinfo()
        let size = MemoryLayout<proc_taskallinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, Int32(size))
        guard result == size else { return nil }

        // Get process name
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        proc_pidpath(pid, &pathBuffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        let path = String(cString: pathBuffer)
        let name = (path as NSString).lastPathComponent

        // Skip empty names
        guard !name.isEmpty else { return nil }

        // Calculate CPU usage
        let userTime = taskInfo.ptinfo.pti_total_user
        let systemTime = taskInfo.ptinfo.pti_total_system
        let cpuUsage = calculateCPUUsage(pid: pid, userTime: userTime, systemTime: systemTime)

        // Memory usage
        let memoryUsage = UInt64(taskInfo.ptinfo.pti_resident_size)

        // Thread count
        let threads = Int(taskInfo.ptinfo.pti_threadnum)

        // Process status
        let status = getProcessStatus(from: taskInfo.pbsd.pbi_status)

        // Get user
        let uid = taskInfo.pbsd.pbi_uid
        let user = getUserName(uid: uid)

        // Get app icon
        let icon = getAppIcon(path: path)
        let bundleIdentifier = Bundle(path: path)?.bundleIdentifier

        return ProcessStats(
            id: pid,
            name: name,
            user: user,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            threads: threads,
            status: status,
            icon: icon,
            executablePath: path,
            bundleIdentifier: bundleIdentifier
        )
    }

    func cpuHistory(for pid: Int32) -> [Double] {
        cpuHistoryByPID[pid] ?? []
    }

    func memoryHistory(for pid: Int32) -> [Double] {
        memoryHistoryByPID[pid] ?? []
    }

    func summary(for process: ProcessStats) -> ProcessSummary {
        Self.summary(for: process)
    }

    private func calculateCPUUsage(pid: Int32, userTime: UInt64, systemTime: UInt64) -> Double {
        let now = ProcessInfo.processInfo.systemUptime
        let totalTime = userTime + systemTime

        // Convert Mach absolute time to nanoseconds
        let nanoSeconds = Double(totalTime) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        let cpuSeconds = nanoSeconds / 1_000_000_000.0

        if let previous = previousCPUTimes[pid] {
            let timeDiff = now - previous.timestamp
            guard timeDiff > 0.1 else { return 0 } // Need at least 100ms between samples

            let prevNanoSeconds = Double(previous.total) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
            let prevCpuSeconds = prevNanoSeconds / 1_000_000_000.0

            let cpuTimeDiff = cpuSeconds - prevCpuSeconds
            guard cpuTimeDiff >= 0 else {
                // Process restarted, reset tracking
                previousCPUTimes[pid] = (totalTime, now)
                return 0
            }

            // CPU usage = (CPU time used / wall time elapsed) * 100
            let usage = (cpuTimeDiff / timeDiff) * 100.0

            previousCPUTimes[pid] = (totalTime, now)
            return min(usage, 800.0) // Cap at 800% (8 cores max)
        }

        previousCPUTimes[pid] = (totalTime, now)
        return 0
    }

    private func getProcessStatus(from status: UInt32) -> ProcessStatus {
        switch status {
        case 1: return .idle
        case 2: return .running
        case 3: return .sleeping
        case 4: return .stopped
        case 5: return .zombie
        default: return .unknown
        }
    }

    private func getUserName(uid: UInt32) -> String {
        if let pw = getpwuid(uid) {
            return String(cString: pw.pointee.pw_name)
        }
        return "\(uid)"
    }

    private func getAppIcon(path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }

        // Try to get app bundle icon
        if let bundle = Bundle(path: path), let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            if let iconPath = bundle.path(forResource: iconName, ofType: "icns") {
                return NSImage(contentsOfFile: iconPath)
            }
        }

        // Fallback to workspace icon
        return NSWorkspace.shared.icon(forFile: path)
    }

    func terminateProcess(pid: Int32) -> Bool {
        return kill(pid, SIGTERM) == 0
    }

    func forceTerminateProcess(pid: Int32) -> Bool {
        return kill(pid, SIGKILL) == 0
    }

    private func appendHistory(value: Double, to history: inout [Double]?) {
        var updated = history ?? []
        updated.append(value)
        if updated.count > maxHistoryPoints {
            updated.removeFirst(updated.count - maxHistoryPoints)
        }
        history = updated
    }

    static func summary(for process: ProcessStats) -> ProcessSummary {
        let lowerName = process.name.lowercased()
        let path = process.executablePath.lowercased()
        let bundleID = process.bundleIdentifier?.lowercased() ?? ""

        if lowerName == "kernel_task" {
            return ProcessSummary(
                role: "System kernel worker",
                purpose: "Steuert zentrale macOS-Kernel-Aufgaben und kann CPU reservieren, um thermische Last abzufangen.",
                explanation: "Hohe Last ist auf Macs oft ein Schutzsignal gegen Hitze oder Treiberaktivität, nicht nur echte Rechenarbeit."
            )
        }

        let known: [(String, ProcessSummary)] = [
            ("windowserver", .init(role: "Display compositor", purpose: "Rendert Fenster, Animationen und Bildschirmausgabe.", explanation: "Steigt bei vielen Displays, hoher Bildwiederholrate oder grafiklastigen Apps.")),
            ("mds", .init(role: "Spotlight indexer", purpose: "Indiziert Dateien und Metadaten für Suche und intelligente Vorschläge.", explanation: "Kurzzeitig erhöhte CPU nach Dateisynchronisation oder Systemupdates ist normal.")),
            ("mdworker", .init(role: "Spotlight worker", purpose: "Analysiert Dateien im Hintergrund für Spotlight und Vorschauinformationen.", explanation: "Taucht oft in Wellen auf, wenn neue oder geänderte Dateien verarbeitet werden.")),
            ("backupd", .init(role: "Time Machine backup", purpose: "Koordiniert Backups und Snapshots.", explanation: "Mehr Aktivität während laufender Sicherungen oder nach längerer Offline-Zeit.")),
            ("corespotlightd", .init(role: "Search metadata service", purpose: "Pflegt App- und Inhaltsmetadaten für Systemsuche.", explanation: "Relevant für Siri-Vorschläge, Spotlight und intelligente Inhalte.")),
            ("photoanalysisd", .init(role: "Photos analysis", purpose: "Analysiert Fotos lokal für Erkennung und Suche.", explanation: "Kann CPU/GPU spürbar nutzen, wenn neue Mediathek-Inhalte importiert wurden.")),
            ("cloudd", .init(role: "iCloud sync service", purpose: "Synchronisiert Dokumente und App-Daten über iCloud.", explanation: "Mehr Netzwerk- und CPU-Last nach Dateiänderungen oder bei Konto-Neuanmeldung.")),
            ("bird", .init(role: "iCloud Drive agent", purpose: "Hält iCloud-Drive-Dateien lokal und in der Cloud konsistent.", explanation: "Aktivität steigt, wenn Dateien hoch- oder heruntergeladen werden.")),
            ("loginwindow", .init(role: "Session controller", purpose: "Verwaltet Benutzeranmeldung, Sperrbildschirm und Sitzungszustand.", explanation: "Normalerweise leichtgewichtig; hohe Last deutet eher auf indirekte UI-Effekte hin.")),
            ("finder", .init(role: "File manager", purpose: "Zeigt Dateien, Ordner und Desktop-Inhalte an.", explanation: "Mehr Last bei großen Ordnern, Vorschauen oder intensiver Dateinavigation.")),
            ("dock", .init(role: "App launcher and spaces", purpose: "Verwaltet Dock, Mission Control und App-Fenstergruppen.", explanation: "Spitzen entstehen oft durch Animationen oder viele offene Spaces.")),
            ("coreservicesuiagent", .init(role: "System prompt agent", purpose: "Zeigt Systemdialoge und Berechtigungsabfragen.", explanation: "Kurz sichtbar bei Systemwarnungen und Autorisierungen.")),
            ("cfprefsd", .init(role: "Preferences daemon", purpose: "Liest und schreibt App- und Systemeinstellungen.", explanation: "Normalerweise kurz aktiv, wenn Einstellungen geändert oder synchronisiert werden.")),
            ("nsurlsessiond", .init(role: "Background transfer service", purpose: "Führt Hintergrund-Downloads und Uploads für Apps aus.", explanation: "Relevant bei Sync-Clients, Mail, Browsern und Medien-Apps.")),
            ("syspolicyd", .init(role: "Security policy service", purpose: "Prüft Signaturen, Gatekeeper-Regeln und Sicherheitsrichtlinien.", explanation: "Kann bei App-Starts, Downloads oder neuen Binärdateien aktiv werden."))
        ]

        if let match = known.first(where: { lowerName == $0.0 || bundleID.contains($0.0) || path.contains("/\($0.0)") }) {
            return match.1
        }

        if path.contains("/applications/") || bundleID.hasPrefix("com.") {
            return ProcessSummary(
                role: "User-facing application",
                purpose: "Das ist wahrscheinlich die Hauptanwendung oder ein direkt zugehöriger App-Prozess.",
                explanation: "CPU zeigt aktive Arbeit der App, Speicher eher ihren aktuellen Footprint und offene Inhalte."
            )
        }

        if lowerName.hasSuffix("d") {
            return ProcessSummary(
                role: "Background daemon",
                purpose: "Ein System- oder Dienstprozess, der Aufgaben ohne sichtbares Fenster im Hintergrund ausführt.",
                explanation: "Solche Prozesse reagieren meist auf Systemereignisse, Synchronisation, Netzwerk oder Wartung."
            )
        }

        if lowerName.contains("helper") || lowerName.contains("agent") {
            return ProcessSummary(
                role: "Support process",
                purpose: "Ein Hilfsprozess für eine App oder Systemfunktion, getrennt vom Hauptfensterprozess.",
                explanation: "Helpers übernehmen oft Rendering, Erweiterungen, Updater oder isolierte Hintergrundarbeit."
            )
        }

        return ProcessSummary(
            role: "General process",
            purpose: "Ein normaler Ausführungsprozess unter macOS, der Code, Threads und Speicher für eine Aufgabe bündelt.",
            explanation: "Zur Einordnung helfen vor allem Name, Benutzer, CPU-Verlauf, Speichertrend und der ausführbare Pfad."
        )
    }
}

struct ProcessSummary {
    let role: String
    let purpose: String
    let explanation: String
}
