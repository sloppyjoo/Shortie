import AppKit

/// Glide's icon in the menu bar.
///
/// - **Left-click** opens the dashboard.
/// - **Right-click** (or Control-click) shows a small menu with About and Quit.
///
/// SwiftUI's `MenuBarExtra` can't tell a left click from a right click, so this
/// part uses AppKit's `NSStatusItem` directly.
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    override init() {
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()

        // Swap the icon when Glide is paused or resumed from the dashboard.
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateIcon),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            WindowManager.shared.show(.settings)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if !Permissions.shared.allGranted {
            let item = menuItem("Shortie Needs Permission…", action: #selector(showOnboarding))
            item.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(item)
            menu.addItem(.separator())
        }

        menu.addItem(menuItem("About Shortie", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Shortie", action: #selector(quit), key: "q"))

        // Attach the menu just long enough to pop it up in the usual spot under the
        // icon, then detach it so the next left-click opens the dashboard again.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func updateIcon() {
        let isPaused = UserDefaults.standard.bool(forKey: DefaultsKey.isPaused)
        let image = PixelArt.menuBarImage(slashed: isPaused)
        image.accessibilityDescription = isPaused ? "Shortie (paused)" : "Shortie"
        statusItem.button?.image = image
    }

    @objc private func showOnboarding() {
        WindowManager.shared.show(.onboarding)
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
