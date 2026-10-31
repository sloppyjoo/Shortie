import SwiftUI
import UniformTypeIdentifiers

/// The Keyboard Shortcuts section of the dashboard.
struct ShortcutsSettingsView: View {
    var body: some View {
        ShortcutListView(
            pane: .shortcuts,
            kinds: [.openApp, .appTask, .runShortcut, .open, .typeText, .pasteText, .copyText, .text, .transformText, .pressKeys, .pressKeysInApp, .modifierKeys, .system, .setVolume, .setBrightness, .soundOutput, .inputSource, .playSound, .mouseClick, .movePointer, .showMessage, .notify, .speak, .menuItem, .clickButton, .clickMenuBarExtra, .appleScript, .javaScript, .browserJavaScript, .shellScript, .runWorkflow, .webRequest, .distributedNotification, .otherRule, .pauseShortie, .clickText, .soundInput, .clipboardItem, .pointerSetting, .keyboardBrightness, .customClick, .steps, .showMenu],
            emptyText: "No shortcuts yet."
        ) {
            EmptyView()
        } topSections: {
            ModifierTapsSection()
        }
    }
}

/// A page of keyboard shortcuts, each with its keys and an on/off switch.
/// Shows only shortcuts whose action is one of `kinds`, so each dashboard
/// section can have its own.
struct ShortcutListView<Extra: View, Top: View>: View {
    let pane: SettingsPane
    let kinds: [ShortcutAction.Kind]
    let emptyText: String
    /// The pixel icon above `emptyText`.
    var emptyIcon: [String] = PixelArt.key
    /// A detail worth knowing, behind an ⓘ next to the list's heading.
    var info: String?
    /// Extra buttons shown next to "Add".
    @ViewBuilder var extraActions: Extra
    /// Extra settings shown above the list.
    @ViewBuilder var topSections: Top

    private var store = ShortcutStore.shared
    @Environment(\.listSearch) private var search

    /// The row whose recorder is listening for keys, if any.
    @State private var recordingID: Shortcut.ID?
    @State private var editing: EditorRequest?

    init(
        pane: SettingsPane,
        kinds: [ShortcutAction.Kind],
        emptyText: String,
        emptyIcon: [String] = PixelArt.key,
        info: String? = nil,
        @ViewBuilder extraActions: () -> Extra = { EmptyView() },
        @ViewBuilder topSections: () -> Top = { EmptyView() }
    ) {
        self.pane = pane
        self.kinds = kinds
        self.emptyText = emptyText
        self.emptyIcon = emptyIcon
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
                EmptyState(emptyText, pixels: emptyIcon)
            }
            if !search.isEmpty, store.shortcuts.contains(where: belongsHere),
               !store.shortcuts.contains(where: { belongsHere($0) && $0.matches(search) }) {
                Text("No matches.").foregroundStyle(.secondary)
            }
            ForEach($store.shortcuts) { $shortcut in
                if belongsHere(shortcut), shortcut.matches(search) {
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
                    Menu("Mouse", systemImage: kind.systemImage) {
                        ForEach(MouseAction.groups, id: \.self) { group in
                            Section {
                                ForEach(group) { click in
                                    Button(click.title, systemImage: click.systemImage) { save(.mouseClick(click: click), to: nil) }
                                }
                            }
                        }
                    }
                } else if kind == .restoreLayout, !WindowLayoutStore.shared.layouts.isEmpty {
                    // Saved layouts go straight into the menu.
                    Section {
                        ForEach(WindowLayoutStore.shared.layouts) { layout in
                            Button(layout.name) { save(.restoreLayout(id: layout.id, name: layout.name), to: nil) }
                        }
                    }
                } else if kind == .text {
                    Menu("Selected Text", systemImage: kind.systemImage) {
                        ForEach(TextAction.groups, id: \.self) { group in
                            Section {
                                ForEach(group) { action in
                                    Button(action.title) { save(.text(action: action), to: nil) }
                                }
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
        case .appTask(_, let path) where !path.isEmpty:
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
        case .restoreLayout: "Restore Window Layout…"
        case .text: "Selected Text…"
        case .showMessage: "Show Message…"
        case .speak: "Speak Text…"
        case .setVolume: "Set Volume…"
        case .soundOutput: "Sound Output…"
        case .soundInput: "Sound Input…"
        case .clipboardItem: "Paste from Clipboard History…"
        case .pointerSetting: "Pointer Speed or Size…"
        case .keyboardBrightness: "Set Keyboard Brightness…"
        case .customClick: "Custom Click…"
        case .flow: "Control Flow…"
        case .clickText: "Find Text on Screen and Click…"
        case .appTask: "Show, Hide or Quit an App…"
        case .setBrightness: "Set Brightness…"
        case .windowFrame: "Custom Window Position…"
        case .moveToDisplay: "Move Window to Display…"
        case .movePointer: "Move Pointer…"
        case .copyText: "Copy Text…"
        case .pasteText: "Paste Text…"
        case .notify: "Show Notification…"
        case .webRequest: "Web Request…"
        case .inputSource: "Input Source…"
        case .playSound: "Play Sound…"
        case .javaScript: "Run JavaScript…"
        case .pressKeysInApp: "Press Keys in a Specific App…"
        case .modifierKeys: "Hold or Let Go of Modifier Keys…"
        case .moveToDesktop: "Move Window to Desktop…"
        case .focusWindow: "Bring a Window Forward by Title…"
        case .transformText: "Change Text with JavaScript…"
        case .browserJavaScript: "Run JavaScript in Browser…"
        case .runWorkflow: "Run Automator Workflow…"
        case .pauseShortie: "Pause Shortie for a While…"
        case .clickButton: "Click a Button by Name…"
        case .clickMenuBarExtra: "Click a Menu Bar Icon…"
        case .distributedNotification: "Post a System Notification…"
        case .otherRule: "Run or Switch Another Rule…"
        }
    }

    /// The dashboard section keyboard shortcuts of this kind live in.
    var sectionName: String {
        switch self {
        case .moveWindow, .appCommand, .windowFrame, .moveToDisplay, .moveToDesktop, .focusWindow: "Windows"
        case .restoreLayout: "Window Layouts"
        default: "Shortcuts"
        }
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
        case .restoreLayout: "rectangle.split.2x1"
        case .text: "character.textbox"
        case .showMessage: "text.bubble.fill"
        case .speak: "waveform"
        case .setVolume: "speaker.wave.2.fill"
        case .soundOutput: "hifispeaker.fill"
        case .soundInput: "mic.fill"
        case .clipboardItem: "list.clipboard"
        case .pointerSetting: "cursorarrow.motionlines"
        case .keyboardBrightness: "light.max"
        case .customClick: "cursorarrow.click.badge.clock"
        case .flow: "arrow.triangle.branch"
        case .clickText: "text.magnifyingglass"
        case .appTask: "app.badge.checkmark"
        case .setBrightness: "sun.max.fill"
        case .windowFrame: "rectangle.dashed"
        case .moveToDisplay: "display.2"
        case .movePointer: "cursorarrow.motionlines"
        case .copyText: "doc.on.clipboard"
        case .pasteText: "doc.on.clipboard.fill"
        case .notify: "bell.badge.fill"
        case .webRequest: "network"
        case .inputSource: "globe"
        case .playSound: "music.note"
        case .javaScript: "curlybraces"
        case .pressKeysInApp: "keyboard.badge.eye"
        case .modifierKeys: "command"
        case .moveToDesktop: "rectangle.2.swap"
        case .focusWindow: "macwindow.and.cursorarrow"
        case .transformText: "function"
        case .browserJavaScript: "safari"
        case .runWorkflow: "gearshape.2"
        case .pauseShortie: "pause.circle"
        case .clickButton: "button.programmable"
        case .clickMenuBarExtra: "menubar.arrow.up.rectangle"
        case .distributedNotification: "antenna.radiowaves.left.and.right"
        case .otherRule: "arrow.triangle.branch"
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
        case .restoreLayout: .blue
        case .text: .indigo
        case .showMessage: .yellow
        case .speak: .pink
        case .setVolume: .red
        case .soundOutput: .red
        case .soundInput: .red
        case .clipboardItem: .indigo
        case .pointerSetting: .orange
        case .keyboardBrightness: .yellow
        case .customClick: .orange
        case .flow: .green
        case .clickText: .orange
        case .appTask: .blue
        case .setBrightness: .yellow
        case .windowFrame: .blue
        case .moveToDisplay: .blue
        case .movePointer: .orange
        case .copyText: .indigo
        case .pasteText: .indigo
        case .notify: .red
        case .webRequest: .teal
        case .inputSource: .gray
        case .playSound: .pink
        case .javaScript: .yellow
        case .pressKeysInApp: .gray
        case .modifierKeys: .gray
        case .moveToDesktop: .blue
        case .focusWindow: .blue
        case .transformText: .indigo
        case .browserJavaScript: .teal
        case .runWorkflow: .gray
        case .pauseShortie: .gray
        case .clickButton: .orange
        case .clickMenuBarExtra: .orange
        case .distributedNotification: .gray
        case .otherRule: .green
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
        case .restoreLayout: .restoreLayout(id: nil, name: "")
        case .text: .text(action: .uppercase)
        case .showMessage: .showMessage(text: "")
        case .speak: .speak(text: "")
        case .setVolume: .setVolume(percent: 50)
        case .soundOutput: .soundOutput(uid: "", name: "")
        case .soundInput: .soundInput(uid: SoundInput.nextDeviceUID, name: "")
        case .clipboardItem: .clipboardItem(number: 1, remove: false)
        case .pointerSetting: .pointerSetting(setting: .mouseSpeed, value: 1, alternate: nil)
        case .keyboardBrightness: .keyboardBrightness(percent: 50)
        case .customClick: .customClick(click: CustomClick())
        case .flow: .flow(step: .ifCondition(condition: FlowCondition()))
        case .clickText: .clickText(text: "")
        case .appTask: .appTask(task: .toggle, path: "")
        case .setBrightness: .setBrightness(percent: 50)
        case .windowFrame: .windowFrame(frame: WindowFrame(x: 10, y: 10, width: 80, height: 80))
        case .moveToDisplay: .moveToDisplay(number: 1)
        case .movePointer: .movePointer(x: 100, y: 100)
        case .copyText: .copyText(text: "")
        case .pasteText: .pasteText(text: "")
        case .notify: .notify(text: "")
        case .webRequest: .webRequest(request: WebRequest())
        case .inputSource: .inputSource(id: InputSources.nextID, name: "")
        case .playSound: .playSound(name: "Glass")
        case .javaScript: .javaScript(source: "")
        case .pressKeysInApp: .pressKeysInApp(combo: nil, path: "")
        case .modifierKeys: .modifierKeys(modifiers: .command, down: true)
        case .moveToDesktop: .moveToDesktop(number: 1)
        case .focusWindow: .focusWindow(title: "")
        case .transformText: .transformText(script: "text.toUpperCase()", onClipboard: false)
        case .browserJavaScript: .browserJavaScript(source: "")
        case .runWorkflow: .runWorkflow(path: "")
        case .pauseShortie: .pauseShortie(seconds: 10)
        case .clickButton: .clickButton(name: "")
        case .clickMenuBarExtra: .clickMenuBarExtra(name: "")
        case .distributedNotification: .distributedNotification(name: "")
        case .otherRule: .otherRule(id: nil, name: "", mode: .run)
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
