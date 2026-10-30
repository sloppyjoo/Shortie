import SwiftUI
import UniformTypeIdentifiers

/// The Automations section of the dashboard: actions that run by themselves
/// when something happens, like an app opening or the Mac waking up.
struct AutomationsSettingsView: View {
    private var store = ShortcutStore.shared
    @State private var editing: AutomationEditorRequest?

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                if !store.shortcuts.contains(where: { $0.event != nil }) {
                    Text("Run an action when something happens: when Zoom opens, mute the sound; when the charger's unplugged, dim the screen; when your Mac wakes, open your to-do list.")
                        .foregroundStyle(.secondary)
                }
                ForEach($store.shortcuts) { $shortcut in
                    if let event = shortcut.event {
                        TriggerRow(
                            shortcut: $shortcut,
                            conflicts: [],
                            edit: { editing = AutomationEditorRequest(shortcutID: shortcut.id, event: event, action: shortcut.action) },
                            delete: { store.delete(id: shortcut.id) },
                            disable: { store.setEnabled(false, id: $0) }
                        ) {
                            if let bundleID = event.bundleID {
                                AppIcon(bundleID: bundleID, size: 20)
                            } else {
                                Image(systemName: event.systemImage)
                                    .frame(width: 20)
                            }
                            Text(event.title)
                                .frame(minWidth: 190, alignment: .leading)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Automations")
                    Spacer()
                    Button("Add Automation", systemImage: "plus") {
                        editing = AutomationEditorRequest(shortcutID: nil, event: .macWoke, action: .openApp(path: ""))
                    }
                }
            } footer: {
                Text("Several automations can share the same event; they run in the order listed.")
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { request in
            AutomationEditor(event: request.event, action: request.action) { event, action in
                save(event: event, action: action, to: request.shortcutID)
            }
        }
    }

    private func save(event: AutomationEvent, action: ShortcutAction, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .event(event: event)
            shortcut.action = action
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .event(event: event), action: action))
        }
    }
}

private struct AutomationEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let event: AutomationEvent
    let action: ShortcutAction
}

extension AutomationEvent {
    /// E.g. "Safari Opens" or "Mac Wakes".
    var title: String {
        switch self {
        case .appLaunched(let id): "\(AppInfo.name(of: id)) Opens"
        case .appQuit(let id): "\(AppInfo.name(of: id)) Quits"
        case .appActivated(let id): "\(AppInfo.name(of: id)) Comes to the Front"
        default: kind.title
        }
    }
}

/// The sheet for setting up one automation.
struct AutomationEditor: View {
    @State var event: AutomationEvent
    @State var action: ShortcutAction
    let onSave: (AutomationEvent, ShortcutAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appID: String

    init(event: AutomationEvent, action: ShortcutAction, onSave: @escaping (AutomationEvent, ShortcutAction) -> Void) {
        _event = State(initialValue: event)
        _action = State(initialValue: action)
        _appID = State(initialValue: event.bundleID ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automation")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("When").gridColumnAlignment(.trailing)
                    Picker("When", selection: kind) {
                        Section("Apps") {
                            ForEach(AutomationEvent.Kind.allCases.filter(\.needsApp)) { Text($0.title).tag($0) }
                        }
                        Section("Your Mac") {
                            ForEach(AutomationEvent.Kind.allCases.filter { !$0.needsApp }) { Text($0.title).tag($0) }
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if event.kind.needsApp {
                    GridRow {
                        Text("App")
                        appChooser
                    }
                }
                GridRow {
                    Text("Action")
                    ActionKindPicker(action: $action)
                }
            }

            ActionFields(action: $action)
                .padding(.leading, 4)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(event, action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!action.isComplete || (event.kind.needsApp && appID.isEmpty))
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private var kind: Binding<AutomationEvent.Kind> {
        Binding(get: { event.kind }, set: { event = AutomationEvent(kind: $0, bundleID: appID) })
    }

    /// Your open apps for quick picking, or any app from the Applications folder.
    private var appChooser: some View {
        Menu {
            Section("Open Apps") {
                ForEach(openApps, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier ?? "") { choose(app.bundleIdentifier) }
                }
            }
            Button("Other App…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                panel.prompt = "Choose"
                if panel.runModal() == .OK, let url = panel.url {
                    choose(Bundle(url: url)?.bundleIdentifier)
                }
            }
        } label: {
            if appID.isEmpty {
                Text("Choose App")
            } else {
                Label {
                    Text(AppInfo.name(of: appID))
                } icon: {
                    Image(nsImage: AppInfo.icon(of: appID))
                }
            }
        }
        .fixedSize()
    }

    private var openApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func choose(_ bundleID: String?) {
        guard let bundleID else { return }
        appID = bundleID
        event = AutomationEvent(kind: event.kind, bundleID: bundleID)
    }
}
