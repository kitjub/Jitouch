# Programmatic settings app

This directory replaces the legacy `NSPreferencePane`/XIB shell with a small
AppKit menu-bar application. It deliberately keeps the historical settings
contract:

- preferences domain: `com.jitouch.Jitouch`
- global enable key: `enAll` (integer `0` or `1`)
- settings-to-engine distributed notification: `My Notification`, object
  `com.jitouch.Jitouch.PrefpaneTarget`
- engine-to-settings distributed notification: `My Notification2`, object
  `com.jitouch.Jitouch.PrefpaneTarget2`

The store sends the complete preferences dictionary after a change because the
existing engine's notification handler replaces its in-memory dictionary with
the notification's `userInfo`.

The settings window is SwiftUI (`ui/`), laid out like System Settings: a
sidebar with General, Trackpad, Magic Mouse and Drawing pages, grouped forms,
and gesture assignments grouped by application. It edits the established
general, Trackpad, Magic Mouse and drawing-recognition keys through
`JTSettingsStore`, which updates selected rows in the nested command arrays
while preserving unknown legacy rows and application-specific assignments the
user did not edit.

The menu-bar item, engine lifecycle and preferences adapter stay in
Objective-C. `ui/JTSwiftBridge.h` exposes them to Swift, and the Swift module
emits `JitouchModern-Swift.h` so the app delegate can open the window. There is
still no storyboard, XIB, `ibtool` or Xcode project: `scripts/build-clt.sh`
compiles the Swift files with `swiftc` from the Command Line Tools and links
them with the ARC Objective-C files, `Cocoa.framework` and `SwiftUI.framework`.
The final combined app uses `LSUIElement = true` and the separate bundle
identifier `com.jitouch.JitouchModern`; the preferences adapter continues to
address the legacy `com.jitouch.Jitouch` domain explicitly.
