import AppKit
import Observation

/// Watches your trackpad(s) and recognises gestures.
///
/// Finger positions come from MultitouchSupport, Apple's private trackpad
/// framework, about 100 times a second. Clicks and force clicks come from
/// macOS's ordinary mouse and pressure events, combined with how many fingers
/// are touching at that moment.
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
    var isWatching = false

    /// The trackpad's shape, for drawing it. Width ÷ height.
    private(set) var aspectRatio = 1.6

    /// The most recent gestures, newest first.
    private(set) var recentGestures: [RecognizedGesture] = []

    @ObservationIgnored private var recognizers: [Int: GestureRecognizer] = [:]
    @ObservationIgnored private var fingersDown: [Int: Int] = [:]
    @ObservationIgnored private var devices: CFArray?
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var lastPressureStage = 0

    func start() {
        guard case .notStarted = status else { return }
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
        let register = unsafeBitCast(registerSymbol, to: MTRegisterContactFrameCallbackFunction.self)
        let startDevice = unsafeBitCast(startSymbol, to: MTDeviceStartFunction.self)
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
            register(device, handleTouchFrame)
            startDevice(device, 0)
        }
        status = .running(trackpads: CFArrayGetCount(list))

        watchClicks()
    }

    /// Called for every frame of finger data.
    fileprivate func receive(_ touches: [TouchPoint], from device: Int, at time: Double) {
        fingersDown[device] = touches.filter(\.isTouching).count
        if isWatching { liveTouches = touches }

        if let gesture = recognizers[device]?.process(touches, at: time) {
            recognized(gesture)
        }
    }

    /// Physical clicks and force clicks arrive as normal mouse and pressure events.
    private func watchClicks() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .pressure], handler: handler) {
            monitors.append(global)
        }
        // A "global" monitor doesn't see clicks in Glide's own windows, so add a local one too.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .pressure], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let fingers = fingersDown.values.max() ?? 0
            if fingers > 0 { recognized(.click(fingers: fingers)) }
        case .pressure:
            // Stage 1 is a normal click; stage 2 is pressing on through to a force click.
            if event.stage == 2, lastPressureStage < 2 { recognized(.forceClick) }
            lastPressureStage = event.stage
        default:
            break
        }
    }

    private func recognized(_ gesture: Gesture) {
        recentGestures.insert(RecognizedGesture(gesture: gesture), at: 0)
        if recentGestures.count > 8 { recentGestures.removeLast() }
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
