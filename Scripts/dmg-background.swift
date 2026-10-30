// Draws the background for Shortie's DMG window.
// Usage: swift Scripts/dmg-background.swift <output.png> <scale>
// The window is 640 × 400 points; scale 1 and 2 make the normal and Retina images.
import AppKit

let arguments = CommandLine.arguments
let output = URL(fileURLWithPath: arguments[1])
let scale = CGFloat(Double(arguments[2]) ?? 1)
let size = CGSize(width: 640, height: 400)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

// A pale wash, white at the top to lavender at the bottom.
NSGradient(colors: [
    NSColor(srgbRed: 0.98, green: 0.98, blue: 1.0, alpha: 1),
    NSColor(srgbRed: 0.93, green: 0.92, blue: 1.0, alpha: 1),
])!.draw(in: CGRect(origin: .zero, size: size), angle: -90)

// Soft blue and violet glows behind each icon, the colours of the app icon.
func glow(at point: CGPoint, color: NSColor) {
    NSGradient(colors: [color.withAlphaComponent(0.22), color.withAlphaComponent(0)])!
        .draw(fromCenter: point, radius: 0, toCenter: point, radius: 190, options: [])
}
// Finder places icons from the top-left; AppKit draws from the bottom-left.
let iconY = size.height - 180
glow(at: CGPoint(x: 170, y: iconY), color: NSColor(srgbRed: 0.29, green: 0.42, blue: 1.0, alpha: 1))
glow(at: CGPoint(x: 470, y: iconY), color: NSColor(srgbRed: 0.61, green: 0.24, blue: 0.94, alpha: 1))

// An arrow from Shortie to Applications.
let arrow = NSBezierPath()
arrow.move(to: CGPoint(x: 268, y: iconY))
arrow.line(to: CGPoint(x: 368, y: iconY))
arrow.move(to: CGPoint(x: 352, y: iconY + 14))
arrow.line(to: CGPoint(x: 370, y: iconY))
arrow.line(to: CGPoint(x: 352, y: iconY - 14))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(srgbRed: 0.45, green: 0.36, blue: 0.95, alpha: 0.75).setStroke()
arrow.stroke()

// One line of instructions near the bottom.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let caption = NSAttributedString(string: "Drag Shortie into Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(srgbRed: 0.43, green: 0.43, blue: 0.47, alpha: 1),
    .paragraphStyle: paragraph,
])
caption.draw(in: CGRect(x: 0, y: 46, width: size.width, height: 20))

_ = context
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: output)
