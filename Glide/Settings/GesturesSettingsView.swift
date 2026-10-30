import SwiftUI

/// The Gestures section of the dashboard: trackpad gestures that run actions,
/// plus the Gesture Lab for seeing what Glide recognises.
struct GesturesSettingsView: View {
    private var engine = GestureEngine.shared
    private var store = ShortcutStore.shared
    @State private var editing: GestureEditorRequest?
    @State private var isLabExpanded = false

    var body: some View {
        Form {
            switch engine.status {
            case .unavailable:
                Section {
                    Label(
                        "BestTouchTool couldn't connect to your trackpad. A macOS update may have changed how trackpads report touches.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            case .notStarted:
                Section {
                    Text("Gestures start once BestTouchTool has Accessibility permission.")
                        .foregroundStyle(.secondary)
                }
            case .running:
                rules
                lab
            }
        }
        .formStyle(.grouped)
        .onAppear { engine.isWatching = true }
        .onDisappear { engine.isWatching = false }
        .sheet(item: $editing) { request in
            GestureEditor(gesture: request.gesture, action: request.action) { gesture, action in
                save(gesture: gesture, action: action, to: request.shortcutID)
            }
        }
    }

    @ViewBuilder
    private var rules: some View {
        @Bindable var store = store

        Section {
            if !store.shortcuts.contains(where: { $0.gesture != nil }) {
                Text("No gestures yet. Add one, then just do it on your trackpad to set it up. Try a two-finger tap for Right Click, or a three-finger tap for Middle Click.")
                    .foregroundStyle(.secondary)
            }
            ForEach($store.shortcuts) { $shortcut in
                if let gesture = shortcut.gesture {
                    TriggerRow(
                        shortcut: $shortcut,
                        conflicts: store.conflicts(with: shortcut),
                        warning: SystemGestures.warning(for: gesture),
                        edit: { editing = GestureEditorRequest(shortcutID: shortcut.id, gesture: gesture, action: shortcut.action) },
                        delete: { store.delete(id: shortcut.id) },
                        disable: { store.setEnabled(false, id: $0) }
                    ) {
                        Image(systemName: gesture.systemImage)
                            .frame(width: 20)
                        Text(gesture.title)
                            .frame(minWidth: 170, alignment: .leading)
                    }
                }
            }
        } header: {
            HStack {
                Text("Gestures")
                Spacer()
                Button("Add Gesture", systemImage: "plus") {
                    editing = GestureEditorRequest(
                        shortcutID: nil,
                        gesture: .tap(fingers: 3),
                        action: .mouseClick(click: .middleClick)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var lab: some View {
        Section {
            DisclosureGroup("Gesture Lab", isExpanded: $isLabExpanded) {
                TrackpadView(touches: engine.liveTouches, aspectRatio: engine.aspectRatio)
                    .frame(maxWidth: 380)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                if engine.recentGestures.isEmpty {
                    Text("Nothing recognised yet. Try a three-finger tap.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.recentGestures) { recognized in
                        HStack {
                            Text(recognized.gesture.title)
                                .fontWeight(recognized.id == engine.recentGestures.first?.id ? .semibold : .regular)
                            Spacer()
                            Text(recognized.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        } footer: {
            Text("See your fingers live and every gesture BestTouchTool recognises, to check how your gestures are being read.")
        }
        .animation(.smooth(duration: 0.25), value: engine.recentGestures.map(\.id))
    }

    private func save(gesture: Gesture, action: ShortcutAction, to id: Shortcut.ID?) {
        if let id, var shortcut = store.shortcuts.first(where: { $0.id == id }) {
            shortcut.trigger = .gesture(gesture: gesture)
            shortcut.action = action
            store.update(shortcut)
        } else {
            store.shortcuts.append(Shortcut(trigger: .gesture(gesture: gesture), action: action))
        }
    }
}

private struct GestureEditorRequest: Identifiable {
    let id = UUID()
    /// `nil` when adding a new one.
    let shortcutID: Shortcut.ID?
    let gesture: Gesture
    let action: ShortcutAction
}

/// The sheet for setting up one gesture action.
struct GestureEditor: View {
    @State var gesture: Gesture
    @State var action: ShortcutAction
    let onSave: (Gesture, ShortcutAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gesture Action")
                .font(.headline)

            GestureRecorder(gesture: $gesture)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Gesture").gridColumnAlignment(.trailing)
                    HStack {
                        Picker("Gesture", selection: kind) {
                            ForEach(Gesture.Kind.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()

                        if let range = gesture.kind.fingerRange {
                            Picker("Fingers", selection: fingers) {
                                ForEach(Array(range), id: \.self) { Text(gesture.kind.fingerTitle($0)).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        if !gesture.kind.variants.isEmpty {
                            Picker("Variant", selection: variant) {
                                ForEach(gesture.kind.variants, id: \.id) { Text($0.title).tag($0.id) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                GridRow {
                    Text("Action")
                    ActionKindPicker(action: $action)
                }
            }

            ActionFields(action: $action)
                .padding(.leading, 4)

            if let warning = SystemGestures.warning(for: gesture) {
                HStack(alignment: .firstTextBaseline) {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if case .click = gesture {} else {
                        Button("Trackpad Settings…", action: SystemGestures.openTrackpadSettings)
                            .controlSize(.small)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(gesture, action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!action.isComplete)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private var kind: Binding<Gesture.Kind> {
        Binding(get: { gesture.kind }, set: { gesture = Gesture(kind: $0, fingers: gesture.fingers, variant: gesture.variant) })
    }

    private var fingers: Binding<Int> {
        Binding(get: { gesture.fingers }, set: { gesture = Gesture(kind: gesture.kind, fingers: $0, variant: gesture.variant) })
    }

    private var variant: Binding<String> {
        Binding(get: { gesture.variant }, set: { gesture = Gesture(kind: gesture.kind, fingers: gesture.fingers, variant: $0) })
    }
}

/// "Do the gesture on your trackpad" — the quickest way to say which gesture you mean.
struct GestureRecorder: View {
    @Binding var gesture: Gesture
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isRecording ? "hand.raised.fingers.spread" : gesture.systemImage)
                .font(.system(size: 22))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
                .symbolEffect(.pulse, isActive: isRecording)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(isRecording ? "Do the gesture on your trackpad…" : gesture.title)
                    .font(.title3)
                Text(isRecording ? "Any tap, swipe, pinch, rotation, click or TipTap." : "Record it, or choose below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isRecording ? "Cancel" : "Record") {
                isRecording ? stop() : start()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 2)
        }
        .animation(.smooth(duration: 0.2), value: isRecording)
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        GestureEngine.shared.recordingHandler = { recorded in
            gesture = recorded
            isRecording = false
        }
    }

    private func stop() {
        isRecording = false
        GestureEngine.shared.recordingHandler = nil
    }
}

/// A drawing of the trackpad with a dot for each finger touching it.
struct TrackpadView: View {
    let touches: [TouchPoint]
    let aspectRatio: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))

                ForEach(touches) { touch in
                    Circle()
                        .fill(touch.isTouching ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 26, height: 26)
                        // The trackpad measures from the bottom-left; the screen from the top-left.
                        .position(
                            x: touch.x * geometry.size.width,
                            y: (1 - touch.y) * geometry.size.height
                        )
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

/// An orange warning that macOS uses the same gesture. Hover to read it.
struct SystemWarningBadge: View {
    let text: String

    var body: some View {
        HoverBadge(systemImage: "exclamationmark.triangle.fill", color: .orange, accessibilityText: text) {
            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Trackpad Settings", action: SystemGestures.openTrackpadSettings)
            }
            .padding(16)
            .frame(width: 320)
        }
    }
}
