# Glide roadmap

The goal is everything BetterTouchTool does, plus more, built to feel like Apple made it.
We build one piece at a time and save a git checkpoint after each piece works.

## Done

1. **App shell** – menu bar icon (left-click opens the dashboard, right-click shows About/Quit), welcome window, permissions.
2. **Keyboard shortcuts** – open an app, run an Apple Shortcut, open a website or file, type text. Saved to `shortcuts.json`.
3. **Window snapping** – halves, corners, thirds, maximise, centre, restore, next display; size cycling ½ → ⅓ → ⅔.
4. **Scrolling fix** (replaces LinearMouse) – separate wheel direction, smooth momentum scrolling with a speed slider.

## Next

Possible scrolling extras: per-device settings, pointer speed and acceleration.

5. **Notch bar** – a black bar across the menu bar that hides the notch, switched on per screen.
6. **Trackpad and mouse gestures** – multi-finger taps, swipes and clicks; Magic Mouse; extra mouse buttons.
   Includes a gesture recorder: do the gesture rather than picking it from a list.

## Later: the rest of BetterTouchTool

- **Only in certain apps** – make any trigger work only in chosen apps.
- **More triggers** – key sequences, typed-word triggers (text expansion), Caps Lock as a "Hyper" key,
  app launched/quit, Mac wakes or sleeps, a device connected, Wi-Fi changed.
- **More actions** – volume, brightness, media keys, lock screen, sleep, screenshots, Do Not Disturb,
  click a menu item, AppleScript and shell scripts, chains of several actions.
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
