import Foundation
import UserNotifications

@Observable
final class AlertService {
    static let shared = AlertService()

    private var cpuHighSince: Date?
    private var memoryHighSince: Date?
    private let alertDelay: TimeInterval = 10 // seconds before alerting

    private init() {
        requestNotificationPermission()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func checkThresholds(cpuUsage: Double, memoryUsage: Double) {
        let alertsEnabled = MacPulseSettings.bool(
            forKey: MacPulseSettings.Key.alertsEnabled,
            defaultValue: MacPulseSettings.Default.alertsEnabled
        )
        guard alertsEnabled else {
            cpuHighSince = nil
            memoryHighSince = nil
            return
        }

        let cpuThreshold = MacPulseSettings.double(
            forKey: MacPulseSettings.Key.cpuAlertThreshold,
            defaultValue: MacPulseSettings.Default.cpuAlertThreshold
        )
        let memoryThreshold = MacPulseSettings.double(
            forKey: MacPulseSettings.Key.memoryAlertThreshold,
            defaultValue: MacPulseSettings.Default.memoryAlertThreshold
        )

        // CPU Check
        if cpuUsage >= cpuThreshold {
            if cpuHighSince == nil {
                cpuHighSince = Date()
            } else if let since = cpuHighSince, Date().timeIntervalSince(since) >= alertDelay {
                sendCPUAlert(usage: cpuUsage)
                cpuHighSince = nil // Reset to avoid spam
            }
        } else {
            cpuHighSince = nil
        }

        // Memory Check
        if memoryUsage >= memoryThreshold {
            if memoryHighSince == nil {
                memoryHighSince = Date()
            } else if let since = memoryHighSince, Date().timeIntervalSince(since) >= alertDelay {
                sendMemoryAlert(usage: memoryUsage)
                memoryHighSince = nil
            }
        } else {
            memoryHighSince = nil
        }
    }

    private func sendCPUAlert(usage: Double) {
        let content = UNMutableNotificationContent()
        content.title = "High CPU Usage"
        content.body = String(format: "CPU usage is at %.0f%% for more than 10 seconds.", usage)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cpu-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendMemoryAlert(usage: Double) {
        let content = UNMutableNotificationContent()
        content.title = "High Memory Usage"
        content.body = String(format: "Memory usage is at %.0f%%.", usage)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "memory-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
