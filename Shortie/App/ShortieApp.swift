import SwiftUI

/// The entry point of Shortie.
///
/// Shortie lives in the menu bar (there's no Dock icon — see `LSUIElement` in the
/// build settings). The menu bar icon and windows are managed by AppKit in
/// `AppDelegate`, `StatusBarController` and `WindowManager`, because we need
/// finer control than SwiftUI's scenes give us (like telling left from right clicks).
@main
struct ShortieApp: App {
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
        #if DEBUG
        // A development-only mode that draws every page to image files, to check layouts.
        if Snapshots.runIfRequested() { return }
        #endif
        statusBar = StatusBarController()
        // Load your shortcuts now, so the first key press or gesture doesn't wait on the file.
        _ = ShortcutStore.shared
        InputEngines.start()
        AutomationEngine.shared.start()
        ClipboardHistory.shared.start()
        MenuBarMenus.shared.refresh()
        if HyperKey.shared.isEnabled { HyperKey.shared.apply() }
        // Settings like smooth scrolling or window snapping can switch listeners on or off.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { InputEngines.updateNeeds() }
        }
        NotchBar.shared.update()

        // Show the welcome window until Shortie has everything it needs.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        if !hasCompletedOnboarding || !Permissions.shared.allGranted {
            WindowManager.shared.show(.onboarding)
        }
    }

    /// Caps Lock only becomes Hyper while Shortie is running.
    func applicationWillTerminate(_ notification: Notification) {
        HyperKey.shared.restoreCapsLock()
    }

    /// Opening Shortie again (from Finder or Spotlight) while it's already running
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
        WindowDragEngine.shared.start()
        updateNeeds()
    }

    /// Switches each listener on or off depending on whether anything needs it.
    /// Called when your shortcuts or settings change.
    static func updateNeeds() {
        ScrollEngine.shared.updateNeed()
        TrafficLightEngine.shared.updateNeed()
        GestureEngine.shared.updateListening()
        MouseButtonEngine.shared.updateNeed()
        WindowDragEngine.shared.updateNeed()
    }
}

/// Where Shortie keeps your shortcuts, menus, layouts and clipboard history:
/// `~/Library/Application Support/Shortie`.
enum AppFolder {
    static let url: URL = {
        let folder = URL.applicationSupportDirectory.appending(path: "Shortie", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()
}

/// Keys for small preferences saved with `@AppStorage` (stored in UserDefaults).
enum DefaultsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let isPaused = "isPaused"
    static let microphoneLevel = "microphoneLevel"
    static let didPromptForAccessibility = "didPromptForAccessibility"
    static let wheelDirection = "wheelDirection"
    static let smoothScrolling = "smoothScrolling"
    static let scrollSpeed = "scrollSpeed"
    static let notchBarScreens = "notchBarScreens"
    static let hyperKey = "hyperKey"
    static let hyperTapAction = "hyperTapAction"
    static let dragMoveEnabled = "dragMoveEnabled"
    static let dragMoveModifiers = "dragMoveModifiers"
    static let dragResizeEnabled = "dragResizeEnabled"
    static let dragResizeModifiers = "dragResizeModifiers"
    static let dragSnapEnabled = "dragSnapEnabled"
    static let clipboardEnabled = "clipboardEnabled"
    static let clipboardLimit = "clipboardLimit"
    static let clipboardExcludedApps = "clipboardExcludedApps"
    static let clipboardShortcutAdded = "clipboardShortcutAdded"
}
