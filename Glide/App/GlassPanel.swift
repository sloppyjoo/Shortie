import AppKit
import SwiftUI

/// A floating, borderless panel like Spotlight's, used for the window switcher
/// and clipboard history. It can take typing without making BestTouchTool
/// the active app, so the app you were using stays in front.
final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(size: NSSize, content: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = NSHostingView(rootView: content)
    }

    /// Shows it a little above the middle of the screen you're using, like Spotlight.
    func showCentred() {
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            setFrameOrigin(NSPoint(
                x: frame.midX - self.frame.width / 2,
                y: frame.midY - self.frame.height / 2 + frame.height / 8
            ))
        }
        makeKeyAndOrderFront(nil)
    }
}

/// Liquid Glass where it's available (macOS 26 and later), frosted glass before.
struct GlassBackground: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.regularMaterial)
        }
    }
}
