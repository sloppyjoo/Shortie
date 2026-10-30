import SwiftUI
import UniformTypeIdentifiers

/// The Keyboard Shortcuts section of the dashboard.
struct ShortcutsSettingsView: View {
    var body: some View {
        ShortcutListView(
            pane: .shortcuts,
            kinds: [.openApp, .runShortcut, .open, .typeText, .pressKeys, .system, .mouseClick, .menuItem, .appleScript, .shellScript, .steps, .showMenu],
            emptyText: "No shortcuts yet."
        )
    }
}

/// A page of keyboard shortcuts, each with its keys and an on/off switch.
/// Shows only shortcuts whose action is one of `kinds`, so each dashboard
/// section can have its own.
struct ShortcutListView<Extra: View, Top: View>: View {
    let pane: SettingsPane
    let kinds: [ShortcutAction.Kind]
    let emptyText: String
    /// A detail worth knowing, behind an ⓘ next to the list's heading.
    var info: String?
    /// Extra buttons shown next to "Add".
    @ViewBuilder var extraActions: Extra
    /// Extra settings shown above the list.
    @ViewBuilder var topSections: Top

    private var store = ShortcutStore.shared

    /// The row whose recorder is listening for keys, if any.
    @State private var recordingID: Shortcut.ID?
    @State private var editing: EditorRequest?

    init(
        pane: SettingsPane,
        kinds: [ShortcutAction.Kind],
        emptyText: String,
        info: String? = nil,
        @ViewBuilder extraActions: () -> Extra = { EmptyView() },
        @ViewBuilder topSections: () -> Top = { EmptyView() }
    ) {
        self.pane = pane
        self.kinds = kinds
        self.emptyText = emptyText
        self.info = info
        self.extraActions = extraActions()
        self.topSections = topSections()
    }

    var body: some View {
        Form {
            PaneHeader(pane: pane)
            topSections
            list
        }
        .formStyle(.grouped)
        // Rows glide in and out as you add and remove them.
        .animation(.smooth(duration: 0.25), value: store.shortcuts.map(\.id))
        .sheet(item: $editing) { request in
            ActionEditor(keyCombo: request.keyCombo, action: request.action, apps: request.apps) { keys, action, apps in
                save(action, keys: keys, apps: apps, to: request.shortcutID)
            }
        }
    }

    private func belongsHere(_ shortcut: Shortcut) -> Bool {
        shortcut.isKeyboardShortcut && kinds.contains(shortcut.action.kind)
    }

    private var list: some View {
        @Bindable var store = store

        return Section {
            if !store.shortcuts.contains(where: belongsHere) {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            }
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
                SectionTitle("Shortcuts")
                if let info { InfoButton(info) }
                Spacer()
                extraActions
                addMenu
            }
        }
    }

    private var addMenu: some View {
        Menu("Add", systemImage: "plus") {
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
                } else if kind == .system {
                    Menu("System & Media", systemImage: kind.systemImage) {
                        ForEach(SystemAction.groups, id: \.self) { group in
                            Section {
                                ForEach(group) { action in
                                    Button(action.title, systemImage: action.systemImage) { save(.system(action: action), to: nil) }
                                }
                            }
                        }
                    }
                } else if kind == .mouseClick {
                    Section {
                        ForEach(MouseAction.allCases) { click in
                            Button(click.title, systemImage: click.systemImage) { save(.mouseClick(click: click), to: nil) }
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
        editing = EditorRequest(shortcutID: nil, action: kind.emptyAction)
    }

    private func edit(_ shortcut: Shortcut) {
        editing = EditorRequest(shortcutID: shortcut.id, keyCombo: shortcut.keyCombo, action: shortcut.action, apps: shortcut.apps)
    }

    /// Updates an existing shortcut, or adds a new one. A new one with no keys
    /// yet starts recording them straight away, right in its row.
    private func save(_ action: ShortcutAction, keys: KeyCombo? = nil, apps: AppScope? = nil, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.keyCombo = keys
            shortcut.action = action
            shortcut.apps = apps
            store.update(shortcut)
        } else {
            var shortcut = Shortcut(keyCombo: keys, action: action)
            shortcut.apps = apps
            store.shortcuts.append(shortcut)
            if keys == nil { recordingID = shortcut.id }
        }
    }
}

private struct EditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new shortcut.
    let shortcutID: Shortcut.ID?
    var keyCombo: KeyCombo?
    let action: ShortcutAction
    var apps: AppScope?
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

    /// The ⋯ menu only shows while you're pointing at the row, to keep lists calm.
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 10) {
                    ActionIcon(action: shortcut.action)
                    Text(shortcut.action.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let apps = shortcut.apps {
                        AppScopeBadge(scope: apps)
                    }
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
            .opacity(isHovering ? 1 : 0)
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Delete", role: .destructive, action: delete)
        }
    }
}

/// The orange warning shown when another shortcut uses the same keys.
/// Hovering shows which one straight away, with a button to switch it off.
struct ConflictBadge: View {
    let conflicts: [Shortcut]
    let disable: (Shortcut.ID) -> Void

    var body: some View {
        HoverBadge(systemImage: "exclamationmark.triangle.fill", color: .orange, accessibilityText: accessibilityText) {
            details
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
        case .mouseClick(let click):
            SettingsIcon(systemImage: click.systemImage, color: action.kind.color)
                .padding(2)
        case .system(let systemAction):
            SettingsIcon(systemImage: systemAction.systemImage, color: action.kind.color)
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
        case .mouseClick: "Mouse Click…"
        case .system: "System & Media…"
        case .pressKeys: "Press Keys…"
        case .menuItem: "Choose Menu Item…"
        case .appleScript: "Run AppleScript…"
        case .shellScript: "Run Shell Script…"
        case .wait: "Wait…"
        case .steps: "Several Actions…"
        case .showMenu: "Show Custom Menu…"
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
        case .mouseClick: "cursorarrow.click"
        case .system: "switch.2"
        case .pressKeys: "keyboard"
        case .menuItem: "filemenu.and.selection"
        case .appleScript: "applescript"
        case .shellScript: "terminal"
        case .wait: "hourglass"
        case .steps: "list.number"
        case .showMenu: "list.bullet.rectangle"
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
        case .mouseClick: .orange
        case .system: .purple
        case .pressKeys: .gray
        case .menuItem: .blue
        case .appleScript: .gray
        case .shellScript: .black
        case .wait: .gray
        case .steps: .green
        case .showMenu: .mint
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
        case .mouseClick: .mouseClick(click: .rightClick)
        case .system: .system(action: .controlCentre)
        case .pressKeys: .pressKeys(combo: nil)
        case .menuItem: .menuItem(path: "")
        case .appleScript: .appleScript(source: "")
        case .shellScript: .shellScript(source: "")
        case .wait: .wait(seconds: 0.5)
        case .steps: .steps(actions: [])
        case .showMenu: .showMenu(id: nil, name: "")
        }
    }
}

extension Shortcut {
    /// The dashboard section this shortcut lives in.
    var sectionName: String {
        if trafficLightClick != nil { return "Traffic Lights" }
        if gesture != nil { return "Gestures" }
        if mouseButtonClick != nil { return "Mouse" }
        if abbreviation != nil { return "Text Shortcuts" }
        if event != nil { return "Automations" }
        return action.kind.sectionName
    }
}

/// A small icon that shows a popover the moment you hover over it.
///
/// macOS's standard tooltips wait about a second before appearing, so this
/// uses a popover that opens as soon as the pointer arrives, and stays open
/// while you move into it to click something.
struct HoverBadge<Details: View>: View {
    let systemImage: String
    let color: Color
    let accessibilityText: String
    @ViewBuilder let details: Details

    @State private var isHoveringBadge = false
    @State private var isHoveringDetails = false
    @State private var isShowingDetails = false

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(color)
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

    /// Opens straight away; closes shortly after the pointer leaves both the
    /// icon and the popover. The short wait gives you time to move across.
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
}

/// A small ⓘ that shows a short explanation the moment you hover over it.
/// Details live here instead of in paragraphs on the page.
struct InfoButton: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HoverBadge(systemImage: "info.circle", color: .secondary, accessibilityText: text) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(width: 290, alignment: .leading)
        }
    }
}
