import AppKit
import Observation

/// Watches your trackpad(s), recognises gestures, and runs the action you've
/// given each one.
///
/// Finger positions come from MultitouchSupport, Apple's private trackpad
/// framework, about 100 times a second. Clicks come from an event tap (so a
/// click used as a gesture can be swallowed), and force clicks from macOS's
/// pressure events, each combined with how many fingers are touching.
///
/// macOS's own trackpad gestures (like swiping between desktops) happen before
/// any app hears about them, so Shortie can't stop those; it warns you instead.
@Observable
final class GestureEngine {
    static let shared = GestureEngine()

    enum Status {
        case notStarted
        case running(trackpads: Int)
        /// MultitouchSupport couldn't be loaded (for example, Apple changed it).
        case unavailable
    }

    private(set) var status = Status.notStarted

    /// Fingers currently on the trackpad. Only kept up to date while something
    /// is watching (the Gesture Lab), to save work the rest of the time.
    private(set) var liveTouches: [TouchPoint] = []
    var isWatching = false {
        didSet { updateListening() }
    }

    /// The trackpad's shape, for drawing it. Width ÷ height.
    private(set) var aspectRatio = 1.6

    /// The most recent gestures, newest first.
    private(set) var recentGestures: [RecognizedGesture] = []

    /// While set, the next gesture goes here (to the gesture recorder) instead
    /// of running an action.
    @ObservationIgnored var recordingHandler: ((Gesture) -> Void)? {
        didSet { updateListening() }
    }

    @ObservationIgnored private var recognizers: [Int: GestureRecognizer] = [:]
    /// The fingers touching each trackpad right now.
    @ObservationIgnored private var touching: [Int: [TouchPoint]] = [:]
    /// A tap waiting to see if a second one turns it into a double tap.
    @ObservationIgnored private var pendingTap: (fingers: Int, work: DispatchWorkItem)?
    /// Swallow clicks until this time; see `handleTap`.
    @ObservationIgnored private var ignoreClicksUntil = Date.distantPast
    @ObservationIgnored private var devices: CFArray?
    @ObservationIgnored private var deviceList: [MTDeviceRef] = []
    @ObservationIgnored private var registerFrames: MTRegisterContactFrameCallbackFunction?
    @ObservationIgnored private var unregisterFrames: MTUnregisterContactFrameCallbackFunction?
    @ObservationIgnored private var startDevice: MTDeviceStartFunction?
    @ObservationIgnored private var stopDevice: MTDeviceStopFunction?
    /// Whether finger data is flowing. It's only switched on when something
    /// needs it, since reading the trackpad ~100 times a second costs battery.
    @ObservationIgnored private var isListening = false
    @ObservationIgnored private var pressureMonitors: [Any] = []
    @ObservationIgnored private var lastPressureStage = 0
    @ObservationIgnored private var clickTap: CFMachPort?
    /// After swallowing a click, also swallow its release.
    @ObservationIgnored private var swallowingRelease: CGEventType?

    /// Safe to call repeatedly; does nothing until Accessibility is granted.
    func start() {
        guard case .notStarted = status, Permissions.shared.accessibility else { return }
        guard
            let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
            let createListSymbol = dlsym(framework, "MTDeviceCreateList"),
            let registerSymbol = dlsym(framework, "MTRegisterContactFrameCallback"),
            let startSymbol = dlsym(framework, "MTDeviceStart")
        else {
            status = .unavailable
            return
        }
        let createList = unsafeBitCast(createListSymbol, to: MTDeviceCreateListFunction.self)
        registerFrames = unsafeBitCast(registerSymbol, to: MTRegisterContactFrameCallbackFunction.self)
        startDevice = unsafeBitCast(startSymbol, to: MTDeviceStartFunction.self)
        stopDevice = dlsym(framework, "MTDeviceStop").map { unsafeBitCast($0, to: MTDeviceStopFunction.self) }
        unregisterFrames = dlsym(framework, "MTUnregisterContactFrameCallback")
            .map { unsafeBitCast($0, to: MTUnregisterContactFrameCallbackFunction.self) }
        let getDimensions = dlsym(framework, "MTDeviceGetSensorSurfaceDimensions")
            .map { unsafeBitCast($0, to: MTDeviceGetSensorSurfaceDimensionsFunction.self) }

        guard let list = createList()?.takeRetainedValue() else {
            status = .unavailable
            return
        }
        devices = list // Keep the devices alive while we're listening to them.

        for index in 0..<CFArrayGetCount(list) {
            guard let pointer = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: pointer)

            // The real size in millimetres (the framework reports hundredths of one).
            var size = CGSize(width: 160, height: 100)
            var width: Int32 = 0
            var height: Int32 = 0
            if let getDimensions, getDimensions(device, &width, &height) == 0, width > 0, height > 0 {
                size = CGSize(width: Double(width) / 100, height: Double(height) / 100)
            }
            if index == 0 { aspectRatio = size.width / size.height }

            recognizers[Int(bitPattern: device)] = GestureRecognizer(surfaceSize: size)
            deviceList.append(device)
        }
        status = .running(trackpads: CFArrayGetCount(list))

        watchClicks()
        updateListening()
    }

    /// Switches finger data (and click watching) on only while something needs
    /// it: a gesture rule, the gesture recorder, or the Gesture Lab being open.
    /// Call whenever your gestures change.
    func updateListening() {
        guard case .running = status else { return }
        let hasRules = ShortcutStore.shared.shortcuts.contains { $0.isEnabled && $0.gesture != nil }
        let needed = hasRules || isWatching || recordingHandler != nil

        if let clickTap { CGEvent.tapEnable(tap: clickTap, enable: needed) }
        guard needed != isListening, let registerFrames, let startDevice else { return }
        isListening = needed

        for device in deviceList {
            if needed {
                registerFrames(device, handleTouchFrame)
                startDevice(device, 0)
            } else {
                // If the framework can't stop, carry on listening rather than break.
                guard let stopDevice, let unregisterFrames else {
                    isListening = true
                    return
                }
                stopDevice(device)
                unregisterFrames(device, handleTouchFrame)
            }
        }
        if !needed {
            touching.removeAll()
            liveTouches = []
        }
    }

    /// Called for every frame of finger data.
    fileprivate func receive(_ touches: [TouchPoint], from device: Int, at time: Double) {
        touching[device] = touches.filter(\.isTouching)
        if isWatching { liveTouches = touches }

        let gesture = recognizers[device]?.process(touches, at: time) { [self] candidate in
            recordingHandler != nil || hasAction(for: candidate)
        }
        switch gesture {
        case .tap(let fingers): handleTap(fingers: fingers)
        case let gesture?: recognized(gesture)
        case nil: break
        }
    }

    /// The number of fingers on the busiest trackpad.
    private var fingersDown: Int {
        touching.values.map(\.count).max() ?? 0
    }

    private func hasAction(for gesture: Gesture) -> Bool {
        ShortcutStore.shared.match(.gesture(gesture: gesture), in: FrontmostApp.bundleID) != nil
    }

    // MARK: - Taps and double taps

    /// A tap might be the first half of a double tap. If you've given that double
    /// tap an action, wait (for your Mac's double-click speed) to see if a second
    /// tap follows before treating it as a single tap.
    private func handleTap(fingers: Int) {
        let tap = Gesture.tap(fingers: fingers)
        let doubleTap = Gesture.doubleTap(fingers: fingers)

        // With "Tap to click" on, macOS also turns taps into clicks. If this tap
        // (or double tap) is doing something, ignore the click macOS sends with it.
        if tap.canBeTrigger, recordingHandler != nil || hasAction(for: tap) || hasAction(for: doubleTap) {
            ignoreClicksUntil = Date().addingTimeInterval(0.3)
        }

        if let pendingTap, pendingTap.fingers == fingers {
            pendingTap.work.cancel()
            self.pendingTap = nil
            recognized(doubleTap)
            return
        }

        flushPendingTap()
        guard recordingHandler != nil || hasAction(for: doubleTap) else {
            recognized(tap)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.pendingTap = nil
            self?.recognized(tap)
        }
        pendingTap = (fingers, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
    }

    /// Treats a waiting tap as a single tap straight away.
    private func flushPendingTap() {
        guard let pendingTap else { return }
        self.pendingTap = nil
        pendingTap.work.cancel()
        recognized(.tap(fingers: pendingTap.fingers))
    }

    // MARK: - Clicks and force clicks

    private func watchClicks() {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: handleClickEvent, userInfo: nil
        ) {
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            clickTap = tap
        }

        // Force clicks can only be watched, not swallowed. A "global" monitor
        // doesn't see Shortie's own windows, so add a local one too.
        let handler: (NSEvent) -> Void = { [weak self] event in
            // Stage 1 is a normal click; stage 2 is pressing on through to a force click.
            guard let self else { return }
            if event.stage == 2, self.lastPressureStage < 2 { _ = self.recognized(.forceClick) }
            self.lastPressureStage = event.stage
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .pressure, handler: handler) {
            pressureMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .pressure, handler: { event in
            handler(event)
            return event
        }) {
            pressureMonitors.append(local)
        }
    }

    /// Returns `true` to swallow the click.
    fileprivate func handleClick(_ type: CGEventType) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let clickTap { CGEvent.tapEnable(tap: clickTap, enable: true) }
            return false
        case .leftMouseUp, .rightMouseUp:
            if swallowingRelease == type {
                swallowingRelease = nil
                return true
            }
            return false
        case .leftMouseDown, .rightMouseDown:
            let release: CGEventType = type == .leftMouseDown ? .leftMouseUp : .rightMouseUp
            if Date() < ignoreClicksUntil {
                swallowingRelease = release
                return true
            }

            let fingers = fingersDown
            guard fingers > 0 else { return false }
            // A quick click looks like a tap too (down and up fast, without moving).
            // It was a click, so make sure it isn't also counted as a tap.
            for device in recognizers.keys { recognizers[device]?.noteClick() }

            let gesture = fingers == 1 ? cornerClick() : .click(fingers: fingers)
            guard let gesture, recognized(gesture) else { return false }
            swallowingRelease = release
            return true
        default:
            return false
        }
    }

    /// A one-finger click in a corner of the trackpad, if that's where the finger is.
    private func cornerClick() -> Gesture? {
        guard let finger = touching.values.first(where: { $0.count == 1 })?.first else { return nil }
        let left = finger.x < 0.25, right = finger.x > 0.75
        // The trackpad measures from the bottom-left, so a high y is the top.
        let top = finger.y > 0.7, bottom = finger.y < 0.3
        switch (left, right, top, bottom) {
        case (true, _, true, _): return .cornerClick(corner: .topLeft)
        case (_, true, true, _): return .cornerClick(corner: .topRight)
        case (true, _, _, true): return .cornerClick(corner: .bottomLeft)
        case (_, true, _, true): return .cornerClick(corner: .bottomRight)
        default: return nil
        }
    }

    // MARK: - Acting on gestures

    /// Records the gesture for the Gesture Lab, then either hands it to the
    /// recorder or runs its action. Returns whether it was used for something.
    @discardableResult
    private func recognized(_ gesture: Gesture) -> Bool {
        recentGestures.insert(RecognizedGesture(gesture: gesture), at: 0)
        if recentGestures.count > 8 { recentGestures.removeLast() }

        guard gesture.canBeTrigger else { return false }

        if let recordingHandler {
            self.recordingHandler = nil
            recordingHandler(gesture)
            return true
        }

        guard let shortcut = ShortcutStore.shared.match(.gesture(gesture: gesture), in: FrontmostApp.bundleID),
              // While paused, the only gesture that works is the one that resumes.
              !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused) || shortcut.action == .system(action: .togglePause),
              // "Gestures Off" leaves only the gesture that switches them back on.
              !UserDefaults.standard.bool(forKey: DefaultsKey.gesturesPaused) || shortcut.action == .system(action: .toggleGestures)
        else { return false }

        let action = shortcut.action
        // Run it just after we return, so the trackpad is never held up.
        DispatchQueue.main.async {
            Haptics.actionRan()
            ActionRunner.run(action)
        }
        return true
    }
}

struct RecognizedGesture: Identifiable {
    let id = UUID()
    let gesture: Gesture
    let date = Date()
}

/// Called by MultitouchSupport on its own background thread for every frame.
/// We copy out what we need and hand it to the main thread.
private nonisolated func handleTouchFrame(
    _ device: MTDeviceRef?, _ touches: UnsafePointer<MTTouch>?, _ count: Int32, _ timestamp: Double, _ frame: Int32
) -> Int32 {
    var points: [TouchPoint] = []
    if let touches {
        for index in 0..<Int(count) {
            let touch = touches[index]
            points.append(TouchPoint(
                id: touch.identifier,
                x: Double(touch.normalized.position.x),
                y: Double(touch.normalized.position.y),
                state: touch.state,
                size: Double(touch.size)
            ))
        }
    }
    let deviceID = Int(bitPattern: device)
    let frame = points
    Task { @MainActor in
        GestureEngine.shared.receive(frame, from: deviceID, at: timestamp)
    }
    return 0
}

/// Called by macOS for every click. Runs on the main thread (main run loop).
private nonisolated func handleClickEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Let through the clicks Shortie itself makes (like a gesture's Right Click action).
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    let swallow = MainActor.assumeIsolated { GestureEngine.shared.handleClick(type) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
