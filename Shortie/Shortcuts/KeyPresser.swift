import Carbon.HIToolbox
import CoreGraphics

/// Presses a keyboard shortcut, as if you'd typed it, in whatever app is in front.
enum KeyPresser {
    /// `extraFlags` is for keys macOS expects with more than ⌃⌥⇧⌘, like arrows.
    static func press(_ combo: KeyCombo, extraFlags: CGEventFlags = []) {
        // A private event source, so modifier keys you're physically holding
        // (say, from the shortcut that triggered this) don't get mixed in.
        let source = CGEventSource(stateID: .privateState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: isDown)
            event?.flags = combo.modifiers.eventFlags.union(extraFlags)
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }
}

extension Modifiers {
    nonisolated var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }
}

/// Everyday keyboard shortcuts, ready to pick for a gesture or traffic light,
/// so you don't have to record them yourself.
nonisolated struct KeyPreset: Identifiable {
    let title: String
    let combo: KeyCombo
    var id: String { title }

    private init(_ title: String, _ keyCode: Int, _ modifiers: Modifiers, _ keyName: String) {
        self.title = title
        self.combo = KeyCombo(keyCode: UInt16(keyCode), modifiers: modifiers, keyName: keyName)
    }

    static let groups: [(title: String, presets: [KeyPreset])] = [
        ("Browsing", [
            KeyPreset("Back", kVK_ANSI_LeftBracket, .command, "["),
            KeyPreset("Forward", kVK_ANSI_RightBracket, .command, "]"),
            KeyPreset("Reload", kVK_ANSI_R, .command, "R"),
            KeyPreset("New Tab", kVK_ANSI_T, .command, "T"),
            KeyPreset("Close Tab", kVK_ANSI_W, .command, "W"),
            KeyPreset("Reopen Closed Tab", kVK_ANSI_T, [.shift, .command], "T"),
            KeyPreset("Next Tab", kVK_Tab, .control, "⇥"),
            KeyPreset("Previous Tab", kVK_Tab, [.control, .shift], "⇥"),
            KeyPreset("New Window", kVK_ANSI_N, .command, "N"),
        ]),
        ("Editing", [
            KeyPreset("Copy", kVK_ANSI_C, .command, "C"),
            KeyPreset("Cut", kVK_ANSI_X, .command, "X"),
            KeyPreset("Paste", kVK_ANSI_V, .command, "V"),
            KeyPreset("Undo", kVK_ANSI_Z, .command, "Z"),
            KeyPreset("Redo", kVK_ANSI_Z, [.shift, .command], "Z"),
            KeyPreset("Select All", kVK_ANSI_A, .command, "A"),
            KeyPreset("Find", kVK_ANSI_F, .command, "F"),
            KeyPreset("Save", kVK_ANSI_S, .command, "S"),
        ]),
        ("Viewing", [
            KeyPreset("Zoom In", kVK_ANSI_Equal, .command, "="),
            KeyPreset("Zoom Out", kVK_ANSI_Minus, .command, "-"),
            KeyPreset("Actual Size", kVK_ANSI_0, .command, "0"),
            KeyPreset("Scroll to Top", kVK_UpArrow, .command, "↑"),
            KeyPreset("Scroll to Bottom", kVK_DownArrow, .command, "↓"),
        ]),
        ("Keys", [
            KeyPreset("Escape", kVK_Escape, [], "⎋"),
            KeyPreset("Return", kVK_Return, [], "↩"),
            KeyPreset("Space", kVK_Space, [], "Space"),
            KeyPreset("Switch App", kVK_Tab, .command, "⇥"),
            KeyPreset("Switch Window", kVK_ANSI_Grave, .command, "`"),
        ]),
    ]

    /// The preset these keys match, if any, for a friendly name.
    static func matching(_ combo: KeyCombo) -> KeyPreset? {
        groups.lazy.flatMap(\.presets).first { $0.combo.matches(keyCode: combo.keyCode, modifiers: combo.modifiers) }
    }
}
