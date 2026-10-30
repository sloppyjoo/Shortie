import SwiftUI
import UniformTypeIdentifiers

/// The Shortcuts section of the dashboard: shortcuts that open things or type text.
struct ShortcutsSettingsView: View {
    var body: some View {
        ShortcutListView(
            kinds: [.openApp, .runShortcut, .open, .typeText],
            emptyTitle: "No Shortcuts Yet",
            emptySymbol: "command",
            emptyDescription: "Press a few keys from anywhere on your Mac to open an app, run a Shortcut, open a website or type some text."
        )
    }
}

/// A list of shortcuts, each with its keys and an on/off switch. Shows only
/// shortcuts whose action is one of `kinds`, so each dashboard section can have its own.
struct ShortcutListView<Extra: View>: View {
    let kinds: [ShortcutAction.Kind]
    let emptyTitle: String
    let emptySymbol: String
    let emptyDescription: String
    var footnote: String?
    /// Extra buttons shown next to "Add Shortcut".
    @ViewBuilder var extraActions: Extra

    private var store = ShortcutStore.shared

    /// The row whose recorder is listening for keys, if any.
    @State private var recordingID: Shortcut.ID?
    @State private var editing: EditorRequest?

    init(
        kinds: [ShortcutAction.Kind],
        emptyTitle: String,
        emptySymbol: String,
        emptyDescription: String,
        footnote: String? = nil,
        @ViewBuilder extraActions: () -> Extra = { EmptyView() }
    ) {
        self.kinds = kinds
        self.emptyTitle = emptyTitle
        self.emptySymbol = emptySymbol
        self.emptyDescription = emptyDescription
        self.footnote = footnote
        self.extraActions = extraActions()
    }

    var body: some View {
        Group {
            if store.shortcuts.contains(where: belongsHere) {
                list
            } else {
                emptyState
            }
        }
        .sheet(item: $editing) { request in
            ActionEditor(action: request.action) { action in
                save(action, to: request.shortcutID)
            }
        }
    }

    private func belongsHere(_ shortcut: Shortcut) -> Bool {
        shortcut.isKeyboardShortcut && kinds.contains(shortcut.action.kind)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptySymbol)
        } description: {
            Text(emptyDescription)
        } actions: {
            HStack {
                extraActions
                addMenu
            }
        }
    }

    private var list: some View {
        @Bindable var store = store

        return Form {
            Section {
                ForEach($store.shortcuts) { $shortcut in
                    if belongsHere(shortcut) {
                        ShortcutRow(
                            shortcut: $shortcut,
                            isRecording: recordingBinding(for: shortcut.id),
                            conflicts: conflicts(with: shortcut),
                            edit: { edit(shortcut) },
                            delete: { store.delete(id: shortcut.id) },
                            disable: { store.setEnabled(false, id: $0) }
                        )
                    }
                }
            } header: {
                HStack {
                    Spacer()
                    extraActions
                    addMenu
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let footnote {
                        Text(footnote)
                    }
                    HStack(spacing: 4) {
                        Text("Saved in shortcuts.json.")
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var addMenu: some View {
        Menu("Add Shortcut", systemImage: "plus") {
            ForEach(kinds) { kind in
                if kind == .moveWindow {
                    // Window positions go straight into the menu, grouped.
                    ForEach(WindowPosition.groups, id: \.self) { group in
                        Section {
                            ForEach(group) { position in
                                Button(position.title) { save(.moveWindow(position: position), to: nil) }
                            }
                        }
                    }
                } else if kind == .appCommand {
                    ForEach(AppCommand.groups, id: \.self) { group in
                        Section {
                            ForEach(group) { command in
                                Button(command.title) { save(.appCommand(command: command), to: nil) }
                            }
                        }
                    }
                } else {
                    Button(kind.menuTitle, systemImage: kind.systemImage) { add(kind) }
                }
            }
        }
        .fixedSize()
    }

    /// Other switched-on shortcuts (in any section) that use the same keys.
    private func conflicts(with shortcut: Shortcut) -> [Shortcut] {
        ShortcutStore.shared.conflicts(with: shortcut)
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
        AppChooser.choose()
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
    /// Other switched-on shortcuts using the same keys.
    let conflicts: [Shortcut]
    let edit: () -> Void
    let delete: () -> Void
    /// Switches off another shortcut, by ID.
    let disable: (Shortcut.ID) -> Void

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

            if !conflicts.isEmpty {
                ConflictBadge(conflicts: conflicts, disable: disable)
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

/// The orange warning shown when another shortcut uses the same keys.
/// Hovering shows which one straight away, with a button to switch it off.
///
/// macOS's standard tooltips wait about a second before appearing, so this
/// uses a popover that opens the moment the pointer arrives instead.
struct ConflictBadge: View {
    let conflicts: [Shortcut]
    let disable: (Shortcut.ID) -> Void

    @State private var isHoveringBadge = false
    @State private var isHoveringDetails = false
    @State private var isShowingDetails = false

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .padding(4)
            .contentShape(.rect)
            .onHover { isHoveringBadge = $0; updateDetails() }
            .onTapGesture { isShowingDetails = true }
            .accessibilityLabel(accessibilityText)
            .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
                details
                    .onHover { isHoveringDetails = $0; updateDetails() }
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Same keys as")
                .font(.headline)

            ForEach(conflicts) { other in
                HStack(spacing: 10) {
                    ActionIcon(action: other.action)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(other.action.title)
                            .lineLimit(1)
                        Text("In \(other.sectionName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button("Turn Off") { disable(other.id) }
                }
            }

            Text("Only one shortcut can use the same keys. Until you fix it, the one higher in the list runs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
    }

    /// Opens straight away; closes shortly after the pointer leaves both the
    /// triangle and the popover. The short wait gives you time to move across.
    private func updateDetails() {
        if isHoveringBadge || isHoveringDetails {
            isShowingDetails = true
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !isHoveringBadge && !isHoveringDetails {
                isShowingDetails = false
            }
        }
    }

    private var accessibilityText: String {
        let names = conflicts.map { "“\($0.action.title)” in \($0.sectionName)" }
        return "Same keys as " + names.joined(separator: ", ")
    }
}

/// The app's own icon for "Open App", a little window diagram for window
/// positions, otherwise a coloured symbol.
struct ActionIcon: View {
    let action: ShortcutAction

    var body: some View {
        switch action {
        case .openApp(let path):
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 24, height: 24)
        case .moveWindow(let position):
            WindowPositionIcon(position: position)
                .frame(width: 24, height: 24)
        case .appCommand(let command):
            SettingsIcon(systemImage: command.systemImage, color: action.kind.color)
                .padding(2)
        default:
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
        case .moveWindow: "Move Window…"
        case .appCommand: "Window or App Command…"
        }
    }

    /// The dashboard section keyboard shortcuts of this kind live in.
    var sectionName: String {
        self == .moveWindow || self == .appCommand ? "Windows" : "Shortcuts"
    }

    var systemImage: String {
        switch self {
        case .openApp: "app.fill"
        case .runShortcut: "bolt.fill"
        case .open: "link"
        case .typeText: "text.cursor"
        case .moveWindow: "macwindow"
        case .appCommand: "macwindow.badge.plus"
        }
    }

    var color: Color {
        switch self {
        case .openApp: .blue
        case .runShortcut: .pink
        case .open: .teal
        case .typeText: .indigo
        case .moveWindow: .blue
        case .appCommand: .gray
        }
    }

    var emptyAction: ShortcutAction {
        switch self {
        case .openApp: .openApp(path: "")
        case .runShortcut: .runShortcut(name: "")
        case .open: .open(target: "")
        case .typeText: .typeText(text: "")
        case .moveWindow: .moveWindow(position: .maximize)
        case .appCommand: .appCommand(command: .closeWindow)
        }
    }
}

extension Shortcut {
    /// The dashboard section this shortcut lives in.
    var sectionName: String {
        trafficLightClick != nil ? "Traffic Lights" : action.kind.sectionName
    }
}
