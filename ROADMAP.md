# BestTouchTool roadmap

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
11. **Renamed to BestTouchTool.**
12. **Per-app rules** – any trigger can work in all apps, only some, or all but some; app-specific rules win.
13. **Text shortcuts** – type an abbreviation like ;email anywhere to expand it (or run any action).
14. **Automations** – run actions when apps open, quit or come forward; on wake, sleep, lock, unlock, charger.
15. **Hyper key** – hold Caps Lock for ⌃⌥⇧⌘; tap it and it's still Caps Lock.
16. **Window dragging** – drag to screen edges to snap (Liquid Glass preview), ⌃⌘-drag to move and ⌃⌥-drag
    to resize from anywhere.
17. **Window switcher** – every window, searchable, in a glass panel.
18. **Dashboard redesign** – grouped sidebar, page headers, minimal text with ⓘ details, one
    When / Do / Works In editor, smooth animations.
19. **Clipboard history** – Hyper+V; search, paste, pin; skips passwords; kept on this Mac only.
20. **Power actions** – choose a menu item, AppleScript, shell scripts, Several Actions with waits.
21. **Custom menus** – your own menus in the menu bar or at the pointer.
22. **App icon, efficiency and polish** – Liquid Glass icon; listeners switch off when unused
    (0% idle CPU, no wake-ups); consistent headings and layouts checked page by page.

See [HANDOFF.md](HANDOFF.md) for how it's built and what's still to confirm.

## Next ideas

- **Mouse** – hold a button and scroll (e.g. Back + scroll to switch tabs), Magic Mouse gestures,
  per-device settings, pointer speed and acceleration.
- **More triggers** – key sequences, a device connected, Wi-Fi changed.
- **Clipboard** – keep rich text (formatting and links), not just plain text.
- **Custom menus** – allow Several Actions as a menu item.
- **Stream Deck support**.

## "And more": beyond BetterTouchTool

- **Command palette** – search every action and run it from one shortcut.
- **Trigger debugger** – see live why something did or didn't fire.
- **Import from BetterTouchTool** – bring your existing BTT presets across.
- **Syncable config** – keep your settings in iCloud.

## Before a public release

- Choose a final name (BestTouchTool is close to BetterTouchTool's trademark).
- Paid Apple Developer account, notarisation, and an update mechanism.
- A GitHub remote, for backup and cloud sessions.
