import SwiftUI

/// The Windows section of the dashboard: shortcuts that snap the front window.
struct WindowsSettingsView: View {
    @State private var addedMessage: String?

    var body: some View {
        ShortcutListView(
            pane: .windows,
            kinds: [.moveWindow, .appCommand],
            emptyText: "No window shortcuts yet.",
            info: "Press a half or corner shortcut again to cycle its width: ½ → ⅓ → ⅔."
        ) {
            Button("Standard Set", action: addStandardShortcuts)
                .help("Add the usual ⌃⌥ arrow-key shortcuts for halves, corners and thirds")
        } topSections: {
            WindowDraggingSettings()
        }
        .alert("Window Shortcuts Added", isPresented: Binding(
            get: { addedMessage != nil },
            set: { if !$0 { addedMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(addedMessage ?? "")
        }
    }

    /// Adds the standard set, skipping any position you already have a shortcut
    /// for and any keys you already use for something else.
    private func addStandardShortcuts() {
        let store = ShortcutStore.shared
        var added = 0
        var skipped: [String] = []

        for standard in WindowPosition.standardShortcuts {
            let keyCode = UInt16(standard.keyCode)
            let combo = KeyCombo(keyCode: keyCode, modifiers: standard.modifiers, keyName: KeyNames.name(for: keyCode))

            let hasPosition = store.shortcuts.contains {
                $0.isKeyboardShortcut && $0.action == .moveWindow(position: standard.position)
            }
            if hasPosition { continue }

            let keysTaken = store.shortcuts.contains {
                $0.keyCombo?.matches(keyCode: keyCode, modifiers: standard.modifiers) == true
            }
            if keysTaken {
                skipped.append("\(combo.displayString) (\(standard.position.title))")
                continue
            }

            store.shortcuts.append(Shortcut(keyCombo: combo, action: .moveWindow(position: standard.position)))
            added += 1
        }

        var message = added == 1 ? "Added 1 shortcut." : "Added \(added) shortcuts."
        if !skipped.isEmpty {
            message += "\n\nSkipped because you already use these keys: " + skipped.joined(separator: ", ")
                + ". You can give those positions different keys."
        }
        addedMessage = message
    }
}

/// A tiny diagram of a screen with the area a position fills highlighted.
struct WindowPositionIcon: View {
    let position: WindowPosition

    var body: some View {
        switch position {
        case .restore:
            SettingsIcon(systemImage: "arrow.uturn.backward", color: .gray)
                .padding(2)
        case .nextDisplay, .previousDisplay, .larger, .smaller, .maximizeHeight, .maximizeWidth,
             .moveLeft, .moveRight, .moveUp, .moveDown:
            SettingsIcon(systemImage: Self.symbol(for: position), color: .gray)
                .padding(2)
        default:
            let unit = position.unitRect() ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
            GeometryReader { geometry in
                let screen = CGRect(x: 1, y: 4, width: geometry.size.width - 2, height: geometry.size.height - 8)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(.secondary, lineWidth: 1.5)
                        .frame(width: screen.width, height: screen.height)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.tint)
                        .frame(
                            width: max(unit.width * (screen.width - 6), 2),
                            height: max(unit.height * (screen.height - 6), 2)
                        )
                        .offset(
                            x: 3 + unit.minX * (screen.width - 6),
                            y: 3 + unit.minY * (screen.height - 6)
                        )
                }
                .offset(x: screen.minX, y: screen.minY)
            }
        }
    }
}

extension WindowPositionIcon {
    /// For positions that depend on where the window already is, so can't be drawn as an area.
    static func symbol(for position: WindowPosition) -> String {
        switch position {
        case .previousDisplay: "arrow.left"
        case .larger: "arrow.up.left.and.arrow.down.right"
        case .smaller: "arrow.down.right.and.arrow.up.left"
        case .maximizeHeight: "arrow.up.and.down"
        case .maximizeWidth: "arrow.left.and.right"
        case .moveLeft: "arrow.left.to.line"
        case .moveRight: "arrow.right.to.line"
        case .moveUp: "arrow.up.to.line"
        case .moveDown: "arrow.down.to.line"
        default: "arrow.right"
        }
    }
}

/// Settings for moving, resizing and snapping windows with the mouse.
struct WindowDraggingSettings: View {
    @AppStorage(DefaultsKey.dragSnapEnabled) private var snaps = true
    @AppStorage(DefaultsKey.dragMoveEnabled) private var moves = true
    @AppStorage(DefaultsKey.dragMoveModifiers) private var moveKeys = WindowDragEngine.defaultMoveModifiers.rawValue
    @AppStorage(DefaultsKey.dragResizeEnabled) private var resizes = true
    @AppStorage(DefaultsKey.dragResizeModifiers) private var resizeKeys = WindowDragEngine.defaultResizeModifiers.rawValue

    var body: some View {
        Section {
            Toggle("Snap at Screen Edges", isOn: $snaps)
            modifierRow("Move from Anywhere", isOn: $moves, keys: $moveKeys)
            modifierRow("Resize from Anywhere", isOn: $resizes, keys: $resizeKeys)
        } header: {
            HStack {
                SectionTitle("Dragging")
                InfoButton("Drag a window to the left or right edge for half the screen, the top to maximise, or right into a corner for a quarter. Hold the keys and drag inside any window to move or resize it.")
            }
        }
    }

    private func modifierRow(_ title: String, isOn: Binding<Bool>, keys: Binding<Int>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
            ModifierToggles(modifiers: Binding(
                get: { Modifiers(rawValue: keys.wrappedValue) },
                set: { keys.wrappedValue = $0.rawValue }
            ))
            .disabled(!isOn.wrappedValue)
        }
    }
}
