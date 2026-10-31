import AppKit
import SwiftUI

enum WindowID {
    case onboarding
    case settings
}

/// Opens Shortie's windows. Each window is created the first time it's needed and
/// kept after you close it, so reopening is instant and remembers its position.
///
/// While any Shortie window is open, Shortie behaves like a normal app (Dock icon,
/// ⌘-Tab). When the last one closes it goes back to living only in the menu bar.
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var windows: [WindowID: NSWindow] = [:]

    func show(_ id: WindowID) {
        let window = windows[id] ?? makeWindow(id)
        windows[id] = window

        // Menu bar apps can't normally bring themselves to the front: macOS only
        // lets "regular" apps do that. So we become one while a window is open...
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        // ...and also put the window on top even if macOS hasn't switched to us yet.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if id == .settings { SettingsView.pinSidebarWidth(in: window) }
    }

    func close(_ id: WindowID) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        let othersOpen = windows.values.contains { $0 !== closing && $0.isVisible }
        if !othersOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func makeWindow(_ id: WindowID) -> NSWindow {
        let window: NSWindow
        switch id {
        case .onboarding:
            window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView()))
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.title = "Welcome to Shortie"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true

        case .settings:
            let controller = NSHostingController(rootView: SettingsView())
            // Let SwiftUI put the sidebar and title into the window's toolbar.
            controller.sceneBridgingOptions = .all
            // Keep one fixed minimum size. Otherwise every section works out its own,
            // and the window jumps around as you click through the sidebar.
            controller.sizingOptions = []
            window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.title = "Shortie"
            window.toolbarStyle = .unified
            window.contentMinSize = NSSize(width: 715, height: 460)
            window.setContentSize(NSSize(width: 760, height: 520))
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
