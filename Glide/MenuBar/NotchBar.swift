import AppKit
import Observation

/// Paints the menu bar black on the screens you choose, so the notch blends in.
///
/// How: a plain black window sits exactly where the menu bar is, one layer
/// *below* it. Windows on a Mac live in layers ("levels"); the menu bar is on
/// the main-menu level, so a window one level lower is above every app but
/// still underneath the menu bar's clock, menus and icons.
@Observable
final class NotchBar {
    static let shared = NotchBar()

    /// Screens with the black bar switched on, by their permanent ID.
    private(set) var enabledScreenIDs: Set<String>

    private var windows: [String: NSWindow] = [:]

    private init() {
        enabledScreenIDs = Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.notchBarScreens) ?? [])

        // Rebuild when screens are plugged in, unplugged or rearranged.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { NotchBar.shared.update() }
        }
    }

    func isEnabled(on screen: NSScreen) -> Bool {
        enabledScreenIDs.contains(screen.stableID)
    }

    func setEnabled(_ enabled: Bool, on screen: NSScreen) {
        if enabled {
            enabledScreenIDs.insert(screen.stableID)
        } else {
            enabledScreenIDs.remove(screen.stableID)
        }
        UserDefaults.standard.set(Array(enabledScreenIDs), forKey: DefaultsKey.notchBarScreens)
        update()
    }

    /// Makes the black bars match the current screens and settings.
    func update() {
        var wanted: [String: CGRect] = [:]
        for screen in NSScreen.screens where isEnabled(on: screen) {
            if let frame = screen.menuBarFrame {
                wanted[screen.stableID] = frame
            }
        }

        for (id, window) in windows where wanted[id] == nil {
            window.orderOut(nil)
            windows[id] = nil
        }
        for (id, frame) in wanted {
            let window = windows[id] ?? makeWindow()
            window.setFrame(frame, display: true)
            window.orderFrontRegardless()
            windows[id] = window
        }
    }

    private func makeWindow() -> NSWindow {
        let window = MenuBarBackdropWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // On every desktop, not moved by Mission Control, not in ⌘-Tab or the Window menu.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        return window
    }
}

/// A window that's allowed to sit where the menu bar is.
///
/// AppKit normally nudges every window down out of the menu bar area, so apps
/// can't hide underneath it. That's exactly where this one needs to be.
private final class MenuBarBackdropWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

extension NSScreen {
    /// A permanent ID for this screen that survives restarts and replugging.
    var stableID: String {
        guard
            let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
            let string = CFUUIDCreateString(nil, uuid) as String?
        else { return localizedName }
        return string
    }

    var hasNotch: Bool { safeAreaInsets.top > 0 }

    /// Where the menu bar sits on this screen, or `nil` if it's hidden
    /// (set to hide automatically). We don't cover a hidden menu bar, or the
    /// black bar would sit over the top of your apps.
    var menuBarFrame: CGRect? {
        let height = frame.maxY - visibleFrame.maxY
        guard height > 0 else { return nil }
        return CGRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }
}
