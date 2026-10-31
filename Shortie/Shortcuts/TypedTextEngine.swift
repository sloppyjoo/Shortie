import AppKit
import Carbon.HIToolbox

/// Notices when you type one of your text shortcuts' abbreviations (like
/// ";email"), erases it, and runs its action, usually typing the full text.
///
/// It's fed by `ShortcutEngine`, which already sees every key press. Only the
/// last few characters are kept, in memory, just long enough to compare with
/// your abbreviations; nothing is saved or sent anywhere. macOS hides what you
/// type into password fields from every app, so those are never seen.
final class TypedTextEngine {
    static let shared = TypedTextEngine()

    /// The last few characters you typed.
    private var recent = ""
    private var lastTypedAt = Date.distantPast
    private static let memoryLength = 64

    /// Keys that move the cursor somewhere else, so what you type next isn't
    /// joined onto what came before.
    private static let resettingKeys: Set<Int> = [
        kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab, kVK_Escape, kVK_ForwardDelete,
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
        kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
    ]

    private init() {
        // Switching apps starts afresh, for the same reason.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { TypedTextEngine.shared.recent = "" }
        }
    }

    /// Called for every key press that isn't a shortcut. Returns `true` to
    /// swallow it (when it's the last character of an abbreviation).
    func typed(_ characters: String, keyCode: UInt16, modifiers: Modifiers, isRepeat: Bool) -> Bool {
        // A pause of a few seconds, ⌘ or ⌃ shortcuts, or cursor keys all start afresh.
        if Date().timeIntervalSince(lastTypedAt) > 5 { recent = "" }
        lastTypedAt = Date()

        if modifiers.contains(.command) || modifiers.contains(.control) || Self.resettingKeys.contains(Int(keyCode)) {
            recent = ""
            return false
        }
        if Int(keyCode) == kVK_Delete {
            if !recent.isEmpty { recent.removeLast() }
            return false
        }
        guard !isRepeat, !characters.isEmpty,
              !characters.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return false }

        recent = String((recent + characters).suffix(Self.memoryLength))

        // Don't fire while you're typing an abbreviation into Shortie itself.
        let app = FrontmostApp.bundleID
        guard app != Bundle.main.bundleIdentifier,
              let (shortcut, abbreviation) = match(in: app)
        else { return false }

        recent = ""
        // The abbreviation's last character hasn't reached the app yet (we swallow
        // it), so erase only the ones already typed, then run the action.
        let alreadyTyped = abbreviation.count - 1
        let action = shortcut.action
        DispatchQueue.main.async {
            for _ in 0..<alreadyTyped {
                KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Delete), modifiers: [], keyName: "⌫"))
            }
            ActionRunner.run(action)
        }
        return true
    }

    /// The text shortcut whose abbreviation you've just finished typing, if any.
    /// Longer abbreviations win (so ";em" doesn't steal ";email"), then ones
    /// limited to this app.
    private func match(in app: String?) -> (Shortcut, String)? {
        let candidates = ShortcutStore.shared.shortcuts.compactMap { shortcut -> (Shortcut, String)? in
            guard shortcut.isEnabled, let abbreviation = shortcut.abbreviation, !abbreviation.isEmpty,
                  recent.hasSuffix(abbreviation), shortcut.apps?.includes(app) ?? true,
                  startsAWord(abbreviation)
            else { return nil }
            return (shortcut, abbreviation)
        }
        return candidates.max { a, b in
            if a.1.count != b.1.count { return a.1.count < b.1.count }
            return a.0.apps?.mode != .only && b.0.apps?.mode == .only
        }
    }

    /// An abbreviation that begins with a letter or number only counts at the
    /// start of a word, so "btw" doesn't fire inside "subtweet". One that begins
    /// with a symbol, like ";", can go anywhere.
    private func startsAWord(_ abbreviation: String) -> Bool {
        guard let first = abbreviation.first, first.isLetter || first.isNumber else { return true }
        guard let before = recent.dropLast(abbreviation.count).last else { return true }
        return !(before.isLetter || before.isNumber)
    }
}
