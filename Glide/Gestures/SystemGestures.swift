import AppKit

/// Which gestures macOS itself is using, read from your Trackpad settings.
///
/// Glide can't stop macOS's own trackpad gestures (they're handled before any
/// app sees them), so if you give one of those gestures an action, both happen.
/// Clicks are different: Glide swallows them, so its action replaces macOS's.
/// This lets the dashboard warn you either way.
enum SystemGestures {
    /// A sentence explaining how this gesture clashes with macOS, if it does.
    static func warning(for gesture: Gesture) -> String? {
        guard let use = systemUse(of: gesture) else { return nil }
        switch gesture {
        case .click, .cornerClick:
            return "This is normally a right-click. Glide's action will replace it."
        default:
            break
        }
        return "macOS also uses this gesture: it \(use). Both will happen unless you turn it off in Trackpad settings."
    }

    /// What macOS does with this gesture, if anything. E.g. "opens Mission Control".
    private static func systemUse(of gesture: Gesture) -> String? {
        let trackpad = UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")

        /// Gesture settings are 0 when off, and 1 or 2 when on. Missing means
        /// you've never changed it, so use macOS's default.
        func isOn(_ key: String, default defaultValue: Bool) -> Bool {
            guard let value = trackpad?.object(forKey: key) as? Int else { return defaultValue }
            return value != 0
        }
        let forceClickOn = UserDefaults.standard.object(forKey: "com.apple.trackpad.forceClick") as? Bool ?? true

        switch gesture {
        case .swipe(3, _) where isOn("TrackpadThreeFingerDrag", default: false):
            return "uses three fingers to drag windows (Three-finger drag, in Accessibility settings)"
        case .swipe(let fingers, .left), .swipe(let fingers, .right):
            let key = fingers == 3 ? "TrackpadThreeFingerHorizSwipeGesture" : "TrackpadFourFingerHorizSwipeGesture"
            return fingers <= 4 && isOn(key, default: true) ? "switches between desktops and full-screen apps" : nil
        case .swipe(let fingers, .up):
            let key = fingers == 3 ? "TrackpadThreeFingerVertSwipeGesture" : "TrackpadFourFingerVertSwipeGesture"
            return fingers <= 4 && isOn(key, default: true) ? "opens Mission Control" : nil
        case .swipe(let fingers, .down):
            let key = fingers == 3 ? "TrackpadThreeFingerVertSwipeGesture" : "TrackpadFourFingerVertSwipeGesture"
            return fingers <= 4 && isOn(key, default: true) ? "shows App Exposé" : nil
        case .doubleTap(2):
            return isOn("TrackpadTwoFingerDoubleTapGesture", default: true) ? "zooms in on what's under the pointer (Smart zoom)" : nil
        case .edgeSwipe(2, .right):
            return isOn("TrackpadTwoFingerFromRightEdgeSwipeGesture", default: true) ? "opens Notification Centre" : nil
        case .pinch(4, let direction), .pinch(5, let direction):
            return isOn("TrackpadFourFingerPinchGesture", default: true) || isOn("TrackpadFiveFingerPinchGesture", default: true)
                ? (direction == .in ? "opens Launchpad" : "shows the desktop") : nil
        case .rotate:
            return isOn("TrackpadRotate", default: true) ? "rotates photos, maps and documents in apps" : nil
        case .cornerClick(.bottomRight):
            return trackpad?.object(forKey: "TrackpadCornerSecondaryClick") as? Int == 2 ? "right-clicks (click in bottom-right corner)" : nil
        case .cornerClick(.bottomLeft):
            return trackpad?.object(forKey: "TrackpadCornerSecondaryClick") as? Int == 1 ? "right-clicks (click in bottom-left corner)" : nil
        case .tap(3):
            return isOn("TrackpadThreeFingerTapGesture", default: false) ? "looks up the word under the pointer" : nil
        case .tap(2):
            return isOn("Clicking", default: false) && isOn("TrackpadRightClick", default: true)
                ? "right-clicks (tap with two fingers)" : nil
        case .click(2):
            return isOn("TrackpadRightClick", default: true) ? "right-clicks (click with two fingers)" : nil
        case .forceClick:
            return forceClickOn ? "looks up words and previews links" : nil
        default:
            return nil
        }
    }

    static func openTrackpadSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }
}
