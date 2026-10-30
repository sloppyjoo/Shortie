import AppKit
import ApplicationServices
import Observation

/// Tracks the macOS privacy permissions Glide needs.
///
/// Right now that's just **Accessibility**, which lets Glide react to keys and
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
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                refresh()
            }
        }
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if granted != accessibility {
            accessibility = granted
            // Start listening for shortcuts and scrolls the moment you allow it, no restart needed.
            if granted {
                ShortcutEngine.shared.start()
                ScrollEngine.shared.start()
            }
        }
    }

    /// The first time, this adds Glide to the Accessibility list and shows macOS's
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
