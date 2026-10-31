import AppKit
import ApplicationServices

/// Things you can do to a window or its app.
nonisolated enum AppCommand: String, Codable, CaseIterable, Identifiable {
    case closeWindow, minimizeWindow, toggleFullScreen
    case closeAllWindows, minimizeAllWindows
    case closeOtherWindows, unminimizeAllWindows, bringAllWindowsForward, nextWindowOfApp
    case forceQuitApp, restartApp
    case moveToNextSpace, moveToPreviousSpace
    case hideApp, hideOtherApps, quitApp, quitOtherApps
    case closeWindowOrQuit
    case closePointerWindow, minimizePointerWindow, zoomPointerWindow, raisePointerWindow
    case hidePointerApp, quitPointerApp

    var id: Self { self }

    var title: String {
        switch self {
        case .closeWindow: "Close Window"
        case .minimizeWindow: "Minimise Window"
        case .toggleFullScreen: "Enter or Exit Full Screen"
        case .closeAllWindows: "Close All of the App's Windows"
        case .minimizeAllWindows: "Minimise All of the App's Windows"
        case .closeOtherWindows: "Close the App's Other Windows"
        case .unminimizeAllWindows: "Bring Back the App's Minimised Windows"
        case .bringAllWindowsForward: "Bring All of the App's Windows Forward"
        case .nextWindowOfApp: "Next Window of the App"
        case .forceQuitApp: "Force Quit App"
        case .restartApp: "Restart App"
        case .moveToNextSpace: "Move Window to Next Space"
        case .moveToPreviousSpace: "Move Window to Previous Space"
        case .hideApp: "Hide App"
        case .hideOtherApps: "Hide Other Apps"
        case .quitApp: "Quit App"
        case .quitOtherApps: "Quit Other Apps"
        case .closeWindowOrQuit: "Close Window, or Quit if It's the Last"
        case .closePointerWindow: "Close Window Under Pointer"
        case .minimizePointerWindow: "Minimise Window Under Pointer"
        case .zoomPointerWindow: "Zoom Window Under Pointer"
        case .raisePointerWindow: "Bring Window Under Pointer to Front"
        case .hidePointerApp: "Hide App Under Pointer"
        case .quitPointerApp: "Quit App Under Pointer"
        }
    }

    var systemImage: String {
        switch self {
        case .closeWindow: "xmark"
        case .minimizeWindow: "minus"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        case .closeAllWindows: "xmark.rectangle"
        case .minimizeAllWindows: "minus.rectangle"
        case .closeOtherWindows: "xmark.rectangle.portrait"
        case .unminimizeAllWindows: "plus.rectangle"
        case .bringAllWindowsForward: "square.stack.3d.up"
        case .nextWindowOfApp: "rectangle.2.swap"
        case .forceQuitApp: "xmark.octagon"
        case .restartApp: "arrow.clockwise.circle"
        case .moveToNextSpace: "arrow.right.square"
        case .moveToPreviousSpace: "arrow.left.square"
        case .hideApp: "eye.slash"
        case .hideOtherApps: "eye.slash.fill"
        case .quitApp: "power"
        case .quitOtherApps: "power.circle"
        case .closeWindowOrQuit: "xmark.square"
        case .closePointerWindow: "xmark.circle"
        case .minimizePointerWindow: "minus.circle"
        case .zoomPointerWindow: "plus.circle"
        case .raisePointerWindow: "macwindow.on.rectangle"
        case .hidePointerApp: "eye.slash.circle"
        case .quitPointerApp: "power.circle.fill"
        }
    }

    /// For menus, so related commands sit together.
    static let groups: [[AppCommand]] = [
        [.closeWindow, .minimizeWindow, .toggleFullScreen],
        [.closeAllWindows, .minimizeAllWindows, .closeOtherWindows, .unminimizeAllWindows],
        [.bringAllWindowsForward, .nextWindowOfApp, .moveToNextSpace, .moveToPreviousSpace],
        [.hideApp, .hideOtherApps, .quitApp, .quitOtherApps, .closeWindowOrQuit, .forceQuitApp, .restartApp],
        [.closePointerWindow, .minimizePointerWindow, .zoomPointerWindow, .raisePointerWindow, .hidePointerApp, .quitPointerApp],
    ]

    /// Commands that act on whatever is under the pointer rather than the window you're using.
    var usesPointer: Bool {
        switch self {
        case .closePointerWindow, .minimizePointerWindow, .zoomPointerWindow, .raisePointerWindow, .hidePointerApp, .quitPointerApp: true
        default: false
        }
    }
}

/// The window an action should apply to. From a keyboard shortcut that's the
/// window you're using; from a traffic light it's the window whose button you
/// clicked, which might be in the background.
nonisolated struct ActionTarget: @unchecked Sendable {
    // AXUIElement is a thread-safe Core Foundation object, so sharing it is fine.
    let window: AXUIElement?
    let processID: pid_t

    /// The window and app you're currently using.
    @MainActor static var frontmost: ActionTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return ActionTarget(window: AX.focusedWindow(of: app.processIdentifier), processID: app.processIdentifier)
    }

    /// The window under the pointer, and its app.
    @MainActor static var underPointer: ActionTarget? {
        guard let point = CGEvent(source: nil)?.location else { return nil }
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
              let element
        else { return nil }
        var processID: pid_t = 0
        AXUIElementGetPid(element, &processID)
        let window = AX.string(element, kAXRoleAttribute) == kAXWindowRole ? element : AX.element(element, kAXWindowAttribute)
        return ActionTarget(window: window, processID: processID)
    }
}

enum AppCommandRunner {
    static func run(_ command: AppCommand, on target: ActionTarget) {
        var target = target
        if command.usesPointer {
            guard let underPointer = MainActor.assumeIsolated({ ActionTarget.underPointer }) else { return }
            target = underPointer
        }
        let app = NSRunningApplication(processIdentifier: target.processID)

        switch command {
        case .closeWindow, .closePointerWindow:
            target.window.map(AX.close)
        case .minimizeWindow, .minimizePointerWindow:
            target.window.map(AX.minimize)
        case .zoomPointerWindow:
            if let window = target.window, let button = AX.element(window, kAXZoomButtonAttribute) {
                AXUIElementPerformAction(button, kAXPressAction as CFString)
            }
        case .raisePointerWindow:
            target.window.map { AXUIElementPerformAction($0, kAXRaiseAction as CFString) }
            app?.activate()
        case .hidePointerApp:
            app?.hide()
        case .quitPointerApp:
            if app?.bundleIdentifier != "com.apple.finder" { app?.terminate() }
        case .closeWindowOrQuit:
            // Minimised windows count as open, so the app only quits when none are left.
            if AX.windows(of: target.processID).count <= 1, app?.bundleIdentifier != "com.apple.finder" {
                app?.terminate()
            } else {
                target.window.map(AX.close)
            }
        case .toggleFullScreen:
            if let window = target.window {
                let isFullScreen = AX.bool(window, "AXFullScreen") ?? false
                AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, (!isFullScreen) as CFBoolean)
            }
        case .closeAllWindows:
            AX.windows(of: target.processID).forEach(AX.close)
        case .minimizeAllWindows:
            AX.windows(of: target.processID).forEach(AX.minimize)
        case .closeOtherWindows:
            for window in AX.windows(of: target.processID) where target.window.map({ !CFEqual($0, window) }) ?? true {
                AX.close(window)
            }
        case .unminimizeAllWindows:
            for window in AX.windows(of: target.processID) {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            app?.activate()
        case .bringAllWindowsForward:
            app?.activate(options: .activateAllWindows)
        case .nextWindowOfApp:
            // Windows are listed front to back, so raising the back one cycles through them all.
            let windows = AX.windows(of: target.processID).filter { AX.bool($0, kAXMinimizedAttribute) != true }
            if windows.count > 1, let back = windows.last {
                AXUIElementPerformAction(back, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(back, kAXMainAttribute as CFString, kCFBooleanTrue)
                app?.activate()
            }
        case .moveToNextSpace, .moveToPreviousSpace:
            target.window.map { SpaceMover.move($0, right: command == .moveToNextSpace) }
        case .forceQuitApp:
            if app?.bundleIdentifier != "com.apple.finder" { app?.forceTerminate() }
        case .restartApp:
            guard let app, let url = app.bundleURL, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            app.terminate()
            Task {
                // Give it up to ten seconds to quit (it may ask to save first).
                for _ in 0..<100 where !app.isTerminated {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                guard app.isTerminated else { return }
                _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .hideApp:
            app?.hide()
        case .hideOtherApps:
            for other in NSWorkspace.shared.runningApplications
            where other.activationPolicy == .regular && other.processIdentifier != target.processID {
                other.hide()
            }
        case .quitApp:
            app?.terminate()
        case .quitOtherApps:
            // Apps still ask to save your work. Finder stays, as it always does.
            let ownID = ProcessInfo.processInfo.processIdentifier
            for other in NSWorkspace.shared.runningApplications
            where other.activationPolicy == .regular && other.processIdentifier != target.processID
                && other.processIdentifier != ownID && other.bundleIdentifier != "com.apple.finder" {
                other.terminate()
            }
        }
    }
}

/// Small helpers for the Accessibility API, which reads and controls other
/// apps' windows and buttons.
enum AX {
    static func focusedWindow(of processID: pid_t) -> AXUIElement? {
        element(AXUIElementCreateApplication(processID), kAXFocusedWindowAttribute)
    }

    static func windows(of processID: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(processID), kAXWindowsAttribute as CFString, &value
        ) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    /// Presses the window's own close button, so the app can ask to save first.
    static func close(_ window: AXUIElement) {
        if let button = element(window, kAXCloseButtonAttribute) {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }

    static func minimize(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }
}
