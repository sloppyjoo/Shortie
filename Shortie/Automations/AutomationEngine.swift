import AppKit
import IOKit.ps
import Network

/// Runs your automations when things happen: apps opening, quitting or switching,
/// the Mac waking or sleeping, the screen locking, the charger, displays, disks,
/// Spaces and the internet connection.
///
/// These all come from notifications macOS already sends to every app, so no
/// extra permission is needed.
final class AutomationEngine {
    static let shared = AutomationEngine()

    private var isStarted = false
    private var wasOnCharger: Bool?
    private var displayCount = NSScreen.screens.count
    private var isOnline: Bool?
    private let network = NWPathMonitor()

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didLaunchApplicationNotification) { .appLaunched(bundleID: $0) }
        observe(workspace, NSWorkspace.didTerminateApplicationNotification) { .appQuit(bundleID: $0) }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { .appActivated(bundleID: $0) }
        observe(workspace, NSWorkspace.didDeactivateApplicationNotification) { .appDeactivated(bundleID: $0) }
        observe(workspace, NSWorkspace.didWakeNotification, .macWoke)
        observe(workspace, NSWorkspace.willSleepNotification, .macWillSleep)
        observe(workspace, NSWorkspace.screensDidSleepNotification, .displaySlept)
        observe(workspace, NSWorkspace.screensDidWakeNotification, .displayWoke)
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification, .spaceChanged)
        observe(workspace, NSWorkspace.didMountNotification, .diskMounted)
        observe(workspace, NSWorkspace.didUnmountNotification, .diskEjected)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .screenLocked)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .screenUnlocked)
        observe(distributed, Notification.Name("com.apple.screensaver.didstart"), .screenSaverStarted)
        observe(distributed, Notification.Name("com.apple.screensaver.didstop"), .screenSaverStopped)

        // Displays: compare how many there are each time the arrangement changes.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AutomationEngine.shared.screensChanged() }
        }

        // Internet: the first answer is just how things are now, not a change.
        network.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            DispatchQueue.main.async { AutomationEngine.shared.networkChanged(isOnline) }
        }
        network.start(queue: .global(qos: .utility))

        // Power changes come through IOKit instead.
        wasOnCharger = Self.isOnCharger
        if let source = IOPSNotificationCreateRunLoopSource(handlePowerChange, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    /// For events about a whole app: the event is built from the app's ID.
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: @escaping @Sendable (String) -> AutomationEvent) {
        center.addObserver(forName: name, object: nil, queue: .main) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let bundleID = app?.bundleIdentifier else { return }
            MainActor.assumeIsolated { AutomationEngine.shared.fire(event(bundleID)) }
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: AutomationEvent) {
        center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AutomationEngine.shared.fire(event) }
        }
    }

    private func screensChanged() {
        let count = NSScreen.screens.count
        defer { displayCount = count }
        if count > displayCount { fire(.displayConnected) }
        if count < displayCount { fire(.displayDisconnected) }
    }

    private func networkChanged(_ online: Bool) {
        defer { isOnline = online }
        guard let isOnline, isOnline != online else { return }
        fire(online ? .internetConnected : .internetDisconnected)
    }

    fileprivate func powerChanged() {
        let isOnCharger = Self.isOnCharger
        defer { wasOnCharger = isOnCharger }
        guard let wasOnCharger, wasOnCharger != isOnCharger else { return }
        fire(isOnCharger ? .chargerConnected : .chargerDisconnected)
    }

    private static var isOnCharger: Bool {
        let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        return source == kIOPMACPowerKey
    }

    /// Runs every switched-on automation for this event, in order.
    private func fire(_ event: AutomationEvent) {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused) else { return }
        for shortcut in ShortcutStore.shared.shortcuts where shortcut.isEnabled && shortcut.event == event {
            ActionRunner.run(shortcut.action)
        }
    }
}

/// Called by IOKit on the main run loop whenever the power source changes.
private nonisolated func handlePowerChange(_ context: UnsafeMutableRawPointer?) {
    MainActor.assumeIsolated { AutomationEngine.shared.powerChanged() }
}
