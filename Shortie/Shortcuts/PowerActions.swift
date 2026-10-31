import AppKit
import ApplicationServices

/// Chooses an item from an app's menus, like "File › Export as PDF…", through
/// the Accessibility API: the same as clicking through the menus yourself.
enum MenuClicker {
    /// "File › Export as PDF…" (or with ">") split into its menus.
    nonisolated static func steps(of path: String) -> [String] {
        path.split(whereSeparator: { $0 == "›" || $0 == ">" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Returns whether the item was found.
    static func choose(_ path: String, in processID: pid_t) -> Bool {
        let steps = steps(of: path)
        guard !steps.isEmpty,
              var current = AX.element(AXUIElementCreateApplication(processID), kAXMenuBarAttribute)
        else { return false }

        for (index, step) in steps.enumerated() {
            guard let item = children(of: current).first(where: { matches(AX.string($0, kAXTitleAttribute), step) }) else {
                return false
            }
            if index == steps.count - 1 {
                return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
            }
            // A menu, or an item with a submenu, holds that menu as its only child.
            guard let menu = children(of: item).first else { return false }
            current = menu
        }
        return false
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        return value as? [AXUIElement] ?? []
    }

    /// Ignores capitals and a trailing "…" or "...", so "export as pdf" finds "Export as PDF…".
    private static func matches(_ title: String?, _ wanted: String) -> Bool {
        func tidy(_ text: String) -> String {
            var text = text.trimmingCharacters(in: .whitespaces).lowercased()
            for ending in ["…", "..."] where text.hasSuffix(ending) {
                text.removeLast(ending.count)
            }
            return text
        }
        guard let title else { return false }
        return tidy(title) == tidy(wanted)
    }
}

/// Runs AppleScript and shell scripts in the background, so a slow script never
/// holds anything up.
enum ScriptRunner {
    /// AppleScript can control other apps; the first time a script talks to an
    /// app, macOS asks you to allow it.
    static func runAppleScript(_ source: String) {
        run("/usr/bin/osascript", arguments: ["-"], input: source)
    }

    /// JavaScript for Automation: the JavaScript version of AppleScript.
    static func runJavaScript(_ source: String) {
        run("/usr/bin/osascript", arguments: ["-l", "JavaScript", "-"], input: source)
    }

    /// Runs with zsh, with Homebrew's folders added so your usual commands are found.
    static func runShellScript(_ source: String) {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        run("/bin/zsh", arguments: ["-c", source], environment: environment)
    }

    private static func run(_ path: String, arguments: [String], input: String? = nil, environment: [String: String]? = nil) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let inputPipe = Pipe()
        if input != nil { process.standardInput = inputPipe }
        guard (try? process.run()) != nil else { return }
        if let input {
            inputPipe.fileHandleForWriting.write(Data(input.utf8))
            try? inputPipe.fileHandleForWriting.close()
        }
    }
}
