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
                    EmptyState("No text shortcuts yet.", pixels: PixelArt.typing)
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
                    SectionTitle("Text Shortcuts")
                    InfoButton("Shortie keeps only the last few characters you typed, in memory, to spot abbreviations. It never sees what you type into password fields.")
                    Spacer()
                    Button("Add", systemImage: "plus") {
                        editing = TextShortcutEditorRequest(shortcutID: nil, abbreviation: ";", action: .typeText(text: ""))
                    }
                }
            }
        }
        .formStyle(.grouped)
        // Rows glide in and out as you add and remove them.
        .animation(.smooth(duration: 0.25), value: store.shortcuts.map(\.id))
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


    var body: some View {
        TriggerEditor(
            title: "Text Shortcut", action: $action, apps: $apps, canSave: problem == nil,
            save: { onSave(abbreviation, action, apps) }
        ) {
            HStack {
                Text("I type")
                TextField("Abbreviation", text: $abbreviation, prompt: Text(";email"))
                    .font(.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            Text(problem ?? "Start it with ; so it doesn't go off in normal writing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Why the abbreviation can't be used yet, if it can't.
    private var problem: String? {
        if abbreviation.count < 2 { return "Use at least two characters." }
        if abbreviation.contains(where: \.isWhitespace) { return "Abbreviations can't contain spaces." }
        return nil
    }
}
