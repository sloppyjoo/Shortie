import SwiftUI

/// The small sheet for setting up what a shortcut does.
struct ActionEditor: View {
    @State var action: ShortcutAction
    let onSave: (ShortcutAction) -> Void

    @Environment(\.dismiss) private var dismiss
    /// Names from the Shortcuts app; `nil` while still loading.
    @State private var availableShortcuts: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(action.kind.editorTitle, systemImage: action.kind.systemImage)
                .font(.headline)

            fields

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!action.isComplete)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    /// Edits the one piece of text the action carries.
    private var payload: Binding<String> {
        Binding(get: { action.payload }, set: { action = action.with(payload: $0) })
    }

    @ViewBuilder
    private var fields: some View {
        switch action.kind {
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
            Picker("Move the front window to", selection: payload) {
                ForEach(WindowPosition.groups, id: \.self) { group in
                    Section {
                        ForEach(group) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
        case .openApp:
            EmptyView()
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

extension ShortcutAction.Kind {
    var editorTitle: String {
        switch self {
        case .openApp: "Open App"
        case .runShortcut: "Run a Shortcut"
        case .open: "Open Website or File"
        case .typeText: "Type Text"
        case .moveWindow: "Move Window"
        }
    }
}
