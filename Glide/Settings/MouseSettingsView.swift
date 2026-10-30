import SwiftUI

/// The Mouse section of the dashboard: extra mouse buttons, then scrolling.
struct MouseSettingsView: View {
    @AppStorage(DefaultsKey.wheelDirection) private var wheelDirection = WheelDirection.system
    @AppStorage(DefaultsKey.smoothScrolling) private var smoothScrolling = true
    @AppStorage(DefaultsKey.scrollSpeed) private var scrollSpeed = 1.0
    @State private var linearMouse: NSRunningApplication?
    @State private var editing: MouseButtonEditorRequest?
    private var store = ShortcutStore.shared

    var body: some View {
        Form {
            if let linearMouse {
                Section {
                    HStack {
                        Label(
                            "LinearMouse is running, so it may also flip your scrolling. Quit it to stop the two apps fighting.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        Spacer()
                        Button("Quit LinearMouse") {
                            linearMouse.terminate()
                            self.linearMouse = nil
                        }
                    }
                }
            }

            buttons

            Section {
                Toggle("Smooth scrolling", isOn: $smoothScrolling)
                if smoothScrolling {
                    Slider(value: $scrollSpeed, in: 0.5...3) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                }
            } header: {
                Text("Mouse Wheel")
            } footer: {
                Text("Each click of the wheel glides and eases to a stop, like scrolling on a trackpad. Scrolling with ⌘, ⌥, ⌃ or ⇧ held isn't smoothed, so zooming and sideways scrolling still work as apps expect.")
            }

            Section {
                Picker("Mouse wheel", selection: $wheelDirection) {
                    ForEach(WheelDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Scroll Direction")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(footer)
                    if !systemIsNatural {
                        // Glide only changes the wheel, so the trackpad's direction comes from macOS.
                        HStack(spacing: 4) {
                            Text("Natural scrolling is off in System Settings, so your trackpad scrolls traditionally.")
                            Button("Open Trackpad Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { request in
            MouseButtonEditor(click: request.click, action: request.action) { click, action in
                save(click: click, action: action, to: request.shortcutID)
            }
        }
        .onAppear(perform: refresh)
        // Pick up changes you make in System Settings while this is open.
        .onReceive(NSApp.publisher(for: \.isActive)) { _ in refresh() }
    }

    @ViewBuilder
    private var buttons: some View {
        @Bindable var store = store

        Section {
            if !store.shortcuts.contains(where: { $0.mouseButtonClick != nil }) {
                Text("Give your mouse's extra buttons something to do, like Back and Forward in every app (Safari ignores them on its own).")
                    .foregroundStyle(.secondary)
            }
            ForEach($store.shortcuts) { $shortcut in
                if let click = shortcut.mouseButtonClick {
                    TriggerRow(
                        shortcut: $shortcut,
                        conflicts: store.conflicts(with: shortcut),
                        edit: { editing = MouseButtonEditorRequest(shortcutID: shortcut.id, click: click, action: shortcut.action) },
                        delete: { store.delete(id: shortcut.id) },
                        disable: { store.setEnabled(false, id: $0) }
                    ) {
                        Image(systemName: "computermouse")
                            .frame(width: 20)
                        Text(click.title)
                            .frame(minWidth: 150, alignment: .leading)
                    }
                }
            }
        } header: {
            HStack {
                Text("Buttons")
                Spacer()
                Button("Add Suggestions", action: addSuggestions)
                Button("Add Button Action", systemImage: "plus") {
                    editing = MouseButtonEditorRequest(
                        shortcutID: nil,
                        click: MouseButtonClick(button: 3, modifiers: []),
                        action: .pressKeys(combo: nil)
                    )
                }
            }
        }
    }

    private func save(click: MouseButtonClick, action: ShortcutAction, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .mouseButton(click: click)
            shortcut.action = action
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .mouseButton(click: click), action: action))
        }
    }

    /// Back and Forward on the thumb buttons, using the shortcuts every app
    /// understands. Skips buttons you've already set up.
    private func addSuggestions() {
        let presets = KeyPreset.groups.flatMap(\.presets)
        let suggestions: [(Int, String)] = [(3, "Back"), (4, "Forward")]
        for (button, presetTitle) in suggestions {
            let click = MouseButtonClick(button: button, modifiers: [])
            guard !store.shortcuts.contains(where: { $0.mouseButtonClick == click }),
                  let preset = presets.first(where: { $0.title == presetTitle })
            else { continue }
            store.shortcuts.append(Shortcut(trigger: .mouseButton(click: click), action: .pressKeys(combo: preset.combo)))
        }
    }

    @State private var systemIsNatural = true

    private func refresh() {
        linearMouse = NSRunningApplication.runningApplications(withBundleIdentifier: "com.lujjjh.LinearMouse").first
        systemIsNatural = UserDefaults(suiteName: UserDefaults.globalDomain)?
            .object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
    }

    private var footer: String {
        let detail = switch wheelDirection {
        case .system: "The wheel scrolls the same way as your trackpad."
        case .traditional: "Rolling the wheel down moves the page down."
        case .natural: "Rolling the wheel down moves the page up, like dragging it."
        }
        return detail + " Your trackpad follows System Settings › Trackpad › Natural scrolling."
    }
}

private struct MouseButtonEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let click: MouseButtonClick
    let action: ShortcutAction
}

/// The sheet for setting up one mouse button action.
struct MouseButtonEditor: View {
    @State var click: MouseButtonClick
    @State var action: ShortcutAction
    let onSave: (MouseButtonClick, ShortcutAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mouse Button Action")
                .font(.headline)

            recorder

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Button").gridColumnAlignment(.trailing)
                    Picker("Button", selection: $click.button) {
                        ForEach(MouseButtonClick.choices, id: \.self) { Text(MouseButtonClick.name(of: $0)).tag($0) }
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

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(click, action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!action.isComplete)
            }
        }
        .padding(20)
        .frame(width: 500)
        .onDisappear { MouseButtonEngine.shared.recordingHandler = nil }
    }

    /// "Press the button on your mouse" — the quickest way to say which one you mean.
    private var recorder: some View {
        HStack(spacing: 14) {
            Image(systemName: "computermouse")
                .font(.system(size: 22))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
                .symbolEffect(.pulse, isActive: isRecording)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(isRecording ? "Press the button on your mouse…" : click.title)
                    .font(.title3)
                Text(isRecording ? "Hold ⌃ ⌥ ⇧ or ⌘ too if you like." : "Record it, or choose below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isRecording ? "Cancel" : "Record") {
                if isRecording {
                    isRecording = false
                    MouseButtonEngine.shared.recordingHandler = nil
                } else {
                    isRecording = true
                    MouseButtonEngine.shared.recordingHandler = { recorded in
                        click = recorded
                        isRecording = false
                    }
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 2)
        }
        .animation(.smooth(duration: 0.2), value: isRecording)
    }
}
