# Shortie: session summary and handoff

*Last updated 30 October 2026, at the end of the first build session.*

Shortie is a menu bar app for macOS that does what BetterTouchTool does: keyboard shortcuts, trackpad gestures, mouse buttons, window snapping and more. It aims to feel like Apple made it. It was built from an empty folder in one session, one confirmed step at a time. Everything listed under "What it does" is built, and all of it is committed in git (33 commits on `main`). Most features have been tried and confirmed by the user. Anything not yet confirmed is listed under [Testing status](#testing-status).

---

## Quick start

| | |
|---|---|
| **Build** | `xcodebuild -project Glide.xcodeproj -scheme Glide -configuration Debug -derivedDataPath build -allowProvisioningUpdates build` |
| **Run** | `open build/Build/Products/Debug/Shortie.app` |
| **Restart after a build** | `pkill -x Shortie; open build/Build/Products/Debug/Shortie.app` |
| **Open in Xcode** | `Glide.xcodeproj`, then ⌘R |
| **Settings and data** | `~/Library/Application Support/Shortie/` (`shortcuts.json`, `menus.json`, `clipboard.json`, `Clipboard Images/`) |

- **Requirements:** macOS 15 or later to run; built with Xcode 27 and Swift 6.4 (strict concurrency, everything on the main actor by default).
- **Signing:** the free Apple Development personal team (`5H354LVSGV`). This matters because Accessibility permission survives rebuilds only with a real certificate; ad-hoc signing loses it on every build.
- **Names:** the app was first called **Glide**, then **BestTouchTool**, and is now **Shortie** (renamed 31 October 2026; the old settings folder is moved across on first launch by `AppFolder`). The Xcode project, target, folders and type names (`GlideApp` and so on) are still called Glide, on purpose. The bundle ID `com.slopbookpro.Glide` was kept so permissions and settings carry over. Everything the user sees says Shortie.

---

## What it does

The dashboard opens with a left-click on the menu bar icon (a right-click gives About and Quit). Its sidebar groups:

**Triggers**: any trigger can run any action, and can work in all apps, only in chosen apps, or everywhere except chosen apps. An app-specific rule overrides a general one.

| Trigger | Notes |
|---|---|
| Keyboard Shortcuts | Recorded in the editor or in the row. Hyper (Caps Lock) shortcuts show as "Hyper X". |
| Text Shortcuts | Type an abbreviation like `;email` and it's erased and replaced, or any action runs. Only the last 64 typed characters are kept, in memory. |
| Trackpad Gestures | About 70: taps, double taps, tap-and-hold, TipTap, swipes, edge swipes, pinch, rotate, 2–5-finger clicks, corner clicks, force click. Includes a recorder and a Gesture Lab, and warns when macOS uses the same gesture. |
| Mouse | Middle, back, forward and higher buttons, optionally with modifiers. |
| Automations | When an app opens, quits or comes to the front; when the Mac wakes or sleeps, the screen locks or unlocks, or the charger is connected or disconnected. |
| Window Buttons | Any click on a red, yellow or green window button, for example "click green to maximise without full screen". |

**Actions**:
- Open an app, a file or a website
- Run a Shortcut
- Type text, or press any keys (with 27 presets)
- Mouse clicks
- 24 System & Media actions: media keys, volume, brightness, Control Centre, Notification Centre, Mission Control, App Exposé, Show Desktop, Apps, Spotlight, emoji, screenshots, lock, sleep, the window switcher and clipboard history
- Move a window to one of 17 positions
- Window and app commands
- Choose a menu item in the front app
- Run AppleScript or a shell script
- Several Actions: a list of steps with optional waits
- Show a custom menu

**Windows**:
- Snapping shortcuts with ½ → ⅓ → ⅔ size cycling; moves glide along Apple's spring curve.
- Drag a window to an edge to snap it (with a Liquid Glass preview; quarters only in the very corner).
- ⌃⌘-drag to move a window from anywhere, ⌃⌥-drag to resize it.
- A window switcher.

**Mac**:
- **Clipboard history**, opened with Hyper+V: a glass panel to search, paste, pin and delete. Skips password-manager items.
- **Custom menus**, shown in the menu bar or opened at the pointer.
- **Black menu bar** to hide the notch, set per screen.
- **Permissions** page.

**General**:
- Open at login.
- Pause everything.
- **Hyper key:** while the app runs, Caps Lock is remapped to F18 with `hidutil`; holding it adds ⌃⌥⇧⌘. A tap still toggles Caps Lock (through IOKit), or can press Escape or do nothing.

**Scrolling** (in the Mouse page):
- The wheel direction is set separately from the trackpad's. This replaced the user's LinearMouse.
- Smooth wheel scrolling, using Apple's momentum physics (0.99 per millisecond deceleration).

---

## How it's built

### The core idea: trigger + action

Every rule is a `Shortcut` (`Glide/Shortcuts/ShortcutStore.swift`) made of four parts:
- a **`Trigger`** (`Trigger.swift`): `keys`, `trafficLight`, `gesture`, `mouseButton`, `typedText` or `event`;
- a **`ShortcutAction`** (`ShortcutAction.swift`);
- `isEnabled`;
- an optional **`AppScope`** that limits which apps it works in.

All rules live in one `ShortcutStore` and are saved to `shortcuts.json`. To find the rule to run, every engine calls `ShortcutStore.match(_:in:)`, which applies the app-scope priority. `ActionRunner.run(_:on:)` carries out any action. The optional `ActionTarget` it takes is the window and app to act on; window buttons pass the clicked window.

Two other stores sit alongside: `CustomMenuStore` (`menus.json`) and `ClipboardHistory` (`clipboard.json`).

### Engines: one per kind of input

Each engine has a `start()` that is safe to call repeatedly, and switches itself off when nothing needs it. `InputEngines.start()` and `InputEngines.updateNeeds()` live in `GlideApp.swift`. `updateNeeds()` runs whenever the shortcuts or settings change.

| Engine | File | How it listens |
|---|---|---|
| Keyboard (also Hyper and text shortcuts) | `Shortcuts/ShortcutEngine.swift`, `HyperKey.swift`, `TypedTextEngine.swift` | Event tap on key down and key up |
| Scrolling | `Mouse/ScrollEngine.swift` | Event tap on scroll wheel events; a display link for smoothing |
| Window buttons | `TrafficLights/TrafficLightEngine.swift` | Mouse event tap plus Accessibility hit-testing |
| Gestures | `Gestures/GestureEngine.swift`, `Gesture.swift` | Private MultitouchSupport framework (loaded with `dlopen`; C types in `Glide-Bridging-Header.h`), plus a click event tap and a pressure monitor |
| Mouse buttons | `Mouse/MouseButtonEngine.swift` | Event tap on extra-button down and up |
| Window dragging | `Windows/WindowDragEngine.swift` | Left-button event tap; follows drags through `CGWindowList`, not the dragged app |
| Automations | `Automations/AutomationEngine.swift` | NSWorkspace and distributed notifications, plus IOKit power notifications |
| Clipboard | `Clipboard/ClipboardHistory.swift` | Checks the clipboard's change counter twice a second, with timer tolerance |

Events Shortie posts itself (keys, clicks, scrolls) are stamped with `SyntheticEvent.marker` (in `MouseClicker.swift`). Every tap lets them straight through, so actions can never set off other shortcuts.

### Moving windows

`Windows/WindowMover.swift` moves windows through the Accessibility API, which uses top-left coordinates. AppKit screen frames are flipped once, in `flipped(_:)`. Moves animate on each display refresh along SwiftUI's `Spring(duration: 0.3, bounce: 0)`. `Windows/AppCommand.swift` holds the window and app commands and the shared `AX` helpers.

### Interface

- **Shell:** the menu bar icon is an `NSStatusItem` (`App/StatusBarController.swift`). SwiftUI's `MenuBarExtra` was replaced because it can't tell left clicks from right clicks.
- **Windows:** `App/WindowManager.swift` hosts the dashboard and the welcome window in AppKit. It switches the app's activation policy to `.regular` while a window is open; that's required, or windows open behind other apps.
- **Dashboard:** `Settings/SettingsView.swift` holds the sidebar (`SettingsPane.groups`), the page header (`PaneHeader`) and `SectionTitle`.
- **Shared building blocks:**
  - `TriggerEditor` and `EditorCard`: the When / Do / Works In editor (`ActionEditor.swift`)
  - `ActionFields`: one action's details, with `StepsEditor` for Several Actions
  - `ActionKindPicker`
  - `TriggerRow`
  - `HoverBadge`, `ConflictBadge`, `InfoButton`
  - `AppScopePicker`
  - `GlassPanel` and `GlassBackground`: Liquid Glass on macOS 26 and later, with a material fallback
- **Floating panels:** the window switcher, clipboard history and floating menus use a non-activating `GlassPanel`, so the app you were in stays in front.
- **App icon:** `Glide/AppIcon.icon`, in Icon Composer's format: `icon.json` plus a glyph PNG. Xcode builds it into `AppIcon.icns` and `Assets.car`.

---

## Decisions worth knowing

- **Outside the Mac App Store:** the app needs Accessibility, which the sandbox doesn't allow. Release would mean the paid developer programme plus notarisation.
- **Only one permission (Accessibility).** Nothing so far needs Input Monitoring or Screen Recording. The window switcher deliberately shows titles and icons rather than thumbnails to avoid needing Screen Recording.
- **Established values instead of invented ones:**
  - Taps use MiddleClick's limits (300 ms, 5% of the trackpad).
  - Tap-and-hold uses Apple's 0.5 s.
  - Snap zones use Rectangle's (5 pt edges).
  - The Hyper-key tap uses Karabiner's 1 s.
  - Scrolling uses Apple's momentum physics.
  - Window glides use Apple's spring.

  The user asked for this explicitly. Swipe, pinch, edge and rotation thresholds (20 mm, 12 mm, 15 mm, 30°) are our own and could still be tuned.
- **macOS's own gestures can't be blocked.** Clicks can be, and are. That's why gestures warn rather than block.
- **Focus and Do Not Disturb have no public API.** Point users to a Shortcuts-app "Set Focus" shortcut, run with Run a Shortcut.
- **Clipboard history is kept across restarts,** on disk in the app's folder (the user's choice). Rich text is kept as plain text for now.

---

## Gotchas (learned the hard way)

1. **Menu bar icons on macOS 27 belong to `com.apple.MenuBarAgent`,** one level down inside an `AXGroup`, not to Control Centre. See `MenuBarExtras` in `SystemAction.swift`. Launchpad is gone; `/System/Applications/Apps.app` replaces it.
2. **Assigning a property inside an `@Observable` class's `init` still runs its `didSet`.** That caused a launch crash, through a recursive `ShortcutStore.shared`. Both stores now guard with `isLoaded`.
3. **AppKit pushes windows out of the menu bar area.** The notch bar overrides `constrainFrameRect(_:to:)`.
4. **Some apps report their window position late while being dragged**, Electron apps such as Claude in particular. Use the window server (`CGWindowListCopyWindowInfo`), not Accessibility, to follow a drag.
5. **Some apps (Chrome) switch on `AXEnhancedUserInterface`**, which makes window moves wobbly. `WindowMover` switches it off while moving a window.
6. **`UserDefaults(suiteName: UserDefaults.globalDomain)` doesn't work.** `UserDefaults.standard` already includes the global settings.
7. **The `shortcuts` command, AppleScript and shell scripts run as child processes.** AppleScript also needs the `com.apple.security.automation.apple-events` entitlement (in `Glide/Shortie.entitlements`) and `NSAppleEventsUsageDescription`.
8. **SwiftUI grouped forms style the first section header on a page differently.** Always use `SectionTitle`.
9. **A `\\"` inside a Swift string written from Python ends the string early.** This bit twice.

### Tooling notes for this machine

- **`log` is a zsh builtin.** Use `/usr/bin/log show --predicate 'subsystem == "com.slopbookpro.Glide"'`.
- **There's no `timeout` command.** Run things in the background and `kill` them.
- **`cd` persists between shell calls.** Always give `xcodebuild` absolute paths.
- **The shell has no Accessibility permission**; only the app does. Accessibility checks have to run inside the app, for example as a temporary `os.Logger` diagnostic, and are removed afterwards.
- **Computer-use tools can't see Shortie**, because it isn't in `/Applications`. Use snapshot mode instead (below).

---

## How to check your work

- **Snapshots of every page (debug builds only):**
  `build/Build/Products/Debug/Shortie.app/Contents/MacOS/Shortie --snapshots /some/folder`
  This draws every dashboard page and four editors, in light and dark, to PNG files, then quits.
  - The sidebar and window title look blank in these images. That's only a quirk of drawing them this way.
  - Gestures and Permissions show "no permission" states, because the snapshot process isn't trusted.
- **Idle cost:**
  `ps -o %cpu=,rss= -p $(pgrep -x Shortie)`
  `top -l 3 -s 3 -stats pid,cpu,idlew,power -pid $(pgrep -x Shortie)`
  Last measured: 0.0% CPU, 0 wake-ups, energy impact 0.0, about 85 MB of memory (debug build).
- **Crashes:** `~/Library/Logs/DiagnosticReports/Shortie-*.ips`
- **Commits:** the user confirms each piece works before it's committed. Commit messages end with the Claude co-author line.

---

## Testing status

**Confirmed working by the user:**
- The shell and onboarding
- Keyboard shortcuts
- Window snapping and gliding
- Scrolling
- The notch bar
- Window buttons
- Gestures (detection, round 1 and the actions)
- Control Centre and the other system actions
- Mouse buttons
- The rename
- Per-app rules
- Text shortcuts and automations
- The Hyper key
- Window dragging
- The redesign (all three steps)
- Clipboard history
- Power actions

**Built, checked with snapshots or measurements, but not yet confirmed by the user:**
- The window switcher
- Custom menus
- The app icon
- The efficiency changes
- The final polish pass

---

## Working with the user

- **Who they are:** new to Swift and macOS development. They want to go **slowly**, in plain language, one decision at a time, with **testing before each commit**.
- **Interface:** a macOS 27 / Apple feel, minimal text (details behind ⓘ), smooth animations, no cut-off or overlapping text.
- **Behaviour:** "feel"-related behaviour should come from established algorithms, not homemade curves.
- **Pace:** they often reply with a single button label ("All working", "Something's off"). When the message is empty or vague, ask what they saw.

---

## What's next

See [ROADMAP.md](ROADMAP.md). The main candidates:

1. **Confirm the untested items** listed above.
2. **Small leftovers:**
   - Hold a mouse button and scroll
   - Magic Mouse gestures
   - Per-device mouse settings
   - Key sequences, device-connected and Wi-Fi triggers
   - Rich text in clipboard history
   - Several Actions allowed as a custom-menu item
3. **Beyond BetterTouchTool:**
   - A command palette
   - A trigger debugger
   - Importing BetterTouchTool presets
4. **Release prep:**
   - Rename the internal project from Glide if wanted
   - Pick a final name: "Shortie" is close to BetterTouchTool's trademark
   - Paid developer account, notarisation, an update mechanism, and a GitHub remote for backup and cloud sessions (there is none yet)
