import AppKit
import Metal
import QuartzCore

/// Brighter than the brightness slider allows, on displays with HDR headroom
/// (like the Liquid Retina XDR display in a MacBook Pro).
///
/// A one-pixel HDR picture in the corner wakes up the display's extra headroom,
/// then the display's colour curve is lifted so everyday content uses it too.
/// Switching off puts the colour curve back.
enum SuperBrightness {
    private static var window: NSWindow?
    /// How much brighter: 1.0 is normal.
    private static let boost: Float = 1.6

    static var isOn: Bool { window != nil }

    static func toggle() {
        isOn ? set(false) : set(true)
    }

    static func set(_ on: Bool) {
        if !on {
            window?.orderOut(nil)
            window = nil
            CGDisplayRestoreColorSyncSettings()
            HUD.show("Super Brightness Off", systemImage: "sun.max")
            return
        }
        guard !isOn else { return }
        guard let screen = NSScreen.screens.first(where: { $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else {
            HUD.show("This Display Can't Go Brighter", systemImage: "sun.max.trianglebadge.exclamationmark")
            return
        }

        let headroom = Double(min(screen.maximumPotentialExtendedDynamicRangeColorComponentValue, CGFloat(boost)))
        let frame = NSRect(x: screen.frame.maxX - 1, y: screen.frame.maxY - 1, width: 1, height: 1)
        let overlay = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        overlay.level = .screenSaver
        overlay.ignoresMouseEvents = true
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        layer.drawableSize = CGSize(width: 1, height: 1)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        view.wantsLayer = true
        view.layer = layer
        overlay.contentView = view
        overlay.orderFrontRegardless()

        // Paint the pixel brighter than white, which is what turns on the headroom.
        if let drawable = layer.nextDrawable(), let commands = queue.makeCommandBuffer() {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: headroom, green: headroom, blue: headroom, alpha: 1)
            commands.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
            commands.present(drawable)
            commands.commit()
        }
        window = overlay

        // Lift the colour curve so the extra headroom is used everywhere.
        let gain = Float(headroom)
        CGSetDisplayTransferByFormula(displayID, 0, gain, 1, 0, gain, 1, 0, gain, 1)
        HUD.show("Super Brightness On", systemImage: "sun.max.fill")
    }
}
