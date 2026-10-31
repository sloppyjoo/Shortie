import AppKit
import JavaScriptCore

/// A step that steers the steps around it: repeats, if/else, waiting, variables.
/// Only used inside "Several Actions".
nonisolated enum FlowStep: Codable, Hashable {
    case repeatStart(times: Int)
    case repeatEnd
    case breakRepeat
    case ifCondition(condition: FlowCondition)
    case elseBranch
    case endIf
    /// Waits until the condition is true; gives up (and stops) after `timeout` seconds.
    case waitUntil(condition: FlowCondition, timeout: Double)
    /// Stops here if these steps last ran less than this long ago.
    case debounce(seconds: Double)
    case stop
    case stopAll
    case setVariable(name: String, value: String)
    case increaseVariable(name: String, amount: Double)
    /// Flips between "true" and "false".
    case toggleVariable(name: String)
    case askForInput(name: String, prompt: String)
    case showVariables
    /// A note to yourself. Does nothing.
    case comment(text: String)

    enum Kind: String, CaseIterable, Identifiable {
        case repeatStart, repeatEnd, breakRepeat, ifCondition, elseBranch, endIf, waitUntil, debounce, stop, stopAll
        case setVariable, increaseVariable, toggleVariable, askForInput, showVariables, comment
        var id: Self { self }

        var title: String {
            switch self {
            case .repeatStart: "Repeat"
            case .repeatEnd: "End Repeat"
            case .breakRepeat: "Stop Repeating"
            case .ifCondition: "If"
            case .elseBranch: "Otherwise"
            case .endIf: "End If"
            case .waitUntil: "Wait Until"
            case .debounce: "Skip If Run Recently"
            case .stop: "Stop These Steps"
            case .stopAll: "Stop All Running Steps"
            case .setVariable: "Set Variable"
            case .increaseVariable: "Increase Variable"
            case .toggleVariable: "Toggle Variable"
            case .askForInput: "Ask for Text"
            case .showVariables: "Show Variables"
            case .comment: "Comment"
            }
        }

        var template: FlowStep {
            switch self {
            case .repeatStart: .repeatStart(times: 3)
            case .repeatEnd: .repeatEnd
            case .breakRepeat: .breakRepeat
            case .ifCondition: .ifCondition(condition: FlowCondition())
            case .elseBranch: .elseBranch
            case .endIf: .endIf
            case .waitUntil: .waitUntil(condition: FlowCondition(), timeout: 10)
            case .debounce: .debounce(seconds: 1)
            case .stop: .stop
            case .stopAll: .stopAll
            case .setVariable: .setVariable(name: "", value: "")
            case .increaseVariable: .increaseVariable(name: "", amount: 1)
            case .toggleVariable: .toggleVariable(name: "")
            case .askForInput: .askForInput(name: "", prompt: "")
            case .showVariables: .showVariables
            case .comment: .comment(text: "")
            }
        }

        static let groups: [[Kind]] = [
            [.ifCondition, .elseBranch, .endIf],
            [.repeatStart, .repeatEnd, .breakRepeat],
            [.waitUntil, .debounce, .stop, .stopAll],
            [.setVariable, .increaseVariable, .toggleVariable, .askForInput, .showVariables],
            [.comment],
        ]
    }

    var kind: Kind {
        switch self {
        case .repeatStart: .repeatStart
        case .repeatEnd: .repeatEnd
        case .breakRepeat: .breakRepeat
        case .ifCondition: .ifCondition
        case .elseBranch: .elseBranch
        case .endIf: .endIf
        case .waitUntil: .waitUntil
        case .debounce: .debounce
        case .stop: .stop
        case .stopAll: .stopAll
        case .setVariable: .setVariable
        case .increaseVariable: .increaseVariable
        case .toggleVariable: .toggleVariable
        case .askForInput: .askForInput
        case .showVariables: .showVariables
        case .comment: .comment
        }
    }

    var title: String {
        switch self {
        case .repeatStart(let times): "Repeat \(times) Times"
        case .ifCondition(let condition): "If \(condition.summary)"
        case .waitUntil(let condition, _): "Wait Until \(condition.summary)"
        case .debounce(let seconds): "Skip If Run in the Last \(seconds.formatted()) s"
        case .setVariable(let name, let value): "Set \(name) to “\(value)”"
        case .increaseVariable(let name, let amount): "Increase \(name) by \(amount.formatted())"
        case .toggleVariable(let name): "Toggle \(name)"
        case .askForInput(let name, _): "Ask for \(name)"
        case .comment(let text): text.isEmpty ? "Comment" : "// \(text)"
        default: kind.title
        }
    }

    /// Whether everything it needs is filled in.
    var isComplete: Bool {
        switch self {
        case .ifCondition(let condition), .waitUntil(let condition, _): condition.isComplete
        case .setVariable(let name, _), .increaseVariable(let name, _), .toggleVariable(let name), .askForInput(let name, _):
            !name.trimmingCharacters(in: .whitespaces).isEmpty
        default: true
        }
    }
}

/// Something that's either true or false right now.
nonisolated struct FlowCondition: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case appInFront, appRunning, variableIs, appleScript, javaScript, textOnScreen, clipboardChanged, windowChanged, keyPressed, ruleRan

        var id: Self { self }

        var title: String {
            switch self {
            case .appInFront: "App Is in Front"
            case .appRunning: "App Is Running"
            case .variableIs: "Variable Is"
            case .appleScript: "AppleScript Returns True"
            case .javaScript: "JavaScript Returns True"
            case .textOnScreen: "Text Is on Screen"
            case .clipboardChanged: "Clipboard Has Changed"
            case .windowChanged: "Front Window Has Changed"
            case .keyPressed: "A Key Was Pressed"
            case .ruleRan: "Another Rule Has Run"
            }
        }
    }

    var kind: Kind = .appInFront
    /// The app's path, the variable's name, the script or the text to look for.
    var text = ""
    /// The value a variable should have.
    var value = ""
    var isNegated = false

    var isComplete: Bool {
        switch kind {
        case .clipboardChanged, .windowChanged, .keyPressed: true
        default: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var summary: String {
        let not = isNegated ? "Not " : ""
        switch kind {
        case .appInFront:
            return "\(appName) Is \(not)in Front"
        case .appRunning:
            return "\(appName) Is \(not)Running"
        case .variableIs:
            return "\(text) Is \(not)“\(value)”"
        case .textOnScreen:
            return "“\(text)” Is \(not)on Screen"
        default:
            return isNegated ? "Not: \(kind.title)" : kind.title
        }
    }

    private var appName: String {
        text.isEmpty ? "App" : FileManager.default.displayName(atPath: text).replacingOccurrences(of: ".app", with: "")
    }
}

/// Named values your steps can set, change and test. They last until Shortie quits.
/// Write `{{name}}` in typed text, messages, web addresses and scripts to use one.
enum Variables {
    static var values: [String: String] = [:]

    static func expand(_ text: String) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return result
    }

    /// The action with `{{name}}` filled in wherever it carries text.
    static func expanded(_ action: ShortcutAction) -> ShortcutAction {
        guard !values.isEmpty else { return action }
        switch action {
        case .typeText(let text): return .typeText(text: expand(text))
        case .pasteText(let text): return .pasteText(text: expand(text))
        case .copyText(let text): return .copyText(text: expand(text))
        case .showMessage(let text): return .showMessage(text: expand(text))
        case .notify(let text): return .notify(text: expand(text))
        case .speak(let text): return .speak(text: expand(text))
        case .open(let target): return .open(target: expand(target))
        case .appleScript(let source): return .appleScript(source: expand(source))
        case .shellScript(let source): return .shellScript(source: expand(source))
        case .javaScript(let source): return .javaScript(source: expand(source))
        case .webRequest(var request):
            request.url = expand(request.url)
            request.body = expand(request.body)
            return .webRequest(request: request)
        default: return action
        }
    }
}

/// Runs "Several Actions", following any repeats, ifs and waits among the steps.
enum StepRunner {
    private static var running: [UUID: Task<Void, Never>] = [:]
    private static var lastRuns: [Int: Date] = [:]

    static func run(_ steps: [ShortcutAction], target: ActionTarget?) {
        let id = UUID()
        running[id] = Task {
            await execute(steps, target: target)
            running[id] = nil
        }
    }

    static func stopAll() {
        running.values.forEach { $0.cancel() }
        running.removeAll()
    }

    /// What things looked like when the steps (or a wait) began, for "has changed" conditions.
    struct Baseline {
        var clipboard = NSPasteboard.general.changeCount
        var window = Baseline.frontWindow()
        var keyPresses = ShortcutEngine.shared.keyPressCount
        var ruleRuns = ShortcutStore.shared.fireCounts

        static func frontWindow() -> String {
            guard let app = NSWorkspace.shared.frontmostApplication else { return "" }
            let title = AX.focusedWindow(of: app.processIdentifier).flatMap { AX.string($0, kAXTitleAttribute) } ?? ""
            return "\(app.processIdentifier) \(title)"
        }
    }

    private static func execute(_ steps: [ShortcutAction], target: ActionTarget?) async {
        let baseline = Baseline()
        var repeats: [(start: Int, remaining: Int)] = []
        var index = 0

        while index < steps.count, !Task.isCancelled {
            let step = steps[index]
            guard case .flow(let flow) = step else {
                if case .wait(let seconds) = step {
                    try? await Task.sleep(for: .seconds(seconds))
                } else {
                    ActionRunner.run(step, on: target)
                    // A moment for each step to take effect before the next.
                    try? await Task.sleep(for: .milliseconds(80))
                }
                index += 1
                continue
            }

            switch flow {
            case .repeatStart(let times):
                repeats.append((index, max(times, 1)))
                index += 1
            case .repeatEnd:
                if var loop = repeats.popLast() {
                    loop.remaining -= 1
                    if loop.remaining > 0 {
                        repeats.append(loop)
                        index = loop.start + 1
                        continue
                    }
                }
                index += 1
            case .breakRepeat:
                guard let loop = repeats.popLast() else {
                    index += 1
                    continue
                }
                index = matchingEnd(in: steps, from: loop.start, open: .repeatStart, close: [.repeatEnd]) + 1
            case .ifCondition(let condition):
                if await isTrue(condition, baseline: baseline) {
                    index += 1
                } else {
                    // Skip to just after "Otherwise", or past "End If".
                    index = matchingEnd(in: steps, from: index, open: .ifCondition, close: [.elseBranch, .endIf]) + 1
                }
            case .elseBranch:
                // Reached by finishing the "if" part, so skip the "otherwise" part.
                index = matchingEnd(in: steps, from: index, open: .ifCondition, close: [.endIf]) + 1
            case .endIf:
                index += 1
            case .waitUntil(let condition, let timeout):
                let start = Date.now
                let waitBaseline = Baseline()
                while !(await isTrue(condition, baseline: waitBaseline)) {
                    if Task.isCancelled || Date.now.timeIntervalSince(start) > timeout { return }
                    try? await Task.sleep(for: .milliseconds(condition.kind == .textOnScreen ? 1000 : 250))
                }
                index += 1
            case .debounce(let seconds):
                let key = steps.hashValue
                if let last = lastRuns[key], Date.now.timeIntervalSince(last) < seconds { return }
                lastRuns[key] = .now
                index += 1
            case .stop:
                return
            case .stopAll:
                stopAll()
                return
            case .setVariable(let name, let value):
                Variables.values[name] = Variables.expand(value)
                index += 1
            case .increaseVariable(let name, let amount):
                let current = Double(Variables.values[name] ?? "") ?? 0
                Variables.values[name] = (current + amount).formatted(.number.grouping(.never))
                index += 1
            case .toggleVariable(let name):
                Variables.values[name] = Variables.values[name] == "true" ? "false" : "true"
                index += 1
            case .askForInput(let name, let prompt):
                guard let answer = askForText(prompt.isEmpty ? "Enter \(name)" : prompt, current: Variables.values[name]) else { return }
                Variables.values[name] = answer
                index += 1
            case .showVariables:
                showVariables()
                index += 1
            case .comment:
                index += 1
            }
        }
    }

    /// The index of the step that closes the block opened at `start`, skipping nested blocks.
    private static func matchingEnd(in steps: [ShortcutAction], from start: Int, open: FlowStep.Kind, close: Set<FlowStep.Kind>) -> Int {
        let closer: FlowStep.Kind = open == .repeatStart ? .repeatEnd : .endIf
        var depth = 0
        var index = start + 1
        while index < steps.count {
            if case .flow(let flow) = steps[index] {
                if flow.kind == open {
                    depth += 1
                } else if depth > 0, flow.kind == closer {
                    depth -= 1
                } else if depth == 0, close.contains(flow.kind) {
                    return index
                }
            }
            index += 1
        }
        return steps.count
    }

    static func isTrue(_ condition: FlowCondition, baseline: Baseline? = nil) async -> Bool {
        let result: Bool
        switch condition.kind {
        case .appInFront:
            result = bundleID(of: condition.text).map { $0 == NSWorkspace.shared.frontmostApplication?.bundleIdentifier } ?? false
        case .appRunning:
            result = bundleID(of: condition.text).map { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty } ?? false
        case .variableIs:
            result = (Variables.values[condition.text] ?? "") == Variables.expand(condition.value)
        case .appleScript:
            var error: NSDictionary?
            let output = NSAppleScript(source: Variables.expand(condition.text))?.executeAndReturnError(&error)
            result = output?.booleanValue == true || output?.stringValue?.lowercased() == "true"
        case .javaScript:
            let context = JSContext()
            context?.setObject(Variables.values, forKeyedSubscript: "vars" as NSString)
            let body = condition.text.contains("return") ? condition.text : "return (\(condition.text));"
            result = context?.evaluateScript("(function () {\n\(body)\n})()")?.toBool() ?? false
        case .textOnScreen:
            result = await ScreenOCR.find(Variables.expand(condition.text)) != nil
        case .clipboardChanged:
            result = NSPasteboard.general.changeCount != (baseline?.clipboard ?? NSPasteboard.general.changeCount)
        case .windowChanged:
            result = Baseline.frontWindow() != (baseline?.window ?? Baseline.frontWindow())
        case .keyPressed:
            result = ShortcutEngine.shared.keyPressCount != (baseline?.keyPresses ?? ShortcutEngine.shared.keyPressCount)
        case .ruleRan:
            let id = UUID(uuidString: condition.text)
            let now = id.flatMap { ShortcutStore.shared.fireCounts[$0] } ?? 0
            let before = id.flatMap { baseline?.ruleRuns[$0] } ?? 0
            result = baseline == nil ? false : now > before
        }
        return condition.isNegated ? !result : result
    }

    private static func bundleID(of path: String) -> String? {
        Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier
    }

    private static func askForText(_ prompt: String, current: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = current ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    private static func showVariables() {
        let alert = NSAlert()
        alert.messageText = "Variables"
        alert.informativeText = Variables.values.isEmpty
            ? "No variables are set."
            : Variables.values.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }.joined(separator: "\n")
        NSApp.activate()
        alert.runModal()
    }
}
