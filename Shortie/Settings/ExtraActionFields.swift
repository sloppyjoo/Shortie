import SwiftUI
import UniformTypeIdentifiers

/// The controls for the newer actions: an app to show or quit, a brightness,
/// an exact window position, a web address…
struct ExtraActionFields: View {
    @Binding var action: ShortcutAction

    @State private var inputSources: [InputSources.Source] = []
    @State private var sounds: [String] = []

    /// Edits the one piece of text the action carries.
    private var payload: Binding<String> {
        Binding(get: { action.payload }, set: { action = action.with(payload: $0) })
    }

    var body: some View {
        switch action {
        case .appTask(let task, let path):
            HStack {
                Picker("Task", selection: Binding(get: { task }, set: { action = .appTask(task: $0, path: path) })) {
                    ForEach(AppTask.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                if path.isEmpty {
                    Text("No app chosen")
                        .foregroundStyle(.secondary)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
                        .lineLimit(1)
                }
                Spacer()
                Button("Choose App…") {
                    if let chosen = AppChooser.choose() { action = .appTask(task: task, path: chosen) }
                }
            }

        case .setBrightness(let percent):
            HStack {
                Image(systemName: "sun.min.fill")
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(percent) },
                    set: { action = .setBrightness(percent: Int($0)) }
                ), in: 0...100, step: 5)
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
                Text("\(percent)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

        case .windowFrame(let frame):
            VStack(alignment: .leading, spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        percentField("From left", frame.x) { var f = frame; f.x = $0; action = .windowFrame(frame: f) }
                        percentField("From top", frame.y) { var f = frame; f.y = $0; action = .windowFrame(frame: f) }
                    }
                    GridRow {
                        percentField("Width", frame.width) { var f = frame; f.width = $0; action = .windowFrame(frame: f) }
                        percentField("Height", frame.height) { var f = frame; f.height = $0; action = .windowFrame(frame: f) }
                    }
                }
                Text("Percent of the screen, not counting the menu bar and Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .moveToDisplay(let number):
            let names = WindowMover.displayNames
            Picker("Display", selection: Binding(get: { number }, set: { action = .moveToDisplay(number: $0) })) {
                ForEach(1...max(names.count, number, 2), id: \.self) { index in
                    let name = names.indices.contains(index - 1) ? " (\(names[index - 1]))" : ""
                    Text("Display \(index)\(name)").tag(index)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Displays are numbered from left to right.")

        case .movePointer(let x, let y):
            HStack {
                pointField("X", x) { action = .movePointer(x: $0, y: y) }
                pointField("Y", y) { action = .movePointer(x: x, y: $0) }
                InfoButton("Points from the top-left corner of your main display. Other displays continue from there, so a display to the left has negative X.")
                Spacer()
            }

        case .copyText, .pasteText:
            TextEditor(text: payload)
                .font(.body)
                .frame(height: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))

        case .notify:
            TextField("Notification", text: payload, prompt: Text("Time to stretch"))
                .textFieldStyle(.roundedBorder)

        case .webRequest(let request):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Method", selection: Binding(get: { request.method }, set: { var r = request; r.method = $0; action = .webRequest(request: r) })) {
                        ForEach(WebRequest.methods, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    TextField("Address", text: Binding(get: { request.url }, set: { var r = request; r.url = $0; action = .webRequest(request: r) }),
                              prompt: Text("https://example.com/webhook"))
                        .textFieldStyle(.roundedBorder)
                }
                if request.method != "GET" {
                    TextEditor(text: Binding(get: { request.body }, set: { var r = request; r.body = $0; action = .webRequest(request: r) }))
                        .font(.body.monospaced())
                        .frame(height: 70)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.background, in: .rect(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    Text("Body to send. JSON is sent as JSON.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .inputSource(let id, _):
            Picker("Input source", selection: Binding(
                get: { id },
                set: { newID in action = .inputSource(id: newID, name: inputSources.first { $0.id == newID }?.name ?? "") }
            )) {
                Text("Next Input Source").tag(InputSources.nextID)
                Divider()
                ForEach(inputSources) { Text($0.name).tag($0.id) }
                if id != InputSources.nextID, !inputSources.contains(where: { $0.id == id }) {
                    Text(action.title).tag(id)
                }
            }
            .labelsHidden()
            .fixedSize()
            .onAppear { inputSources = InputSources.all() }

        case .playSound(let name):
            Picker("Sound", selection: Binding(get: { name }, set: { SystemSounds.play($0); action = .playSound(name: $0) })) {
                ForEach(sounds.contains(name) ? sounds : sounds + [name], id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .onAppear { sounds = SystemSounds.names() }

        case .pressKeysInApp(let combo, let path):
            VStack(alignment: .leading, spacing: 8) {
                appRow(path) { action = .pressKeysInApp(combo: combo, path: $0) }
                HStack {
                    Text("Keys")
                        .foregroundStyle(.secondary)
                    ShortcutRecorder(
                        keyCombo: Binding(get: { combo }, set: { action = .pressKeysInApp(combo: $0, path: path) }),
                        isRecording: $isRecordingKeys,
                        allowsPlainKeys: true
                    )
                }
                Text("Works even when the app is in the background. Some apps only listen when they're in front.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .modifierKeys(let modifiers, let down):
            HStack {
                Picker("Hold or let go", selection: Binding(get: { down }, set: { action = .modifierKeys(modifiers: modifiers, down: $0) })) {
                    Text("Hold Down").tag(true)
                    Text("Let Go of").tag(false)
                }
                .labelsHidden()
                .fixedSize()
                ModifierToggles(modifiers: Binding(get: { modifiers }, set: { action = .modifierKeys(modifiers: $0, down: down) }))
                InfoButton("Held keys stay down until a step lets go of them, so pair this with a \"Let Go of\" step.")
            }

        case .moveToDesktop(let number):
            HStack {
                Picker("Desktop", selection: Binding(get: { number }, set: { action = .moveToDesktop(number: $0) })) {
                    ForEach(1...9, id: \.self) { Text("Desktop \($0)").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                InfoButton("Uses macOS's ⌃1–⌃9 shortcuts. Switch them on in System Settings › Keyboard › Keyboard Shortcuts › Mission Control.")
            }

        case .focusWindow:
            TextField("Window title", text: payload, prompt: Text("Part of the window's title, like Inbox"))
                .textFieldStyle(.roundedBorder)

        case .transformText(_, let onClipboard):
            VStack(alignment: .leading, spacing: 8) {
                Picker("Change", selection: Binding(
                    get: { onClipboard },
                    set: { action = .transformText(script: action.payload, onClipboard: $0) }
                )) {
                    Text("Selected Text").tag(false)
                    Text("Clipboard").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                codeEditor(payload)
                Text("JavaScript. The text is `text`; return the new text. A single expression works too, like `text.trim()`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .browserJavaScript:
            VStack(alignment: .leading, spacing: 8) {
                codeEditor(payload)
                Text("Runs in the page in front, in Safari or a Chrome-based browser. Turn on \"Allow JavaScript from Apple Events\" in the browser's Develop menu first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .runWorkflow:
            HStack {
                TextField("Workflow", text: payload, prompt: Text("~/Library/Services/My Workflow.workflow"))
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType(filenameExtension: "workflow") ?? .package]
                    panel.treatsFilePackagesAsDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        payload.wrappedValue = (url.path as NSString).abbreviatingWithTildeInPath
                    }
                }
            }

        case .pauseShortie(let seconds):
            Stepper(value: Binding(get: { seconds }, set: { action = .pauseShortie(seconds: $0) }), in: 1...3600, step: 5) {
                Text("\(Int(seconds)) seconds")
                    .monospacedDigit()
            }
            .fixedSize()

        case .clickButton:
            HStack {
                TextField("Button", text: payload, prompt: Text("The button's name, like Save"))
                    .textFieldStyle(.roundedBorder)
                InfoButton("Presses the button, checkbox or tab with this name in the window you're using.")
            }

        case .clickMenuBarExtra:
            HStack {
                TextField("Menu bar icon", text: payload, prompt: Text("Its name or its app's name, like Wi-Fi or Dropbox"))
                    .textFieldStyle(.roundedBorder)
                InfoButton("Clicks an icon on the right of the menu bar, found by its name.")
            }

        case .distributedNotification:
            TextField("Notification name", text: payload, prompt: Text("com.example.refresh"))
                .textFieldStyle(.roundedBorder)

        case .otherRule(let id, _, let mode):
            HStack {
                Picker("Mode", selection: Binding(get: { mode }, set: { action = .otherRule(id: id, name: ruleName(id), mode: $0) })) {
                    ForEach(RuleMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Picker("Rule", selection: Binding(get: { id }, set: { action = .otherRule(id: $0, name: ruleName($0), mode: mode) })) {
                    Text("Choose a Rule").tag(UUID?.none)
                    ForEach(ShortcutStore.shared.shortcuts) { shortcut in
                        Text(Self.label(for: shortcut)).tag(UUID?.some(shortcut.id))
                    }
                }
                .labelsHidden()
            }

        default:
            EmptyView()
        }
    }

    @State private var isRecordingKeys = false

    private func appRow(_ path: String, choose: @escaping (String) -> Void) -> some View {
        HStack {
            if path.isEmpty {
                Text("No app chosen")
                    .foregroundStyle(.secondary)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
                    .lineLimit(1)
            }
            Spacer()
            Button("Choose App…") {
                if let chosen = AppChooser.choose() { choose(chosen) }
            }
        }
    }

    private func codeEditor(_ text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.body.monospaced())
            .frame(height: 90)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(.background, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
    }

    private func ruleName(_ id: UUID?) -> String {
        ShortcutStore.shared.shortcuts.first { $0.id == id }.map(Self.label) ?? ""
    }

    /// How a rule is named in lists: what sets it off, then what it does.
    static func label(for shortcut: Shortcut) -> String {
        let trigger: String = switch shortcut.trigger {
        case .keys(let combo): combo.displayString
        case .gesture(let gesture): gesture.title
        case .mouseButton(let click): click.title
        case .trafficLight(let click): "\(click.clickDescription) \(click.button.title)"
        case .typedText(let abbreviation): abbreviation
        case .event(let event): event.kind.title
        case .modifierTap(let tap): tap.title
        case nil: "No Trigger"
        }
        return "\(trigger) → \(shortcut.action.title)"
    }

    private func percentField(_ label: String, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            TextField(label, value: Binding(get: { value }, set: { set(min(max($0, 0), 100)) }), format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .labelsHidden()
            Text("%")
                .foregroundStyle(.secondary)
        }
    }

    private func pointField(_ label: String, _ value: Int, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            TextField(label, value: Binding(get: { value }, set: set), format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .labelsHidden()
        }
    }
}
