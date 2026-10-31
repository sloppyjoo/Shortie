import AppKit
import QuartzCore

/// Which way the mouse wheel scrolls, independently of the trackpad.
enum WheelDirection: String, CaseIterable, Identifiable {
    /// Leave it to macOS (the wheel follows the trackpad setting).
    case system
    /// Wheel down scrolls the page down, like on Windows.
    case traditional
    /// Wheel down scrolls the page up, like dragging a page on the trackpad.
    case natural

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Same as Trackpad"
        case .traditional: "Traditional"
        case .natural: "Natural"
        }
    }
}

/// Makes the mouse wheel behave nicely:
///
/// - **Direction:** macOS forces the wheel and trackpad to scroll the same way.
///   We can flip just the wheel.
/// - **Smoothness:** a wheel scrolls in jumpy steps, one per click. We swallow each
///   click and turn it into momentum, using the same physics as Apple's trackpad
///   and iOS scroll views: each click gives the page a push (velocity), and
///   friction slows it by a fixed share every millisecond until it stops.
///
/// Like `ShortcutEngine`, this uses an event tap, but for scroll events.
/// Trackpad scrolls always pass through untouched.
final class ScrollEngine: NSObject {
    static let shared = ScrollEngine()

    /// How far one wheel click glides at normal speed, in points.
    private static let pointsPerClick = 50.0

    /// Friction: each millisecond, keep 99% of the speed. This is Apple's "fast"
    /// rate (`UIScrollView.DecelerationRate.fast`). Their "normal" rate (99.8%) is
    /// tuned for big trackpad flicks; for a single wheel click it crawls along for
    /// over a second. With this one, a click covers two-thirds of its distance in
    /// the first tenth of a second, then eases out over about 0.4 s.
    private static let decelerationPerMillisecond = 0.99

    /// How far something coasts per unit of starting speed (points per point/second).
    /// From summing the speed over every millisecond: r / (1 − r) / 1000.
    private static let coastFactor = decelerationPerMillisecond / (1 - decelerationPerMillisecond) / 1000

    /// Below this speed (points per second) the movement is invisible, so stop.
    private static let stoppingSpeed = 8.0

    private var tap: CFMachPort?

    /// Current scrolling speed, in points per second. `dx` is sideways, `dy` up/down.
    private var velocity = CGVector.zero
    /// Fractions of a point not yet included in the whole-point field of an event.
    private var carry = CGVector.zero
    private var displayLink: CADisplayLink?

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
            eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
            callback: handleScrollEvent,
            userInfo: nil
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    /// Only watch scrolling while smooth scrolling or a wheel direction is set.
    func updateNeed() {
        let smooth = UserDefaults.standard.object(forKey: DefaultsKey.smoothScrolling) as? Bool ?? true
        let direction = UserDefaults.standard.string(forKey: DefaultsKey.wheelDirection) ?? WheelDirection.system.rawValue
        if let tap { CGEvent.tapEnable(tap: tap, enable: smooth || direction != WheelDirection.system.rawValue) }
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Decides what to do with one click of a mouse wheel.
    fileprivate func handle(_ wheel: WheelClick) -> WheelDecision {
        let flip = shouldFlipWheel
        let smooth = UserDefaults.standard.object(forKey: DefaultsKey.smoothScrolling) as? Bool ?? true

        // With ⌘, ⌥, ⌃ or ⇧ held, apps often do something special (zoom, scroll
        // sideways), so leave those scrolls as they are apart from the direction.
        guard smooth, !wheel.hasModifiers else { return flip ? .flip : .passThrough }

        let speed = UserDefaults.standard.object(forKey: DefaultsKey.scrollSpeed) as? Double ?? 1
        // Push hard enough that one click, on its own, coasts `pointsPerClick`.
        let strength = (flip ? -1 : 1) * Self.pointsPerClick * speed / Self.coastFactor
        push(by: CGVector(dx: wheel.dx * strength, dy: wheel.dy * strength))
        return .swallow
    }

    /// Whether wheel scrolls currently need flipping, based on your choice and
    /// System Settings › Trackpad › Natural scrolling.
    private var shouldFlipWheel: Bool {
        let choice = UserDefaults.standard.string(forKey: DefaultsKey.wheelDirection)
            .flatMap(WheelDirection.init) ?? .system
        // macOS's own setting (it's on unless you've turned it off).
        let systemIsNatural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        switch choice {
        case .system: return false
        case .traditional: return systemIsNatural
        case .natural: return !systemIsNatural
        }
    }

    // MARK: - Smooth scrolling

    private func push(by impulse: CGVector) {
        // Clicks in the same direction add up, so spinning the wheel builds speed
        // naturally. Changing direction should feel instant, so start afresh.
        if impulse.dy != 0, impulse.dy.sign != velocity.dy.sign { velocity.dy = 0 }
        if impulse.dx != 0, impulse.dx.sign != velocity.dx.sign { velocity.dx = 0 }
        velocity.dx += impulse.dx
        velocity.dy += impulse.dy

        if displayLink == nil, let screen = NSScreen.main {
            // A display link calls us once per screen refresh (60–120 times a second).
            let link = screen.displayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        let milliseconds = max(link.targetTimestamp - link.timestamp, 1.0 / 240) * 1000

        // Exactly how far we travel this frame while friction slows us down:
        // the sum of the speed over each millisecond of the frame.
        let r = Self.decelerationPerMillisecond
        let travelled = (1 - pow(r, milliseconds)) * r / (1 - r) / 1000
        let move = CGVector(dx: velocity.dx * travelled, dy: velocity.dy * travelled)

        let friction = pow(r, milliseconds)
        velocity.dx *= friction
        velocity.dy *= friction
        if abs(velocity.dx) < Self.stoppingSpeed, abs(velocity.dy) < Self.stoppingSpeed {
            velocity = .zero
            carry = .zero
            link.invalidate()
            displayLink = nil
        }

        post(move)
    }

    /// Sends one frame's worth of scrolling to whatever is under the pointer.
    private func post(_ move: CGVector) {
        // The whole-point field can't hold fractions, so keep the leftovers for
        // next time; the precise field gets the exact amount. Apps that read the
        // precise value (most do) get perfectly even movement with no stutter.
        carry.dx += move.dx
        carry.dy += move.dy
        let wholeX = carry.dx.rounded(.towardZero)
        let wholeY = carry.dy.rounded(.towardZero)
        carry.dx -= wholeX
        carry.dy -= wholeY

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 2, wheel1: Int32(wholeY), wheel2: Int32(wholeX), wheel3: 0
        ) else { return }
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: move.dy)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: move.dx)
        event.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        // "Continuous" tells apps this is precise, pixel-by-pixel scrolling.
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.post(tap: .cgSessionEventTap)
    }
}

/// One click of a mouse wheel, copied out of the system's event.
fileprivate nonisolated struct WheelClick {
    /// Up/down and sideways clicks (usually 1 or −1; more if macOS bundled
    /// several fast clicks into one event).
    let dy: Double
    let dx: Double
    let hasModifiers: Bool
}

fileprivate nonisolated enum WheelDecision {
    case passThrough, flip, swallow
}

/// Called by macOS for every scroll. Runs on the main thread (main run loop).
private nonisolated func handleScrollEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { ScrollEngine.shared.reenable() }
        return Unmanaged.passUnretained(event)
    }
    guard type == .scrollWheel,
          event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker
    else { return Unmanaged.passUnretained(event) }

    // Trackpads (and the Magic Mouse) scroll "continuously" and in phases as your
    // fingers touch and lift. A mouse wheel clicks in discrete steps with no phases.
    let isWheel = event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
        && event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0
        && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
    guard isWheel else { return Unmanaged.passUnretained(event) }

    // Count raw clicks rather than macOS's sped-up distance: the momentum already
    // builds speed when you spin fast, and doing both makes fast flicks overshoot.
    let wheel = WheelClick(
        dy: clicks(event, .scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1),
        dx: clicks(event, .scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2),
        hasModifiers: !event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty
    )

    switch MainActor.assumeIsolated({ ScrollEngine.shared.handle(wheel) }) {
    case .passThrough:
        return Unmanaged.passUnretained(event)
    case .swallow:
        return nil
    case .flip:
        // Each scroll carries its distance three ways (lines, pixels, and a precise
        // fractional value); apps read different ones, so flip them all.
        // Axis 1 is up/down, axis 2 is left/right (Shift + wheel, or tilt wheels).
        for (lines, points, fixed) in [
            (CGEventField.scrollWheelEventDeltaAxis1, CGEventField.scrollWheelEventPointDeltaAxis1, CGEventField.scrollWheelEventFixedPtDeltaAxis1),
            (CGEventField.scrollWheelEventDeltaAxis2, CGEventField.scrollWheelEventPointDeltaAxis2, CGEventField.scrollWheelEventFixedPtDeltaAxis2),
        ] {
            event.setIntegerValueField(lines, value: -event.getIntegerValueField(lines))
            event.setIntegerValueField(points, value: -event.getIntegerValueField(points))
            event.setDoubleValueField(fixed, value: -event.getDoubleValueField(fixed))
        }
        return Unmanaged.passUnretained(event)
    }
}

/// The number of wheel clicks in one direction. Some mice send tiny fractional
/// movements with a zero click count; treat those as one click.
private nonisolated func clicks(_ event: CGEvent, _ lines: CGEventField, _ precise: CGEventField) -> Double {
    let count = Double(event.getIntegerValueField(lines))
    if count != 0 { return count }
    let fraction = event.getDoubleValueField(precise)
    return fraction == 0 ? 0 : (fraction > 0 ? 1 : -1)
}
