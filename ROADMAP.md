# Glide roadmap

The goal is everything BetterTouchTool does, plus more, built to feel like Apple made it.
We build one piece at a time and save a git checkpoint after each piece works.

## Done

1. **App shell** – menu bar icon (left-click opens the dashboard, right-click shows About/Quit), welcome window, permissions.
2. **Keyboard shortcuts** – open an app, run an Apple Shortcut, open a website or file, type text. Saved to `shortcuts.json`.
3. **Window snapping** – halves, corners, thirds, maximise, centre, restore, next display; size cycling ½ → ⅓ → ⅔.
4. **Scrolling fix** (replaces LinearMouse) – separate wheel direction, smooth momentum scrolling with a speed slider.
5. **Notch bar** – a black menu bar that hides the notch, switched on per screen.
6. **Traffic lights** – any click on a window's red, yellow or green button can run any action
   (e.g. click green to maximise without full screen). New window and app commands: close, minimise,
   full screen, close or minimise all windows, hide, hide others, quit.
7. **Polish** – windows glide into place with Apple's spring; steadier dashboard sidebar.
8. **Trackpad gestures** – about 70: taps, double taps, tap and hold, TipTaps, swipes, edge swipes,
   pinches, rotation, multi-finger and corner clicks, force click. Gesture recorder, Gesture Lab,
   warnings where macOS uses the same gesture.
9. **Many more actions** – mouse clicks; System & Media (media keys, volume, brightness, Control Centre,
   Notification Centre, Mission Control, Show Desktop, screenshots, lock, sleep…); Press Keys with
   common shortcuts (also remaps keys).
10. **Mouse buttons** – middle, back, forward and more (with ⌃⌥⇧⌘) run any action; Back/Forward suggestions.

## Next ideas

- **Hold a mouse button and scroll** – e.g. hold Back and scroll to switch tabs or change the volume.
- **Magic Mouse gestures** – taps and swipes on a Magic Mouse.
- **Scrolling extras** – per-device settings, pointer speed and acceleration.

## Later: the rest of BetterTouchTool

- **Only in certain apps** – make any trigger work only in chosen apps.
- **More triggers** – key sequences, typed-word triggers (text expansion), Caps Lock as a "Hyper" key,
  app launched/quit, Mac wakes or sleeps, a device connected, Wi-Fi changed.
- **More actions** – Do Not Disturb, click a menu item, AppleScript and shell scripts,
  chains of several actions.
- **More window tools** – drag a window to a screen edge to snap, move or resize with a modifier key plus the mouse,
  a window switcher.
- **Clipboard history**.
- **Custom menu bar items and floating menus**.
- **Stream Deck support**.

## "And more": beyond BetterTouchTool

- **Trigger debugger** – see live why something did or didn't fire.
- **Command palette** – search every action and run it from one shortcut.
- **Import from BetterTouchTool** – bring your existing BTT presets across.
- **Readable, syncable config** – plain files you can back up, share or keep in iCloud.
