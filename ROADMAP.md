# Shortie roadmap

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
11. **Renamed** from Glide to BestTouchTool, and later to **Shortie**.
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

23. **Window layouts** – save where every window is and glide them all back with one trigger.
24. **Renamed to Shortie**, with a website in `docs/`.

## Every gesture and action: the plan

Built one batch at a time, each tested before it's saved. Batches 1–3 are done.

1. **Mac actions** – toggle dark mode, Dock hiding, menu bar hiding, hidden files, desktop icons;
   microphone on/off; keyboard backlight; screen saver; Force Quit window; eject all disks;
   log out, restart, shut down (with macOS's own confirmation); open the dashboard; pause Shortie.
   A small glass HUD confirms toggles.
2. **Window actions** – previous display, almost maximise, maximise height or width, make larger or
   smaller, nudge to an edge without resizing, quit other apps.
3. **Text and feedback actions** – change selected text (UPPERCASE, lowercase, Title Case, trim,
   remove line breaks, sort lines, URL-encode…), search the web for it, show a HUD message,
   speak text, set volume to a level, switch sound output.
4. **Mouse actions** – triple click, ⌘-click, move the pointer to the screen's or window's centre,
   scroll to top or bottom.
5. **More trackpad gestures** – diagonal swipes, TipSwipes (rest a finger, swipe others),
   corner taps, edge taps, three-finger rotate, swipe and hold, tap sequences, edge sliders
   (slide along an edge to change volume or brightness).
6. **Keyboard triggers** – key sequences (press G then M), double-press a modifier (⌘ ⌘),
   tap a modifier alone (right ⌘), hold a key, left vs right modifiers.
7. **Mouse triggers** – hold a button and scroll, hold a button and move (mouse gestures),
   screen corners and edges, scroll over the menu bar or Dock, mouse drawings, Magic Mouse gestures.
8. **Other triggers** – at a time or every N minutes, Wi-Fi network changed, USB or Bluetooth device
   connected, display connected, battery level, clipboard changed.
9. **And then some** – if/else conditions inside Several Actions, command palette, trigger debugger.

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

- Paid Apple Developer account, notarisation, and an update mechanism.
- A GitHub remote, for backup and cloud sessions.
