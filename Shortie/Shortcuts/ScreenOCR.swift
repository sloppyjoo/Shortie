import AppKit
@preconcurrency import Vision

/// Reads the text on every display, to find where a word or phrase is.
/// macOS asks for Screen Recording permission the first time.
enum ScreenOCR {
    /// The middle of the first place `text` appears on screen (in the
    /// coordinates the pointer uses), or `nil` if it's nowhere.
    nonisolated static func find(_ text: String) async -> CGPoint? {
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        return await Task.detached(priority: .userInitiated) { search(for: wanted) }.value
    }

    private nonisolated static func search(for wanted: String) -> CGPoint? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        let displays = Array(ids.prefix(Int(count)))
        guard !displays.isEmpty else { return nil }

        let folder = FileManager.default.temporaryDirectory.appending(path: "Shortie OCR \(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        // One picture per display, main display first, the same order as the display list.
        let files = displays.indices.map { folder.appending(path: "\($0).png") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x"] + files.map(\.path)
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()

        for (index, file) in files.enumerated() {
            guard let image = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: image).perform([request])
            for observation in request.results ?? [] {
                guard let candidate = observation.topCandidates(1).first,
                      let range = candidate.string.range(of: wanted, options: [.caseInsensitive, .diacriticInsensitive])
                else { continue }
                let box = (try? candidate.boundingBox(for: range))?.boundingBox ?? observation.boundingBox
                let bounds = CGDisplayBounds(displays[index])
                // Vision measures from the bottom-left, as fractions of the picture.
                return CGPoint(x: bounds.minX + box.midX * bounds.width, y: bounds.minY + (1 - box.midY) * bounds.height)
            }
        }
        return nil
    }
}
