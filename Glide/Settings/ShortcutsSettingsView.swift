import SwiftUI
import UniformTypeIdentifiers

/// The Shortcuts section of the dashboard: a list of your shortcuts,
/// each with its keys and an on/off switch.
struct ShortcutsSettingsView: View {
    private var store = ShortcutStore.shared

    /// The row whose recorder is listening for keys, if any.
    @State private var recordingID: Shortcut.ID?
    @State private var editing: EditorRequest?

    var body: some View {
        Group {
            if store.shortcuts.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .sheet(item: $editing) { request in
            ActionEditor(action: request.action) { action in
                save(action, to: request.shortcutID)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Shortcuts Yet", systemImage: "command")
        } description: {
            Text("Press a few keys from anywhere on your Mac to open an app, run a Shortcut, open a website or type some text.")
        } actions: {
            addMenu
        }
    }

    private var list: some View {
        @Bindable var store = store
        let duplicates = duplicateCombos

        return Form {
            Section {
                ForEach($store.shortcuts) { $shortcut in
                    ShortcutRow(
                        shortcut: $shortcut,
                        isRecording: recordingBinding(for: shortcut.id),
                        isDuplicate: shortcut.keyCombo.map(duplicates.contains) ?? false,
                        edit: { edit(shortcut) },
                        delete: { store.delete(id: shortcut.id) }
                    )
                }
            } header: {
                HStack {
                    Text("Shortcuts")
                    Spacer()
                    addMenu
                }
            } footer: {
                HStack(spacing: 4) {
                    Text("Saved in shortcuts.json.")
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                    }
                    .buttonStyle(.link)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var addMenu: some View {
        Menu("Add Shortcut", systemImage: "plus") {
            ForEach(ShortcutAction.Kind.allCases) { kind in
                Button(kind.menuTitle, systemImage: kind.systemImage) { add(kind) }
            }
        }
        .fixedSize()
    }

    /// Key combos used by more than one shortcut, so we can warn about them.
    private var duplicateCombos: Set<KeyCombo> {
        var seen = Set<KeyCombo>()
        var duplicates = Set<KeyCombo>()
        for combo in store.shortcuts.compactMap(\.keyCombo) where !seen.insert(combo).inserted {
            duplicates.insert(combo)
        }
        return duplicates
    }

    private func recordingBinding(for id: Shortcut.ID) -> Binding<Bool> {
        Binding(
            get: { recordingID == id },
            set: { isRecording in
                if isRecording {
                    recordingID = id
                } else if recordingID == id {
                    recordingID = nil
                }
            }
        )
    }

    private func add(_ kind: ShortcutAction.Kind) {
        if kind == .openApp {
            if let path = chooseApp() { save(.openApp(path: path), to: nil) }
        } else {
            editing = EditorRequest(shortcutID: nil, action: kind.emptyAction)
        }
    }

    private func edit(_ shortcut: Shortcut) {
        if shortcut.action.kind == .openApp {
            if let path = chooseApp() { save(.openApp(path: path), to: shortcut.id) }
        } else {
            editing = EditorRequest(shortcutID: shortcut.id, action: shortcut.action)
        }
    }

    /// Updates an existing shortcut, or adds a new one and starts recording its keys straight away.
    private func save(_ action: ShortcutAction, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.action = action
            store.update(shortcut)
        } else {
            let shortcut = Shortcut(action: action)
            store.shortcuts.append(shortcut)
            recordingID = shortcut.id
        }
    }

    private func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        panel.message = "Choose the app this shortcut should open."
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

private struct EditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new shortcut.
    let shortcutID: Shortcut.ID?
    let action: ShortcutAction
}

struct ShortcutRow: View {
    @Binding var shortcut: Shortcut
    @Binding var isRecording: Bool
    let isDuplicate: Bool
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 10) {
                    ActionIcon(action: shortcut.action)
                    Text(shortcut.action.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(shortcut.isEnabled ? 1 : 0.45)

            if isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Another shortcut uses the same keys. Only the first one will run.")
            }

            ShortcutRecorder(keyCombo: $shortcut.keyCombo, isRecording: $isRecording)

            Toggle("Enabled", isOn: $shortcut.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            Menu {
                Button("Edit…", action: edit)
                Button("Delete", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Delete", role: .destructive, action: delete)
        }
    }
}

/// The app's own icon for "Open App", otherwise a coloured symbol.
struct ActionIcon: View {
    let action: ShortcutAction

    var body: some View {
        if case .openApp(let path) = action {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            SettingsIcon(systemImage: action.kind.systemImage, color: action.kind.color)
                .padding(2)
        }
    }
}

extension ShortcutAction.Kind {
    var menuTitle: String {
        switch self {
        case .openApp: "Open App…"
        case .runShortcut: "Run a Shortcut…"
        case .open: "Open Website or File…"
        case .typeText: "Type Text…"
        }
    }

    var systemImage: String {
        switch self {
        case .openApp: "app.fill"
        case .runShortcut: "bolt.fill"
        case .open: "link"
        case .typeText: "text.cursor"
        }
    }

    var color: Color {
        switch self {
        case .openApp: .blue
        case .runShortcut: .pink
        case .open: .teal
        case .typeText: .indigo
        }
    }

    var emptyAction: ShortcutAction {
        switch self {
        case .openApp: .openApp(path: "")
        case .runShortcut: .runShortcut(name: "")
        case .open: .open(target: "")
        case .typeText: .typeText(text: "")
        }
    }
}
