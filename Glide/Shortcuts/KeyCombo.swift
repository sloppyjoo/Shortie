import AppKit
import Carbon.HIToolbox

/// A key plus modifier keys, like ⌃⌥T.
nonisolated struct KeyCombo: Codable, Hashable {
    /// The physical key, as macOS numbers it. It stays the same whatever
    /// keyboard layout (English, French, …) is active.
    var keyCode: UInt16
    var modifiers: Modifiers
    /// How the key is labelled, e.g. "T" or "→". Saved so the config file is readable.
    var keyName: String

    var displayString: String { modifiers.symbols + keyName }

    func matches(keyCode: UInt16, modifiers: Modifiers) -> Bool {
        self.keyCode == keyCode && self.modifiers == modifiers
    }
}

/// The ⌃ ⌥ ⇧ ⌘ keys.
nonisolated struct Modifiers: OptionSet, Hashable {
    let rawValue: Int

    static let control = Modifiers(rawValue: 1 << 0)
    static let option = Modifiers(rawValue: 1 << 1)
    static let shift = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// From a key press seen inside Glide's own windows.
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }

    /// From a key press seen by the event tap.
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    /// In the order Apple always shows them: ⌃⌥⇧⌘.
    var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

/// Saved as a list of words, e.g. `["control", "option"]`, rather than a number,
/// so the config file stays readable.
extension Modifiers: Codable {
    private static let names: [(String, Modifiers)] = [
        ("control", .control), ("option", .option), ("shift", .shift), ("command", .command),
    ]

    init(from decoder: Decoder) throws {
        let saved = try decoder.singleValueContainer().decode([String].self)
        self.init(Self.names.filter { saved.contains($0.0) }.map(\.1))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.names.filter { contains($0.1) }.map(\.0))
    }
}

/// Turns key codes into the labels printed on your keyboard.
enum KeyNames {
    static func name(for keyCode: UInt16) -> String {
        specialKeys[Int(keyCode)] ?? character(for: keyCode) ?? "Key \(keyCode)"
    }

    /// F1–F20 can be shortcuts on their own; every other key needs a modifier,
    /// or you'd lose the ability to type that letter.
    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        functionKeys.contains(Int(keyCode))
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    private static let specialKeys: [Int: String] = {
        var keys: [Int: String] = [
            kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥", kVK_Space: "Space",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        ]
        let fKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, code) in fKeys.enumerated() {
            keys[code] = "F\(index + 1)"
        }
        return keys
    }()

    /// Asks the current keyboard layout which character a key types.
    private static func character(for keyCode: UInt16) -> String? {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layout = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes { bytes in
            UCKeyTranslate(
                bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress,
                keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState,
                characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
