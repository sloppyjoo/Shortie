import SwiftUI

/// The Text Shortcuts section of the dashboard: type an abbreviation anywhere,
/// and it's replaced with longer text (or runs any other action).
struct TextShortcutsSettingsView: View {
    private var store = ShortcutStore.shared
    @State private var editing: TextShortcutEditorRequest?

    var body: some View {
        @Bindable var store = store

        Form {
            PaneHeader(pane: .textShortcuts)

            Section {
                if !store.shortcuts.contains(where: { $0.abbreviation != nil }) {
                    Text("No text shortcuts yet. Try ;email for your address.")
                        .foregroundStyle(.secondary)
                }
                ForEach($store.shortcuts) { $shortcut in
                    if let abbreviation = shortcut.abbreviation {
                        TriggerRow(
                            shortcut: $shortcut,
                            conflicts: store.conflicts(with: shortcut),
                            edit: { editing = TextShortcutEditorRequest(shortcutID: shortcut.id, abbreviation: abbreviation, action: shortcut.action, apps: shortcut.apps) },
                            delete: { store.delete(id: shortcut.id) },
                            disable: { store.setEnabled(false, id: $0) }
                        ) {
                            Text(abbreviation)
                                .font(.body.monospaced())
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 5))
                                .frame(minWidth: 110, alignment: .leading)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Text Shortcuts")
                    InfoButton("Only the last few characters you type are kept, in memory, to spot abbreviations. Nothing is saved or sent anywhere, and password fields are never seen.")
                    Spacer()
                    Button("Add", systemImage: "plus") {
                        editing = TextShortcutEditorRequest(shortcutID: nil, abbreviation: ";", action: .typeText(text: ""))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { request in
            TextShortcutEditor(abbreviation: request.abbreviation, action: request.action, apps: request.apps) { abbreviation, action, apps in
                save(abbreviation: abbreviation, action: action, apps: apps, to: request.shortcutID)
            }
        }
    }

    private func save(abbreviation: String, action: ShortcutAction, apps: AppScope?, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .typedText(abbreviation: abbreviation)
            shortcut.action = action
            shortcut.apps = apps
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .typedText(abbreviation: abbreviation), action: action, apps: apps))
        }
    }
}

private struct TextShortcutEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let abbreviation: String
    let action: ShortcutAction
    var apps: AppScope?
}

/// The sheet for setting up one text shortcut.
struct TextShortcutEditor: View {
    @State var abbreviation: String
    @State var action: ShortcutAction
    @State var apps: AppScope?
    let onSave: (String, ShortcutAction, AppScope?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text Shortcut")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("When I type").gridColumnAlignment(.trailing)
                    TextField("Abbreviation", text: $abbreviation, prompt: Text(";email"))
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                GridRow {
                    Text("Action")
                    ActionKindPicker(action: $action)
                }
            }

            ActionFields(action: $action)
                .padding(.leading, 4)

            AppScopePicker(scope: $apps)

            if let problem {
                Label(problem, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Starting with ; keeps it out of ordinary writing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(abbreviation, action, apps)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil || !action.isComplete || apps?.isValid == false)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    /// Why the abbreviation can't be used yet, if it can't.
    private var problem: String? {
        if abbreviation.count < 2 { return "Use at least two characters." }
        if abbreviation.contains(where: \.isWhitespace) { return "Abbreviations can't contain spaces." }
        return nil
    }
}
