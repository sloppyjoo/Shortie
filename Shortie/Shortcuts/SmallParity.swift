import AppKit

/// Keeps the pointer moving along one line (left–right or up–down) until switched off.
enum MouseAxisLock {
    enum Axis {
        case horizontal, vertical
    }

    private(set) static var axis: Axis?
    fileprivate static var anchor = CGPoint.zero
    private static var tap: CFMachPort?

    static func toggle(_ newAxis: Axis) {
        if axis == newAxis {
            axis = nil
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            HUD.show("Pointer Unlocked", systemImage: "lock.open")
            return
        }
        axis = newAxis
        anchor = CGEvent(source: nil)?.location ?? .zero
        startTap()
        HUD.show(newAxis == .horizontal ? "Pointer Moves Only Left and Right" : "Pointer Moves Only Up and Down", systemImage: "lock")
    }

    private static func startTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                             eventsOfInterest: mask, callback: handleAxisEvent, userInfo: nil)
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, newTap, 0), .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
    }

    fileprivate static func reenable() {
        if let tap, axis != nil { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

private nonisolated func handleAxisEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { MouseAxisLock.reenable() }
        return Unmanaged.passUnretained(event)
    }
    let (axis, anchor) = MainActor.assumeIsolated { (MouseAxisLock.axis, MouseAxisLock.anchor) }
    guard let axis else { return Unmanaged.passUnretained(event) }
    var location = event.location
    switch axis {
    case .horizontal:
        location.y = anchor.y
        event.setIntegerValueField(.mouseEventDeltaY, value: 0)
    case .vertical:
        location.x = anchor.x
        event.setIntegerValueField(.mouseEventDeltaX, value: 0)
    }
    event.location = location
    CGWarpMouseCursorPosition(location)
    CGAssociateMouseAndMouseCursorPosition(1)
    return Unmanaged.passUnretained(event)
}

/// Goes to the login window without logging out, like the Fast User Switching menu.
enum LoginWindow {
    private typealias Switch = @convention(c) () -> Int32

    static func show() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACSwitchToLoginWindow")
        else {
            NSSound.beep()
            return
        }
        _ = unsafeBitCast(symbol, to: Switch.self)()
    }
}

/// Runs a different one of its actions each time: the first, then the second… then round again.
enum ActionCycle {
    private static var positions: [Int: Int] = [:]

    static func run(_ actions: [ShortcutAction], target: ActionTarget?) {
        guard !actions.isEmpty else { return }
        let key = actions.hashValue
        let index = (positions[key] ?? 0) % actions.count
        positions[key] = index + 1
        ActionRunner.run(actions[index], on: target)
    }
}
