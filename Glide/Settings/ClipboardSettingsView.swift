import SwiftUI
import UniformTypeIdentifiers

/// The Clipboard page: clipboard history on or off, how much to keep, its
/// shortcut, and apps whose copies are never kept.
struct ClipboardSettingsView: View {
    @AppStorage(DefaultsKey.clipboardEnabled) private var isEnabled = true
    @AppStorage(DefaultsKey.clipboardLimit) private var limit = 100
    @State private var excludedApps = ClipboardHistory.shared.excludedApps
    @State private var isRecording = false
    private var history = ClipboardHistory.shared
    private var store = ShortcutStore.shared

    var body: some View {
        Form {
            PaneHeader(pane: .clipboard)

            Section {
                Toggle("Keep Clipboard History", isOn: $isEnabled)
                if isEnabled {
                    LabeledContent("Open With") {
                        ShortcutRecorder(keyCombo: openShortcut, isRecording: $isRecording)
                    }
                    Picker("Remember", selection: $limit) {
                        ForEach([25, 50, 100, 250, 500], id: \.self) { Text("\($0) items").tag($0) }
                    }
                }
            }

            if isEnabled {
                Section {
                    FlowRow {
                        // Apps that aren't installed are still excluded, just not shown.
                        ForEach(excludedApps.filter(AppInfo.isInstalled), id: \.self) { bundleID in
                            AppChip(bundleID: bundleID) { setExcluded(excludedApps.filter { $0 != bundleID }) }
                        }
                        addAppMenu
                    }
                } header: {
                    HStack {
                        SectionTitle("Never Keep Copies From")
                        InfoButton("Passwords are never kept anyway: password managers mark them as secret, and Shortie skips anything marked that way. History stays on your Mac and is never sent anywhere.")
                    }
                }

                Section {
                    LabeledContent(history.entries.count == 1 ? "1 item saved" : "\(history.entries.count) items saved") {
                        Button("Clear History", role: .destructive) { history.clearUnpinned() }
                            .disabled(history.entries.allSatisfy(\.isPinned))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.smooth(duration: 0.2), value: isEnabled)
    }

    /// The keys that open clipboard history, kept in your shortcuts like any other.
    private var openShortcut: Binding<KeyCombo?> {
        Binding(
            get: { shortcut?.keyCombo },
            set: { keys in
                if var existing = shortcut {
                    existing.keyCombo = keys
                    store.update(existing)
                } else {
                    store.shortcuts.append(Shortcut(keyCombo: keys, action: .system(action: .clipboardHistory)))
                }
            }
        )
    }

    private var shortcut: Shortcut? {
        store.shortcuts.first { $0.isKeyboardShortcut && $0.action == .system(action: .clipboardHistory) }
    }

    private var addAppMenu: some View {
        Menu("Add App", systemImage: "plus") {
            Section("Open Apps") {
                ForEach(openApps, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier ?? "") { add(app.bundleIdentifier) }
                }
            }
            Button("Other App…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                panel.prompt = "Add"
                if panel.runModal() == .OK, let url = panel.url {
                    add(Bundle(url: url)?.bundleIdentifier)
                }
            }
        }
        .fixedSize()
    }

    private var openApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !excludedApps.contains($0.bundleIdentifier ?? "") }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID, !excludedApps.contains(bundleID) else { return }
        setExcluded(excludedApps + [bundleID])
    }

    private func setExcluded(_ apps: [String]) {
        excludedApps = apps
        UserDefaults.standard.set(apps, forKey: DefaultsKey.clipboardExcludedApps)
    }
}
