import Foundation

/// What sets a shortcut off: some keys, a click on a window button, a
/// trackpad gesture, or an extra mouse button.
nonisolated enum Trigger: Codable, Hashable {
    case keys(combo: KeyCombo)
    case trafficLight(click: TrafficLightClick)
    case gesture(gesture: Gesture)
    case mouseButton(click: MouseButtonClick)

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
