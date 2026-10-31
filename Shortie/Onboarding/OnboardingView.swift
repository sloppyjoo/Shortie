import SwiftUI

/// The welcome window. First it walks you through granting permissions, updating
/// live as you flip switches in System Settings. Then, the first time, it offers
/// a way to get started: import from BetterTouchTool, start with the everyday set,
/// or start empty.
struct OnboardingView: View {
    @AppStorage(DefaultsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(DefaultsKey.look) private var look = Look.retro
    private var permissions = Permissions.shared

    enum Page { case welcome, getStarted, importer, everyday }
    @State private var page = Page.welcome

    var body: some View {
        Group {
            switch page {
            case .welcome: welcome
            case .getStarted: GetStartedView(choose: choose, back: { page = .welcome })
            case .importer: BTTImportView(done: finish, back: { page = .getStarted })
            case .everyday: ComingNextView(title: "The Everyday Set", back: { page = .getStarted })
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 540)
        .animation(.smooth(duration: 0.25), value: page)
        // You'll usually grant permission over in System Settings. When you do,
        // bring this window back so you can see the checkmark and carry on.
        .onChange(of: permissions.allGranted) { _, granted in
            if granted { NSApp.activate() }
        }
    }

    // MARK: - Welcome and permissions

    private var welcome: some View {
        VStack(spacing: 28) {
            header

            GroupBox {
                PermissionRow.accessibility(permissions)
                    .padding(10)
            }

            HStack(spacing: 10) {
                Text("Look")
                    .foregroundStyle(.secondary)
                LookPicker()
            }

            Text("Shortie never records or sends anything you type.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(permissions.allGranted ? "Continue" : "Set Up Later", action: next)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .tint(permissions.allGranted ? look.tint : .secondary)
        }
        .transition(.opacity)
    }

    /// The first time through, choose how to get started. After that (for example
    /// when this window comes back because a permission was turned off), just close.
    private func next() {
        if hasCompletedOnboarding {
            WindowManager.shared.close(.onboarding)
        } else {
            page = .getStarted
        }
    }

    private func choose(_ choice: GetStartedView.Choice) {
        switch choice {
        case .importer: page = .importer
        case .everyday: page = .everyday
        case .empty: finish()
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        WindowManager.shared.close(.onboarding)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Group {
                if look == .retro {
                    PixelIcon(pixels: PixelArt.hand, size: 64)
                } else {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .foregroundStyle(.tint)
            .frame(height: 64)
            .padding(.bottom, 6)

            Text("Welcome to Shortie")
                .font(.largeTitle.bold())

            Text("Customise your keyboard shortcuts, trackpad gestures and mouse buttons.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The second page: how to get started.
struct GetStartedView: View {
    enum Choice { case importer, everyday, empty }

    let choose: (Choice) -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Get Started")
                    .font(.largeTitle.bold())
                Text("Bring your setup across, or start with a few useful shortcuts. You can change everything later.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ChoiceRow(
                    title: "Import from BetterTouchTool",
                    detail: "Bring across shortcuts and gestures from a BetterTouchTool preset.",
                    pixels: PixelArt.disk, systemImage: "square.and.arrow.down"
                ) { choose(.importer) }
                ChoiceRow(
                    title: "Start with the Everyday Set",
                    detail: "Window, app and media shortcuts most people use every day.",
                    pixels: PixelArt.hand, systemImage: "sparkles"
                ) { choose(.everyday) }
                ChoiceRow(
                    title: "Start Empty",
                    detail: "Set everything up yourself.",
                    pixels: PixelArt.page, systemImage: "doc"
                ) { choose(.empty) }
            }

            Button("Back", action: back)
                .buttonStyle(.link)
        }
        .transition(.opacity)
    }
}

/// One big, clickable choice: icon, title, one line, and a chevron.
private struct ChoiceRow: View {
    let title: String
    let detail: String
    let pixels: [String]
    let systemImage: String
    let action: () -> Void

    @AppStorage(DefaultsKey.look) private var look = Look.retro
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Group {
                    if look == .retro {
                        PixelIcon(pixels: pixels, size: 32)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 22))
                    }
                }
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0.04))
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// A placeholder for the import and everyday-set pages, which come next.
private struct ComingNextView: View {
    let title: String
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.largeTitle.bold())
            Text("Not built yet.")
                .foregroundStyle(.secondary)
            Button("Back", action: back)
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }
}

#Preview {
    OnboardingView()
}
