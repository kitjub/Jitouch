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

The programmatic window edits the established general, Trackpad, Magic Mouse,
and drawing-recognition keys. Its gesture editor updates selected rows in the
nested command arrays while preserving unknown legacy rows and existing
application-specific assignments that the user did not edit.

All UI is created in Objective-C, so the target needs no storyboard, XIB,
`ibtool`, or Xcode project. Compile the files in this directory with ARC and link
`Cocoa.framework`. The final combined app uses `LSUIElement = true` and the
separate bundle identifier `com.jitouch.JitouchModern`; the preferences adapter
continues to address the legacy `com.jitouch.Jitouch` domain explicitly.
