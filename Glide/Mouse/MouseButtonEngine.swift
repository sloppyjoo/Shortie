import AppKit

/// Runs actions when you press a mouse's extra buttons (the middle button,
/// thumb buttons and so on).
///
/// Like the other engines, an event tap sees each button press before the app
/// under the pointer does. If it matches one of your mouse button actions, we
/// run the action and swallow the press, so the app never sees it.
final class MouseButtonEngine {
    static let shared = MouseButtonEngine()

    /// While set, the next button press goes here (to the recorder) instead of
    /// running an action.
    var recordingHandler: ((MouseButtonClick) -> Void)?

    private var tap: CFMachPort?
    /// After swallowing a press, also swallow that button's release.
    private var swallowingRelease: Int64?

    /// Safe to call repeatedly; does nothing until Accessibility is granted.
    func start() {
        guard Permissions.shared.accessibility else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue) | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: handleButtonEvent, userInfo: nil
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    /// Returns `true` to swallow the press.
    fileprivate func handle(_ type: CGEventType, button: Int64, flags: CGEventFlags) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .otherMouseUp:
            if swallowingRelease == button {
                swallowingRelease = nil
                return true
            }
            return false
        case .otherMouseDown:
            break
        default:
            return false
        }

        let click = MouseButtonClick(button: Int(button), modifiers: Modifiers(flags))

        if let recordingHandler {
            self.recordingHandler = nil
            recordingHandler(click)
            swallowingRelease = button
            return true
        }

        guard !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused),
              let shortcut = ShortcutStore.shared.match(.mouseButton(click: click), in: FrontmostApp.bundleID)
        else { return false }

        swallowingRelease = button
        let action = shortcut.action
        // Run it just after we return, so the mouse is never held up.
        DispatchQueue.main.async { ActionRunner.run(action) }
        return true
    }
}

/// Called by macOS for every extra-button press. Runs on the main thread (main run loop).
private nonisolated func handleButtonEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Let through the clicks Glide itself makes (like a Middle Click action).
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    let button = event.getIntegerValueField(.mouseEventButtonNumber)
    let flags = event.flags
    let swallow = MainActor.assumeIsolated { MouseButtonEngine.shared.handle(type, button: button, flags: flags) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
