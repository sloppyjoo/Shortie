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
            HStack {
                Picker("Sound", selection: Binding(get: { name }, set: { SystemSounds.play($0); action = .playSound(name: $0) })) {
                    ForEach(sounds.contains(name) ? sounds : sounds + [name], id: \.self) { sound in
                        Text(((sound as NSString).lastPathComponent as NSString).deletingPathExtension).tag(sound)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onAppear { sounds = SystemSounds.names() }
                Button("Choose File…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.audio]
                    if panel.runModal() == .OK, let url = panel.url {
                        action = .playSound(name: (url.path as NSString).abbreviatingWithTildeInPath)
                        SystemSounds.play(url.path)
                    }
                }
            }

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

        case .soundInput(let uid, _):
            Picker("Input", selection: Binding(
                get: { uid },
                set: { newUID in action = .soundInput(uid: newUID, name: inputs.first { $0.uid == newUID }?.name ?? "") }
            )) {
                Text("Next Input").tag(SoundInput.nextDeviceUID)
                Divider()
                ForEach(inputs) { Text($0.name).tag($0.uid) }
                if uid != SoundInput.nextDeviceUID, !inputs.contains(where: { $0.uid == uid }) {
                    Text(action.title).tag(uid)
                }
            }
            .labelsHidden()
            .fixedSize()
            .onAppear { inputs = SoundInput.devices() }

        case .clipboardItem(let number, let remove):
            HStack {
                Stepper(value: Binding(get: { number }, set: { action = .clipboardItem(number: $0, remove: remove) }), in: 1...100) {
                    Text(number == 1 ? "Newest item" : "Item \(number)").monospacedDigit()
                }
                .fixedSize()
                Toggle("Remove it from history", isOn: Binding(get: { remove }, set: { action = .clipboardItem(number: number, remove: $0) }))
            }

        case .pointerSetting(let setting, let value, let alternate):
            VStack(alignment: .leading, spacing: 8) {
                Picker("Setting", selection: Binding(get: { setting }, set: {
                    action = .pointerSetting(setting: $0, value: min(max(value, $0.range.lowerBound), $0.range.upperBound), alternate: nil)
                })) {
                    ForEach(PointerSetting.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                pointerSlider(setting, value) { action = .pointerSetting(setting: setting, value: $0, alternate: alternate) }
                Toggle("Switch back and forth with another value", isOn: Binding(
                    get: { alternate != nil },
                    set: { action = .pointerSetting(setting: setting, value: value, alternate: $0 ? setting.range.upperBound : nil) }
                ))
                if let alternate {
                    pointerSlider(setting, alternate) { action = .pointerSetting(setting: setting, value: value, alternate: $0) }
                }
            }

        case .keyboardBrightness(let percent):
            HStack {
                Image(systemName: "light.min").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(percent) }, set: { action = .keyboardBrightness(percent: Int($0)) }), in: 0...100, step: 5)
                Image(systemName: "light.max").foregroundStyle(.secondary)
                Text("\(percent)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

        case .customClick(let click):
            HStack {
                Picker("Button", selection: Binding(get: { click.button }, set: { var c = click; c.button = $0; action = .customClick(click: c) })) {
                    ForEach(CustomClick.Button.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Picker("Times", selection: Binding(get: { click.count }, set: { var c = click; c.count = $0; action = .customClick(click: c) })) {
                    Text("Once").tag(1)
                    Text("Twice").tag(2)
                    Text("Three Times").tag(3)
                }
                .labelsHidden()
                .fixedSize()
                ModifierToggles(modifiers: Binding(get: { click.modifiers }, set: { var c = click; c.modifiers = $0; action = .customClick(click: c) }))
            }

        case .remapKey(let from, let to):
            HStack {
                Text("Make").foregroundStyle(.secondary)
                keyPicker(from) { action = .remapKey(from: $0, to: to) }
                Text("act as").foregroundStyle(.secondary)
                keyPicker(to) { action = .remapKey(from: from, to: $0) }
                InfoButton("Works in every app until \"Put All Remapped Keys Back\" runs or Shortie quits.")
            }

        case .openSettingsPane(let pane):
            Picker("Page", selection: Binding(get: { pane }, set: { action = .openSettingsPane(pane: $0) })) {
                ForEach(SettingsPane.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .labelsHidden()
            .fixedSize()

        case .callService:
            HStack {
                TextField("Service", text: payload, prompt: Text("Its name in the Services menu, like Make New Sticky Note"))
                    .textFieldStyle(.roundedBorder)
                InfoButton("Runs on the selected text. If the service changes the text, the result replaces the selection.")
            }

        case .bluetoothDevice(let address, _, let mode):
            HStack {
                Picker("Mode", selection: Binding(get: { mode }, set: { action = .bluetoothDevice(address: address, name: bluetoothName(address), mode: $0) })) {
                    ForEach(ConnectMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Picker("Device", selection: Binding(get: { address }, set: { action = .bluetoothDevice(address: $0, name: bluetoothName($0), mode: mode) })) {
                    Text("Choose a Device").tag("")
                    ForEach(bluetooth) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .fixedSize()
            }
            .onAppear { bluetooth = BluetoothDevices.paired() }

        case .midi(let destination, let bytes):
            VStack(alignment: .leading, spacing: 8) {
                Picker("Destination", selection: Binding(get: { destination }, set: { action = .midi(destination: $0, bytes: bytes) })) {
                    Text("Choose a Destination").tag("")
                    ForEach(midiDestinations, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .onAppear { midiDestinations = MIDI.destinations() }
                TextField("Bytes", text: Binding(get: { bytes }, set: { action = .midi(destination: destination, bytes: $0) }), prompt: Text("90 3C 7F"))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                Text("Hex bytes, like 90 3C 7F for note on, middle C, full velocity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .osc(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Host", text: Binding(get: { message.host }, set: { var m = message; m.host = $0; action = .osc(message: m) }), prompt: Text("127.0.0.1"))
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", value: Binding(get: { message.port }, set: { var m = message; m.port = $0; action = .osc(message: m) }), format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                }
                TextField("Address", text: Binding(get: { message.address }, set: { var m = message; m.address = $0; action = .osc(message: m) }), prompt: Text("/lights/1/on"))
                    .textFieldStyle(.roundedBorder)
                TextField("Arguments", text: Binding(get: { message.arguments }, set: { var m = message; m.arguments = $0; action = .osc(message: m) }), prompt: Text("1 0.5 \"some text\""))
                    .textFieldStyle(.roundedBorder)
            }

        case .externalBrightness(let percent):
            HStack {
                Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(percent) }, set: { action = .externalBrightness(percent: Int($0)) }), in: 0...100, step: 5)
                Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                Text("\(percent)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                InfoButton("For external displays on Apple silicon Macs, over the display cable. Not every display allows it.")
            }

        case .contextMenuItem:
            TextField("Menu item", text: payload, prompt: Text("The item's name, like Copy Link"))
                .textFieldStyle(.roundedBorder)

        case .slider(let name, let value, let relative):
            HStack {
                TextField("Slider", text: Binding(get: { name }, set: { action = .slider(name: $0, value: value, relative: relative) }), prompt: Text("Its name, or blank for the first"))
                    .textFieldStyle(.roundedBorder)
                Picker("How", selection: Binding(get: { relative }, set: { action = .slider(name: name, value: value, relative: $0) })) {
                    Text("Set to").tag(false)
                    Text("Change by").tag(true)
                }
                .labelsHidden()
                .fixedSize()
                TextField("Value", value: Binding(get: { value }, set: { action = .slider(name: name, value: $0, relative: relative) }), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }

        default:
            EmptyView()
        }
    }

    @State private var bluetooth: [BluetoothDevices.Device] = []
    @State private var midiDestinations: [String] = []

    private func bluetoothName(_ address: String) -> String {
        bluetooth.first { $0.id == address }?.name ?? ""
    }

    private func keyPicker(_ keyCode: UInt16, set: @escaping (UInt16) -> Void) -> some View {
        Picker("Key", selection: Binding(get: { keyCode }, set: set)) {
            ForEach(KeyRemapper.keyCodes, id: \.self) { Text(KeyRemapper.name(for: $0)).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
    }

    @State private var inputs: [SoundOutput.Device] = []

    private func pointerSlider(_ setting: PointerSetting, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack {
            Slider(value: Binding(get: { value }, set: { set(($0 * 20).rounded() / 20) }), in: setting.range)
            Text(value.formatted(.number.precision(.fractionLength(2))))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
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

/// The controls for a searchable list: where its lines come from, and what to do with the pick.
struct SearchListFields: View {
    @Binding var action: ShortcutAction

    var body: some View {
        if case .searchList(let source, let fromScript, let output) = action {
            VStack(alignment: .leading, spacing: 8) {
                Picker("From", selection: Binding(get: { fromScript }, set: { action = .searchList(source: source, fromScript: $0, output: output) })) {
                    Text("These Lines").tag(false)
                    Text("A Shell Script's Output").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                TextEditor(text: Binding(get: { source }, set: { action = .searchList(source: $0, fromScript: fromScript, output: output) }))
                    .font(fromScript ? .body.monospaced() : .body)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.background, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                Picker("Then", selection: Binding(get: { output }, set: { action = .searchList(source: source, fromScript: fromScript, output: $0) })) {
                    ForEach(ListOutput.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                Text(fromScript ? "Each line the script prints is one choice." : "One choice per line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The controls for an AI action: what to ask, what it reads, where the answer goes, and the API key.
struct AIFields: View {
    @Binding var action: ShortcutAction

    @State private var key = ""
    @State private var hasKey = APIKey.value != nil

    var body: some View {
        if case .ai(let instructions, let input, let output) = action {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: Binding(get: { instructions }, set: { action = .ai(instructions: $0, input: input, output: output) }))
                    .frame(height: 70)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.background, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                Picker("Reads", selection: Binding(get: { input }, set: { action = .ai(instructions: instructions, input: $0, output: output) })) {
                    ForEach(AIInput.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                Picker("Then", selection: Binding(get: { output }, set: { action = .ai(instructions: instructions, input: input, output: $0) })) {
                    ForEach(AIOutput.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                HStack {
                    SecureField(hasKey ? "API key saved in Keychain" : "Anthropic API key (sk-ant-…)", text: $key)
                        .textFieldStyle(.roundedBorder)
                    Button(hasKey && key.isEmpty ? "Remove Key" : "Save Key") {
                        APIKey.save(key)
                        key = ""
                        hasKey = APIKey.value != nil
                    }
                    .disabled(!hasKey && key.isEmpty)
                }
                Text("Uses Claude (\(AI.model)) with your own key from console.anthropic.com. The text is sent to Anthropic only when the action runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
