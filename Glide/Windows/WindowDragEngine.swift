import AppKit
import ApplicationServices
import SwiftUI

/// Everything to do with dragging windows with the mouse:
///
/// - **Move from anywhere:** hold your chosen keys (⌃⌘ by default) and drag
///   anywhere inside a window to move it.
/// - **Resize from anywhere:** hold your chosen keys (⌃⌥ by default) and drag;
///   the corner nearest where you grabbed follows the pointer.
/// - **Drag to snap:** drag a window by its title bar to a screen edge or corner,
///   see a preview of where it'll go, and let go to snap it there.
///
/// One event tap watches left-button presses, drags and releases. Moving and
/// resizing swallow those events (the window underneath never sees them);
/// snapping only watches, so ordinary dragging is untouched.
final class WindowDragEngine {
    static let shared = WindowDragEngine()

    /// Drag-to-snap edges, from the open-source Rectangle app's defaults: within
    /// 5 points of a screen edge. Corners only count right in the corner,
    /// pressed into both edges at once.
    private static let edgeMargin: CGFloat = 5

    private enum Drag {
        case moving(window: AXUIElement, startMouse: CGPoint, startFrame: CGRect)
        case resizing(window: AXUIElement, startMouse: CGPoint, startFrame: CGRect, growsLeft: Bool, growsUp: Bool)
        /// An ordinary drag that might turn out to be a window being dragged by its title bar.
        case watching(SnapWatch)
    }

    /// Following an ordinary drag, in case it's a window being dragged to snap.
    private struct SnapWatch {
        let startMouse: CGPoint
        /// The window that was clicked, found on the first drag event. The
        /// window server's number for it is what we watch (see `windowBounds`);
        /// the Accessibility element is what we move when you let go.
        var window: AXUIElement?
        var windowNumber: CGWindowID?
        var startBounds: CGRect?
        /// The window has started moving, so this really is a window drag.
        var isMoving = false
        var zone: WindowPosition?
    }

    private var tap: CFMachPort?
    private var drag: Drag?
    private let systemWide = AXUIElementCreateSystemWide()
    private let preview = SnapPreview()

    private init() {
        // If an app is frozen, don't wait more than a moment for it to answer.
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
    }

    // MARK: - Settings

    var movesWithKeys: Bool { UserDefaults.standard.object(forKey: DefaultsKey.dragMoveEnabled) as? Bool ?? true }
    var resizesWithKeys: Bool { UserDefaults.standard.object(forKey: DefaultsKey.dragResizeEnabled) as? Bool ?? true }
    var snapsAtEdges: Bool { UserDefaults.standard.object(forKey: DefaultsKey.dragSnapEnabled) as? Bool ?? true }

    static func modifiers(for key: String, default defaultValue: Modifiers) -> Modifiers {
        (UserDefaults.standard.object(forKey: key) as? Int).map(Modifiers.init(rawValue:)) ?? defaultValue
    }

    static let defaultMoveModifiers: Modifiers = [.control, .command]
    static let defaultResizeModifiers: Modifiers = [.control, .option]

    // MARK: - Listening

    /// Safe to call repeatedly; does nothing until Accessibility is granted.
    func start() {
        guard Permissions.shared.accessibility else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: handleDragEvent, userInfo: nil
        ) else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
    }

    /// Returns `true` to swallow the event.
    fileprivate func handle(_ type: CGEventType, at location: CGPoint, flags: CGEventFlags) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseDown:
            return mouseDown(at: location, modifiers: Modifiers(flags))
        case .leftMouseDragged:
            return mouseDragged(to: location)
        case .leftMouseUp:
            return mouseUp(at: location)
        default:
            return false
        }
    }

    private func mouseDown(at location: CGPoint, modifiers: Modifiers) -> Bool {
        drag = nil
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused) else { return false }

        let moveKeys = Self.modifiers(for: DefaultsKey.dragMoveModifiers, default: Self.defaultMoveModifiers)
        let resizeKeys = Self.modifiers(for: DefaultsKey.dragResizeModifiers, default: Self.defaultResizeModifiers)
        let wantsMove = movesWithKeys && !modifiers.isEmpty && modifiers == moveKeys
        let wantsResize = resizesWithKeys && !modifiers.isEmpty && modifiers == resizeKeys

        guard wantsMove || wantsResize else {
            // An ordinary click. Only if it turns into a drag do we look for a
            // window (see `mouseDragged`), so plain clicking is never slowed down.
            if snapsAtEdges { drag = .watching(SnapWatch(startMouse: location)) }
            return false
        }

        guard let window = window(at: location), let frame = WindowMover.shared.frame(of: window) else { return false }
        raise(window)
        if wantsMove {
            drag = .moving(window: window, startMouse: location, startFrame: frame)
        } else {
            drag = .resizing(
                window: window, startMouse: location, startFrame: frame,
                growsLeft: location.x < frame.midX, growsUp: location.y < frame.midY
            )
        }
        return true
    }

    private func mouseDragged(to location: CGPoint) -> Bool {
        switch drag {
        case let .moving(window, startMouse, startFrame):
            let origin = CGPoint(x: startFrame.minX + location.x - startMouse.x, y: startFrame.minY + location.y - startMouse.y)
            WindowMover.shared.setPositionAndSize(of: window, to: CGRect(origin: origin, size: startFrame.size))
            return true

        case let .resizing(window, startMouse, startFrame, growsLeft, growsUp):
            let dx = location.x - startMouse.x
            let dy = location.y - startMouse.y
            var frame = startFrame
            if growsLeft {
                frame.origin.x += dx
                frame.size.width -= dx
            } else {
                frame.size.width += dx
            }
            if growsUp {
                frame.origin.y += dy
                frame.size.height -= dy
            } else {
                frame.size.height += dy
            }
            frame.size.width = max(frame.width, 150)
            frame.size.height = max(frame.height, 100)
            WindowMover.shared.setPositionAndSize(of: window, to: frame)
            return true

        case var .watching(watch):

            // First drag: find the window that was clicked.
            guard let windowNumber = watch.windowNumber, let startBounds = watch.startBounds else {
                guard let (number, bounds) = Self.windowUnder(watch.startMouse), let window = window(at: watch.startMouse) else {
                    drag = nil
                    return false
                }
                watch.window = window
                watch.windowNumber = number
                watch.startBounds = bounds
                drag = .watching(watch)
                return false
            }

            // Until it moves, check whether you're dragging the window itself (by
            // its title bar) or doing something else, like selecting text. The
            // window server always knows where windows are, live, whichever app
            // they belong to, and asking it doesn't slow the app down.
            if !watch.isMoving {
                guard let bounds = Self.windowBounds(windowNumber), bounds.origin != startBounds.origin else {
                    if hypot(location.x - watch.startMouse.x, location.y - watch.startMouse.y) > 80 {
                        drag = nil // Not a window drag; stop watching so it's never slowed down.
                    }
                    return false
                }
                watch.isMoving = true
                drag = .watching(watch)
            }

            // It's a window drag: the snap zone depends only on the pointer.
            let zone = snapZone(at: location)
            guard zone != watch.zone else { return false }
            watch.zone = zone
            drag = .watching(watch)
            if let zone, let screen = WindowMover.screen(at: location), let target = WindowMover.frame(for: zone, on: screen) {
                preview.show(at: target)
            } else {
                preview.hide()
            }
            return false

        case nil:
            return false
        }
    }

    private func mouseUp(at location: CGPoint) -> Bool {
        defer { drag = nil }
        switch drag {
        case .moving, .resizing:
            return true
        case let .watching(watch):
            preview.hide()
            if watch.isMoving, let window = watch.window, let zone = watch.zone {
                // Let the app finish its own drag first, then glide into place.
                DispatchQueue.main.async { WindowMover.shared.move(zone, window: window) }
            }
            return false
        case nil:
            return false
        }
    }

    /// Which snap zone the pointer is in, if any.
    private func snapZone(at point: CGPoint) -> WindowPosition? {
        guard let screen = WindowMover.screen(at: point) else { return nil }
        let frame = WindowMover.flipped(screen.frame)
        let atLeft = point.x <= frame.minX + Self.edgeMargin
        let atRight = point.x >= frame.maxX - Self.edgeMargin
        let atTop = point.y <= frame.minY + Self.edgeMargin
        let atBottom = point.y >= frame.maxY - Self.edgeMargin

        switch true {
        case atLeft && atTop: return .topLeft
        case atRight && atTop: return .topRight
        case atLeft && atBottom: return .bottomLeft
        case atRight && atBottom: return .bottomRight
        case atLeft: return .leftHalf
        case atRight: return .rightHalf
        case atTop: return .maximize
        default: return nil
        }
    }

    // MARK: - Windows

    /// The frontmost ordinary window under a point, as the window server sees
    /// it: its number and where it is (top-left coordinates, like Accessibility).
    private static func windowUnder(_ point: CGPoint) -> (CGWindowID, CGRect)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? pid_t) != ownProcess,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  bounds.contains(point)
            else { continue }
            return (number, bounds)
        }
        return nil
    }

    /// Where the window server says a window is right now.
    private static func windowBounds(_ number: CGWindowID) -> CGRect? {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, number) as? [[String: Any]])?.first,
              let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary
        else { return nil }
        return CGRect(dictionaryRepresentation: boundsInfo)
    }

    /// The window under a point on the screen.
    private func window(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element
        else { return nil }
        if AX.string(element, kAXRoleAttribute) == kAXWindowRole { return element }
        return AX.element(element, kAXWindowAttribute)
    }

    /// Brings a window and its app to the front, as clicking it normally would.
    private func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        var processID: pid_t = 0
        AXUIElementGetPid(window, &processID)
        NSRunningApplication(processIdentifier: processID)?.activate()
    }
}

/// Called by macOS for every left-button press, drag and release. Runs on the main thread.
private nonisolated func handleDragEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Let through the clicks BestTouchTool itself makes (like a Left Click action).
    guard event.getIntegerValueField(.eventSourceUserData) != SyntheticEvent.marker else {
        return Unmanaged.passUnretained(event)
    }
    let location = event.location
    let flags = event.flags
    let swallow = MainActor.assumeIsolated { WindowDragEngine.shared.handle(type, at: location, flags: flags) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}

/// The soft, rounded preview of where a dragged window will snap.
private final class SnapPreview {
    private var window: NSWindow?

    /// `frame` is in Accessibility coordinates (top-left origin), like everything else here.
    func show(at frame: CGRect) {
        let target = WindowMover.flipped(frame).insetBy(dx: 6, dy: 6)
        let window = self.window ?? makeWindow(at: target)
        self.window = window
        if window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(target, display: true)
            }
        } else {
            window.setFrame(target, display: true)
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let window, window.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        }
    }

    private func makeWindow(at frame: CGRect) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SnapPreviewShape())
        return window
    }
}

/// Apple's Liquid Glass where it's available (macOS 26 and later): clear and
/// quiet, like the system's own controls. A plain frosted panel before that.
private struct SnapPreviewShape: View {
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
    }
}
