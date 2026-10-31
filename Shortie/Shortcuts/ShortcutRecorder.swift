import Carbon.HIToolbox
import SwiftUI

/// A box you click, then press the keys you want, like System Settings' shortcut fields.
///
/// While recording: Esc cancels, Delete clears the shortcut.
struct ShortcutRecorder: View {
    @Binding var keyCombo: KeyCombo?
    @Binding var isRecording: Bool
    /// For keys Shortie will press (rather than listen for), a single key like
    /// ↩ or → is fine, since it won't stop you typing.
    var allowsPlainKeys = false

    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(label)
                .foregroundStyle(keyCombo == nil && !isRecording ? .secondary : .primary)
                .frame(minWidth: 120)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 2)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Press Esc to cancel, Delete to clear" : "Click to record a shortcut")
        .onChange(of: isRecording, initial: true) { _, recording in
            recording ? startListening() : stopListening()
        }
        .onDisappear {
            isRecording = false
            stopListening()
        }
    }

    private var label: String {
        if isRecording { return "Type Shortcut…" }
        return keyCombo?.displayString ?? "Record Shortcut"
    }

    private func startListening() {
        guard monitor == nil else { return }
        ShortcutEngine.shared.isRecording = true
        // A "local" monitor sees key presses aimed at Shortie's own windows,
        // before anything else (even menu shortcuts like ⌘Q) acts on them.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            record(event)
            return nil
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            ShortcutEngine.shared.isRecording = false
        }
        monitor = nil
    }

    private func record(_ event: NSEvent) {
        let modifiers = Modifiers(event.modifierFlags)
        let keyCode = Int(event.keyCode)

        if modifiers.isEmpty && keyCode == kVK_Escape {
            isRecording = false
        } else if modifiers.isEmpty && (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete) {
            keyCombo = nil
            isRecording = false
        } else if modifiers.isEmpty && !allowsPlainKeys && !KeyNames.isFunctionKey(event.keyCode) {
            // A plain letter as a shortcut would stop you typing that letter.
            NSSound.beep()
        } else {
            keyCombo = KeyCombo(
                keyCode: event.keyCode,
                modifiers: modifiers,
                keyName: KeyNames.name(for: event.keyCode)
            )
            isRecording = false
        }
    }
}
