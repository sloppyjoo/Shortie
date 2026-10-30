import AppKit
import ApplicationServices
import QuartzCore
import SwiftUI

/// Moves and resizes other apps' windows.
///
/// This uses the Accessibility API: the part of macOS that lets one app read and
/// control another app's windows (it's what screen readers use). Each window is an
/// "element" with attributes like position and size that we can read and set.
///
/// Windows glide into place rather than jumping: on each screen refresh we set
/// the window a little further along Apple's spring curve.
///
/// A note on coordinates: AppKit measures screens from the *bottom*-left corner,
/// but the Accessibility API measures windows from the *top*-left. Everything in
/// here works in Accessibility (top-left) coordinates.
final class WindowMover: NSObject {
    static let shared = WindowMover()

    /// The last snap Glide did, so pressing the same shortcut again can cycle sizes.
    private struct LastMove {
        let window: AXUIElement
        let position: WindowPosition
        let cycle: Int
        var frame: CGRect
    }

    private var lastMove: LastMove?

    /// Where windows were before Glide first moved them, for Restore.
    private var originalFrames: [(window: AXUIElement, frame: CGRect)] = []

    /// Moves `window`, or the window you're using if none is given.
    func move(_ position: WindowPosition, window: AXUIElement? = nil) {
        // If a window is still gliding, land it first so we start from where it's going.
        finishGlide()

        guard let window = window ?? ActionTarget.frontmost?.window, let current = frame(of: window) else {
            NSSound.beep()
            return
        }

        if position == .restore {
            restore(window)
            return
        }

        let screens = Self.screensLeftToRight
        guard let screenIndex = screens.firstIndex(of: Self.screen(containing: current)) else { return }
        let area = Self.usableArea(of: screens[screenIndex])

        var cycle = 0
        if position.cyclesSizes, let lastMove, lastMove.position == position,
           CFEqual(lastMove.window, window), lastMove.frame.isClose(to: current) {
            cycle = lastMove.cycle + 1
        }

        let target: CGRect
        switch position {
        case .center:
            let width = min(current.width, area.width)
            let height = min(current.height, area.height)
            target = CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
        case .nextDisplay:
            guard screens.count > 1 else {
                NSSound.beep()
                return
            }
            let destination = Self.usableArea(of: screens[(screenIndex + 1) % screens.count])
            // Keep the same relative place and size on the new screen.
            target = CGRect(
                x: destination.minX + (current.minX - area.minX) / area.width * destination.width,
                y: destination.minY + (current.minY - area.minY) / area.height * destination.height,
                width: current.width / area.width * destination.width,
                height: current.height / area.height * destination.height
            )
        default:
            guard let unit = position.unitRect(cycle: cycle) else { return }
            target = CGRect(
                x: area.minX + unit.minX * area.width,
                y: area.minY + unit.minY * area.height,
                width: unit.width * area.width,
                height: unit.height * area.height
            )
        }

        // Maximising a window that's already maximised puts it back how it was,
        // like the green button's own zoom.
        if position == .maximize, current.isClose(to: target.integral, tolerance: 4),
           originalFrames.contains(where: { CFEqual($0.window, window) }) {
            restore(window)
            return
        }

        rememberOriginalFrame(of: window, current)
        lastMove = LastMove(window: window, position: position, cycle: cycle, frame: target.integral)
        animate(window, from: current, to: target.integral)
    }

    /// Moves several windows at once, all gliding along the same spring.
    func move(_ windows: [(window: AXUIElement, to: CGRect)]) {
        finishGlide()
        let moves = windows.compactMap { window in
            frame(of: window.window).map { (window: window.window, from: $0, to: window.to.integral) }
        }
        lastMove = nil
        animate(moves)
    }

    // MARK: - Restore

    private func rememberOriginalFrame(of window: AXUIElement, _ frame: CGRect) {
        guard !originalFrames.contains(where: { CFEqual($0.window, window) }) else { return }
        originalFrames.append((window, frame))
        // Don't remember windows forever.
        if originalFrames.count > 50 { originalFrames.removeFirst() }
    }

    private func restore(_ window: AXUIElement) {
        guard let index = originalFrames.firstIndex(where: { CFEqual($0.window, window) }) else {
            NSSound.beep()
            return
        }
        let original = originalFrames[index].frame
        originalFrames.remove(at: index)
        lastMove = nil
        animate(window, from: frame(of: window) ?? original, to: original)
    }

    // MARK: - Gliding

    /// Apple's smooth, no-bounce spring: the same curve as SwiftUI's `.smooth`
    /// animation, shortened to suit window moves. It starts briskly and settles
    /// gently, like the system's own animations.
    private static let spring = Spring(duration: 0.3, bounce: 0)

    private struct Glide {
        struct Item {
            let window: AXUIElement
            let from: CGRect
            let to: CGRect
            /// The app whose "enhanced user interface" we switched off, to switch back on after.
            let enhancedUIApp: AXUIElement?
        }

        let items: [Item]
        let startTime: CFTimeInterval
        let link: CADisplayLink
    }

    private var currentGlide: Glide?

    private func animate(_ window: AXUIElement, from start: CGRect, to end: CGRect) {
        animate([(window, start, end)])
    }

    private func animate(_ moves: [(window: AXUIElement, from: CGRect, to: CGRect)]) {
        finishGlide()
        guard !moves.isEmpty else { return }

        let items = moves.map {
            Glide.Item(window: $0.window, from: $0.from, to: $0.to, enhancedUIApp: switchOffEnhancedUserInterface(for: $0.window))
        }

        // Respect System Settings › Accessibility › Display › Reduce motion.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              items.contains(where: { !$0.from.isClose(to: $0.to, tolerance: 1) }),
              let screen = NSScreen.main
        else {
            land(items)
            return
        }

        // A display link calls us once per screen refresh (60–120 times a second).
        let link = screen.displayLink(target: self, selector: #selector(stepGlide))
        currentGlide = Glide(items: items, startTime: CACurrentMediaTime(), link: link)
        link.add(to: .main, forMode: .common)
    }

    @objc private func stepGlide(_ link: CADisplayLink) {
        guard let glide = currentGlide else {
            link.invalidate()
            return
        }
        let elapsed = link.targetTimestamp - glide.startTime
        let progress = Self.spring.value(target: 1.0, time: elapsed)

        // A spring only ever gets closer to its target; once it's nearly there, land exactly.
        if progress > 0.997 || elapsed > 0.6 {
            finishGlide()
            return
        }
        for item in glide.items {
            setPositionAndSize(of: item.window, to: item.from.interpolated(to: item.to, progress))
        }
    }

    /// Lands gliding windows at their destinations straight away.
    private func finishGlide() {
        guard let glide = currentGlide else { return }
        currentGlide = nil
        glide.link.invalidate()
        land(glide.items)
    }

    private func land(_ items: [Glide.Item]) {
        for item in items {
            setFrame(of: item.window, to: item.to)
        }
        for item in items {
            switchOnEnhancedUserInterface(item.enhancedUIApp)
            recordWhereItLanded(item.window)
        }
    }

    /// Some apps have a minimum size, so note where the window really ended up.
    /// That's what the next press compares against to decide whether to cycle sizes.
    private func recordWhereItLanded(_ window: AXUIElement) {
        guard let lastMove, CFEqual(lastMove.window, window), let landed = frame(of: window) else { return }
        self.lastMove?.frame = landed
    }

    // MARK: - Reading and setting windows

    func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private func setFrame(of window: AXUIElement, to frame: CGRect) {
        var origin = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }

        // Position, then size, then position again: moving to another screen can
        // briefly limit the size, and some apps nudge the window when resized.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }

    /// The quicker version for each frame of a glide.
    func setPositionAndSize(of window: AXUIElement, to frame: CGRect) {
        var origin = frame.origin
        var size = frame.size
        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private static let enhancedUserInterface = "AXEnhancedUserInterface" as CFString

    /// Some apps (Chrome, for one) turn on "enhanced user interface" mode when an
    /// accessibility app is around, which makes window moves slow and wobbly.
    /// We switch it off while moving a window. Returns the app if we did, so it
    /// can be switched back on afterwards.
    private func switchOffEnhancedUserInterface(for window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = AXUIElementCreateApplication(pid)
        guard AX.bool(app, Self.enhancedUserInterface as String) == true else { return nil }
        AXUIElementSetAttributeValue(app, Self.enhancedUserInterface, kCFBooleanFalse)
        return app
    }

    private func switchOnEnhancedUserInterface(_ app: AXUIElement?) {
        if let app { AXUIElementSetAttributeValue(app, Self.enhancedUserInterface, kCFBooleanTrue) }
    }

    // MARK: - Screens

    private static var screensLeftToRight: [NSScreen] {
        NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Converts an AppKit rectangle (bottom-left origin) to Accessibility coordinates (top-left origin).
    static func flipped(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The part of a screen windows should fill: everything except the menu bar and Dock.
    static func usableArea(of screen: NSScreen) -> CGRect {
        flipped(screen.visibleFrame)
    }

    /// The screen a point is on (in Accessibility coordinates).
    static func screen(at point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { flipped($0.frame).contains(point) }
    }

    /// Where a position would put a window on a screen, without moving anything.
    static func frame(for position: WindowPosition, on screen: NSScreen) -> CGRect? {
        guard let unit = position.unitRect() else { return nil }
        let area = usableArea(of: screen)
        return CGRect(
            x: area.minX + unit.minX * area.width,
            y: area.minY + unit.minY * area.height,
            width: unit.width * area.width,
            height: unit.height * area.height
        )
    }

    /// The screen showing most of the window.
    private static func screen(containing window: CGRect) -> NSScreen {
        NSScreen.screens.max { a, b in
            flipped(a.frame).intersection(window).area < flipped(b.frame).intersection(window).area
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }

    /// Part-way from this rectangle to `other`; `progress` 0 is here, 1 is there.
    func interpolated(to other: CGRect, _ progress: Double) -> CGRect {
        CGRect(
            x: minX + (other.minX - minX) * progress,
            y: minY + (other.minY - minY) * progress,
            width: width + (other.width - width) * progress,
            height: height + (other.height - height) * progress
        )
        .rounded
    }

    /// Each edge on a whole point, so the window doesn't shimmer as it moves.
    var rounded: CGRect {
        CGRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }

    func isClose(to other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
