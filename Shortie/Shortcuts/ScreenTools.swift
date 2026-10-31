import AppKit
@preconcurrency import Vision

/// Copy Text from Screen: drag over any text on screen (in a picture, a video,
/// a window that won't let you select it) and it's copied as text.
enum ScreenText {
    static func copy() {
        let file = FileManager.default.temporaryDirectory.appending(path: "Shortie Text Capture.png")
        try? FileManager.default.removeItem(at: file)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i lets you drag a selection; -x skips the shutter sound.
        process.arguments = ["-i", "-x", file.path]
        process.terminationHandler = { _ in
            Task { @MainActor in recognise(file) }
        }
        try? process.run()
    }

    private static func recognise(_ file: URL) {
        // No file means you pressed Escape.
        guard let image = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        try? FileManager.default.removeItem(at: file)

        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
            Task { @MainActor in
                guard !lines.isEmpty else {
                    HUD.show("No Text Found", systemImage: "text.viewfinder")
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                HUD.show("Text Copied", systemImage: "text.viewfinder")
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: image).perform([request])
        }
    }
}

/// Pick Colour from Screen: the system magnifier, then the colour you click is
/// copied as a hex code like #7B5CF0.
enum ColourPicker {
    static func pick() {
        NSApp.activate()
        NSColorSampler().show { colour in
            guard let colour = colour?.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X",
                             Int((colour.redComponent * 255).rounded()),
                             Int((colour.greenComponent * 255).rounded()),
                             Int((colour.blueComponent * 255).rounded()))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            HUD.show("Copied \(hex)", systemImage: "eyedropper")
        }
    }
}
