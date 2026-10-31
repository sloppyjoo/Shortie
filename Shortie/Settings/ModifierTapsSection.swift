import SwiftUI

/// Rules set off by tapping ⌘ ⌥ ⌃ ⇧ or fn on its own, shown at the top of
/// Keyboard Shortcuts.
struct ModifierTapsSection: View {
    @Environment(\.listSearch) private var search
    @State private var editing: ModifierTapEditorRequest?
    private var store = ShortcutStore.shared

    var body: some View {
        @Bindable var store = store

        Section {
            if !store.shortcuts.contains(where: { $0.modifierTap != nil }) {
                Text("Double-tap ⌘, tap right ⌥ and so on, without pressing another key.")
                    .foregroundStyle(.secondary)
            }
            ForEach($store.shortcuts) { $shortcut in
                if let tap = shortcut.modifierTap, shortcut.matches(search) {
                    TriggerRow(
                        shortcut: $shortcut,
                        conflicts: store.conflicts(with: shortcut),
                        edit: { editing = ModifierTapEditorRequest(shortcutID: shortcut.id, tap: tap, action: shortcut.action, apps: shortcut.apps) },
                        delete: { store.delete(id: shortcut.id) },
                        disable: { store.setEnabled(false, id: $0) }
                    ) {
                        Image(systemName: "keyboard")
                            .frame(width: 20)
                        Text(tap.title)
                            .frame(minWidth: 150, alignment: .leading)
                    }
                }
            }
        } header: {
            HStack {
                SectionTitle("Modifier Key Taps")
                InfoButton("A tap only counts if you let go quickly and don't press another key or click in between, so ⌘C and ⇧-typing still work normally.")
                Spacer()
                Button("Add", systemImage: "plus") {
                    editing = ModifierTapEditorRequest(
                        shortcutID: nil,
                        tap: ModifierTap(key: .command, side: .either, taps: 2),
                        action: .pressKeys(combo: nil)
                    )
                }
            }
        }
        .sheet(item: $editing) { request in
            ModifierTapEditor(tap: request.tap, action: request.action, apps: request.apps) { tap, action, apps in
                save(tap: tap, action: action, apps: apps, to: request.shortcutID)
            }
        }
    }

    private func save(tap: ModifierTap, action: ShortcutAction, apps: AppScope?, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .modifierTap(tap: tap)
            shortcut.action = action
            shortcut.apps = apps
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .modifierTap(tap: tap), action: action, apps: apps))
        }
    }
}

private struct ModifierTapEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let tap: ModifierTap
    let action: ShortcutAction
    var apps: AppScope?
}

/// The sheet for setting up one modifier key tap.
struct ModifierTapEditor: View {
    @State var tap: ModifierTap
    @State var action: ShortcutAction
    @State var apps: AppScope?
    let onSave: (ModifierTap, ShortcutAction, AppScope?) -> Void

    var body: some View {
        TriggerEditor(title: "Modifier Key Tap", action: $action, apps: $apps, save: { onSave(tap, action, apps) }) {
            HStack {
                Picker("Taps", selection: $tap.taps) {
                    Text("Tap").tag(1)
                    Text("Double-tap").tag(2)
                }
                .labelsHidden()
                .fixedSize()

                if tap.key.hasSides {
                    Picker("Side", selection: $tap.side) {
                        ForEach(ModifierTap.Side.allCases) { side in
                            Text(side == .either ? "Either" : side.title).tag(side)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Picker("Key", selection: $tap.key) {
                    ForEach(ModifierTap.Key.allCases) { key in
                        Text("\(key.symbol)  \(key.name)").tag(key)
                    }
                }
                .labelsHidden()
                .fixedSize()

                Spacer(minLength: 0)
            }
        }
    }
}
