import SwiftUI

/// The welcome window. Explains what Glide does and walks you through
/// granting permissions, updating live as you flip switches in System Settings.
struct OnboardingView: View {
    @AppStorage(DefaultsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    private var permissions = Permissions.shared

    var body: some View {
        VStack(spacing: 28) {
            header

            GroupBox {
                PermissionRow.accessibility(permissions)
                    .padding(10)
            }

            Text("Shortie never records or sends anything you type.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(permissions.allGranted ? "Start Using Shortie" : "Set Up Later") {
                hasCompletedOnboarding = true
                WindowManager.shared.close(.onboarding)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .tint(permissions.allGranted ? .accentColor : .secondary)
        }
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 540)
        // You'll usually grant permission over in System Settings. When you do,
        // bring this window back so you can see the checkmark and carry on.
        .onChange(of: permissions.allGranted) { _, granted in
            if granted { NSApp.activate() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            PixelIcon(pixels: PixelArt.hand, size: 64)
                .foregroundStyle(.tint)
                .padding(.bottom, 6)

            Text("Welcome to Shortie")
                .font(.largeTitle.bold())

            Text("Customise your keyboard shortcuts, trackpad gestures and mouse buttons.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    OnboardingView()
}
