# Building without Xcode

The personal Apple Silicon build uses only Apple's Command Line Tools. It does
not use `xcodebuild`, `ibtool`, an Apple Developer account, or a distribution
certificate.

## Build

```sh
make
make verify
```

The integrated gesture engine and programmatic settings application is written
to `build/Jitouch Modern.app`. It is arm64-only and ad-hoc signed for local use.
Open it with Finder or `open "build/Jitouch Modern.app"` and grant Accessibility
and Apple Events permissions when macOS requests them.

`build/JitouchEngine-arm64` is deliberately a smoke-test executable. It proves
that the unchanged engine compiles and links against the current private
`MultitouchSupport.framework`, but its old entry point still expects an Xcode-
compiled `MainMenu.nib`. Do not install that diagnostic binary as an app.

Other useful targets:

```sh
make probe          # enumerate multitouch devices through the private framework
make engine-smoke   # compile/link only the legacy engine diagnostic
make install        # back up an existing personal app, install, start at login
make uninstall      # move only this personal app/login item to Trash
make clean
```

Personal installation uses `~/Applications/Jitouch Modern.app` and the separate
LaunchAgent label `com.jitouch.JitouchModern.agent`. Installation stops a loaded
legacy job but does not overwrite or delete its
`~/Library/LaunchAgents/com.jitouch.Jitouch.plist`. The legacy preference pane
and saved `com.jitouch.Jitouch` preferences are not removed. Uninstall is
recoverable through Trash and affects only the modern app and login item.

The modern app deliberately uses bundle identifier `com.jitouch.JitouchModern`
so macOS Accessibility can distinguish it from the Developer-ID-signed legacy
app. The gesture settings adapter continues to address the legacy preferences
domain explicitly, preserving existing assignments. Because the personal build
is ad-hoc signed, a binary-changing rebuild can require granting Accessibility
again after installing the final build.

The build targets macOS 13 or later and Apple Silicon. Because
`MultitouchSupport.framework` is private, a future macOS update can change or
remove its ABI; rerun `make probe` and the smoke build after major OS updates.
Ad-hoc signing is sufficient for personal local use but is not suitable for
redistribution or notarization.
