<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Shortie app icon">
</p>

<h1 align="center">Shortie</h1>

<p align="center">
  <b>Make your Mac do what you mean.</b><br>
  Trackpad gestures, keyboard and mouse shortcuts, window snapping and over a hundred actions,<br>
  in one small menu bar app that feels like Apple made it.
</p>

<p align="center">
  <a href="https://GITHUB_USER.github.io/Shortie/"><b>Website</b></a> ·
  <a href="#install"><b>Install</b></a> ·
  <a href="ROADMAP.md"><b>Roadmap</b></a>
</p>

<p align="center">
  <img src="docs/images/gesture-editor-light.png#gh-light-mode-only" width="440" alt="The gesture editor: a three-finger swipe down opens Control Centre, only in Safari and Finder">
  <img src="docs/images/gesture-editor-dark.png#gh-dark-mode-only" width="440" alt="The gesture editor: a three-finger swipe down opens Control Centre, only in Safari and Finder">
</p>

---

## Any trigger, any action, any app

Every rule in Shortie is three plain steps:

| **When** you… | **Do** this… | **Works in**… |
|---|---|---|
| swipe, tap, pinch or click the trackpad, press keys, type an abbreviation, press a mouse button, click a window's red/yellow/green button, or an app opens | open things, type, press keys, move windows, control media, change selected text, run scripts, or several actions in a row | every app, only the apps you pick, or every app except those |

## Features

- **Trackpad gestures:** about 70. Taps, double taps, tap and hold, TipTaps, 3–5 finger swipes, swipes in from an edge, pinches, rotation, multi-finger and corner clicks, force click. There's a recorder that learns yours, and a warning when macOS already uses a gesture.
- **Keyboard shortcuts:** any keys run any action. A **Hyper key** turns Caps Lock into ⌃⌥⇧⌘ while held and keeps it as Caps Lock when tapped.
- **Window snapping:** halves, thirds, fourths, corners, Almost Maximise, Make Larger/Smaller and more, by key or by dragging to a screen edge. Windows glide along Apple's own spring curve.
- **Window layouts:** save where every window sits and bring the whole arrangement back with one trigger.
- **Window buttons:** new tricks for the traffic lights. Green maximises without full screen; right-click red to quit.
- **Mouse:** extra buttons run any action. The wheel direction is set apart from the trackpad's, with smooth momentum scrolling.
- **Text shortcuts:** type `;email` anywhere and it expands.
- **Selected text:** UPPERCASE, Title Case, sort lines, URL-encode, search the web, read aloud, paste as plain text.
- **Clipboard history:** searchable, with pins. Skips passwords and stays on your Mac.
- **Custom menus:** in the menu bar or at the pointer.
- **Automations:** run actions when apps open or quit, or when your Mac wakes, sleeps, locks or plugs in.
- **And more:** media keys, volume and sound output, dark mode, Dock hiding, hidden files, screenshots, a window switcher, AppleScript and shell scripts, choosing menu items, and a black menu bar to hide the notch.

<p align="center">
  <img src="docs/images/windows-light.png#gh-light-mode-only" width="420" alt="The Window Snapping page">
  <img src="docs/images/windows-dark.png#gh-dark-mode-only" width="420" alt="The Window Snapping page">
  &nbsp;
  <img src="docs/images/steps-editor-light.png#gh-light-mode-only" width="340" alt="A shortcut that runs several actions in a row">
  <img src="docs/images/steps-editor-dark.png#gh-dark-mode-only" width="340" alt="A shortcut that runs several actions in a row">
</p>

## Built with care

- **Native:** Swift, SwiftUI and AppKit, with Liquid Glass on macOS 26 and later.
- **Light:** every listener switches itself off when nothing needs it, so it uses 0% CPU and causes no wake-ups when idle.
- **Private:** no accounts, no analytics, no network access. Your settings live in `~/Library/Application Support/Shortie`.
- **One permission:** Accessibility, used to see your input and move windows.

## Install

There's no signed download yet, so build it with Xcode:

```bash
git clone https://github.com/GITHUB_USER/Shortie.git
cd Shortie
open Glide.xcodeproj
```

In Xcode, choose your own team under **Signing & Capabilities**, then press **⌘R**. On first launch, Shortie asks for Accessibility permission. Then click the hand in the menu bar to open the dashboard.

**Requirements:** macOS 15 or later; Xcode 27 to build.

> Some trackpad features use macOS's private MultitouchSupport framework, so they may need updating after major macOS releases.

## Project notes

- The Xcode project and source folders still use the app's first name, **Glide**.
- [HANDOFF.md](HANDOFF.md) explains how everything is built.
- [ROADMAP.md](ROADMAP.md) lists what's done and what's next.

---

<sub>Shortie is an independent project, not made by or affiliated with Apple. Mac and macOS are trademarks of Apple Inc.</sub>
