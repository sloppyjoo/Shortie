import AppKit

/// Listens to every key press on the Mac and runs the matching Glide shortcut.
///
/// This uses an *event tap*: macOS hands Glide each key press before the app
/// you're typing in sees it. If it matches one of your shortcuts, Glide runs the
/// action and swallows the key press, so the app never sees it. Everything else
/// passes straight through untouched. This is why Glide needs Accessibility.
final class ShortcutEngine {
    static let shared = ShortcutEngine()

    /// While you're recording a new shortcut, let every key through so the
    /// recorder sees it (instead of an existing shortcut firing).
    var isRecording = false

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
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
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

        guard !isRecording, !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused) else { return false }

        let keys = KeyCombo(keyCode: keyPress.keyCode, modifiers: Modifiers(keyPress.flags), keyName: "")
        guard let shortcut = ShortcutStore.shared.match(.keys(combo: keys), in: FrontmostApp.bundleID) else { return false }

        // Holding keys down repeats the key press; only act on the first one.
        if !keyPress.isRepeat {
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
}

/// The C-style function macOS calls for every key press. It runs on the main
/// thread because the tap is attached to the main run loop.
private nonisolated func handleTapEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Keys Glide presses itself (a "Press Keys" action) must never set off a shortcut.
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    let keyPress = KeyPress(
        type: type,
        keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
        flags: event.flags,
        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    )
    let swallow = MainActor.assumeIsolated { ShortcutEngine.shared.handle(keyPress) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
