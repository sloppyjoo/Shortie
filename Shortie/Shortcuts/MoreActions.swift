import AppKit
import Carbon.HIToolbox
import CoreWLAN
import IOKit.ps

/// The workings behind some of the smaller system actions.
enum MoreActions {
    static func toggleWiFi() {
        guard let wifi = CWWiFiClient.shared().interface() else {
            NSSound.beep()
            return
        }
        let on = !wifi.powerOn()
        do {
            try wifi.setPower(on)
            HUD.show(on ? "Wi-Fi On" : "Wi-Fi Off", systemImage: on ? "wifi" : "wifi.slash")
        } catch {
            NSSound.beep()
        }
    }

    /// Uses macOS's own "Switch to Desktop N" shortcuts (⌃1, ⌃2…). They're
    /// off until you turn them on in System Settings › Keyboard › Keyboard
    /// Shortcuts › Mission Control.
    static func switchToDesktop(_ number: Int) {
        let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        guard (1...keys.count).contains(number) else { return }
        KeyPresser.press(KeyCombo(keyCode: UInt16(keys[number - 1]), modifiers: .control, keyName: String(number)))
    }

    static func openTerminalHere() {
        ScriptRunner.runAppleScript("""
        tell application "Finder"
            try
                set here to POSIX path of (target of front Finder window as alias)
            on error
                set here to POSIX path of (path to desktop folder)
            end try
        end tell
        do shell script "open -a Terminal " & quoted form of here
        """)
    }

    static func copyFinderPaths() {
        guard let paths = finderSelection(), !paths.isEmpty else {
            NSSound.beep()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        HUD.show(paths.count == 1 ? "Path Copied" : "\(paths.count) Paths Copied", systemImage: "doc.on.doc")
    }

    static func quickLook() {
        guard let paths = finderSelection(), !paths.isEmpty else {
            NSSound.beep()
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-p"] + paths
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// Copies the address of the page in front, in Safari or a Chrome-based browser.
    static func copyBrowserURL() {
        guard let app = NSWorkspace.shared.frontmostApplication, let bundleID = app.bundleIdentifier else { return }
        let source: String
        if bundleID.hasPrefix("com.apple.Safari") {
            source = "tell application id \"\(bundleID)\" to return URL of front document"
        } else if bundleID == "org.mozilla.firefox" {
            NSSound.beep() // Firefox can't be asked for its address.
            return
        } else {
            source = "tell application id \"\(bundleID)\" to return URL of active tab of front window"
        }
        var error: NSDictionary?
        guard let url = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, !url.isEmpty else {
            NSSound.beep()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        HUD.show("Address Copied", systemImage: "link")
    }

    static func showBattery() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let level = description[kIOPSCurrentCapacityKey] as? Int
            else { continue }
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            HUD.show("Battery \(level)%\(charging ? ", Charging" : "")", systemImage: charging ? "battery.100percent.bolt" : "battery.75percent")
            return
        }
        HUD.show("No Battery", systemImage: "powerplug")
    }

    /// The POSIX paths of the files selected in Finder.
    private static func finderSelection() -> [String]? {
        let source = """
        tell application "Finder" to set picked to selection as alias list
        set paths to {}
        repeat with f in picked
            set end of paths to POSIX path of f
        end repeat
        set AppleScript's text item delimiters to linefeed
        return paths as text
        """
        var error: NSDictionary?
        guard let text = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else { return nil }
        return text.split(separator: "\n").map(String.init)
    }
}
