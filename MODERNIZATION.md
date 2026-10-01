# Jitouch modernization

Target environment: Apple Silicon and current macOS, initially validated on an
M1 Pro running macOS 26.

## Legacy architecture

Jitouch consists of two separate Xcode projects:

1. `jitouch/Jitouch/Jitouch.xcodeproj` builds the background gesture engine.
2. `prefpane/Jitouch.xcodeproj` builds an `NSPreferencePane` settings bundle and
   embeds the engine app as a resource.

The gesture engine reads raw touch data through Apple's private
`MultitouchSupport.framework`. Accessibility APIs and Core Graphics event taps
perform configured actions. This means the app cannot be sandboxed and requires
Accessibility permission.

## Modern personal build

The modern target combines the retained gesture engine with an AppKit menu-bar
app and a SwiftUI settings window. It has no XIB, Preference Pane, or Xcode
project dependency and builds as a native arm64 app using Command Line Tools.
The existing `com.jitouch.Jitouch` preferences domain and gesture command arrays
are preserved, while the app identity is separated as
`com.jitouch.JitouchModern` to avoid Accessibility and LaunchServices collisions
with the legacy signed app.

## Migration sequence

1. Completed: native arm64 compile and link with the macOS 26 SDK.
2. Completed: standalone, programmatic settings and menu-bar UI.
3. Completed: combined engine lifecycle, wake reload, settings notifications,
   first-run defaults, and recoverable personal install scripts.
4. Completed: event-tap recovery and several memory/API correctness fixes without
   changing gesture thresholds or recognition logic.
5. Completed: visual editing of nested gesture-command arrays with preservation
   of unknown legacy rows, native three-finger-drag conflict protection, and
   modern shortcut/event routing.
6. Remaining long-term work: broader hardware testing and revalidation after
   each major macOS release.

## Local preflight

Install Apple's Command Line Tools, then run:

```sh
./scripts/preflight-modernization.sh
```

The script verifies the host, SDK, compiler, signing tool, and private framework.
Use `make`, `make verify`, and `make probe` for the complete build and checks.
