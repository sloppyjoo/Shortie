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
        case .system:
            Picker("Action", selection: payload) {
                ForEach(SystemAction.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
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
        case .mouseClick:
            Picker("Click", selection: payload) {
                ForEach(MouseAction.allCases) { Text($0.title).tag($0.rawValue) }
            }
        case .appCommand:
            Picker("Command", selection: payload) {
                ForEach(AppCommand.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var shortcutPicker: some View {
        Group {
            if let availableShortcuts, !availableShortcuts.isEmpty {
                Picker("Shortcut", selection: payload) {
                    ForEach(availableShortcuts, id: \.self) { Text($0).tag($0) }
                }
            } else if availableShortcuts != nil {
                Text("You don't have any shortcuts yet. Make one in the Shortcuts app, then come back.")
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
                ActionKindPicker(action: $action)
                ActionFields(action: $action)
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
