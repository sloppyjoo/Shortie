import SwiftUI

/// The Gestures section of the dashboard. For now it's the Gesture Lab: a live
/// view of your fingers and the gestures Glide recognises, so we can check
/// detection works well before gestures can run actions.
struct GesturesSettingsView: View {
    private var engine = GestureEngine.shared

    var body: some View {
        Form {
            switch engine.status {
            case .unavailable:
                Section {
                    Label(
                        "Glide couldn't connect to your trackpad. A macOS update may have changed how trackpads report touches.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            case .notStarted:
                Section {
                    Text("Gestures start once Glide has Accessibility permission.")
                        .foregroundStyle(.secondary)
                }
            case .running:
                lab
            }
        }
        .formStyle(.grouped)
        .onAppear { engine.isWatching = true }
        .onDisappear { engine.isWatching = false }
    }

    @ViewBuilder
    private var lab: some View {
        Section {
            TrackpadView(touches: engine.liveTouches, aspectRatio: engine.aspectRatio)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } header: {
            Text("Gesture Lab")
        } footer: {
            Text("Try taps, swipes and clicks with different numbers of fingers. Your fingers show up live, and each gesture Glide recognises appears below.")
        }

        Section("Recognised") {
            if engine.recentGestures.isEmpty {
                Text("Nothing yet. Try a three-finger tap.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.recentGestures) { recognized in
                    HStack {
                        Text(recognized.gesture.title)
                            .fontWeight(recognized.id == engine.recentGestures.first?.id ? .semibold : .regular)
                        Spacer()
                        Text(recognized.date, format: .dateTime.hour().minute().second())
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: engine.recentGestures.map(\.id))
    }
}

/// A drawing of the trackpad with a dot for each finger touching it.
struct TrackpadView: View {
    let touches: [TouchPoint]
    let aspectRatio: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))

                ForEach(touches) { touch in
                    Circle()
                        .fill(touch.isTouching ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 26, height: 26)
                        // The trackpad measures from the bottom-left; the screen from the top-left.
                        .position(
                            x: touch.x * geometry.size.width,
                            y: (1 - touch.y) * geometry.size.height
                        )
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
