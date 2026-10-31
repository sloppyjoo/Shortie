import SwiftUI
import UniformTypeIdentifiers

/// The editor for a keyboard shortcut.
struct ActionEditor: View {
    @State var keyCombo: KeyCombo?
    @State var action: ShortcutAction
    @State var apps: AppScope?
    let onSave: (KeyCombo?, ShortcutAction, AppScope?) -> Void

    @State private var isRecording = false

    var body: some View {
        TriggerEditor(title: "Keyboard Shortcut", action: $action, apps: $apps, save: { onSave(keyCombo, action, apps) }) {
            HStack {
                Text("I press")
                ShortcutRecorder(keyCombo: $keyCombo, isRecording: $isRecording)
            }
        }
    }
}

/// The controls for one action's details: which app, which website, what text…
/// Shared by every editor that sets up an action.
struct ActionFields: View {
    @Binding var action: ShortcutAction

    /// Names from the Shortcuts app; `nil` while still loading.
    @State private var availableShortcuts: [String]?
    @State private var isRecordingKeys = false

    /// The length, for "Wait" steps.
    private var seconds: Binding<Double> {
        Binding(
            get: { if case .wait(let seconds) = action { seconds } else { 0.5 } },
            set: { action = .wait(seconds: ($0 * 10).rounded() / 10) }
        )
    }

    /// The keys, for "Press Keys" actions.
    private var keys: Binding<KeyCombo?> {
        Binding(
            get: { if case .pressKeys(let combo) = action { combo } else { nil } },
            set: { action = .pressKeys(combo: $0) }
        )
    }

    /// Edits the one piece of text the action carries.
    private var payload: Binding<String> {
        Binding(get: { action.payload }, set: { action = action.with(payload: $0) })
    }

    var body: some View {
        switch action.kind {
        case .openApp:
            HStack {
                if action.isComplete {
                    ActionIcon(action: action)
                    Text(action.title)
                } else {
                    Text("No app chosen")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose App…") {
                    if let path = AppChooser.choose() { payload.wrappedValue = path }
                }
            }
        case .runShortcut:
            shortcutPicker
        case .open:
            HStack {
                TextField("Website or file", text: payload, prompt: Text("apple.com or ~/Documents/notes.txt"))
                    .textFieldStyle(.roundedBorder)
                Button("Choose File…", action: chooseFile)
            }
        case .typeText:
            TextEditor(text: payload)
                .font(.body)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        case .moveWindow:
            Picker("Move the window to", selection: payload) {
                ForEach(WindowPosition.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        case .system:
            Picker("Action", selection: payload) {
                ForEach(SystemAction.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        case .pressKeys:
            HStack {
                Menu("Common Shortcuts") {
                    ForEach(KeyPreset.groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.presets) { preset in
                                Button("\(preset.title)   \(preset.combo.displayString)") {
                                    action = .pressKeys(combo: preset.combo)
                                }
                            }
                        }
                    }
                }
                .fixedSize()
                Text("or")
                    .foregroundStyle(.secondary)
                ShortcutRecorder(keyCombo: keys, isRecording: $isRecordingKeys, allowsPlainKeys: true)
            }
        case .menuItem:
            HStack {
                TextField("Menu item", text: payload, prompt: Text("File › Export as PDF…"))
                    .textFieldStyle(.roundedBorder)
                InfoButton("Chooses this from the menus of the app in front. Separate menus with › or >. Capitals and a trailing … don't matter.")
            }
        case .appleScript, .shellScript, .javaScript:
            TextEditor(text: payload)
                .font(.body.monospaced())
                .frame(height: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        case .wait:
            Stepper(value: seconds, in: 0.1...10, step: 0.1) {
                Text("\(seconds.wrappedValue.formatted(.number.precision(.fractionLength(1)))) seconds")
                    .monospacedDigit()
            }
            .fixedSize()
        case .steps:
            StepsEditor(action: $action)
        case .showMenu:
            let menus = CustomMenuStore.shared.menus
            if menus.isEmpty {
                Text("Make a menu in Custom Menus first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Menu", selection: Binding(
                    get: { if case .showMenu(let id, _) = action { id } else { nil } },
                    set: { newID in action = .showMenu(id: newID, name: CustomMenuStore.shared.menu(id: newID)?.name ?? "") }
                )) {
                    Text("Choose a Menu").tag(UUID?.none)
                    ForEach(menus) { menu in
                        Label(menu.name, systemImage: menu.symbol).tag(UUID?.some(menu.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        case .text:
            Picker("Text action", selection: payload) {
                ForEach(TextAction.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        case .showMessage:
            TextField("Message", text: payload, prompt: Text("Time for a break"))
                .textFieldStyle(.roundedBorder)
        case .speak:
            TextField("Text to say", text: payload, prompt: Text("Hello!"))
                .textFieldStyle(.roundedBorder)
        case .setVolume:
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(action.payload) ?? 50 },
                    set: { payload.wrappedValue = String(Int($0)) }
                ), in: 0...100, step: 5)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                Text("\(action.payload)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        case .soundOutput:
            SoundOutputPicker(action: $action)
        case .remapKey:
            ExtraActionFields(action: $action)
        case .openSettingsPane:
            ExtraActionFields(action: $action)
        case .callService:
            ExtraActionFields(action: $action)
        case .soundInput:
            ExtraActionFields(action: $action)
        case .clipboardItem:
            ExtraActionFields(action: $action)
        case .pointerSetting:
            ExtraActionFields(action: $action)
        case .keyboardBrightness:
            ExtraActionFields(action: $action)
        case .customClick:
            ExtraActionFields(action: $action)
        case .flow:
            FlowFields(action: $action)
        case .clickText:
            ExtraActionFields(action: $action)
        case .appTask, .setBrightness, .windowFrame, .moveToDisplay, .movePointer,
             .copyText, .pasteText, .notify, .webRequest, .inputSource, .playSound,
             .pressKeysInApp, .modifierKeys, .moveToDesktop, .focusWindow, .transformText, .browserJavaScript, .runWorkflow, .pauseShortie, .clickButton, .clickMenuBarExtra, .distributedNotification, .otherRule:
            ExtraActionFields(action: $action)
        case .restoreLayout:
            let layouts = WindowLayoutStore.shared.layouts
            if layouts.isEmpty {
                Text("Save a layout in Window Layouts first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Layout", selection: Binding(
                    get: { if case .restoreLayout(let id, _) = action { id } else { nil } },
                    set: { newID in action = .restoreLayout(id: newID, name: WindowLayoutStore.shared.layout(id: newID)?.name ?? "") }
                )) {
                    Text("Choose a Layout").tag(UUID?.none)
                    ForEach(layouts) { layout in
                        Text(layout.name).tag(UUID?.some(layout.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        case .mouseClick:
            Picker("Click", selection: payload) {
                ForEach(MouseAction.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        case .appCommand:
            Picker("Command", selection: payload) {
                ForEach(AppCommand.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    @ViewBuilder
    private var shortcutPicker: some View {
        Group {
            if let availableShortcuts, !availableShortcuts.isEmpty {
                HStack {
                    Picker("Shortcut", selection: payload) {
                        ForEach(availableShortcuts, id: \.self) { Text($0).tag($0) }
                    }
                    InfoButton("To turn on Do Not Disturb or another Focus, make a shortcut with the Set Focus action in the Shortcuts app, then choose it here.")
                }
            } else if availableShortcuts != nil {
                Text("No shortcuts found. Make one in the Shortcuts app first.")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Loading your shortcuts…")
                    .controlSize(.small)
            }
        }
        .task {
            let names = await ShortcutsApp.list()
            availableShortcuts = names
            if action.payload.isEmpty, let first = names.first {
                payload.wrappedValue = first
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            // Show paths in your home folder as ~/… so they're shorter to read.
            payload.wrappedValue = (url.path as NSString).abbreviatingWithTildeInPath
        }
    }
}

/// Picks a speaker or headphones, or "whichever comes next".
private struct SoundOutputPicker: View {
    @Binding var action: ShortcutAction

    @State private var devices: [SoundOutput.Device] = []

    var body: some View {
        Picker("Device", selection: Binding(
            get: { action.payload },
            set: { uid in
                let name = devices.first { $0.uid == uid }?.name ?? ""
                action = .soundOutput(uid: uid, name: name)
            }
        )) {
            Text("Choose a Device").tag("")
            Text("Next Device").tag(SoundOutput.nextDeviceUID)
            Divider()
            ForEach(devices) { Text($0.name).tag($0.uid) }
            // A device you chose before that isn't connected now.
            if case .soundOutput(let uid, let name) = action, !uid.isEmpty, uid != SoundOutput.nextDeviceUID,
               !devices.contains(where: { $0.uid == uid }) {
                Text("\(name) (Not Connected)").tag(uid)
            }
        }
        .labelsHidden()
        .fixedSize()
        .onAppear { devices = SoundOutput.devices() }
    }
}

enum AppChooser {
    /// Asks you to pick an app; returns its path.
    static func choose() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        panel.message = "Choose the app to open."
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

extension ShortcutAction.Kind {
    /// Actions whose only detail is one menu (which window position, which
    /// command…), so it can sit right beside the action type.
    var isSingleChoice: Bool {
        switch self {
        case .moveWindow, .appCommand, .mouseClick, .system, .showMenu, .restoreLayout, .text, .soundOutput,
             .moveToDisplay, .inputSource, .playSound, .moveToDesktop: true
        default: false
        }
    }

    var editorTitle: String {
        switch self {
        case .openApp: "Open App"
        case .runShortcut: "Run a Shortcut"
        case .open: "Open Website or File"
        case .typeText: "Type Text"
        case .moveWindow: "Move Window"
        case .appCommand: "Window or App Command"
        case .mouseClick: "Mouse Click"
        case .system: "System & Media"
        case .pressKeys: "Press Keys"
        case .menuItem: "Choose Menu Item"
        case .appleScript: "Run AppleScript"
        case .shellScript: "Run Shell Script"
        case .wait: "Wait"
        case .steps: "Several Actions"
        case .showMenu: "Show Custom Menu"
        case .restoreLayout: "Restore Window Layout"
        case .text: "Selected Text"
        case .showMessage: "Show Message"
        case .speak: "Speak Text"
        case .setVolume: "Set Volume"
        case .soundOutput: "Sound Output"
        case .remapKey: "Remap a Key"
        case .openSettingsPane: "Open Shortie Settings At"
        case .callService: "Run a Service"
        case .soundInput: "Sound Input"
        case .clipboardItem: "Paste from Clipboard History"
        case .pointerSetting: "Pointer Speed or Size"
        case .keyboardBrightness: "Set Keyboard Brightness"
        case .customClick: "Custom Click"
        case .flow: "Control Flow"
        case .clickText: "Find Text on Screen and Click"
        case .appTask: "Show, Hide or Quit an App"
        case .setBrightness: "Set Brightness"
        case .windowFrame: "Custom Window Position"
        case .moveToDisplay: "Move Window to Display"
        case .movePointer: "Move Pointer"
        case .copyText: "Copy Text"
        case .pasteText: "Paste Text"
        case .notify: "Show Notification"
        case .webRequest: "Web Request"
        case .inputSource: "Input Source"
        case .playSound: "Play Sound"
        case .javaScript: "Run JavaScript"
        case .pressKeysInApp: "Press Keys in a Specific App"
        case .modifierKeys: "Hold or Let Go of Modifier Keys"
        case .moveToDesktop: "Move Window to Desktop"
        case .focusWindow: "Bring a Window Forward by Title"
        case .transformText: "Change Text with JavaScript"
        case .browserJavaScript: "Run JavaScript in Browser"
        case .runWorkflow: "Run Automator Workflow"
        case .pauseShortie: "Pause Shortie for a While"
        case .clickButton: "Click a Button by Name"
        case .clickMenuBarExtra: "Click a Menu Bar Icon"
        case .distributedNotification: "Post a System Notification"
        case .otherRule: "Run or Switch Another Rule"
        }
    }
}

/// The one editor layout every trigger uses, in three plain steps:
/// **When** (the trigger), **Do** (the action), **Works In** (which apps).
struct TriggerEditor<When: View>: View {
    let title: String
    @Binding var action: ShortcutAction
    /// `nil` hides "Works In", for triggers that aren't about the app in front.
    var apps: Binding<AppScope?>?
    var canSave = true
    let save: () -> Void
    @ViewBuilder let when: When

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.bottom, 2)

            EditorCard("When") { when }

            EditorCard("Do") {
                if action.kind.isSingleChoice {
                    HStack {
                        ActionKindPicker(action: $action)
                        ActionFields(action: $action)
                        Spacer(minLength: 0)
                    }
                } else {
                    ActionKindPicker(action: $action)
                    ActionFields(action: $action)
                }
            }

            if let apps {
                EditorCard("Works In") {
                    AppScopePicker(scope: apps)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave || !action.isComplete || apps?.wrappedValue?.isValid == false)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 520)
        .animation(.smooth(duration: 0.2), value: action.kind)
    }
}

/// A softly tinted, rounded group with a small heading, like a section of
/// System Settings.
struct EditorCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}

/// The list of steps in a "Several Actions" action: each one an ordinary
/// action, run in order, with optional waits in between.
struct StepsEditor: View {
    @Binding var action: ShortcutAction

    private var steps: [ShortcutAction] {
        if case .steps(let actions) = action { actions } else { [] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let depths = Self.depths(of: steps)
            ForEach(Array(steps.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(index + 1)")
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        ActionKindPicker(action: step(index), forSteps: true)
                        Spacer()
                        Group {
                            Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(index == 0)
                            Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(index == steps.count - 1)
                            Button { remove(index) } label: { Image(systemName: "minus.circle") }
                        }
                        .buttonStyle(.borderless)
                    }
                    // A step's own details (wrapped so a list of steps can hold more steps' fields).
                    AnyView(ActionFields(action: step(index)))
                        .padding(.leading, 26)
                }
                .padding(10)
                .background(.background.opacity(0.6), in: .rect(cornerRadius: 9, style: .continuous))
                // Steps inside a repeat or an if sit further in.
                .padding(.leading, CGFloat(depths.indices.contains(index) ? depths[index] : 0) * 18)
            }

            Menu("Add Step", systemImage: "plus") {
                Menu("Control Flow", systemImage: "arrow.triangle.branch") {
                    ForEach(FlowStep.Kind.groups, id: \.self) { group in
                        Section {
                            ForEach(group) { kind in
                                Button(kind.title) { set(steps + [.flow(step: kind.template)]) }
                            }
                        }
                    }
                }
                Divider()
                ForEach(ActionKindPicker.stepKinds.filter { $0 != .flow }) { kind in
                    Button(kind.editorTitle, systemImage: kind.systemImage) {
                        set(steps + [kind.emptyAction])
                    }
                }
            }
            .fixedSize()
        }
        .animation(.smooth(duration: 0.2), value: steps)
    }

    /// How far in each step sits: one level for each repeat or if it's inside.
    static func depths(of steps: [ShortcutAction]) -> [Int] {
        var depth = 0
        return steps.map { step in
            guard case .flow(let flow) = step else { return depth }
            switch flow.kind {
            case .repeatStart, .ifCondition:
                depth += 1
                return depth - 1
            case .repeatEnd, .endIf:
                depth = max(depth - 1, 0)
                return depth
            case .elseBranch:
                return max(depth - 1, 0)
            default:
                return depth
            }
        }
    }

    private func step(_ index: Int) -> Binding<ShortcutAction> {
        Binding(
            get: { steps.indices.contains(index) ? steps[index] : .wait(seconds: 0.5) },
            set: { newValue in
                var updated = steps
                guard updated.indices.contains(index) else { return }
                updated[index] = newValue
                set(updated)
            }
        )
    }

    private func move(_ index: Int, by offset: Int) {
        var updated = steps
        let target = index + offset
        guard updated.indices.contains(target) else { return }
        updated.swapAt(index, target)
        set(updated)
    }

    private func remove(_ index: Int) {
        var updated = steps
        updated.remove(at: index)
        set(updated)
    }

    private func set(_ actions: [ShortcutAction]) {
        action = .steps(actions: actions)
    }
}
