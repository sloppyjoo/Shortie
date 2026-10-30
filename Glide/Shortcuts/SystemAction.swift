import AppKit
import ApplicationServices
import Carbon.HIToolbox
import IOKit.hidsystem

/// Built-in Mac things a shortcut or gesture can do: media keys, Control Centre,
/// Mission Control, screenshots, locking the screen…
nonisolated enum SystemAction: String, Codable, CaseIterable, Identifiable {
    case playPause, nextTrack, previousTrack
    case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    case controlCentre, notificationCentre, missionControl, appExpose, showDesktop, apps, spotlight, emojiAndSymbols
    case windowSwitcher
    case screenshotTool, screenshotSelection, screenshotScreen
    case lockScreen, sleepDisplay, sleep

    var id: Self { self }

    var title: String {
        switch self {
        case .playPause: "Play or Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        case .brightnessUp: "Brightness Up"
        case .brightnessDown: "Brightness Down"
        case .controlCentre: "Open Control Centre"
        case .notificationCentre: "Open Notification Centre"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        case .showDesktop: "Show Desktop"
        case .apps: "Show Apps"
        case .spotlight: "Spotlight"
        case .emojiAndSymbols: "Emoji & Symbols"
        case .windowSwitcher: "Window Switcher"
        case .screenshotTool: "Screenshot Tool"
        case .screenshotSelection: "Screenshot of Selection"
        case .screenshotScreen: "Screenshot of Screen"
        case .lockScreen: "Lock Screen"
        case .sleepDisplay: "Turn Display Off"
        case .sleep: "Sleep"
        }
    }

    var systemImage: String {
        switch self {
        case .playPause: "playpause.fill"
        case .nextTrack: "forward.fill"
        case .previousTrack: "backward.fill"
        case .volumeUp: "speaker.wave.3.fill"
        case .volumeDown: "speaker.wave.1.fill"
        case .mute: "speaker.slash.fill"
        case .brightnessUp: "sun.max.fill"
        case .brightnessDown: "sun.min.fill"
        case .controlCentre: "switch.2"
        case .notificationCentre: "bell.fill"
        case .missionControl: "rectangle.3.group"
        case .appExpose: "rectangle.stack"
        case .showDesktop: "menubar.dock.rectangle"
        case .apps: "square.grid.3x3.fill"
        case .spotlight: "magnifyingglass"
        case .emojiAndSymbols: "face.smiling"
        case .windowSwitcher: "rectangle.on.rectangle"
        case .screenshotTool: "camera.viewfinder"
        case .screenshotSelection: "rectangle.dashed"
        case .screenshotScreen: "camera.fill"
        case .lockScreen: "lock.fill"
        case .sleepDisplay: "display"
        case .sleep: "moon.fill"
        }
    }

    /// For menus, so related actions sit together.
    static let groups: [[SystemAction]] = [
        [.playPause, .nextTrack, .previousTrack],
        [.volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown],
        [.windowSwitcher, .controlCentre, .notificationCentre, .missionControl, .appExpose, .showDesktop, .apps, .spotlight, .emojiAndSymbols],
        [.screenshotTool, .screenshotSelection, .screenshotScreen],
        [.lockScreen, .sleepDisplay, .sleep],
    ]
}

enum SystemActionRunner {
    static func run(_ action: SystemAction) {
        switch action {
        case .playPause: MediaKey.press(NX_KEYTYPE_PLAY)
        case .nextTrack: MediaKey.press(NX_KEYTYPE_NEXT)
        case .previousTrack: MediaKey.press(NX_KEYTYPE_PREVIOUS)
        case .volumeUp: MediaKey.press(NX_KEYTYPE_SOUND_UP)
        case .volumeDown: MediaKey.press(NX_KEYTYPE_SOUND_DOWN)
        case .mute: MediaKey.press(NX_KEYTYPE_MUTE)
        case .brightnessUp: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_UP)
        case .brightnessDown: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_DOWN)

        case .controlCentre:
            MenuBarExtras.press(identifierContaining: "controlcenter")
        case .notificationCentre:
            // Clicking the clock opens Notification Centre.
            MenuBarExtras.press(identifierContaining: "clock")
        case .missionControl:
            missionControl()
        case .appExpose:
            missionControl("2")
        case .showDesktop:
            missionControl("1")
        case .apps:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Apps.app"))
        case .spotlight:
            if !MenuBarExtras.press(identifierContaining: "spotlight") {
                KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Space), modifiers: .command, keyName: "Space"))
            }
        case .windowSwitcher:
            WindowSwitcher.shared.show()
        case .emojiAndSymbols:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Space), modifiers: [.control, .command], keyName: "Space"))

        // These use macOS's own screenshot shortcuts, so your save location and
        // other Screenshot settings apply.
        case .screenshotTool:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_5), modifiers: [.shift, .command], keyName: "5"))
        case .screenshotSelection:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_4), modifiers: [.shift, .command], keyName: "4"))
        case .screenshotScreen:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_3), modifiers: [.shift, .command], keyName: "3"))

        case .lockScreen:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_Q), modifiers: [.control, .command], keyName: "Q"))
        case .sleepDisplay:
            run("/usr/bin/pmset", ["displaysleepnow"])
        case .sleep:
            run("/usr/bin/pmset", ["sleepnow"])
        }
    }

    /// Mission Control's own app takes "1" for Show Desktop and "2" for App Exposé.
    private static func missionControl(_ argument: String? = nil) {
        run("/System/Applications/Mission Control.app/Contents/MacOS/Mission Control", argument.map { [$0] } ?? [])
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}

/// The media keys on a Mac keyboard (play, volume, brightness…) aren't ordinary
/// keys: they're sent as special "system" events, which we imitate here.
private enum MediaKey {
    static func press(_ key: Int32) {
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00)
            let data1 = (Int(key) << 16) | ((isDown ? 0xA : 0xB) << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// The icons on the right of the menu bar (Control Centre, the clock, Spotlight…).
/// Pressing one through the Accessibility API is the same as clicking it.
private enum MenuBarExtras {
    /// The system processes that own menu bar icons. Newer macOS versions keep
    /// them all in MenuBarAgent; older ones spread them across the others.
    private static let owners = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.Spotlight", "com.apple.systemuiserver"]

    @discardableResult
    static func press(identifierContaining fragment: String) -> Bool {
        for bundleID in owners {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                guard let bar = AX.element(element, "AXExtrasMenuBar"),
                      let item = find(fragment, in: bar, depth: 0)
                else { continue }
                AXUIElementPerformAction(item, kAXPressAction as CFString)
                return true
            }
        }
        return false
    }

    /// Icons can sit directly in the menu bar or be wrapped in a container
    /// (newer macOS), so look a few levels down.
    private static func find(_ fragment: String, in element: AXUIElement, depth: Int) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        for child in children as? [AXUIElement] ?? [] {
            if AX.string(child, "AXIdentifier")?.localizedCaseInsensitiveContains(fragment) == true {
                return child
            }
            if depth < 2, let found = find(fragment, in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }
}
