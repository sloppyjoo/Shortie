import SwiftUI
import UniformTypeIdentifiers

/// "Works in: All Apps / Only These Apps / All Apps Except", plus the chosen apps.
/// Used in every editor.
struct AppScopePicker: View {
    @Binding var scope: AppScope?

    private enum Choice: Hashable {
        case all, only, except
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Works in", selection: choice) {
                Text("All Apps").tag(Choice.all)
                Text("Only These Apps").tag(Choice.only)
                Text("All Apps Except").tag(Choice.except)
            }
            .labelsHidden()
            .fixedSize()

            if let scope {
                FlowRow {
                    ForEach(scope.bundleIDs, id: \.self) { bundleID in
                        AppChip(bundleID: bundleID) { remove(bundleID) }
                    }
                    addMenu
                }
                if !scope.isValid {
                    Text("Add at least one app.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var choice: Binding<Choice> {
        Binding(
            get: {
                switch scope?.mode {
                case nil: .all
                case .only: .only
                case .except: .except
                }
            },
            set: { newValue in
                let apps = scope?.bundleIDs ?? []
                switch newValue {
                case .all: scope = nil
                case .only: scope = AppScope(mode: .only, bundleIDs: apps)
                case .except: scope = AppScope(mode: .except, bundleIDs: apps)
                }
            }
        )
    }

    /// Your open apps for quick picking, or any app from the Applications folder.
    private var addMenu: some View {
        Menu("Add App", systemImage: "plus") {
            Section("Open Apps") {
                ForEach(openApps, id: \.bundleIdentifier) { app in
                    Button {
                        add(app.bundleIdentifier)
                    } label: {
                        Label {
                            Text(app.localizedName ?? app.bundleIdentifier ?? "")
                        } icon: {
                            if let icon = app.icon { Image(nsImage: icon) }
                        }
                    }
                }
            }
            Button("Other App…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.allowsMultipleSelection = true
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                panel.prompt = "Add"
                if panel.runModal() == .OK {
                    panel.urls.forEach { add(Bundle(url: $0)?.bundleIdentifier) }
                }
            }
        }
        .fixedSize()
    }

    private var openApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .filter { !(scope?.bundleIDs.contains($0.bundleIdentifier ?? "") ?? false) }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID, var current = scope, !current.bundleIDs.contains(bundleID) else { return }
        current.bundleIDs.append(bundleID)
        scope = current
    }

    private func remove(_ bundleID: String) {
        scope?.bundleIDs.removeAll { $0 == bundleID }
    }
}

/// One chosen app: its icon and name, with a button to remove it.
struct AppChip: View {
    let bundleID: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            AppIcon(bundleID: bundleID, size: 16)
            Text(AppInfo.name(of: bundleID))
                .lineLimit(1)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(AppInfo.name(of: bundleID))")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .background(.quaternary.opacity(0.6), in: .capsule)
    }
}

/// Shown on a row when a shortcut only works in some apps: "Only in" or
/// "Not in", followed by the apps' icons. Hover for their names.
struct AppScopeBadge: View {
    let scope: AppScope

    var body: some View {
        HStack(spacing: 3) {
            Text(scope.mode == .only ? "Only in" : "Not in")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(scope.bundleIDs.prefix(3), id: \.self) { bundleID in
                AppIcon(bundleID: bundleID, size: 16)
            }
            if scope.bundleIDs.count > 3 {
                Text("+\(scope.bundleIDs.count - 3)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .help((scope.mode == .only ? "Only in " : "Not in ") + scope.bundleIDs.map(AppInfo.name).joined(separator: ", "))
    }
}

struct AppIcon: View {
    let bundleID: String
    let size: CGFloat

    var body: some View {
        Image(nsImage: AppInfo.icon(of: bundleID))
            .resizable()
            .frame(width: size, height: size)
    }
}

enum AppInfo {
    static func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func name(of bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(of bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Lays out its children left to right, wrapping onto new lines like text.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
