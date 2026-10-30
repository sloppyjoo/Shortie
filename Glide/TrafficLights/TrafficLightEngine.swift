import AppKit
import ApplicationServices

/// Gives the red, yellow and green window buttons extra actions.
///
/// An event tap sees every mouse click before the app under the pointer does.
/// When a click matches one of your traffic light actions (say, a right-click),
/// we ask the Accessibility API what's under the pointer. If it's a window's
/// close, minimise or zoom button, we run your action and swallow the click,
/// so the window never sees it. All other clicks pass straight through.
final class TrafficLightEngine {
    static let shared = TrafficLightEngine()

    private var tap: CFMachPort?
    private let systemWide = AXUIElementCreateSystemWide()

    /// After swallowing a button press, also swallow its release, or the app
    /// would see a stray "mouse up".
    private var swallowingRelease: MouseButton?

    private init() {
        // If an app is frozen, don't wait more than a moment for it to answer.
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
    }

    /// Safe to call repeatedly; does nothing until Accessibility is granted.
    func start() {
        guard Permissions.shared.accessibility else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: handleClickEvent,
            userInfo: nil
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    /// Only watch clicks while you have window button rules.
    func updateNeed() {
        let needed = ShortcutStore.shared.shortcuts.contains { $0.isEnabled && $0.trafficLightClick != nil }
        if let tap { CGEvent.tapEnable(tap: tap, enable: needed) }
    }

    /// Returns `true` to swallow the click.
    fileprivate func handle(_ click: MouseClick) -> Bool {
        switch click.type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if let swallowingRelease, swallowingRelease == click.mouseButton {
                self.swallowingRelease = nil
                return true
            }
            return false
        default:
            break
        }

        guard let mouseButton = click.mouseButton,
              !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused)
        else { return false }

        // Most clicks have nothing to do with us, so check the (instant) settings
        // before asking the app under the pointer anything.
        let modifiers = Modifiers(click.flags)
        let candidates = ShortcutStore.shared.shortcuts.filter {
            guard $0.isEnabled, let rule = $0.trafficLightClick else { return false }
            return rule.mouseButton == mouseButton && rule.modifiers == modifiers
        }
        guard !candidates.isEmpty, let hit = trafficLight(at: click.location) else { return false }

        // Rules can be limited to certain apps: check against the app whose window was clicked.
        let trigger = Trigger.trafficLight(click: TrafficLightClick(button: hit.button, mouseButton: mouseButton, modifiers: modifiers))
        let app = NSRunningApplication(processIdentifier: hit.target.processID)?.bundleIdentifier
        guard let match = ShortcutStore.shared.match(trigger, in: app) else { return false }

        swallowingRelease = mouseButton
        let action = match.action
        let target = hit.target
        // Run it just after we return, so the click is never held up.
        DispatchQueue.main.async { ActionRunner.run(action, on: target) }
        return true
    }

    /// Which traffic light, if any, is under a point on the screen.
    private func trafficLight(at point: CGPoint) -> (button: TrafficLightButton, target: ActionTarget)? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element
        else { return nil }

        // Sometimes we get the picture inside the button, so check its parent too.
        for candidate in [element, AX.element(element, kAXParentAttribute)].compactMap({ $0 }) {
            let button: TrafficLightButton
            switch AX.string(candidate, kAXSubroleAttribute) {
            case kAXCloseButtonSubrole: button = .close
            case kAXMinimizeButtonSubrole: button = .minimize
            case kAXZoomButtonSubrole, kAXFullScreenButtonSubrole: button = .zoom
            default: continue
            }
            var processID: pid_t = 0
            AXUIElementGetPid(candidate, &processID)
            let window = AX.element(candidate, kAXWindowAttribute)
            return (button, ActionTarget(window: window, processID: processID))
        }
        return nil
    }
}

/// The parts of a click we care about, copied out of the system's event.
fileprivate nonisolated struct MouseClick {
    let type: CGEventType
    let mouseButton: MouseButton?
    let flags: CGEventFlags
    /// In screen coordinates measured from the top-left, like the Accessibility API.
    let location: CGPoint
}

/// Called by macOS for every click. Runs on the main thread (main run loop).
private nonisolated func handleClickEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Let through the clicks Glide itself makes (like a gesture's Right Click action).
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    let click = MouseClick(
        type: type,
        mouseButton: MouseButton(number: event.getIntegerValueField(.mouseEventButtonNumber)),
        flags: event.flags,
        location: event.location
    )
    let swallow = MainActor.assumeIsolated { TrafficLightEngine.shared.handle(click) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
