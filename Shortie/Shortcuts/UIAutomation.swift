import AppKit
import SwiftUI

/// Driving other apps' windows, menus and controls through Accessibility.
enum UIAutomation {
    // MARK: - Context menus and sliders

    /// Right-clicks where the pointer is, then chooses the item with this name.
    static func chooseContextMenuItem(_ name: String) {
        MouseClicker.perform(.rightClick)
        Task {
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(100))
                if let item = findMenuItem(named: name) {
                    AXUIElementPerformAction(item, kAXPressAction as CFString)
                    return
                }
            }
            // Close the menu again rather than leave it hanging.
            KeyPresser.press(KeyCombo(keyCode: 53, modifiers: [], keyName: "Esc"))
            NSSound.beep()
        }
    }

    private static func findMenuItem(named name: String) -> AXUIElement? {
        let apps = [NSWorkspace.shared.frontmostApplication, ActionTarget.underPointer.flatMap { NSRunningApplication(processIdentifier: $0.processID) }]
        for app in apps.compactMap({ $0 }) {
            let root = AXUIElementCreateApplication(app.processIdentifier)
            if let found = find(in: root, depth: 0, where: { element in
                AX.string(element, kAXRoleAttribute) == kAXMenuItemRole
                    && AX.string(element, kAXTitleAttribute)?.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(name) == .orderedSame
            }, skippingMenuBar: true) {
                return found
            }
        }
        return nil
    }

    /// Sets (or, if `relative`, changes) the slider with this name in the front window.
    static func setSlider(named name: String, value: Double, relative: Bool) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = AX.focusedWindow(of: app.processIdentifier),
              let slider = find(in: window, depth: 0, where: { element in
                  AX.string(element, kAXRoleAttribute) == kAXSliderRole
                      && (name.isEmpty || [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].contains { AX.string(element, $0)?.localizedCaseInsensitiveContains(name) == true })
              })
        else {
            NSSound.beep()
            return
        }
        var current: CFTypeRef?
        AXUIElementCopyAttributeValue(slider, kAXValueAttribute as CFString, &current)
        let now = (current as? NSNumber)?.doubleValue ?? 0
        AXUIElementSetAttributeValue(slider, kAXValueAttribute as CFString, NSNumber(value: relative ? now + value : value))
    }

    private static func find(in element: AXUIElement, depth: Int, where matches: (AXUIElement) -> Bool, skippingMenuBar: Bool = false) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        for child in children as? [AXUIElement] ?? [] {
            if skippingMenuBar, AX.string(child, kAXRoleAttribute) == kAXMenuBarRole { continue }
            if matches(child) { return child }
            if depth < 14, let found = find(in: child, depth: depth + 1, where: matches, skippingMenuBar: skippingMenuBar) { return found }
        }
        return nil
    }

    // MARK: - Blocking the keyboard

    /// Swallows every key press until switched off again (or for a minute at most),
    /// so you can clean the keyboard. The shortcut that switches it off still works.
    private(set) static var isBlockingKeyboard = false

    static func toggleKeyboardBlocking() {
        isBlockingKeyboard.toggle()
        HUD.show(isBlockingKeyboard ? "Keyboard Blocked for a Minute" : "Keyboard Unblocked",
                 systemImage: isBlockingKeyboard ? "keyboard.badge.ellipsis" : "keyboard")
        if isBlockingKeyboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                if isBlockingKeyboard { toggleKeyboardBlocking() }
            }
        }
    }

    // MARK: - Smooth scrolling

    private static var scrollTimer: Timer?

    /// Starts scrolling steadily in a direction, or stops if it's already scrolling.
    static func toggleAutoScroll(up: Bool) {
        if let scrollTimer {
            scrollTimer.invalidate()
            self.scrollTimer = nil
            return
        }
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: up ? 2 : -2, wheel2: 0, wheel3: 0)
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Moving and resizing windows with the pointer

    private static var followTimer: Timer?
    private static var following: (window: AXUIElement, frame: CGRect, start: CGPoint, resize: Bool)?

    /// The window under the pointer follows it (moving or resizing) until this
    /// runs again or you click.
    static func toggleFollowPointer(resize: Bool) {
        if followTimer != nil {
            stopFollowing()
            return
        }
        guard let target = ActionTarget.underPointer, let window = target.window,
              let frame = WindowMover.shared.frame(of: window),
              let start = CGEvent(source: nil)?.location
        else {
            NSSound.beep()
            return
        }
        following = (window, frame, start, resize)
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
            MainActor.assumeIsolated { followStep() }
        }
    }

    private static func followStep() {
        // A click ends it.
        guard let following, NSEvent.pressedMouseButtons == 0, let now = CGEvent(source: nil)?.location else {
            stopFollowing()
            return
        }
        let frame = following.frame
        let dx = now.x - following.start.x
        let dy = now.y - following.start.y
        let moved = following.resize
            ? CGRect(x: frame.minX, y: frame.minY, width: max(frame.width + dx, 200), height: max(frame.height + dy, 150))
            : CGRect(x: frame.minX + dx, y: frame.minY + dy, width: frame.width, height: frame.height)
        WindowMover.shared.setPositionAndSize(of: following.window, to: moved)
    }

    private static func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
        following = nil
    }

    // MARK: - Dock

    /// Acts like clicking the Dock icon under the pointer, but smarter: hides the
    /// app if it's already in front, otherwise brings it (and its minimised windows) back.
    static func dockIconUnderPointer() {
        guard let point = CGEvent(source: nil)?.location else { return }
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
              let element, AX.string(element, kAXSubroleAttribute) == "AXApplicationDockItem"
        else {
            NSSound.beep()
            return
        }
        var url: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &url)
        guard let appURL = url as? URL, let bundleID = Bundle(url: appURL)?.bundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
            return
        }
        if app.isActive {
            app.hide()
        } else {
            for window in AX.windows(of: app.processIdentifier) where AX.bool(window, kAXMinimizedAttribute) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            app.unhide()
            app.activate()
        }
    }

    // MARK: - Spaces

    /// Opens Mission Control and presses its "add desktop" button.
    static func addSpace() {
        SystemActionRunner.run(.missionControl)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
                  let button = find(in: AXUIElementCreateApplication(dock.processIdentifier), depth: 0, where: { element in
                      AX.string(element, kAXRoleAttribute) == kAXButtonRole
                          && (AX.string(element, kAXDescriptionAttribute)?.localizedCaseInsensitiveContains("add desktop") == true
                              || AX.string(element, "AXIdentifier")?.localizedCaseInsensitiveContains("addspace") == true)
                  })
            else {
                NSSound.beep()
                return
            }
            AXUIElementPerformAction(button, kAXPressAction as CFString)
            try? await Task.sleep(for: .milliseconds(500))
            KeyPresser.press(KeyCombo(keyCode: 53, modifiers: [], keyName: "Esc"))
        }
    }

    // MARK: - Dictation

    /// macOS's own dictation shortcut: pressing fn (🌐) twice.
    static func startDictation() {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<2 {
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 63, keyDown: isDown)
                event?.type = .flagsChanged
                event?.flags = isDown ? .maskSecondaryFn : []
                event?.post(tap: .cghidEventTap)
            }
            usleep(60_000)
        }
    }
}

/// A see-through layer over the screen: drag to measure anything, in points.
/// Esc or a click without dragging closes it.
final class ScreenRuler: NSObject {
    static let shared = ScreenRuler()

    private var windows: [NSWindow] = []

    func show() {
        close()
        for screen in NSScreen.screens {
            let window = RulerPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: RulerView(close: { [weak self] in self?.close() }))
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate()
        NSCursor.crosshair.push()
    }

    func close() {
        guard !windows.isEmpty else { return }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSCursor.pop()
    }
}

/// Borderless windows can't normally take key presses; this one needs Esc.
private final class RulerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct RulerView: View {
    let close: () -> Void

    @State private var start: CGPoint?
    @State private var end: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.08)
            if let start, let end {
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 1)
                    .background(Color.accentColor.opacity(0.12))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                Text("\(Int(rect.width)) × \(Int(rect.height))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: .capsule)
                    .offset(x: rect.maxX + 8, y: rect.maxY + 8)
            } else {
                Text("Drag to measure · Esc to close")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: .capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    start = value.startLocation
                    end = value.location
                }
                .onEnded { value in
                    if hypot(value.translation.width, value.translation.height) < 3 { close() }
                }
        )
        .onExitCommand(perform: close)
    }
}
