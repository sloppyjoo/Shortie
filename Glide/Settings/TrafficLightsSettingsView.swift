import SwiftUI

/// The Traffic Lights section of the dashboard: extra actions for the red,
/// yellow and green buttons on every window.
struct TrafficLightsSettingsView: View {
    private var store = ShortcutStore.shared
    @State private var editing: TrafficLightEditorRequest?

    var body: some View {
        @Bindable var store = store

        Form {
            PaneHeader(pane: .trafficLights)

            Section {
                if !store.shortcuts.contains(where: { $0.trafficLightClick != nil }) {
                    Text("No window button actions yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach($store.shortcuts) { $shortcut in
                    if let click = shortcut.trafficLightClick {
                        TrafficLightRow(
                            shortcut: $shortcut,
                            click: click,
                            conflicts: store.conflicts(with: shortcut),
                            edit: { edit(shortcut, click: click) },
                            delete: { store.delete(id: shortcut.id) },
                            disable: { store.setEnabled(false, id: $0) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Window Buttons")
                    Spacer()
                    Button("Suggestions", action: addSuggestions)
                        .help("Add a handy starting set, like click green to maximise")
                    Button("Add", systemImage: "plus") {
                        editing = TrafficLightEditorRequest(
                            shortcutID: nil,
                            click: TrafficLightClick(button: .close, mouseButton: .right, modifiers: []),
                            action: .appCommand(command: .quitApp)
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { request in
            TrafficLightEditor(click: request.click, action: request.action, apps: request.apps) { click, action, apps in
                save(click: click, action: action, apps: apps, to: request.shortcutID)
            }
        }
    }

    private func edit(_ shortcut: Shortcut, click: TrafficLightClick) {
        editing = TrafficLightEditorRequest(shortcutID: shortcut.id, click: click, action: shortcut.action, apps: shortcut.apps)
    }

    private func save(click: TrafficLightClick, action: ShortcutAction, apps: AppScope?, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .trafficLight(click: click)
            shortcut.action = action
            shortcut.apps = apps
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .trafficLight(click: click), action: action, apps: apps))
        }
    }

    /// A handy starting set. Skips any click you've already given an action.
    private func addSuggestions() {
        let suggestions: [(TrafficLightClick, ShortcutAction)] = [
            (TrafficLightClick(button: .close, mouseButton: .right, modifiers: []), .appCommand(command: .quitApp)),
            (TrafficLightClick(button: .minimize, mouseButton: .right, modifiers: []), .appCommand(command: .hideApp)),
            // Green maximises without full screen (click again to restore); ⌥ keeps full screen to hand.
            (TrafficLightClick(button: .zoom, mouseButton: .left, modifiers: []), .moveWindow(position: .maximize)),
            (TrafficLightClick(button: .zoom, mouseButton: .left, modifiers: .option), .appCommand(command: .toggleFullScreen)),
            (TrafficLightClick(button: .close, mouseButton: .left, modifiers: .option), .appCommand(command: .closeAllWindows)),
            (TrafficLightClick(button: .minimize, mouseButton: .left, modifiers: .option), .appCommand(command: .minimizeAllWindows)),
        ]
        for (click, action) in suggestions where !store.shortcuts.contains(where: { $0.trafficLightClick == click }) {
            store.shortcuts.append(Shortcut(trigger: .trafficLight(click: click), action: action))
        }
    }
}

private struct TrafficLightEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let click: TrafficLightClick
    let action: ShortcutAction
    var apps: AppScope?
}

struct TrafficLightRow: View {
    @Binding var shortcut: Shortcut
    let click: TrafficLightClick
    let conflicts: [Shortcut]
    let edit: () -> Void
    let delete: () -> Void
    let disable: (Shortcut.ID) -> Void

    var body: some View {
        TriggerRow(shortcut: $shortcut, conflicts: conflicts, edit: edit, delete: delete, disable: disable) {
            TrafficLightDots(highlighted: click.button)
            Text(click.clickDescription)
                .frame(minWidth: 110, alignment: .leading)
        }
    }
}

/// One "trigger → action" row, with its warnings, on/off switch and menu.
/// Used for traffic lights and gestures.
struct TriggerRow<Trigger: View>: View {
    @Binding var shortcut: Shortcut
    let conflicts: [Shortcut]
    var warning: String?
    let edit: () -> Void
    let delete: () -> Void
    let disable: (Shortcut.ID) -> Void
    @ViewBuilder let trigger: Trigger

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 10) {
                    trigger
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
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

            if let warning {
                SystemWarningBadge(text: warning)
            }
            if !conflicts.isEmpty {
                ConflictBadge(conflicts: conflicts, disable: disable)
            }

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

/// The three window buttons, with one lit up and the others greyed out.
/// Pass `nil` to light up all three.
struct TrafficLightDots: View {
    let highlighted: TrafficLightButton?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TrafficLightButton.allCases) { button in
                Circle()
                    .fill(highlighted == nil || highlighted == button ? button.color : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityLabel(highlighted.map { "\($0.title) button" } ?? "Window buttons")
    }
}

extension TrafficLightButton {
    var color: Color {
        switch self {
        case .close: Color(red: 1, green: 0.37, blue: 0.34)
        case .minimize: Color(red: 1, green: 0.74, blue: 0.18)
        case .zoom: Color(red: 0.16, green: 0.79, blue: 0.25)
        }
    }
}

/// The sheet for setting up one traffic light action.
struct TrafficLightEditor: View {
    @State var click: TrafficLightClick
    @State var action: ShortcutAction
    @State var apps: AppScope?
    let onSave: (TrafficLightClick, ShortcutAction, AppScope?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Traffic Light Action")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Button").gridColumnAlignment(.trailing)
                    TrafficLightButtonPicker(selection: $click.button)
                }
                GridRow {
                    Text("Click")
                    Picker("Click", selection: $click.mouseButton) {
                        ForEach(MouseButton.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                GridRow {
                    Text("While holding")
                    ModifierToggles(modifiers: $click.modifiers)
                }
                GridRow {
                    Text("Action")
                    ActionKindPicker(action: $action)
                }
            }

            ActionFields(action: $action)
                .padding(.leading, 4)

            AppScopePicker(scope: $apps)

            if click.mouseButton == .left && click.modifiers.isEmpty {
                Label("This replaces the button's normal click.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(click, action, apps)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!action.isComplete || apps?.isValid == false)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

/// Chooses what kind of action to run. Changing it starts that kind afresh.
struct ActionKindPicker: View {
    @Binding var action: ShortcutAction

    /// Clicks and window commands first, since they're what you'll usually want
    /// from a gesture or window button.
    private static let order: [ShortcutAction.Kind] = [
        .mouseClick, .system, .pressKeys, .appCommand, .moveWindow, .openApp, .runShortcut, .open, .typeText,
    ]

    var body: some View {
        Picker("Action", selection: Binding(
            get: { action.kind },
            set: { if $0 != action.kind { action = $0.emptyAction } }
        )) {
            ForEach(Self.order) { kind in
                Label(kind.editorTitle, systemImage: kind.systemImage).tag(kind)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

/// Four little ⌃ ⌥ ⇧ ⌘ toggle buttons.
struct ModifierToggles: View {
    @Binding var modifiers: Modifiers

    private static let all: [(Modifiers, String, String)] = [
        (.control, "⌃", "Control"), (.option, "⌥", "Option"), (.shift, "⇧", "Shift"), (.command, "⌘", "Command"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.all, id: \.1) { modifier, symbol, name in
                Toggle(symbol, isOn: Binding(
                    get: { modifiers.contains(modifier) },
                    set: { isOn in
                        if isOn { modifiers.insert(modifier) } else { modifiers.remove(modifier) }
                    }
                ))
                .toggleStyle(.button)
                .help(name)
            }
        }
    }
}

/// Choose a window button by clicking a picture of it, the way they look on a
/// real window, with their symbols showing as if you're hovering.
struct TrafficLightButtonPicker: View {
    @Binding var selection: TrafficLightButton

    var body: some View {
        HStack(spacing: 18) {
            ForEach(TrafficLightButton.allCases) { button in
                Button {
                    selection = button
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(button.color.gradient)
                                .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                            Image(systemName: button.symbol)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.black.opacity(0.55))
                        }
                        .frame(width: 26, height: 26)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 2.5)
                                .opacity(selection == button ? 1 : 0)
                        }

                        Text(button.title)
                            .font(.caption)
                            .foregroundStyle(selection == button ? .primary : .secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(button.title) button")
                .accessibilityAddTraits(selection == button ? .isSelected : [])
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

extension TrafficLightButton {
    /// The little symbol that appears on the button when you hover over it.
    var symbol: String {
        switch self {
        case .close: "xmark"
        case .minimize: "minus"
        case .zoom: "plus"
        }
    }
}
