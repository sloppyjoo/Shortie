import AppKit
import ApplicationServices

/// Moves and resizes other apps' windows.
///
/// This uses the Accessibility API: the part of macOS that lets one app read and
/// control another app's windows (it's what screen readers use). Each window is an
/// "element" with attributes like position and size that we can read and set.
///
/// A note on coordinates: AppKit measures screens from the *bottom*-left corner,
/// but the Accessibility API measures windows from the *top*-left. Everything in
/// here works in Accessibility (top-left) coordinates.
final class WindowMover {
    static let shared = WindowMover()

    /// The last snap Glide did, so pressing the same shortcut again can cycle sizes.
    private struct LastMove {
        let window: AXUIElement
        let position: WindowPosition
        let cycle: Int
        let frame: CGRect
    }

    private var lastMove: LastMove?

    /// Where windows were before Glide first moved them, for Restore.
    private var originalFrames: [(window: AXUIElement, frame: CGRect)] = []

    func move(_ position: WindowPosition) {
        guard let window = focusedWindow(), let current = frame(of: window) else {
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

        rememberOriginalFrame(of: window, current)
        setFrame(of: window, to: target.integral)

        // Read back where it actually ended up: some apps have a minimum size.
        lastMove = LastMove(window: window, position: position, cycle: cycle, frame: frame(of: window) ?? target)
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
        setFrame(of: window, to: originalFrames[index].frame)
        originalFrames.remove(at: index)
        lastMove = nil
    }

    // MARK: - Reading and setting windows

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value
        else { return nil }
        return (value as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
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

        withoutEnhancedUserInterface(for: window) {
            // Position, then size, then position again: moving to another screen can
            // briefly limit the size, and some apps nudge the window when resized.
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
    }

    /// Some apps (Chrome, for one) turn on "enhanced user interface" mode when an
    /// accessibility app is around, which makes window moves slow and wobbly.
    /// Switch it off just while we move the window.
    private func withoutEnhancedUserInterface(for window: AXUIElement, _ body: () -> Void) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = AXUIElementCreateApplication(pid)
        let attribute = "AXEnhancedUserInterface" as CFString

        var value: CFTypeRef?
        let wasEnabled = AXUIElementCopyAttributeValue(app, attribute, &value) == .success
            && (value as? Bool) == true

        if wasEnabled { AXUIElementSetAttributeValue(app, attribute, kCFBooleanFalse) }
        body()
        if wasEnabled { AXUIElementSetAttributeValue(app, attribute, kCFBooleanTrue) }
    }

    // MARK: - Screens

    private static var screensLeftToRight: [NSScreen] {
        NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Converts an AppKit rectangle (bottom-left origin) to Accessibility coordinates (top-left origin).
    private static func flipped(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The part of a screen windows should fill: everything except the menu bar and Dock.
    private static func usableArea(of screen: NSScreen) -> CGRect {
        flipped(screen.visibleFrame)
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

    func isClose(to other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
