import SwiftUI
import UniformTypeIdentifiers

/// Bring rules across from BetterTouchTool: pick a preset (or have BetterTouchTool
/// export one), see what will come across, then add it. Used in the welcome window
/// and from General.
struct BTTImportView: View {
    /// Called when you're finished, whether or not anything was added.
    let done: () -> Void
    /// Shown as a link at the bottom of the first step, if given.
    var back: (() -> Void)?
    var backTitle = "Back"

    private enum Step {
        case start
        case exporting
        case review(name: String, items: [ImportItem])
        case added(Int)
    }

    @AppStorage(DefaultsKey.look) private var look = Look.retro
    @State private var step = Step.start
    @State private var problem: String?
    @State private var isChoosingFile = false

    private static let bttBundleID = "com.hegenberg.BetterTouchTool"
    private var bttInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bttBundleID) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch step {
            case .start: start
            case .exporting: exporting
            case let .review(name, items): review(name: name, items: items)
            case .added(let count): added(count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: Self.presetTypes) { result in
            if case .success(let url) = result { open(url) }
        }
        #if DEBUG
        // For snapshots: open a sample preset straight away.
        .onAppear {
            if let path = UserDefaults.standard.string(forKey: "bttSample") { open(URL(fileURLWithPath: path)) }
        }
        #endif
    }

    // MARK: - Steps

    private var start: some View {
        Group {
            title("Import from BetterTouchTool",
                  "Shortie reads a BetterTouchTool preset and adds the shortcuts and gestures it can do. Nothing you already have is changed.")

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    exportFromBTT()
                } label: {
                    Label("Import from BetterTouchTool", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(look.tint)
                .disabled(!bttInstalled)

                Button {
                    isChoosingFile = true
                } label: {
                    Text("Choose a Preset File…")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Text(bttInstalled
                     ? "BetterTouchTool will export your current preset for Shortie to read."
                     : "BetterTouchTool isn't on this Mac. You can still choose a preset you exported (File › Export Preset in BetterTouchTool).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let back {
                Button(backTitle, action: back)
                    .buttonStyle(.link)
            }
        }
    }

    private var exporting: some View {
        Group {
            title("Import from BetterTouchTool", "Waiting for BetterTouchTool to export your preset…")
            ProgressView()
                .frame(maxWidth: .infinity)
            Button("Cancel") { step = .start }
                .buttonStyle(.link)
        }
    }

    private func review(name: String, items: [ImportItem]) -> some View {
        let ready = items.filter { if case .ready = $0.outcome { true } else { false } }
        let clashes = items.filter { if case .clash = $0.outcome { true } else { false } }
        let unsupported = items.filter { if case .unsupported = $0.outcome { true } else { false } }

        return Group {
            title("Import “\(name)”", summary(ready: ready.count, clashes: clashes.count, unsupported: unsupported.count))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ImportSection(title: "Ready to Add", systemImage: "checkmark.circle.fill", color: .green, items: ready, isExpanded: true)
                    ImportSection(title: "Already in Use", systemImage: "arrow.triangle.branch", color: .orange, items: clashes, isExpanded: ready.isEmpty)
                    ImportSection(title: "Not in Shortie Yet", systemImage: "circle.dashed", color: .secondary, items: unsupported, isExpanded: ready.isEmpty && clashes.isEmpty)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 260)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))

            HStack {
                Button("Back") { step = .start }
                    .buttonStyle(.link)
                Spacer()
                Button(ready.isEmpty ? "Close" : "Add \(ready.count) \(ready.count == 1 ? "Shortcut" : "Shortcuts")") {
                    add(ready)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .tint(look.tint)
            }
        }
    }

    private func added(_ count: Int) -> some View {
        Group {
            title("All Done", count == 1 ? "Added 1 shortcut. You'll find it in Settings." : "Added \(count) shortcuts. You'll find them in Settings.")
            HStack {
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .tint(look.tint)
            }
        }
    }

    private func title(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
            Text(detail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summary(ready: Int, clashes: Int, unsupported: Int) -> String {
        var parts = ["\(ready) ready to add"]
        if clashes > 0 { parts.append("\(clashes) already in use, so skipped") }
        if unsupported > 0 { parts.append("\(unsupported) Shortie can't do yet") }
        return parts.joined(separator: ", ") + "."
    }

    // MARK: - Doing it

    private static let presetTypes: [UTType] = [UTType(filenameExtension: "bttpreset"), .json].compactMap { $0 }

    private func open(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let items = try BTTImport.read(data, existing: ShortcutStore.shared.shortcuts)
            problem = nil
            step = .review(name: BTTImport.presetName(data) ?? url.deletingPathExtension().lastPathComponent, items: items)
        } catch {
            problem = (error as? LocalizedError)?.errorDescription ?? "Shortie couldn't read that file."
            step = .start
        }
    }

    /// Asks BetterTouchTool to export its current preset to a file, then waits for it.
    private func exportFromBTT() {
        problem = nil
        let output = FileManager.default.temporaryDirectory.appending(path: "Shortie BTT Export.bttpreset")
        try? FileManager.default.removeItem(at: output)

        var link = URLComponents(string: "btt://export_preset/")!
        link.queryItems = [URLQueryItem(name: "outputPath", value: output.path)]
        guard let url = link.url, NSWorkspace.shared.open(url) else {
            problem = "Shortie couldn't reach BetterTouchTool."
            return
        }

        step = .exporting
        Task { @MainActor in
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(250))
                guard case .exporting = step else { return }
                if FileManager.default.fileExists(atPath: output.path) {
                    // Give it a moment to finish writing.
                    try? await Task.sleep(for: .milliseconds(300))
                    NSApp.activate()
                    open(output)
                    return
                }
            }
            guard case .exporting = step else { return }
            problem = "BetterTouchTool didn't export anything. In BetterTouchTool, export your preset (File › Export Preset), then choose the file here."
            step = .start
        }
    }

    private func add(_ ready: [ImportItem]) {
        let shortcuts = ready.compactMap(\.shortcut)
        guard !shortcuts.isEmpty else { return done() }
        ShortcutStore.shared.shortcuts.append(contentsOf: shortcuts)
        step = .added(shortcuts.count)
    }
}

/// One group of rules in the review, folded away when there are lots.
private struct ImportSection: View {
    let title: String
    let systemImage: String
    let color: Color
    let items: [ImportItem]
    @State var isExpanded: Bool

    var body: some View {
        if !items.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.summary)
                                .lineLimit(2)
                            if let note = item.note {
                                Text(note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 4)
            } label: {
                Label("\(title) (\(items.count))", systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(color, .primary)
            }
        }
    }
}

extension ImportItem {
    /// Why it won't be added, if it won't.
    var note: String? {
        switch outcome {
        case .ready: nil
        case .clash(let reason), .unsupported(let reason): reason
        }
    }
}
