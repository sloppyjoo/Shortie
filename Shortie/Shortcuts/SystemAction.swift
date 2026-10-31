import AppKit
import ApplicationServices
import Carbon.HIToolbox
import IOKit.hidsystem

/// Built-in Mac things a shortcut or gesture can do: media keys, Control Centre,
/// Mission Control, screenshots, locking the screen…
nonisolated enum SystemAction: String, Codable, CaseIterable, Identifiable {
    case playPause, nextTrack, previousTrack
    case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    case toggleMicrophone, keyboardBrightnessUp, keyboardBrightnessDown
    case controlCentre, notificationCentre, missionControl, appExpose, showDesktop, apps, spotlight, emojiAndSymbols
    case windowSwitcher, clipboardHistory
    case screenshotTool, screenshotSelection, screenshotScreen
    case lockScreen, sleepDisplay, sleep
    case toggleDarkMode, toggleDockHiding, toggleMenuBarHiding, toggleHiddenFiles, toggleDesktopIcons
    case screenSaver, forceQuit, ejectAll
    case logOut, restart, shutDown
    case openDashboard, togglePause
    case volumeUpSmall, volumeDownSmall, brightnessUpSmall, brightnessDownSmall
    case previousApp, hideAllApps, showAllApps, siri, spaceLeft, spaceRight
    case screenshotWindow, screenshotSelectionToClipboard, screenshotWindowToClipboard, copyTextFromScreen, pickColour
    case toggleCapsLock, emptyTrash
    case resetKeyRemaps, showAppMenus, showShortcutsMenu, showShortieMenu, cheatSheet, toggleGestures
    case functionKeysToggle, stageManagerToggle, ignoreTrackpadToggle
    case releaseModifiers, contextMenuKey, lookUpSelection, trueToneToggle, bluetoothOn, bluetoothOff, closeNotifications, saveClipboard, restoreClipboard, hideClipboardHistory, colourPanel, hapticTap, newFileInFinder, compressFinderSelection, screenshotAndEdit, quitShortie, restartShortie
    case nightShiftToggle, nightShiftOn, nightShiftOff, toggleBluetooth, toggleMirroring, screenshotScreenToClipboard, desktop5, desktop6, desktop7, desktop8, desktop9
    case fastForward, rewind, keyboardBacklightToggle, muteOn, muteOff, toggleWiFi, lightMode, darkMode, desktop1, desktop2, desktop3, desktop4, openSystemSettings, newFinderWindow, openTerminalHere, copyFinderPath, quickLook, copyBrowserURL, restartFinder, restartDock, clearClipboard, typeDate, typeTime, showDateTime, showBattery, zoomToggle, zoomIn, zoomOut

    var id: Self { self }

    var title: String {
        switch self {
        case .playPause: "Play or Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        case .brightnessUp: "Brightness Up"
        case .brightnessDown: "Brightness Down"
        case .toggleMicrophone: "Microphone On or Off"
        case .keyboardBrightnessUp: "Keyboard Backlight Up"
        case .keyboardBrightnessDown: "Keyboard Backlight Down"
        case .controlCentre: "Open Control Centre"
        case .notificationCentre: "Open Notification Centre"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        case .showDesktop: "Show Desktop"
        case .apps: "Show Apps"
        case .spotlight: "Spotlight"
        case .emojiAndSymbols: "Emoji & Symbols"
        case .windowSwitcher: "Window Switcher"
        case .clipboardHistory: "Clipboard History"
        case .screenshotTool: "Screenshot Tool"
        case .screenshotSelection: "Screenshot of Selection"
        case .screenshotScreen: "Screenshot of Screen"
        case .lockScreen: "Lock Screen"
        case .sleepDisplay: "Turn Display Off"
        case .sleep: "Sleep"
        case .toggleDarkMode: "Dark Mode On or Off"
        case .toggleDockHiding: "Hide or Show the Dock"
        case .toggleMenuBarHiding: "Hide or Show the Menu Bar"
        case .toggleHiddenFiles: "Show or Hide Hidden Files"
        case .toggleDesktopIcons: "Show or Hide Desktop Icons"
        case .screenSaver: "Start Screen Saver"
        case .forceQuit: "Force Quit…"
        case .ejectAll: "Eject All Disks"
        case .logOut: "Log Out…"
        case .restart: "Restart…"
        case .shutDown: "Shut Down…"
        case .openDashboard: "Open Shortie Settings"
        case .togglePause: "Pause or Resume Shortie"
        case .volumeUpSmall: "Volume Up a Little"
        case .volumeDownSmall: "Volume Down a Little"
        case .brightnessUpSmall: "Brightness Up a Little"
        case .brightnessDownSmall: "Brightness Down a Little"
        case .previousApp: "Previous App"
        case .hideAllApps: "Hide All Apps"
        case .showAllApps: "Show All Hidden Apps"
        case .siri: "Siri"
        case .spaceLeft: "Space to the Left"
        case .spaceRight: "Space to the Right"
        case .screenshotWindow: "Screenshot of Window"
        case .screenshotSelectionToClipboard: "Copy Screenshot of Selection"
        case .screenshotWindowToClipboard: "Copy Screenshot of Window"
        case .copyTextFromScreen: "Copy Text from Screen"
        case .pickColour: "Pick Colour from Screen"
        case .toggleCapsLock: "Caps Lock On or Off"
        case .emptyTrash: "Empty Bin…"
        case .resetKeyRemaps: "Put All Remapped Keys Back"
        case .showAppMenus: "Show App's Menus at Pointer"
        case .showShortcutsMenu: "Show Shortcuts at Pointer"
        case .showShortieMenu: "Show Shortie's Menu"
        case .cheatSheet: "Show or Hide Cheat Sheet"
        case .toggleGestures: "Gestures On or Off"
        case .functionKeysToggle: "F1, F2… as Function Keys On or Off"
        case .stageManagerToggle: "Stage Manager On or Off"
        case .ignoreTrackpadToggle: "Ignore Trackpad While a Mouse Is Connected On or Off"
        case .releaseModifiers: "Let Go of All Modifier Keys"
        case .contextMenuKey: "Show Context Menu for Selection"
        case .lookUpSelection: "Look Up (⌃⌘D)"
        case .trueToneToggle: "True Tone On or Off"
        case .bluetoothOn: "Bluetooth On"
        case .bluetoothOff: "Bluetooth Off"
        case .closeNotifications: "Close All Notifications"
        case .saveClipboard: "Save Clipboard for Later"
        case .restoreClipboard: "Restore Saved Clipboard"
        case .hideClipboardHistory: "Hide Clipboard History"
        case .colourPanel: "Show Colour Picker"
        case .hapticTap: "Haptic Tap on Trackpad"
        case .newFileInFinder: "New File in Finder's Folder"
        case .compressFinderSelection: "Compress Selected Files"
        case .screenshotAndEdit: "Screenshot and Edit in Preview"
        case .quitShortie: "Quit Shortie"
        case .restartShortie: "Restart Shortie"
        case .nightShiftToggle: "Night Shift On or Off"
        case .nightShiftOn: "Night Shift On"
        case .nightShiftOff: "Night Shift Off"
        case .toggleBluetooth: "Bluetooth On or Off"
        case .toggleMirroring: "Mirror Displays On or Off"
        case .screenshotScreenToClipboard: "Copy Screenshot of Screen"
        case .desktop5: "Switch to Desktop 5"
        case .desktop6: "Switch to Desktop 6"
        case .desktop7: "Switch to Desktop 7"
        case .desktop8: "Switch to Desktop 8"
        case .desktop9: "Switch to Desktop 9"
        case .fastForward: "Fast Forward"
        case .rewind: "Rewind"
        case .keyboardBacklightToggle: "Keyboard Backlight On or Off"
        case .muteOn: "Mute Sound"
        case .muteOff: "Unmute Sound"
        case .toggleWiFi: "Wi-Fi On or Off"
        case .lightMode: "Light Mode"
        case .darkMode: "Dark Mode"
        case .desktop1: "Switch to Desktop 1"
        case .desktop2: "Switch to Desktop 2"
        case .desktop3: "Switch to Desktop 3"
        case .desktop4: "Switch to Desktop 4"
        case .openSystemSettings: "Open System Settings"
        case .newFinderWindow: "New Finder Window"
        case .openTerminalHere: "Open Terminal in Finder's Folder"
        case .copyFinderPath: "Copy Path of Selected Files"
        case .quickLook: "Quick Look Selected Files"
        case .copyBrowserURL: "Copy Current Web Page Address"
        case .restartFinder: "Restart Finder"
        case .restartDock: "Restart Dock"
        case .clearClipboard: "Clear Clipboard"
        case .typeDate: "Type Today's Date"
        case .typeTime: "Type the Time"
        case .showDateTime: "Show Date and Time"
        case .showBattery: "Show Battery Level"
        case .zoomToggle: "Zoom In or Out (Accessibility)"
        case .zoomIn: "Zoom In (Accessibility)"
        case .zoomOut: "Zoom Out (Accessibility)"
        }
    }

    var systemImage: String {
        switch self {
        case .playPause: "playpause.fill"
        case .nextTrack: "forward.fill"
        case .previousTrack: "backward.fill"
        case .volumeUp: "speaker.wave.3.fill"
        case .volumeDown: "speaker.wave.1.fill"
        case .mute: "speaker.slash.fill"
        case .brightnessUp: "sun.max.fill"
        case .brightnessDown: "sun.min.fill"
        case .toggleMicrophone: "mic.slash.fill"
        case .keyboardBrightnessUp: "light.max"
        case .keyboardBrightnessDown: "light.min"
        case .controlCentre: "switch.2"
        case .notificationCentre: "bell.fill"
        case .missionControl: "rectangle.3.group"
        case .appExpose: "rectangle.stack"
        case .showDesktop: "menubar.dock.rectangle"
        case .apps: "square.grid.3x3.fill"
        case .spotlight: "magnifyingglass"
        case .emojiAndSymbols: "face.smiling"
        case .windowSwitcher: "rectangle.on.rectangle"
        case .clipboardHistory: "doc.on.clipboard"
        case .screenshotTool: "camera.viewfinder"
        case .screenshotSelection: "rectangle.dashed"
        case .screenshotScreen: "camera.fill"
        case .lockScreen: "lock.fill"
        case .sleepDisplay: "display"
        case .sleep: "moon.fill"
        case .toggleDarkMode: "circle.lefthalf.filled"
        case .toggleDockHiding: "dock.rectangle"
        case .toggleMenuBarHiding: "menubar.rectangle"
        case .toggleHiddenFiles: "eye"
        case .toggleDesktopIcons: "menubar.dock.rectangle"
        case .screenSaver: "sparkles.tv"
        case .forceQuit: "xmark.octagon.fill"
        case .ejectAll: "eject.fill"
        case .logOut: "rectangle.portrait.and.arrow.right"
        case .restart: "arrow.clockwise"
        case .shutDown: "power"
        case .openDashboard: "gearshape.fill"
        case .togglePause: "hand.raised.slash"
        case .volumeUpSmall: "speaker.wave.2"
        case .volumeDownSmall: "speaker.wave.1"
        case .brightnessUpSmall: "sun.max"
        case .brightnessDownSmall: "sun.min"
        case .previousApp: "arrow.uturn.backward.square"
        case .hideAllApps: "eye.slash"
        case .showAllApps: "eye"
        case .siri: "waveform.circle"
        case .spaceLeft: "rectangle.lefthalf.inset.filled.arrow.left"
        case .spaceRight: "rectangle.righthalf.inset.filled.arrow.right"
        case .screenshotWindow: "macwindow"
        case .screenshotSelectionToClipboard: "rectangle.dashed.badge.record"
        case .screenshotWindowToClipboard: "macwindow.badge.plus"
        case .copyTextFromScreen: "text.viewfinder"
        case .pickColour: "eyedropper"
        case .toggleCapsLock: "capslock"
        case .emptyTrash: "trash"
        case .resetKeyRemaps: "keyboard"
        case .showAppMenus: "filemenu.and.selection"
        case .showShortcutsMenu: "bolt.fill"
        case .showShortieMenu: "hand.point.up.left"
        case .cheatSheet: "list.bullet.rectangle"
        case .toggleGestures: "hand.raised"
        case .functionKeysToggle: "fn"
        case .stageManagerToggle: "squares.leading.rectangle"
        case .ignoreTrackpadToggle: "rectangle.and.hand.point.up.left"
        case .releaseModifiers: "keyboard.badge.ellipsis"
        case .contextMenuKey: "contextualmenu.and.cursorarrow"
        case .lookUpSelection: "character.book.closed"
        case .trueToneToggle: "sun.max.trianglebadge.exclamationmark"
        case .bluetoothOn: "antenna.radiowaves.left.and.right"
        case .bluetoothOff: "antenna.radiowaves.left.and.right.slash"
        case .closeNotifications: "bell.slash"
        case .saveClipboard: "tray.and.arrow.down"
        case .restoreClipboard: "tray.and.arrow.up"
        case .hideClipboardHistory: "doc.on.clipboard"
        case .colourPanel: "paintpalette"
        case .hapticTap: "hand.tap"
        case .newFileInFinder: "doc.badge.plus"
        case .compressFinderSelection: "doc.zipper"
        case .screenshotAndEdit: "pencil.and.outline"
        case .quitShortie: "xmark.circle"
        case .restartShortie: "arrow.clockwise"
        case .nightShiftToggle: "moon.circle"
        case .nightShiftOn: "moon.circle.fill"
        case .nightShiftOff: "moon.circle"
        case .toggleBluetooth: "antenna.radiowaves.left.and.right"
        case .toggleMirroring: "rectangle.on.rectangle"
        case .screenshotScreenToClipboard: "camera.on.rectangle"
        case .desktop5: "5.square"
        case .desktop6: "6.square"
        case .desktop7: "7.square"
        case .desktop8: "8.square"
        case .desktop9: "9.square"
        case .fastForward: "forward.end.fill"
        case .rewind: "backward.end.fill"
        case .keyboardBacklightToggle: "light.max"
        case .muteOn: "speaker.slash"
        case .muteOff: "speaker.wave.2"
        case .toggleWiFi: "wifi"
        case .lightMode: "sun.max"
        case .darkMode: "moon"
        case .desktop1: "1.square"
        case .desktop2: "2.square"
        case .desktop3: "3.square"
        case .desktop4: "4.square"
        case .openSystemSettings: "gear"
        case .newFinderWindow: "folder"
        case .openTerminalHere: "terminal"
        case .copyFinderPath: "doc.on.doc"
        case .quickLook: "eye.circle"
        case .copyBrowserURL: "link"
        case .restartFinder: "arrow.clockwise.circle"
        case .restartDock: "arrow.clockwise.square"
        case .clearClipboard: "clipboard"
        case .typeDate: "calendar"
        case .typeTime: "clock"
        case .showDateTime: "clock.fill"
        case .showBattery: "battery.75percent"
        case .zoomToggle: "plus.magnifyingglass"
        case .zoomIn: "plus.magnifyingglass"
        case .zoomOut: "minus.magnifyingglass"
        }
    }

    /// For menus, so related actions sit together.
    static let groups: [[SystemAction]] = [
        [.playPause, .nextTrack, .previousTrack, .fastForward, .rewind],
        [.volumeUp, .volumeDown, .volumeUpSmall, .volumeDownSmall, .mute, .muteOn, .muteOff, .toggleMicrophone],
        [.brightnessUp, .brightnessDown, .brightnessUpSmall, .brightnessDownSmall, .keyboardBrightnessUp, .keyboardBrightnessDown, .keyboardBacklightToggle],
        [.windowSwitcher, .previousApp, .clipboardHistory, .controlCentre, .notificationCentre, .missionControl, .appExpose, .showDesktop, .apps, .spotlight, .siri, .emojiAndSymbols],
        [.spaceLeft, .spaceRight, .desktop1, .desktop2, .desktop3, .desktop4, .desktop5, .desktop6, .desktop7, .desktop8, .desktop9, .hideAllApps, .showAllApps],
        [.toggleDarkMode, .lightMode, .darkMode, .nightShiftToggle, .nightShiftOn, .nightShiftOff, .trueToneToggle, .toggleWiFi, .toggleBluetooth, .bluetoothOn, .bluetoothOff, .toggleMirroring, .toggleDockHiding, .toggleMenuBarHiding, .toggleHiddenFiles, .toggleDesktopIcons, .toggleCapsLock, .functionKeysToggle, .stageManagerToggle, .ignoreTrackpadToggle],
        [.newFinderWindow, .newFileInFinder, .compressFinderSelection, .openTerminalHere, .copyFinderPath, .quickLook, .copyBrowserURL, .openSystemSettings],
        [.typeDate, .typeTime, .showDateTime, .showBattery, .colourPanel, .hapticTap],
        [.clearClipboard, .saveClipboard, .restoreClipboard, .hideClipboardHistory],
        [.releaseModifiers, .contextMenuKey, .lookUpSelection, .closeNotifications],
        [.zoomToggle, .zoomIn, .zoomOut],
        [.screenshotTool, .screenshotSelection, .screenshotScreen, .screenshotWindow, .screenshotAndEdit],
        [.screenshotSelectionToClipboard, .screenshotWindowToClipboard, .screenshotScreenToClipboard, .copyTextFromScreen, .pickColour],
        [.screenSaver, .forceQuit, .ejectAll, .emptyTrash, .restartFinder, .restartDock],
        [.lockScreen, .sleepDisplay, .sleep, .logOut, .restart, .shutDown],
        [.showAppMenus, .showShortcutsMenu, .cheatSheet, .resetKeyRemaps],
        [.openDashboard, .showShortieMenu, .togglePause, .toggleGestures, .restartShortie, .quitShortie],
    ]
}

enum SystemActionRunner {
    static func run(_ action: SystemAction) {
        switch action {
        case .playPause: MediaKey.press(NX_KEYTYPE_PLAY)
        case .nextTrack: MediaKey.press(NX_KEYTYPE_NEXT)
        case .previousTrack: MediaKey.press(NX_KEYTYPE_PREVIOUS)
        case .volumeUp: MediaKey.press(NX_KEYTYPE_SOUND_UP)
        case .volumeDown: MediaKey.press(NX_KEYTYPE_SOUND_DOWN)
        case .mute: MediaKey.press(NX_KEYTYPE_MUTE)
        case .brightnessUp: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_UP)
        case .brightnessDown: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_DOWN)
        case .keyboardBrightnessUp: MediaKey.press(NX_KEYTYPE_ILLUMINATION_UP)
        case .keyboardBrightnessDown: MediaKey.press(NX_KEYTYPE_ILLUMINATION_DOWN)
        case .toggleMicrophone:
            MacToggles.toggleMicrophone()

        case .controlCentre:
            MenuBarExtras.press(identifierContaining: "controlcenter")
        case .notificationCentre:
            // Clicking the clock opens Notification Centre.
            MenuBarExtras.press(identifierContaining: "clock")
        case .missionControl:
            missionControl()
        case .appExpose:
            missionControl("2")
        case .showDesktop:
            missionControl("1")
        case .apps:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Apps.app"))
        case .spotlight:
            if !MenuBarExtras.press(identifierContaining: "spotlight") {
                KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Space), modifiers: .command, keyName: "Space"))
            }
        case .windowSwitcher:
            WindowSwitcher.shared.show()
        case .clipboardHistory:
            ClipboardPanel.shared.show()
        case .emojiAndSymbols:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Space), modifiers: [.control, .command], keyName: "Space"))

        // These use macOS's own screenshot shortcuts, so your save location and
        // other Screenshot settings apply.
        case .screenshotTool:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_5), modifiers: [.shift, .command], keyName: "5"))
        case .screenshotSelection:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_4), modifiers: [.shift, .command], keyName: "4"))
        case .screenshotScreen:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_3), modifiers: [.shift, .command], keyName: "3"))

        case .lockScreen:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_Q), modifiers: [.control, .command], keyName: "Q"))
        case .sleepDisplay:
            run("/usr/bin/pmset", ["displaysleepnow"])
        case .sleep:
            run("/usr/bin/pmset", ["sleepnow"])

        case .toggleDarkMode:
            ScriptRunner.runAppleScript(#"tell application "System Events" to tell appearance preferences to set dark mode to not dark mode"#)
        case .toggleDockHiding:
            ScriptRunner.runAppleScript(#"tell application "System Events" to tell dock preferences to set autohide to not autohide"#)
        case .toggleMenuBarHiding:
            ScriptRunner.runAppleScript(#"tell application "System Events" to tell dock preferences to set autohide menu bar to not autohide menu bar"#)
        case .toggleHiddenFiles:
            let isShown = MacToggles.toggleFinderSetting("AppleShowAllFiles", defaultValue: false)
            HUD.show(isShown ? "Hidden Files Shown" : "Hidden Files Hidden", systemImage: isShown ? "eye" : "eye.slash")
        case .toggleDesktopIcons:
            let isShown = MacToggles.toggleFinderSetting("CreateDesktop", defaultValue: true)
            HUD.show(isShown ? "Desktop Icons Shown" : "Desktop Icons Hidden", systemImage: isShown ? "eye" : "eye.slash")
        case .screenSaver:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        case .forceQuit:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Escape), modifiers: [.option, .command], keyName: "Esc"))
        case .ejectAll:
            MacToggles.ejectAll()

        // macOS's own "Are you sure?" windows, so nothing happens by accident.
        case .logOut:
            ScriptRunner.runAppleScript(#"tell application "loginwindow" to «event aevtlogo»"#)
        case .restart:
            ScriptRunner.runAppleScript(#"tell application "loginwindow" to «event aevtrrst»"#)
        case .shutDown:
            ScriptRunner.runAppleScript(#"tell application "loginwindow" to «event aevtrsdn»"#)

        case .openDashboard:
            WindowManager.shared.show(.settings)
        case .volumeUpSmall: MediaKey.press(NX_KEYTYPE_SOUND_UP, small: true)
        case .volumeDownSmall: MediaKey.press(NX_KEYTYPE_SOUND_DOWN, small: true)
        case .brightnessUpSmall: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_UP, small: true)
        case .brightnessDownSmall: MediaKey.press(NX_KEYTYPE_BRIGHTNESS_DOWN, small: true)

        case .previousApp:
            // A quick ⌘-Tab goes back to the app you used before.
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Tab), modifiers: .command, keyName: "Tab"))
        case .hideAllApps:
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                app.hide()
            }
        case .showAllApps:
            for app in NSWorkspace.shared.runningApplications where app.isHidden {
                app.unhide()
            }
        case .siri:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Siri.app"))
        // macOS's own Mission Control shortcuts. Arrow keys count as function keys,
        // so they need those flags too.
        case .spaceLeft:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_LeftArrow), modifiers: .control, keyName: "←"), extraFlags: [.maskSecondaryFn, .maskNumericPad])
        case .spaceRight:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_RightArrow), modifiers: .control, keyName: "→"), extraFlags: [.maskSecondaryFn, .maskNumericPad])

        case .screenshotWindow:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_4), modifiers: [.shift, .command], keyName: "4"))
            // Space switches the crosshair to picking a window.
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Space), modifiers: [], keyName: "Space"))
            }
        case .screenshotSelectionToClipboard:
            run("/usr/sbin/screencapture", ["-i", "-c"])
        case .screenshotWindowToClipboard:
            run("/usr/sbin/screencapture", ["-i", "-W", "-c"])
        case .copyTextFromScreen:
            ScreenText.copy()
        case .pickColour:
            ColourPicker.pick()
        case .toggleCapsLock:
            CapsLockState.set(!CapsLockState.isOn)
        case .emptyTrash:
            // Finder asks first, unless you've turned that off in Finder's settings.
            ScriptRunner.runAppleScript(#"tell application "Finder" to empty trash"#)

        case .fastForward:
            MediaKey.press(NX_KEYTYPE_FAST)
        case .rewind:
            MediaKey.press(NX_KEYTYPE_REWIND)
        case .keyboardBacklightToggle:
            MediaKey.press(NX_KEYTYPE_ILLUMINATION_TOGGLE)
        case .muteOn:
            ScriptRunner.runAppleScript("set volume with output muted")
        case .muteOff:
            ScriptRunner.runAppleScript("set volume without output muted")
        case .toggleWiFi:
            MoreActions.toggleWiFi()
        case .lightMode:
            ScriptRunner.runAppleScript(#"tell application "System Events" to tell appearance preferences to set dark mode to false"#)
        case .darkMode:
            ScriptRunner.runAppleScript(#"tell application "System Events" to tell appearance preferences to set dark mode to true"#)
        case .desktop1:
            MoreActions.switchToDesktop(1)
        case .desktop2:
            MoreActions.switchToDesktop(2)
        case .desktop3:
            MoreActions.switchToDesktop(3)
        case .desktop4:
            MoreActions.switchToDesktop(4)
        case .openSystemSettings:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        case .newFinderWindow:
            ScriptRunner.runAppleScript("tell application \"Finder\"\nactivate\nmake new Finder window\nend tell")
        case .openTerminalHere:
            MoreActions.openTerminalHere()
        case .copyFinderPath:
            MoreActions.copyFinderPaths()
        case .quickLook:
            MoreActions.quickLook()
        case .copyBrowserURL:
            MoreActions.copyBrowserURL()
        case .restartFinder:
            run("/usr/bin/killall", ["Finder"])
        case .restartDock:
            run("/usr/bin/killall", ["Dock"])
        case .clearClipboard:
            NSPasteboard.general.clearContents()
        case .typeDate:
            Task { await TextTyper.type(Date.now.formatted(date: .long, time: .omitted)) }
        case .typeTime:
            Task { await TextTyper.type(Date.now.formatted(date: .omitted, time: .shortened)) }
        case .showDateTime:
            HUD.show(Date.now.formatted(date: .complete, time: .shortened), systemImage: "clock.fill")
        case .showBattery:
            MoreActions.showBattery()
        case .zoomToggle:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_8), modifiers: [.option, .command], keyName: "8"))
        case .zoomIn:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_Equal), modifiers: [.option, .command], keyName: "="))
        case .zoomOut:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_Minus), modifiers: [.option, .command], keyName: "-"))
        case .nightShiftToggle:
            NightShift.toggle()
        case .nightShiftOn:
            NightShift.set(true)
        case .nightShiftOff:
            NightShift.set(false)
        case .toggleBluetooth:
            Bluetooth.toggle()
        case .toggleMirroring:
            DisplayMirroring.toggle()
        case .screenshotScreenToClipboard:
            run("/usr/sbin/screencapture", ["-c"])
        case .desktop5:
            MoreActions.switchToDesktop(5)
        case .desktop6:
            MoreActions.switchToDesktop(6)
        case .desktop7:
            MoreActions.switchToDesktop(7)
        case .desktop8:
            MoreActions.switchToDesktop(8)
        case .desktop9:
            MoreActions.switchToDesktop(9)
        case .releaseModifiers:
            ParityActions.releaseAllModifiers()
        case .contextMenuKey:
            ParityActions.showContextMenuForFocus()
        case .lookUpSelection:
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control, .command], keyName: "D"))
        case .trueToneToggle:
            TrueTone.toggle()
        case .bluetoothOn:
            Bluetooth.set(true)
        case .bluetoothOff:
            Bluetooth.set(false)
        case .closeNotifications:
            ParityActions.closeAllNotifications()
        case .saveClipboard:
            ParityActions.saveClipboard()
        case .restoreClipboard:
            ParityActions.restoreClipboard()
        case .hideClipboardHistory:
            ClipboardPanel.shared.close()
        case .colourPanel:
            ParityActions.showColourPanel()
        case .hapticTap:
            Haptics.tap(.medium)
        case .newFileInFinder:
            ParityActions.newFileInFinder()
        case .compressFinderSelection:
            ParityActions.compressFinderSelection()
        case .screenshotAndEdit:
            ParityActions.screenshotAndEdit()
        case .quitShortie:
            NSApp.terminate(nil)
        case .restartShortie:
            ParityActions.restartShortie()
        case .functionKeysToggle:
            SettingToggles.toggleFunctionKeys()
        case .stageManagerToggle:
            SettingToggles.toggleStageManager()
        case .ignoreTrackpadToggle:
            SettingToggles.toggleIgnoreTrackpad()
        case .resetKeyRemaps:
            KeyRemapper.reset()
        case .showAppMenus:
            PointerMenus.shared.showAppMenus()
        case .showShortcutsMenu:
            PointerMenus.shared.showShortcuts()
        case .showShortieMenu:
            StatusBarController.current?.showMenu()
        case .cheatSheet:
            CheatSheet.shared.toggle()
        case .toggleGestures:
            let off = !UserDefaults.standard.bool(forKey: DefaultsKey.gesturesPaused)
            UserDefaults.standard.set(off, forKey: DefaultsKey.gesturesPaused)
            HUD.show(off ? "Gestures Off" : "Gestures On", systemImage: off ? "hand.raised.slash" : "hand.raised")
        case .togglePause:
            let isPaused = !UserDefaults.standard.bool(forKey: DefaultsKey.isPaused)
            UserDefaults.standard.set(isPaused, forKey: DefaultsKey.isPaused)
            HUD.show(isPaused ? "Shortie Paused" : "Shortie Resumed", systemImage: isPaused ? "hand.raised.slash" : "hand.draw")
        }
    }

    /// Mission Control's own app takes "1" for Show Desktop and "2" for App Exposé.
    private static func missionControl(_ argument: String? = nil) {
        run("/System/Applications/Mission Control.app/Contents/MacOS/Mission Control", argument.map { [$0] } ?? [])
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}

/// The media keys on a Mac keyboard (play, volume, brightness…) aren't ordinary
/// keys: they're sent as special "system" events, which we imitate here.
private enum MediaKey {
    /// `small` holds ⇧⌥, which makes volume and brightness move a quarter step.
    static func press(_ key: Int32, small: Bool = false) {
        let modifiers: NSEvent.ModifierFlags = small ? [.shift, .option] : []
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: (isDown ? 0xA00 : 0xB00) | modifiers.rawValue)
            let data1 = (Int(key) << 16) | ((isDown ? 0xA : 0xB) << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// The icons on the right of the menu bar (Control Centre, the clock, Spotlight…).
/// Pressing one through the Accessibility API is the same as clicking it.
private enum MenuBarExtras {
    /// The system processes that own menu bar icons. Newer macOS versions keep
    /// them all in MenuBarAgent; older ones spread them across the others.
    private static let owners = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.Spotlight", "com.apple.systemuiserver"]

    @discardableResult
    static func press(identifierContaining fragment: String) -> Bool {
        for bundleID in owners {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                guard let bar = AX.element(element, "AXExtrasMenuBar"),
                      let item = find(fragment, in: bar, depth: 0)
                else { continue }
                AXUIElementPerformAction(item, kAXPressAction as CFString)
                return true
            }
        }
        return false
    }

    /// Icons can sit directly in the menu bar or be wrapped in a container
    /// (newer macOS), so look a few levels down.
    private static func find(_ fragment: String, in element: AXUIElement, depth: Int) -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        for child in children as? [AXUIElement] ?? [] {
            if AX.string(child, "AXIdentifier")?.localizedCaseInsensitiveContains(fragment) == true {
                return child
            }
            if depth < 2, let found = find(fragment, in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }
}
