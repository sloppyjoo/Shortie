import AppKit
import Security
import SwiftUI

/// What an AI action reads.
nonisolated enum AIInput: String, Codable, CaseIterable, Identifiable {
    case selection, clipboard, ask, none

    var id: Self { self }

    var title: String {
        switch self {
        case .selection: "Selected Text"
        case .clipboard: "Clipboard"
        case .ask: "Text I Type When It Runs"
        case .none: "Nothing (Just the Instructions)"
        }
    }
}

/// Where an AI action's answer goes.
nonisolated enum AIOutput: String, Codable, CaseIterable, Identifiable {
    case replaceSelection, paste, copy, show, variable, speak

    var id: Self { self }

    var title: String {
        switch self {
        case .replaceSelection: "Replace the Selection"
        case .paste: "Paste It"
        case .copy: "Copy It"
        case .show: "Show It"
        case .variable: "Put It in the Variable “ai”"
        case .speak: "Say It Aloud"
        }
    }
}

/// Talks to Claude through Anthropic's Messages API, with your own API key.
/// Nothing is sent anywhere until you run an AI action.
enum AI {
    /// The current Opus model; quick enough for text actions at low effort.
    nonisolated static let model = "claude-opus-5-5"

    private static var task: Task<Void, Never>?
    /// The ongoing conversation, for "Ask" actions and the chat window.
    private(set) static var history: [(role: String, text: String)] = []

    // MARK: Actions

    static func run(instructions: String, input: AIInput, output: AIOutput) {
        guard APIKey.value != nil else {
            HUD.show("Add Your Anthropic API Key in the Action First", systemImage: "key.fill")
            return
        }
        cancel()
        task = Task {
            let source: String?
            switch input {
            case .selection: source = await SelectedText.selectedText()
            case .clipboard: source = NSPasteboard.general.string(forType: .string)
            case .ask: source = askForText(instructions)
            case .none: source = ""
            }
            guard let source else { return }
            let prompt = source.isEmpty ? instructions : "\(instructions)\n\n<text>\n\(source)\n</text>"
            let system = output == .replaceSelection || output == .paste || output == .copy
                ? "You transform text for the user. Reply with only the resulting text: no preamble, no quotes, no explanation."
                : "You are a concise, helpful assistant. Answer briefly."

            HUD.show("Asking Claude…", systemImage: "sparkles")
            let result = await send([(role: "user", text: prompt)], system: system)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let answer): deliver(answer, to: output)
            case .failure(let error): HUD.show(error.message, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }

    static func cancel() {
        task?.cancel()
        task = nil
    }

    static func resetConversation() {
        history.removeAll()
        HUD.show("Conversation Cleared", systemImage: "sparkles")
    }

    /// One turn of the chat window's conversation.
    static func chat(_ text: String) async -> String {
        history.append((role: "user", text: text))
        switch await send(history, system: "You are a concise, helpful assistant.") {
        case .success(let answer):
            history.append((role: "assistant", text: answer))
            return answer
        case .failure(let error):
            history.removeLast()
            return "⚠️ \(error.message)"
        }
    }

    private static func deliver(_ answer: String, to output: AIOutput) {
        switch output {
        case .replaceSelection, .paste: ExtraActionRunner.paste(answer)
        case .copy: ExtraActionRunner.copy(answer)
        case .variable:
            Variables.values["ai"] = answer
            ExtraActionRunner.copy(answer)
        case .speak: Speaker.speak(answer)
        case .show:
            let alert = NSAlert()
            alert.messageText = "Claude"
            alert.informativeText = answer
            alert.addButton(withTitle: "Copy")
            alert.addButton(withTitle: "Close")
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn { ExtraActionRunner.copy(answer) }
        }
    }

    private static func askForText(_ prompt: String) -> String? {
        let alert = NSAlert()
        alert.messageText = prompt.isEmpty ? "Ask Claude" : prompt
        alert.addButton(withTitle: "Ask")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    // MARK: The request

    struct Failure: Error {
        let message: String
    }

    private static func send(_ messages: [(role: String, text: String)], system: String) async -> Result<String, Failure> {
        guard let key = APIKey.value else { return .failure(Failure(message: "No API key")) }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // If the model declines on safety grounds, let the API retry on a suitable fallback model.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": system,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "messages": messages.map { ["role": $0.role, "content": $0.text] },
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Request failed (\(status))"
                return .failure(Failure(message: status == 401 ? "The API key wasn't accepted" : message))
            }
            if json["stop_reason"] as? String == "refusal" {
                return .failure(Failure(message: "Claude declined this request"))
            }
            let text = (json["content"] as? [[String: Any]] ?? [])
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failure(Failure(message: "No answer came back")) : .success(text)
        } catch is CancellationError {
            return .failure(Failure(message: "Cancelled"))
        } catch {
            return .failure(Failure(message: "Couldn't reach Anthropic: \(error.localizedDescription)"))
        }
    }
}

/// Your Anthropic API key, kept in the macOS Keychain.
enum APIKey {
    private static let service = "Shortie Anthropic API Key"

    static var value: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self)
        return key.isEmpty ? nil : key
    }

    static func save(_ key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}

// MARK: - Chat window

/// A small floating chat with Claude, sharing the "Ask" conversation.
final class AIChatPanel: NSObject {
    static let shared = AIChatPanel()

    private var window: NSPanel?

    func show() {
        if APIKey.value == nil {
            HUD.show("Add Your Anthropic API Key in an AI Action First", systemImage: "key.fill")
            return
        }
        let window = self.window ?? {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                styleMask: [.titled, .closable, .resizable, .utilityWindow],
                backing: .buffered, defer: false
            )
            panel.title = "Claude"
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: AIChatView())
            panel.center()
            return panel
        }()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

private struct AIChatView: View {
    @State private var messages: [ChatMessage] = AI.history.map { ChatMessage(role: $0.role, text: $0.text) }
    @State private var draft = ""
    @State private var isWaiting = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            Text(message.text)
                                .textSelection(.enabled)
                                .padding(10)
                                .background(message.role == "user" ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.quaternary), in: .rect(cornerRadius: 10))
                                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                                .id(message.id)
                        }
                        if isWaiting {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { scroller.scrollTo(messages.last?.id) }
            }
            Divider()
            HStack {
                TextField("Ask Claude", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit(send)
                Button("Clear") {
                    AI.resetConversation()
                    messages.removeAll()
                }
                Button("Send", action: send)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isWaiting)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWaiting else { return }
        draft = ""
        messages.append(ChatMessage(role: "user", text: text))
        isWaiting = true
        Task {
            let answer = await AI.chat(text)
            messages.append(ChatMessage(role: "assistant", text: answer))
            isWaiting = false
        }
    }
}
