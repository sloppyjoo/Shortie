import SwiftUI

/// The Windows section of the dashboard: shortcuts that snap the front window.
struct WindowsSettingsView: View {
    @State private var addedMessage: String?

    var body: some View {
        ShortcutListView(
            kinds: [.moveWindow],
            emptyTitle: "Snap Windows with Your Keyboard",
            emptySymbol: "macwindow",
            emptyDescription: "Move the front window to a half, corner or third of the screen. Start with the standard set, or add your own.",
            footnote: "Press a half or corner shortcut again to cycle its width: ½ → ⅓ → ⅔."
        ) {
            Button("Add Standard Shortcuts", action: addStandardShortcuts)
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

            let hasPosition = store.shortcuts.contains { $0.action == .moveWindow(position: standard.position) }
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
        case .nextDisplay:
            SettingsIcon(systemImage: "arrow.right", color: .gray)
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
