import AppKit
import Carbon.HIToolbox
import JavaScriptCore

/// What to do to another of your rules.
nonisolated enum RuleMode: String, Codable, CaseIterable, Identifiable {
    case run, enable, disable, toggle

    var id: Self { self }

    var title: String {
        switch self {
        case .run: "Run"
        case .enable: "Switch On"
        case .disable: "Switch Off"
        case .toggle: "Switch On or Off"
        }
    }
}

enum MoreActionKindsRunner {
    /// Presses keys in a particular app, even when it isn't in front.
    static func press(_ combo: KeyCombo, inAppAt path: String) {
        guard let bundleID = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else {
            NSSound.beep()
            return
        }
        let source = CGEventSource(stateID: .privateState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: isDown)
            event?.flags = combo.modifiers.eventFlags
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.postToPid(app.processIdentifier)
        }
    }

    /// Holds modifier keys down (until a matching "let go"), or lets go of them.
    static func modifierKeys(_ modifiers: Modifiers, down: Bool) {
        let keys: [(Modifiers, CGKeyCode)] = [(.control, 59), (.option, 58), (.shift, 56), (.command, 55)]
        var held: CGEventFlags = down ? [] : CGEventSource.flagsState(.combinedSessionState)
        let source = CGEventSource(stateID: .hidSystemState)
        for (modifier, keyCode) in keys where modifiers.contains(modifier) {
            let flag = modifier.eventFlags
            if down { held.formUnion(flag) } else { held.subtract(flag) }
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
            event?.type = .flagsChanged
            event?.flags = held
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Brings forward the first window, from any app, whose title contains `text`.
    static func focusWindow(titled text: String) {
        let wanted = text.trimmingCharacters(in: .whitespaces)
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            for window in AX.windows(of: app.processIdentifier) {
                guard let title = AX.string(window, kAXTitleAttribute), title.localizedCaseInsensitiveContains(wanted) else { continue }
                if AX.bool(window, kAXMinimizedAttribute) == true {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
                WindowOrder.focus(window, processID: app.processIdentifier)
                return
            }
        }
        NSSound.beep()
    }

    /// Runs your JavaScript on the selected text (or the clipboard) and puts the result back.
    static func transformText(script: String, onClipboard: Bool) {
        if onClipboard {
            guard let text = NSPasteboard.general.string(forType: .string), let result = JavaScriptText.run(script, on: text) else {
                NSSound.beep()
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            HUD.show("Clipboard Changed", systemImage: "curlybraces")
        } else {
            SelectedText.replace { JavaScriptText.run(script, on: $0) }
        }
    }

    /// Runs JavaScript in the page in front, in Safari or a Chrome-based browser.
    /// The browser has to allow it: Safari's Develop menu › Allow JavaScript from
    /// Apple Events; Chrome's View › Developer › Allow JavaScript from Apple Events.
    static func runInBrowser(_ source: String) {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        let escaped = source.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = bundleID.hasPrefix("com.apple.Safari")
            ? "tell application id \"\(bundleID)\" to do JavaScript \"\(escaped)\" in current tab of front window"
            : "tell application id \"\(bundleID)\" to execute active tab of front window javascript \"\(escaped)\""
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil { NSSound.beep() }
    }

    static func runWorkflow(at path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/automator")
        process.arguments = [(path as NSString).expandingTildeInPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// Pauses every trigger, then resumes on its own.
    static func pause(for seconds: Double) {
        UserDefaults.standard.set(true, forKey: DefaultsKey.isPaused)
        HUD.show("Shortie Paused for \(seconds.formatted()) s", systemImage: "hand.raised.slash")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            UserDefaults.standard.set(false, forKey: DefaultsKey.isPaused)
        }
    }

    /// Presses the button, checkbox or tab with this name in the window you're using.
    static func clickButton(named name: String) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = AX.focusedWindow(of: app.processIdentifier),
              let button = find(in: window, depth: 0, where: { element in
                  let role = AX.string(element, kAXRoleAttribute) ?? ""
                  guard ["AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXLink"].contains(role) else { return false }
                  return [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].contains { attribute in
                      AX.string(element, attribute)?.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(name) == .orderedSame
                  }
              }) ?? find(in: AX.focusedWindow(of: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) ?? AXUIElementCreateSystemWide(), depth: 0, where: { element in
                  // Anything else with that name that can be pressed: rows, cells, images, static text…
                  var actions: CFArray?
                  AXUIElementCopyActionNames(element, &actions)
                  guard (actions as? [String])?.contains(kAXPressAction) == true else { return false }
                  return [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].contains { attribute in
                      AX.string(element, attribute)?.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(name) == .orderedSame
                  }
              })
        else {
            NSSound.beep()
            return
        }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }

    /// Clicks an icon on the right of the menu bar, from any app, by its name.
    static func clickMenuBarExtra(named name: String) {
        for app in NSWorkspace.shared.runningApplications {
            let root = AXUIElementCreateApplication(app.processIdentifier)
            guard let bar = AX.element(root, "AXExtrasMenuBar") else { continue }
            let item = find(in: bar, depth: 0) { element in
                [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, "AXIdentifier"].contains { attribute in
                    AX.string(element, attribute)?.localizedCaseInsensitiveContains(name) == true
                }
            } ?? ((app.localizedName?.localizedCaseInsensitiveContains(name) == true) ? firstChild(of: bar) : nil)
            if let item {
                AXUIElementPerformAction(item, kAXPressAction as CFString)
                return
            }
        }
        NSSound.beep()
    }

    /// Runs, switches on or switches off another of your rules.
    static func otherRule(_ id: UUID?, mode: RuleMode) {
        let store = ShortcutStore.shared
        guard let id, let shortcut = store.shortcuts.first(where: { $0.id == id }) else {
            NSSound.beep()
            return
        }
        switch mode {
        case .run:
            // Rules that run each other in a circle would never stop.
            guard ruleDepth < 8 else { return }
            ruleDepth += 1
            defer { ruleDepth -= 1 }
            ActionRunner.run(shortcut.action)
        case .enable:
            store.setEnabled(true, id: id)
        case .disable:
            store.setEnabled(false, id: id)
        case .toggle:
            store.setEnabled(!shortcut.isEnabled, id: id)
        }
    }

    private static var ruleDepth = 0

    private static func firstChild(of element: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        return (children as? [AXUIElement])?.first
    }

    private static func find(in element: AXUIElement, depth: Int, where matches: (AXUIElement) -> Bool) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        for child in children as? [AXUIElement] ?? [] {
            if matches(child) { return child }
            if depth < 14, let found = find(in: child, depth: depth + 1, where: matches) { return found }
        }
        return nil
    }
}

/// Runs a little JavaScript on some text. The script sees the text as `text`
/// and returns the new text; a single expression like `text.toUpperCase()`
/// works too.
enum JavaScriptText {
    static func run(_ script: String, on text: String) -> String? {
        guard let context = JSContext() else { return nil }
        context.setObject(text, forKeyedSubscript: "text" as NSString)
        let body = script.contains("return") ? script : "return (\(script));"
        let result = context.evaluateScript("(function (text) {\n\(body)\n})(text)")
        if let exception = context.exception {
            HUD.show("Script Error: \(exception.toString() ?? "")", systemImage: "exclamationmark.triangle.fill")
            return nil
        }
        guard let result, !result.isUndefined, !result.isNull else { return nil }
        return result.toString()
    }
}
