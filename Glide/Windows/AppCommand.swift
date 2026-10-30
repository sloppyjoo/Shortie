import AppKit
import ApplicationServices

/// Things you can do to a window or its app.
nonisolated enum AppCommand: String, Codable, CaseIterable, Identifiable {
    case closeWindow, minimizeWindow, toggleFullScreen
    case closeAllWindows, minimizeAllWindows
    case hideApp, hideOtherApps, quitApp

    var id: Self { self }

    var title: String {
        switch self {
        case .closeWindow: "Close Window"
        case .minimizeWindow: "Minimise Window"
        case .toggleFullScreen: "Enter or Exit Full Screen"
        case .closeAllWindows: "Close All of the App's Windows"
        case .minimizeAllWindows: "Minimise All of the App's Windows"
        case .hideApp: "Hide App"
        case .hideOtherApps: "Hide Other Apps"
        case .quitApp: "Quit App"
        }
    }

    var systemImage: String {
        switch self {
        case .closeWindow: "xmark"
        case .minimizeWindow: "minus"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        case .closeAllWindows: "xmark.rectangle"
        case .minimizeAllWindows: "minus.rectangle"
        case .hideApp: "eye.slash"
        case .hideOtherApps: "eye.slash.fill"
        case .quitApp: "power"
        }
    }

    /// For menus, so related commands sit together.
    static let groups: [[AppCommand]] = [
        [.closeWindow, .minimizeWindow, .toggleFullScreen],
        [.closeAllWindows, .minimizeAllWindows],
        [.hideApp, .hideOtherApps, .quitApp],
    ]
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
}

enum AppCommandRunner {
    static func run(_ command: AppCommand, on target: ActionTarget) {
        let app = NSRunningApplication(processIdentifier: target.processID)

        switch command {
        case .closeWindow:
            target.window.map(AX.close)
        case .minimizeWindow:
            target.window.map(AX.minimize)
        case .toggleFullScreen:
            if let window = target.window {
                let isFullScreen = AX.bool(window, "AXFullScreen") ?? false
                AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, (!isFullScreen) as CFBoolean)
            }
        case .closeAllWindows:
            AX.windows(of: target.processID).forEach(AX.close)
        case .minimizeAllWindows:
            AX.windows(of: target.processID).forEach(AX.minimize)
        case .hideApp:
            app?.hide()
        case .hideOtherApps:
            for other in NSWorkspace.shared.runningApplications
            where other.activationPolicy == .regular && other.processIdentifier != target.processID {
                other.hide()
            }
        case .quitApp:
            app?.terminate()
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
