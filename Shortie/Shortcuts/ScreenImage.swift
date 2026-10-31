import AppKit

/// Finds a picture (say, a screenshot of a button) on screen.
/// macOS asks for Screen Recording permission the first time.
enum ScreenImage {
    /// The middle of the best match for the picture at `path`, or `nil` if it isn't on screen.
    nonisolated static func find(_ path: String) async -> CGPoint? {
        let file = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return await Task.detached(priority: .userInitiated) { search(for: file) }.value
    }

    /// Each display's picture, with where that display sits (in pointer coordinates).
    nonisolated static func captureDisplays() -> [(image: CGImage, bounds: CGRect)] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        let displays = Array(ids.prefix(Int(count)))
        guard !displays.isEmpty else { return [] }

        let folder = FileManager.default.temporaryDirectory.appending(path: "Shortie Capture \(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let files = displays.indices.map { folder.appending(path: "\($0).png") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x"] + files.map(\.path)
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()

        return files.enumerated().compactMap { index, file in
            guard let image = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return (image, CGDisplayBounds(displays[index]))
        }
    }

    private nonisolated static func search(for file: URL) -> CGPoint? {
        guard let template = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // Compare at a quarter of the size: much quicker, and still precise enough to click.
        let shrink = 4
        guard let small = Gray(template, shrink: shrink), small.width >= 2, small.height >= 2 else { return nil }

        var best: (score: Int, point: CGPoint)?
        for (image, bounds) in captureDisplays() {
            guard let screen = Gray(image, shrink: shrink), screen.width >= small.width, screen.height >= small.height else { continue }
            let pixels = small.width * small.height
            // Allow an average difference of about 6% per pixel.
            var limit = best?.score ?? pixels * 16
            for y in 0...(screen.height - small.height) {
                for x in 0...(screen.width - small.width) {
                    var total = 0
                    rows: for row in 0..<small.height {
                        let screenRow = (y + row) * screen.width + x
                        let templateRow = row * small.width
                        for column in 0..<small.width {
                            total += abs(Int(screen.pixels[screenRow + column]) - Int(small.pixels[templateRow + column]))
                        }
                        if total >= limit { break rows }
                    }
                    if total < limit {
                        limit = total
                        // From picture pixels back to screen points.
                        let scaleX = bounds.width / CGFloat(image.width)
                        let scaleY = bounds.height / CGFloat(image.height)
                        let centre = CGPoint(
                            x: bounds.minX + (CGFloat(x * shrink) + CGFloat(template.width) / 2) * scaleX,
                            y: bounds.minY + (CGFloat(y * shrink) + CGFloat(template.height) / 2) * scaleY
                        )
                        best = (total, centre)
                    }
                }
            }
        }
        return best?.point
    }

    /// A picture as one brightness value per pixel, shrunk.
    private nonisolated struct Gray {
        let width: Int
        let height: Int
        var pixels: [UInt8]

        init?(_ image: CGImage, shrink: Int) {
            width = max(image.width / shrink, 1)
            height = max(image.height / shrink, 1)
            pixels = [UInt8](repeating: 0, count: width * height)
            let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
                ) else { return false }
                context.interpolationQuality = .medium
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn else { return nil }
        }
    }
}

/// Trackpad gestures sent to the app under the pointer, as if you'd made them.
enum GestureSynth {
    /// The HID event system's gesture types and phases.
    private static let zoomType: Int64 = 8
    private static let rotateType: Int64 = 5
    private static let smartZoomType: Int64 = 22
    private static let began: Int64 = 1
    private static let changed: Int64 = 2
    private static let ended: Int64 = 4

    /// Pinches in or out by `amount` (0.5 is a good-sized pinch).
    static func zoom(by amount: Double) {
        Task {
            post(type: zoomType, phase: began, magnification: 0)
            for _ in 0..<10 {
                post(type: zoomType, phase: changed, magnification: amount / 10)
                try? await Task.sleep(for: .milliseconds(12))
            }
            post(type: zoomType, phase: ended, magnification: 0)
        }
    }

    /// Turns by `degrees` (positive is anticlockwise, like the trackpad).
    static func rotate(by degrees: Double) {
        Task {
            post(type: rotateType, phase: began, rotation: 0)
            for _ in 0..<10 {
                post(type: rotateType, phase: changed, rotation: degrees / 10)
                try? await Task.sleep(for: .milliseconds(12))
            }
            post(type: rotateType, phase: ended, rotation: 0)
        }
    }

    /// The two-finger double tap that zooms into what's under the pointer.
    static func smartZoom() {
        post(type: smartZoomType, phase: 0)
    }

    // MARK: Continuous

    private static var timer: Timer?
    private static var running: (type: Int64, step: Double)?

    /// Starts zooming or turning steadily, or stops if it already is.
    static func toggleSmooth(zoom: Bool, step: Double) {
        if let running {
            timer?.invalidate()
            timer = nil
            post(type: running.type, phase: ended)
            self.running = nil
            return
        }
        let type = zoom ? zoomType : rotateType
        running = (type, step)
        post(type: type, phase: began)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard let running = GestureSynth.running else { return }
                if running.type == zoomType {
                    post(type: running.type, phase: changed, magnification: running.step)
                } else {
                    post(type: running.type, phase: changed, rotation: running.step)
                }
            }
        }
    }

    private static func post(type: Int64, phase: Int64, magnification: Double = 0, rotation: Double = 0) {
        guard let event = CGEvent(source: nil) else { return }
        // Field numbers the window server uses for gesture events.
        event.setIntegerValueField(CGEventField(rawValue: 110)!, value: type)
        event.setIntegerValueField(CGEventField(rawValue: 132)!, value: phase)
        event.setDoubleValueField(CGEventField(rawValue: 113)!, value: magnification)
        event.setDoubleValueField(CGEventField(rawValue: 114)!, value: rotation)
        event.type = CGEventType(rawValue: 29)!
        event.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event.post(tap: .cghidEventTap)
    }
}
