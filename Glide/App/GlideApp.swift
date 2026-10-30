import SwiftUI

/// The entry point of Glide.
///
/// Glide lives in the menu bar (there's no Dock icon — see `LSUIElement` in the
/// build settings). The menu bar icon and windows are managed by AppKit in
/// `AppDelegate`, `StatusBarController` and `WindowManager`, because we need
/// finer control than SwiftUI's scenes give us (like telling left from right clicks).
@main
struct GlideApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // SwiftUI needs at least one scene. This one is never shown.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        // Load your shortcuts now, so the first key press or gesture doesn't wait on the file.
        _ = ShortcutStore.shared
        InputEngines.start()
        NotchBar.shared.update()

        // Show the welcome window until Glide has everything it needs.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        if !hasCompletedOnboarding || !Permissions.shared.allGranted {
            WindowManager.shared.show(.onboarding)
        }
    }

    /// Opening Glide again (from Finder or Spotlight) while it's already running
    /// shows the dashboard, so it never feels like nothing happened.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        WindowManager.shared.show(.settings)
        return false
    }
}

/// Everything that listens to your keyboard, mouse and trackpad.
enum InputEngines {
    /// Safe to call repeatedly; each one waits until Accessibility is granted.
    static func start() {
        ShortcutEngine.shared.start()
        ScrollEngine.shared.start()
        TrafficLightEngine.shared.start()
        GestureEngine.shared.start()
        MouseButtonEngine.shared.start()
    }
}

/// Keys for small preferences saved with `@AppStorage` (stored in UserDefaults).
enum DefaultsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let isPaused = "isPaused"
    static let didPromptForAccessibility = "didPromptForAccessibility"
    static let wheelDirection = "wheelDirection"
    static let smoothScrolling = "smoothScrolling"
    static let scrollSpeed = "scrollSpeed"
    static let notchBarScreens = "notchBarScreens"
}
