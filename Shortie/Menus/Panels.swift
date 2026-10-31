import AppKit
import SwiftUI
import WebKit

// MARK: - Searchable list

/// One choice in a searchable list.
struct ListChoice: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String?
    var icon: NSImage?
    let choose: () -> Void
}

/// A Spotlight-like panel: type to filter, ↑↓ to move, ↩ to choose, Esc to close.
/// Used for searchable lists and the launcher.
final class ChoicePanel: NSObject, NSWindowDelegate {
    static let shared = ChoicePanel()

    private var panel: GlassPanel?
    private(set) var title = ""

    var isShowing: Bool { panel?.isVisible == true }

    func show(title: String, prompt: String, choices: [ListChoice]) {
        close()
        self.title = title
        let panel = GlassPanel(size: NSSize(width: 560, height: 420), content: ChoiceListView(
            title: title, prompt: prompt, choices: choices,
            choose: { [weak self] choice in
                self?.close()
                // Let the panel go first, so the choice reaches the app you were using.
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    choice.choose()
                }
            },
            dismiss: { [weak self] in self?.close() }
        ))
        panel.delegate = self
        panel.showCentred()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private struct ChoiceListView: View {
    let title: String
    let prompt: String
    let choices: [ListChoice]
    let choose: (ListChoice) -> Void
    let dismiss: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var visible: [ListChoice] {
        let words = query.split(separator: " ")
        guard !words.isEmpty else { return choices }
        return choices.filter { choice in
            words.allSatisfy { choice.title.localizedCaseInsensitiveContains($0) || (choice.subtitle?.localizedCaseInsensitiveContains($0) ?? false) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(prompt, text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focused)
                    .onSubmit { if visible.indices.contains(selection) { choose(visible[selection]) } }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(visible.count - 1, 0)); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            Divider()
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, choice in
                            HStack(spacing: 10) {
                                if let icon = choice.icon {
                                    Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(choice.title).lineLimit(1)
                                    if let subtitle = choice.subtitle {
                                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index == selection ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
                            .contentShape(.rect)
                            .onTapGesture { choose(choice) }
                            .id(index)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) { scroller.scrollTo(selection) }
            }
        }
        .background(GlassBackground())
        .onChange(of: query) { selection = 0 }
        .onAppear { focused = true }
    }
}

/// How a searchable list uses what you pick.
nonisolated enum ListOutput: String, Codable, CaseIterable, Identifiable {
    case paste, type, copy, open, variable

    var id: Self { self }

    var title: String {
        switch self {
        case .paste: "Paste It"
        case .type: "Type It"
        case .copy: "Copy It"
        case .open: "Open It as a Link or File"
        case .variable: "Put It in the Variable “choice”"
        }
    }
}

/// A searchable list from lines of text, or from what a shell script prints.
enum SearchableList {
    static func show(source: String, fromScript: Bool, output: ListOutput) {
        Task {
            let text = fromScript ? await scriptOutput(source) : source
            let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !lines.isEmpty else {
                NSSound.beep()
                return
            }
            let choices = lines.map { line in
                ListChoice(title: line) { use(line, output) }
            }
            ChoicePanel.shared.show(title: "List", prompt: "Search", choices: choices)
        }
    }

    private static func use(_ line: String, _ output: ListOutput) {
        switch output {
        case .paste: ExtraActionRunner.paste(line)
        case .type: Task { await TextTyper.type(line) }
        case .copy: ExtraActionRunner.copy(line)
        case .open: ShortcutAction.url(for: line).map { NSWorkspace.shared.open($0) }
        case .variable: Variables.values["choice"] = line
        }
    }

    private static func scriptOutput(_ source: String) async -> String {
        await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", source]
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return "" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }.value
    }
}

// MARK: - Launcher

/// Your apps and your Shortie rules, in one searchable list.
enum Launcher {
    static func toggle() {
        if ChoicePanel.shared.isShowing, ChoicePanel.shared.title == "Launcher" {
            ChoicePanel.shared.close()
        } else {
            show()
        }
    }

    static func show() {
        var choices: [ListChoice] = apps().map { url in
            ListChoice(
                title: url.deletingPathExtension().lastPathComponent,
                subtitle: "App",
                icon: NSWorkspace.shared.icon(forFile: url.path)
            ) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        }
        for rule in ShortcutStore.shared.shortcuts where rule.isEnabled {
            choices.append(ListChoice(title: rule.action.title, subtitle: "Shortie · \(rule.sectionName)") {
                ActionRunner.run(rule.action)
            })
        }
        ChoicePanel.shared.show(title: "Launcher", prompt: "Open an app or run an action", choices: choices)
    }

    static func hide() {
        if ChoicePanel.shared.title == "Launcher" { ChoicePanel.shared.close() }
    }

    private static func apps() -> [URL] {
        let folders = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                       NSHomeDirectory() + "/Applications"]
        var seen = Set<String>()
        return folders.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
        }
        .filter { $0.pathExtension == "app" && seen.insert($0.lastPathComponent).inserted }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

// MARK: - Floating web view

/// A small floating window showing a web page or your own HTML.
final class WebPanel: NSObject, NSWindowDelegate {
    static let shared = WebPanel()

    private var window: NSPanel?

    /// `content` is a web address, or HTML if it starts with "<".
    func show(_ content: String) {
        let window = self.window ?? makeWindow()
        self.window = window
        guard let webView = window.contentView as? WKWebView else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") {
            webView.loadHTMLString(trimmed, baseURL: nil)
        } else if let url = ShortcutAction.url(for: trimmed) {
            webView.load(URLRequest(url: url))
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSPanel {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.title = "Shortie"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = WKWebView(frame: window.contentLayoutRect, configuration: WKWebViewConfiguration())
        window.center()
        window.delegate = self
        return window
    }
}
