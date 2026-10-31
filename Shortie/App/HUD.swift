import AppKit
import SwiftUI

/// A small glass message near the bottom of the screen, like the one macOS
/// shows when you change the volume. It fades away on its own and never
/// takes clicks or focus.
enum HUD {
    private static var panel: GlassPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ text: String, systemImage: String) {
        hideTask?.cancel()
        panel?.orderOut(nil)

        let view = HUDView(text: text, systemImage: systemImage)
        let size = NSHostingView(rootView: view).fittingSize
        let panel = GlassPanel(size: size, content: view)
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.minY + 120))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
            if self.panel === panel { self.panel = nil }
        }
    }
}

private struct HUDView: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 28)
            Text(text)
                .font(.title3.weight(.medium))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(GlassBackground(cornerRadius: 26))
        .fixedSize()
    }
}
