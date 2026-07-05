import Foundation

enum BPFPermissionHelper {

    // Returns true if at least one /dev/bpf* device is readable by the current user
    static func hasPermission() -> Bool {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: "/dev") else { return false }
        let bpfDevices = contents.filter { $0.hasPrefix("bpf") }
        return bpfDevices.contains { fm.isReadableFile(atPath: "/dev/\($0)") }
    }

    // Returns true if the error string looks like a BPF permission error
    static func isBPFPermissionError(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("permission denied") ||
               lower.contains("operation not permitted") ||
               lower.contains("bpf") ||
               lower.contains("cannot open")
    }

    // Grant read permission to all /dev/bpf* via AppleScript elevation.
    // Calls completion on the main thread.
    static func grantPermission(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            do shell script "chmod o+r /dev/bpf*" with administrator privileges
            """
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let err = error {
                    let msg = (err[NSAppleScript.errorMessage] as? String) ?? "Unknown error"
                    completion(false, msg)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // Install a LaunchDaemon that permanently grants BPF access on every boot.
    // Calls completion on the main thread.
    static func installLaunchDaemon(completion: @escaping (Bool, String?) -> Void) {
        let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macpulse.bpf-permissions</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>/bin/chmod o+r /dev/bpf*</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
"""
        let plistPath = "/Library/LaunchDaemons/com.macpulse.bpf-permissions.plist"

        // Escape the plist content for the shell
        let escaped = plistContent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "echo \\"\(escaped)\\" > \(plistPath) && chmod 644 \(plistPath) && chown root:wheel \(plistPath) && launchctl load \(plistPath)" with administrator privileges
        """

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let err = error {
                    let msg = (err[NSAppleScript.errorMessage] as? String) ?? "Unknown error"
                    completion(false, msg)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
}
