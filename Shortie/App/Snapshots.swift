#if DEBUG
import AppKit
import SwiftUI

/// Development only: launched with `--snapshots <folder>`, Shortie draws
/// every dashboard page and a few editors to PNG files (light and dark), then
/// quits. Used to check layouts for cut-off or overlapping text.
enum Snapshots {
    static func runIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--snapshots"), index + 1 < arguments.count else { return false }
        let folder = URL(fileURLWithPath: arguments[index + 1])
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            for pane in SettingsPane.allCases {
                render(SettingsView(initialPane: pane), size: NSSize(width: 760, height: 620), appearance: appearance,
                       to: folder.appending(path: "\(pane.rawValue)-\(suffix).png"))
            }
            let editors: [(String, AnyView)] = [
                ("onboarding", AnyView(OnboardingView())),
                ("get-started", AnyView(GetStartedView(choose: { _ in }, back: {}).padding(40).frame(width: 540))),
                ("import", AnyView(BTTImportView(done: {}).padding(40).frame(width: 540))),
                ("action-library", AnyView(ActionLibrary(current: .mouseClick, forSteps: false) { _ in })),
                ("action-library-windows", AnyView(ActionLibrary(current: .moveWindow, forSteps: false, drill: .moveWindow, currentAction: .moveWindow(position: .leftHalf)) { _ in })),
                ("action-library-system", AnyView(ActionLibrary(current: .system, forSteps: false, drill: .system, currentAction: .system(action: .playPause)) { _ in })),
                ("action-library-steps", AnyView(ActionLibrary(current: .flow, forSteps: true) { _ in })),
                ("action-library-search", AnyView(ActionLibrary(current: .mouseClick, forSteps: false, query: "click") { _ in })),
                ("editor-gesture-click", AnyView(GestureEditor(gesture: .tap(fingers: 3), action: .mouseClick(click: .middleClick), apps: nil) { _, _, _ in })),
                ("editor-ai", AnyView(ActionEditor(keyCombo: nil, action: .ai(instructions: "Fix the spelling and grammar", input: .selection, output: .replaceSelection), apps: nil) { _, _, _ in })),
                ("editor-flow", AnyView(ActionEditor(keyCombo: nil, action: .steps(actions: [.flow(step: .ifCondition(condition: FlowCondition())), .typeText(text: "Hello"), .flow(step: .elseBranch), .flow(step: .repeatStart(times: 3)), .mouseClick(click: .leftClick), .flow(step: .repeatEnd), .flow(step: .endIf)]), apps: nil) { _, _, _ in })),
                ("action-search", AnyView(ActionSearchList(forSteps: false) { _ in })),
                ("action-search-max", AnyView(ActionSearchList(forSteps: false, query: "max") { _ in })),
                ("action-search-typed", AnyView(ActionSearchList(forSteps: false, typedLater: "desktop") { _ in })),
                ("editor-keyboard", AnyView(ActionEditor(keyCombo: nil, action: .openApp(path: "/System/Applications/Safari.app"), apps: nil) { _, _, _ in })),
                ("editor-gesture", AnyView(GestureEditor(gesture: .swipe(fingers: 3, direction: .down), action: .system(action: .controlCentre), apps: AppScope(mode: .only, bundleIDs: ["com.apple.Safari", "com.apple.finder"])) { _, _, _ in })),
                ("editor-window-button", AnyView(TrafficLightEditor(click: TrafficLightClick(button: .zoom, mouseButton: .left, modifiers: []), action: .moveWindow(position: .maximize), apps: nil) { _, _, _ in })),
                ("editor-steps", AnyView(ActionEditor(keyCombo: nil, action: .steps(actions: [.pressKeys(combo: KeyPreset.groups[1].presets[0].combo), .wait(seconds: 0.3), .open(target: "google.com")]), apps: nil) { _, _, _ in })),
            ]
            for (name, view) in editors {
                render(view, size: nil, appearance: appearance, to: folder.appending(path: "\(name)-\(suffix).png"))
            }
        }
        NSApp.terminate(nil)
        return true
    }

    private static func render(_ view: some View, size: NSSize?, appearance: NSAppearance.Name, to url: URL) {
        let controller = NSHostingController(rootView: view.lookTint())
        controller.sceneBridgingOptions = .all
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: appearance)
        if let size { window.setContentSize(size) }
        // Off screen, out of the way.
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        SettingsView.pinSidebarWidth(in: window)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        guard let frameView = window.contentView?.superview,
              let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds)
        else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}
#endif
