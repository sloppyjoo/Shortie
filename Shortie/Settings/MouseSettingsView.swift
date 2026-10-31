import SwiftUI

/// The Mouse section of the dashboard: extra mouse buttons, then scrolling.
struct MouseSettingsView: View {
    @Environment(\.listSearch) private var search
    @AppStorage(DefaultsKey.wheelDirection) private var wheelDirection = WheelDirection.system
    @AppStorage(DefaultsKey.smoothScrolling) private var smoothScrolling = true
    @AppStorage(DefaultsKey.scrollSpeed) private var scrollSpeed = 1.0
    @State private var linearMouse: NSRunningApplication?
    @State private var editing: MouseButtonEditorRequest?
    private var store = ShortcutStore.shared

    var body: some View {
        Form {
            PaneHeader(pane: .mouse)

            if let linearMouse {
                Section {
                    HStack {
                        Label("LinearMouse is also changing your scrolling.", systemImage: "exclamationmark.triangle.fill")
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
                HStack {
                    Toggle("Smooth Scrolling", isOn: $smoothScrolling)
                    InfoButton("Each click of the wheel glides to a stop, like a trackpad. Scrolling with ⌘ ⌥ ⌃ or ⇧ held isn't smoothed, so zooming still works.")
                }
                if smoothScrolling {
                    Slider(value: $scrollSpeed, in: 0.5...3) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                }
                Picker("Wheel Direction", selection: $wheelDirection) {
                    ForEach(WheelDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                // Shortie only changes the wheel; the trackpad's direction comes from macOS.
                if !systemIsNatural {
                    LabeledContent("Trackpad natural scrolling is off") {
                        Button("Trackpad Settings…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                SectionTitle("Scrolling")
            }
        }
        .formStyle(.grouped)
        // Rows glide in and out as you add and remove them.
        .animation(.smooth(duration: 0.25), value: store.shortcuts.map(\.id))
        .animation(.smooth(duration: 0.2), value: smoothScrolling)
        .sheet(item: $editing) { request in
            MouseButtonEditor(click: request.click, action: request.action, apps: request.apps) { click, action, apps in
                save(click: click, action: action, apps: apps, to: request.shortcutID)
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
                EmptyState("No button actions yet.", pixels: PixelArt.mouse)
            }
            if !search.isEmpty, store.shortcuts.contains(where: { $0.mouseButtonClick != nil }),
               !store.shortcuts.contains(where: { $0.mouseButtonClick != nil && $0.matches(search) }) {
                Text("No matches.").foregroundStyle(.secondary)
            }
            ForEach($store.shortcuts) { $shortcut in
                if let click = shortcut.mouseButtonClick, shortcut.matches(search) {
                    TriggerRow(
                        shortcut: $shortcut,
                        conflicts: store.conflicts(with: shortcut),
                        edit: { editing = MouseButtonEditorRequest(shortcutID: shortcut.id, click: click, action: shortcut.action, apps: shortcut.apps) },
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
                SectionTitle("Buttons")
                Spacer()
                Button("Back & Forward", action: addSuggestions)
                    .help("Make the thumb buttons go Back and Forward in every app")
                Button("Add", systemImage: "plus") {
                    editing = MouseButtonEditorRequest(
                        shortcutID: nil,
                        click: MouseButtonClick(button: 3, modifiers: []),
                        action: .pressKeys(combo: nil)
                    )
                }
            }
        }
    }

    private func save(click: MouseButtonClick, action: ShortcutAction, apps: AppScope?, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .mouseButton(click: click)
            shortcut.action = action
            shortcut.apps = apps
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .mouseButton(click: click), action: action, apps: apps))
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
        systemIsNatural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
    }

}

private struct MouseButtonEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let click: MouseButtonClick
    let action: ShortcutAction
    var apps: AppScope?
}

/// The sheet for setting up one mouse button action.
struct MouseButtonEditor: View {
    @State var click: MouseButtonClick
    @State var action: ShortcutAction
    @State var apps: AppScope?
    let onSave: (MouseButtonClick, ShortcutAction, AppScope?) -> Void

    @State private var isRecording = false

    var body: some View {
        TriggerEditor(title: "Mouse Button", action: $action, apps: $apps, save: { onSave(click, action, apps) }) {
            recorder
            HStack {
                Picker("Button", selection: $click.button) {
                    ForEach(MouseButtonClick.choices, id: \.self) { Text(MouseButtonClick.name(of: $0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Text("while holding")
                    .foregroundStyle(.secondary)
                ModifierToggles(modifiers: $click.modifiers)
            }
        }
        .onDisappear { MouseButtonEngine.shared.recordingHandler = nil }
    }

    /// "Press the button on your mouse" — the quickest way to say which one you mean.
    private var recorder: some View {
        HStack(spacing: 14) {
            Image(systemName: "computermouse")
                .font(.system(size: 22))
                .foregroundStyle(isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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
                .strokeBorder(isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
        }
        .animation(.smooth(duration: 0.2), value: isRecording)
    }
}
