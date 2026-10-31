import SwiftUI

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

        default:
            EmptyView()
        }
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
