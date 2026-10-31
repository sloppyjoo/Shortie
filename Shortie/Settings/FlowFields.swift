import SwiftUI

/// The controls for a Control Flow step: which kind, then its details.
struct FlowFields: View {
    @Binding var action: ShortcutAction

    var body: some View {
        if case .flow(let step) = action {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Step", selection: Binding(get: { step.kind }, set: { action = .flow(step: $0.template) })) {
                    ForEach(FlowStep.Kind.groups, id: \.self) { group in
                        Section {
                            ForEach(group) { Text($0.title).tag($0) }
                        }
                    }
                }
                .labelsHidden()
                .fixedSize()
                details(step)
            }
        }
    }

    private func set(_ step: FlowStep) {
        action = .flow(step: step)
    }

    @ViewBuilder
    private func details(_ step: FlowStep) -> some View {
        switch step {
        case .repeatStart(let times):
            Stepper(value: Binding(get: { times }, set: { set(.repeatStart(times: $0)) }), in: 1...1000) {
                Text("\(times) times").monospacedDigit()
            }
            .fixedSize()
            caption("Repeats the steps between here and End Repeat.")
        case .ifCondition(let condition):
            ConditionEditor(condition: Binding(get: { condition }, set: { set(.ifCondition(condition: $0)) }))
            caption("Runs the steps up to Otherwise or End If only when this is true.")
        case .waitUntil(let condition, let timeout):
            ConditionEditor(condition: Binding(get: { condition }, set: { set(.waitUntil(condition: $0, timeout: timeout)) }))
            Stepper(value: Binding(get: { timeout }, set: { set(.waitUntil(condition: condition, timeout: $0)) }), in: 1...3600, step: 1) {
                Text("Give up after \(Int(timeout)) seconds").monospacedDigit()
            }
            .fixedSize()
        case .debounce(let seconds):
            Stepper(value: Binding(get: { seconds }, set: { set(.debounce(seconds: $0)) }), in: 0.1...600, step: 0.5) {
                Text("\(seconds.formatted()) seconds").monospacedDigit()
            }
            .fixedSize()
            caption("Stops here if these steps ran less than this long ago, so a bouncy trigger only runs once.")
        case .setVariable(let name, let value):
            HStack {
                nameField(name) { set(.setVariable(name: $0, value: value)) }
                Text("to").foregroundStyle(.secondary)
                TextField("Value", text: Binding(get: { value }, set: { set(.setVariable(name: name, value: $0)) }))
                    .textFieldStyle(.roundedBorder)
            }
            caption("Use it in text, messages, web addresses and scripts by writing {{\(name.isEmpty ? "name" : name)}}.")
        case .increaseVariable(let name, let amount):
            HStack {
                nameField(name) { set(.increaseVariable(name: $0, amount: amount)) }
                Text("by").foregroundStyle(.secondary)
                TextField("Amount", value: Binding(get: { amount }, set: { set(.increaseVariable(name: name, amount: $0)) }), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
        case .toggleVariable(let name):
            nameField(name) { set(.toggleVariable(name: $0)) }
            caption("Switches between true and false.")
        case .askForInput(let name, let prompt):
            HStack {
                nameField(name) { set(.askForInput(name: $0, prompt: prompt)) }
                TextField("Question", text: Binding(get: { prompt }, set: { set(.askForInput(name: name, prompt: $0)) }), prompt: Text("What should I search for?"))
                    .textFieldStyle(.roundedBorder)
            }
        case .breakRepeat:
            caption("Leaves the repeat it's in and carries on after End Repeat.")
        case .stopAll:
            caption("Also stops any other steps that are still running or waiting.")
        default:
            EmptyView()
        }
    }

    private func nameField(_ name: String, set: @escaping (String) -> Void) -> some View {
        TextField("Variable", text: Binding(get: { name }, set: set), prompt: Text("name"))
            .textFieldStyle(.roundedBorder)
            .frame(width: 130)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Chooses what to test, and its details.
struct ConditionEditor: View {
    @Binding var condition: FlowCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Condition", selection: $condition.kind) {
                    ForEach(FlowCondition.Kind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Toggle("Not", isOn: $condition.isNegated)
                    .help("Reverses the test: true when the condition isn't met.")
            }
            switch condition.kind {
            case .appInFront, .appRunning:
                HStack {
                    if condition.text.isEmpty {
                        Text("No app chosen").foregroundStyle(.secondary)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: condition.text))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(FileManager.default.displayName(atPath: condition.text).replacingOccurrences(of: ".app", with: ""))
                    }
                    Spacer()
                    Button("Choose App…") {
                        if let path = AppChooser.choose() { condition.text = path }
                    }
                }
            case .variableIs:
                HStack {
                    TextField("Variable", text: $condition.text, prompt: Text("name"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                    Text("is").foregroundStyle(.secondary)
                    TextField("Value", text: $condition.value)
                        .textFieldStyle(.roundedBorder)
                }
            case .appleScript, .javaScript:
                TextEditor(text: $condition.text)
                    .font(.body.monospaced())
                    .frame(height: 70)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.background, in: .rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                Text(condition.kind == .javaScript
                     ? "Return true or false. Variables are in `vars`, like vars.count > 3."
                     : "Return true or false.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .textOnScreen:
                TextField("Text", text: $condition.text, prompt: Text("Text to look for"))
                    .textFieldStyle(.roundedBorder)
                Text("Reads the screen, so macOS asks for Screen Recording permission the first time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .clipboardChanged, .windowChanged, .keyPressed:
                Text("Compared with when the steps started (or, for Wait Until, when the wait started).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
