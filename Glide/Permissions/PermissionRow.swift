import SwiftUI

/// One permission, explained in plain words, with a button to allow it.
/// Used in both the welcome window and Settings.
struct PermissionRow: View {
    let title: String
    let explanation: String
    let systemImage: String
    let isGranted: Bool
    /// Extra help shown while the permission is still missing.
    var hint: String? = nil
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.blue.gradient, in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint, !isGranted {
                    Label(hint, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 12)

            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Allow…", action: grant)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: isGranted)
    }
}

extension PermissionRow {
    /// The Accessibility row, wired up to `Permissions`.
    static func accessibility(_ permissions: Permissions) -> PermissionRow {
        PermissionRow(
            title: "Accessibility",
            explanation: "Lets Glide respond to your gestures and shortcuts, and move windows for you.",
            systemImage: "accessibility",
            isGranted: permissions.accessibility,
            // macOS sometimes keeps an old, stale entry for Glide (for example after
            // an update), which looks switched on but doesn't count.
            hint: permissions.hasAskedForAccessibility
                ? "Already switched on? Select Glide in the list, click −, then click Allow… again."
                : nil,
            grant: permissions.requestAccessibility
        )
    }
}
