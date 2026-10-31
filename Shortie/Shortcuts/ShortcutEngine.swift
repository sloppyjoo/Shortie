import AppKit

/// Listens to every key press on the Mac and runs the matching Shortie shortcut.
///
/// This uses an *event tap*: macOS hands Shortie each key press before the app
/// you're typing in sees it. If it matches one of your shortcuts, Shortie runs the
/// action and swallows the key press, so the app never sees it. Everything else
/// passes straight through untouched. This is why Shortie needs Accessibility.
final class ShortcutEngine {
    static let shared = ShortcutEngine()

    /// While you're recording a new shortcut, let every key through so the
    /// recorder sees it (instead of an existing shortcut firing).
    var isRecording = false

    /// Key presses so far, for the "A Key Was Pressed" condition.
    private(set) var keyPressCount = 0

    private var tap: CFMachPort?

    /// Safe to call repeatedly; does nothing until Accessibility is granted.
    func start() {
        guard Permissions.shared.accessibility else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
                | CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: handleTapEvent,
            userInfo: nil
        ) else { return }

        // Deliver key presses on the main thread, alongside the rest of the app.
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    /// Returns `true` to swallow the key press.
    fileprivate func handle(_ keyPress: KeyPress) -> Bool {
        switch keyPress.type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches the tap off if we're ever too slow. Switch it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown:
            break
        default:
            return false
        }

        guard !isRecording else { return false }
        if !keyPress.isRepeat { keyPressCount += 1 }
        let isPaused = UserDefaults.standard.bool(forKey: DefaultsKey.isPaused)

        let modifiers = Modifiers(keyPress.flags)
        let keys = KeyCombo(keyCode: keyPress.keyCode, modifiers: modifiers, keyName: "")

        // "Block Keyboard": swallow everything except the shortcut that unblocks it.
        if UIAutomation.isBlockingKeyboard {
            if !keyPress.isRepeat, let shortcut = ShortcutStore.shared.match(.keys(combo: keys), in: FrontmostApp.bundleID),
               shortcut.action == .system(action: .blockKeyboard) {
                DispatchQueue.main.async { ActionRunner.run(shortcut.action) }
            }
            return true
        }
        guard let shortcut = ShortcutStore.shared.match(.keys(combo: keys), in: FrontmostApp.bundleID) else {
            if isPaused { return false }
            // Not a shortcut, so it's ordinary typing: maybe it finishes a text shortcut.
            return TypedTextEngine.shared.typed(
                keyPress.characters, keyCode: keyPress.keyCode, modifiers: modifiers, isRepeat: keyPress.isRepeat
            )
        }

        // While paused, the only shortcut that works is the one that resumes.
        if isPaused, shortcut.action != .system(action: .togglePause) { return false }

        // Holding keys down repeats the key press; only act on the first one.
        if !keyPress.isRepeat {
            ShortcutStore.shared.noteFired(shortcut)
            // Run it just after we return, so the key press is never held up.
            DispatchQueue.main.async { ActionRunner.run(shortcut.action) }
        }
        return true
    }
}

/// The parts of a key press we care about, copied out of the system's event.
fileprivate nonisolated struct KeyPress {
    let type: CGEventType
    let keyCode: UInt16
    let flags: CGEventFlags
    let isRepeat: Bool
    /// What the key types, like "a" or "A".
    let characters: String
}

/// The C-style function macOS calls for every key press. It runs on the main
/// thread because the tap is attached to the main run loop.
private nonisolated func handleTapEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Keys Shortie presses itself (a "Press Keys" action) must never set off a shortcut.
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    // Caps Lock as Hyper: Caps Lock itself is swallowed, and keys pressed while
    // it's held get ⌃⌥⇧⌘ added before anything else sees them.
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let hyper = MainActor.assumeIsolated { () -> (isCapsLock: Bool, isHeld: Bool) in
        let hyperKey = HyperKey.shared
        guard hyperKey.isEnabled || KeyRemapper.usesHyper, type == .keyDown || type == .keyUp else { return (false, false) }
        if keyCode == HyperKey.keyCode {
            hyperKey.capsLock(isDown: type == .keyDown, isRepeat: isRepeat)
            return (true, true)
        }
        if hyperKey.isHeld, type == .keyDown { hyperKey.noteUsed() }
        return (false, hyperKey.isHeld)
    }
    if hyper.isCapsLock { return nil }
    if hyper.isHeld { event.flags.formUnion(HyperKey.flags) }

    // Modifier keys on their own: maybe a tap of ⌘ or ⌥. They always pass through.
    if type == .flagsChanged {
        let flags = event.flags
        MainActor.assumeIsolated { ModifierTapDetector.shared.flagsChanged(keyCode: keyCode, flags: flags) }
        return Unmanaged.passUnretained(event)
    }
    if type == .keyDown {
        MainActor.assumeIsolated { ModifierTapDetector.shared.keyPressed() }
    }

    var length = 0
    var characters = [UniChar](repeating: 0, count: 8)
    event.keyboardGetUnicodeString(maxStringLength: characters.count, actualStringLength: &length, unicodeString: &characters)
    let keyPress = KeyPress(
        type: type,
        keyCode: keyCode,
        flags: event.flags,
        isRepeat: isRepeat,
        characters: String(utf16CodeUnits: characters, count: length)
    )
    let swallow = MainActor.assumeIsolated { ShortcutEngine.shared.handle(keyPress) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
