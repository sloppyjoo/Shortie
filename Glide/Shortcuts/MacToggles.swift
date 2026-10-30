import AppKit

/// Mac settings that actions switch on and off.
enum MacToggles {
    /// Mutes the microphone by setting its input level to zero, and puts the
    /// level back when switched on again.
    static func toggleMicrophone() {
        guard let level = appleScriptNumber("input volume of (get volume settings)") else {
            NSSound.beep()
            return
        }
        if level > 0 {
            UserDefaults.standard.set(level, forKey: DefaultsKey.microphoneLevel)
            _ = appleScriptNumber("set volume input volume 0")
            HUD.show("Microphone Off", systemImage: "mic.slash.fill")
        } else {
            let saved = UserDefaults.standard.integer(forKey: DefaultsKey.microphoneLevel)
            _ = appleScriptNumber("set volume input volume \(saved > 0 ? saved : 75)")
            HUD.show("Microphone On", systemImage: "mic.fill")
        }
    }

    /// Flips one of Finder's on/off settings and restarts Finder, which only
    /// reads them when it starts. Returns the new value.
    static func toggleFinderSetting(_ key: String, defaultValue: Bool) -> Bool {
        let domain = "com.apple.finder" as CFString
        let isOn: Bool = switch CFPreferencesCopyAppValue(key as CFString, domain) {
        case let value as Bool: value
        // Some guides set these as text, like "YES" or "TRUE".
        case let value as String: ["1", "yes", "true"].contains(value.lowercased())
        default: defaultValue
        }
        CFPreferencesSetAppValue(key as CFString, (!isOn) as CFBoolean, domain)
        CFPreferencesAppSynchronize(domain)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
        return !isOn
    }

    /// Ejects every disk you could eject from Finder: USB drives, SD cards, disk images.
    static func ejectAll() {
        let keys: Set<URLResourceKey> = [.volumeIsEjectableKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        let ejectable = volumes.filter { (try? $0.resourceValues(forKeys: keys))?.volumeIsEjectable == true }
        guard !ejectable.isEmpty else {
            HUD.show("No Disks to Eject", systemImage: "eject")
            return
        }
        HUD.show(ejectable.count == 1 ? "Ejecting 1 Disk" : "Ejecting \(ejectable.count) Disks", systemImage: "eject.fill")
        // Ejecting waits for each disk to finish writing, so do it in the background.
        Task.detached {
            for volume in ejectable {
                try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
            }
        }
    }

    /// Runs a line of AppleScript inside BestTouchTool and returns its result as a number.
    /// Only for Standard Additions commands like `set volume`, which need no permission.
    private static func appleScriptNumber(_ source: String) -> Int? {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else { return nil }
        return Int(result.int32Value)
    }
}
