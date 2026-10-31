import Foundation

/// What sets a shortcut off: some keys, a click on a window button, a
/// trackpad gesture, an extra mouse button, something you type, or
/// something that happens (an app opening, the Mac waking…).
nonisolated enum Trigger: Codable, Hashable {
    case keys(combo: KeyCombo)
    case trafficLight(click: TrafficLightClick)
    case gesture(gesture: Gesture)
    case mouseButton(click: MouseButtonClick)
    /// Typing this abbreviation, like ";email".
    case typedText(abbreviation: String)
    case event(event: AutomationEvent)
    /// Tapping ⌘ ⌥ ⌃ ⇧ or fn on its own, once or twice.
    case modifierTap(tap: ModifierTap)

    /// Whether two triggers would fire on the same thing.
    func clashes(with other: Trigger) -> Bool {
        switch (self, other) {
        case let (.keys(a), .keys(b)):
            a.matches(keyCode: b.keyCode, modifiers: b.modifiers)
        case let (.trafficLight(a), .trafficLight(b)):
            a == b
        case let (.gesture(a), .gesture(b)):
            a == b
        case let (.mouseButton(a), .mouseButton(b)):
            a == b
        case let (.typedText(a), .typedText(b)):
            a == b
        case let (.modifierTap(a), .modifierTap(b)):
            a.clashes(with: b)
        case (.event, .event):
            // Doing several things when one event happens is fine.
            false
        default:
            false
        }
    }
}

/// The red, yellow and green buttons in the corner of every window.
nonisolated enum TrafficLightButton: String, Codable, CaseIterable, Identifiable {
    case close, minimize, zoom

    var id: Self { self }

    var title: String {
        switch self {
        case .close: "Close"
        case .minimize: "Minimise"
        case .zoom: "Zoom"
        }
    }
}

nonisolated enum MouseButton: String, Codable, CaseIterable, Identifiable {
    case left, right, middle

    var id: Self { self }

    var title: String {
        switch self {
        case .left: "Click"
        case .right: "Right-click"
        case .middle: "Middle-click"
        }
    }

    /// How macOS numbers mouse buttons.
    init?(number: Int64) {
        switch number {
        case 0: self = .left
        case 1: self = .right
        case 2: self = .middle
        default: return nil
        }
    }
}

/// A particular kind of click on a particular traffic light, like ⌥-clicking red.
nonisolated struct TrafficLightClick: Codable, Hashable {
    var button: TrafficLightButton
    var mouseButton: MouseButton
    var modifiers: Modifiers

    /// E.g. "⌥ Right-click".
    var clickDescription: String {
        modifiers.isEmpty ? mouseButton.title : "\(modifiers.symbols) \(mouseButton.title)"
    }
}

/// Pressing one of a mouse's extra buttons, optionally while holding ⌃⌥⇧⌘.
/// Left and right click aren't included, so ordinary clicking always works.
nonisolated struct MouseButtonClick: Codable, Hashable {
    /// How macOS numbers mouse buttons: 2 is the middle button (usually pressing
    /// the wheel), 3 and 4 are usually the thumb buttons for back and forward.
    var button: Int
    var modifiers: Modifiers

    /// The buttons you can choose from.
    static let choices = Array(2...9)

    static func name(of button: Int) -> String {
        switch button {
        case 2: "Middle Button"
        case 3: "Back Button"
        case 4: "Forward Button"
        default: "Button \(button + 1)"
        }
    }

    /// E.g. "⌥ Back Button".
    var title: String {
        modifiers.isEmpty ? Self.name(of: button) : "\(modifiers.symbols) \(Self.name(of: button))"
    }
}

/// Tapping a modifier key by itself, like double-tapping ⌘ or tapping right ⌥.
/// It only counts if you let go quickly without pressing anything else.
nonisolated struct ModifierTap: Codable, Hashable {
    enum Key: String, Codable, CaseIterable, Identifiable {
        case command, option, control, shift, function

        var id: Self { self }

        var symbol: String {
            switch self {
            case .command: "⌘"
            case .option: "⌥"
            case .control: "⌃"
            case .shift: "⇧"
            case .function: "fn"
            }
        }

        var name: String {
            switch self {
            case .command: "Command"
            case .option: "Option"
            case .control: "Control"
            case .shift: "Shift"
            case .function: "fn"
            }
        }

        /// fn only has one key, so it has no sides.
        var hasSides: Bool { self != .function }
    }

    enum Side: String, Codable, CaseIterable, Identifiable {
        case either, left, right

        var id: Self { self }

        var title: String {
            switch self {
            case .either: "Either"
            case .left: "Left"
            case .right: "Right"
            }
        }
    }

    var key: Key
    var side: Side
    /// 1 for a tap, 2 for a double tap.
    var taps: Int

    /// E.g. "Double-tap Right ⌘".
    var title: String {
        let side = key.hasSides && self.side != .either ? "\(self.side.title) " : ""
        return "\(taps == 2 ? "Double-tap" : "Tap") \(side)\(key.symbol)"
    }

    /// Whether one physical tap could set off both.
    func clashes(with other: ModifierTap) -> Bool {
        key == other.key && taps == other.taps
            && (side == other.side || side == .either || other.side == .either || !key.hasSides)
    }

    /// Whether a tap of this key, on this side, this many times, sets it off.
    func matches(key: Key, side: Side, taps: Int) -> Bool {
        self.key == key && self.taps == taps && (self.side == .either || self.side == side || !key.hasSides)
    }
}

/// Something that happens on your Mac, which can run an action.
nonisolated enum AutomationEvent: Codable, Hashable {
    case appLaunched(bundleID: String)
    case appQuit(bundleID: String)
    case appActivated(bundleID: String)
    case appDeactivated(bundleID: String)
    case macWoke
    case macWillSleep
    case screenLocked
    case screenUnlocked
    case chargerConnected
    case chargerDisconnected
    case displaySlept, displayWoke, screenSaverStarted, screenSaverStopped
    case spaceChanged, displayConnected, displayDisconnected
    case diskMounted, diskEjected, internetConnected, internetDisconnected

    enum Kind: String, CaseIterable, Identifiable {
        case appLaunched, appQuit, appActivated, appDeactivated, macWoke, macWillSleep, screenLocked, screenUnlocked
        case displaySlept, displayWoke, screenSaverStarted, screenSaverStopped
        case chargerConnected, chargerDisconnected, spaceChanged, displayConnected, displayDisconnected
        case diskMounted, diskEjected, internetConnected, internetDisconnected
        var id: Self { self }

        var title: String {
            switch self {
            case .appLaunched: "An App Opens"
            case .appQuit: "An App Quits"
            case .appActivated: "An App Comes to the Front"
            case .appDeactivated: "An App Goes to the Back"
            case .macWoke: "Mac Wakes"
            case .macWillSleep: "Mac Goes to Sleep"
            case .screenLocked: "Screen Locks"
            case .screenUnlocked: "Screen Unlocks"
            case .chargerConnected: "Charger Connected"
            case .chargerDisconnected: "Charger Disconnected"
            case .displaySlept: "Display Turns Off"
            case .displayWoke: "Display Turns On"
            case .screenSaverStarted: "Screen Saver Starts"
            case .screenSaverStopped: "Screen Saver Stops"
            case .spaceChanged: "You Switch Space"
            case .displayConnected: "A Display Is Connected"
            case .displayDisconnected: "A Display Is Disconnected"
            case .diskMounted: "A Disk Is Connected"
            case .diskEjected: "A Disk Is Ejected"
            case .internetConnected: "Internet Connects"
            case .internetDisconnected: "Internet Disconnects"
            }
        }

        var needsApp: Bool {
            self == .appLaunched || self == .appQuit || self == .appActivated || self == .appDeactivated
        }
    }

    init(kind: Kind, bundleID: String) {
        switch kind {
        case .appLaunched: self = .appLaunched(bundleID: bundleID)
        case .appQuit: self = .appQuit(bundleID: bundleID)
        case .appActivated: self = .appActivated(bundleID: bundleID)
        case .appDeactivated: self = .appDeactivated(bundleID: bundleID)
        case .macWoke: self = .macWoke
        case .macWillSleep: self = .macWillSleep
        case .screenLocked: self = .screenLocked
        case .screenUnlocked: self = .screenUnlocked
        case .chargerConnected: self = .chargerConnected
        case .chargerDisconnected: self = .chargerDisconnected
        case .displaySlept: self = .displaySlept
        case .displayWoke: self = .displayWoke
        case .screenSaverStarted: self = .screenSaverStarted
        case .screenSaverStopped: self = .screenSaverStopped
        case .spaceChanged: self = .spaceChanged
        case .displayConnected: self = .displayConnected
        case .displayDisconnected: self = .displayDisconnected
        case .diskMounted: self = .diskMounted
        case .diskEjected: self = .diskEjected
        case .internetConnected: self = .internetConnected
        case .internetDisconnected: self = .internetDisconnected
        }
    }

    var kind: Kind {
        switch self {
        case .appLaunched: .appLaunched
        case .appQuit: .appQuit
        case .appActivated: .appActivated
        case .appDeactivated: .appDeactivated
        case .macWoke: .macWoke
        case .macWillSleep: .macWillSleep
        case .screenLocked: .screenLocked
        case .screenUnlocked: .screenUnlocked
        case .chargerConnected: .chargerConnected
        case .chargerDisconnected: .chargerDisconnected
        case .displaySlept: .displaySlept
        case .displayWoke: .displayWoke
        case .screenSaverStarted: .screenSaverStarted
        case .screenSaverStopped: .screenSaverStopped
        case .spaceChanged: .spaceChanged
        case .displayConnected: .displayConnected
        case .displayDisconnected: .displayDisconnected
        case .diskMounted: .diskMounted
        case .diskEjected: .diskEjected
        case .internetConnected: .internetConnected
        case .internetDisconnected: .internetDisconnected
        }
    }

    /// The app, for app events.
    var bundleID: String? {
        switch self {
        case .appLaunched(let id), .appQuit(let id), .appActivated(let id), .appDeactivated(let id): id
        default: nil
        }
    }

    var systemImage: String {
        switch self {
        case .appLaunched: "app.badge"
        case .appQuit: "xmark.app"
        case .appActivated: "macwindow.on.rectangle"
        case .macWoke: "sun.horizon"
        case .macWillSleep: "moon.zzz"
        case .screenLocked: "lock"
        case .screenUnlocked: "lock.open"
        case .chargerConnected: "powerplug"
        case .chargerDisconnected: "battery.75percent"
        case .appDeactivated: "rectangle.on.rectangle.slash"
        case .displaySlept: "display"
        case .displayWoke: "sun.max"
        case .screenSaverStarted: "sparkles.tv"
        case .screenSaverStopped: "tv"
        case .spaceChanged: "square.split.2x1"
        case .displayConnected: "display.2"
        case .displayDisconnected: "display.trianglebadge.exclamationmark"
        case .diskMounted: "externaldrive.badge.plus"
        case .diskEjected: "eject"
        case .internetConnected: "wifi"
        case .internetDisconnected: "wifi.slash"
        }
    }
}
