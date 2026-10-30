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
        ShortcutEngine.shared.start()
        ScrollEngine.shared.start()

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

/// Keys for small preferences saved with `@AppStorage` (stored in UserDefaults).
enum DefaultsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let isPaused = "isPaused"
    static let didPromptForAccessibility = "didPromptForAccessibility"
    static let wheelDirection = "wheelDirection"
    static let smoothScrolling = "smoothScrolling"
    static let scrollSpeed = "scrollSpeed"
}
