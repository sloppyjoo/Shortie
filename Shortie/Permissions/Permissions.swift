import AppKit
import ApplicationServices
import Observation

/// Tracks the macOS privacy permissions Shortie needs.
///
/// Right now that's just **Accessibility**, which lets Shortie react to keys and
/// gestures anywhere on the Mac and move other apps' windows. We only ask for
/// what we actually use — fewer scary prompts is part of feeling built in.
///
/// macOS doesn't tell apps when you flip a switch in System Settings, so we
/// re-check once a second. The check is very cheap.
@Observable
final class Permissions {
    static let shared = Permissions()

    private(set) var accessibility = AXIsProcessTrusted()

    /// Whether we've already shown macOS's Accessibility prompt once.
    private(set) var hasAskedForAccessibility = UserDefaults.standard.bool(forKey: DefaultsKey.didPromptForAccessibility)

    var allGranted: Bool { accessibility }

    private init() {
        // While you're granting permission, check every second so the checkmark
        // appears straight away. Once it's granted, macOS's notice whenever the
        // Accessibility list changes does the work; a slow check every 30 seconds
        // is just a safety net in case a notice is missed.
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: accessibility ? .seconds(30) : .seconds(1))
                refresh()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { _ in
            // The change takes a moment to apply after the notice.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Permissions.shared.refresh()
            }
        }
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if granted != accessibility {
            accessibility = granted
            // Start listening for shortcuts, scrolls and clicks the moment you allow it, no restart needed.
            if granted { InputEngines.start() }
        }
    }

    /// The first time, this adds Shortie to the Accessibility list and shows macOS's
    /// own prompt. macOS only shows that prompt once, so after that we open the
    /// right page of System Settings directly.
    func requestAccessibility() {
        if hasAskedForAccessibility {
            openAccessibilitySettings()
        } else {
            hasAskedForAccessibility = true
            UserDefaults.standard.set(true, forKey: DefaultsKey.didPromptForAccessibility)
            // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
