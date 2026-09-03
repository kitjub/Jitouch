#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${BUILD_DIR:-$repo_root/build}"
mode="${1:-settings}"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"
framework_dir="/System/Library/PrivateFrameworks"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

preflight() {
    [[ "$(uname -m)" == arm64 ]] || die "this personal build targets Apple Silicon (arm64)"
    [[ -x "$clang" ]] || die "clang is unavailable; install Apple Command Line Tools"
    [[ -d "$sdk" ]] || die "macOS SDK is unavailable"
    [[ -d "$framework_dir/MultitouchSupport.framework" ]] || die "MultitouchSupport.framework is unavailable on this macOS"
    command -v codesign >/dev/null || die "codesign is unavailable"
    mkdir -p "$build_root"
}

compile_app() {
    preflight
    local app="$build_root/Jitouch Modern.app"
    local macos="$app/Contents/MacOS"
    local resources="$app/Contents/Resources"
    local objects="$build_root/objects"
    local binary="$macos/Jitouch Modern"
    rm -rf "$app"
    rm -rf "$objects"
    mkdir -p "$macos" "$resources" "$objects"

    local common=(-arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 -fblocks -O2
        -I "$repo_root/modern/settings" -I "$repo_root/modern/engine"
        -I "$repo_root/jitouch/Jitouch")
    local source name
    local linked_objects=()

    # The new AppKit lifecycle and settings UI use ARC.
    for source in \
        "$repo_root/modern/settings/main.m" \
        "$repo_root/modern/settings/JTSettingsAppDelegate.m" \
        "$repo_root/modern/settings/JTSettingsStore.m" \
        "$repo_root/modern/settings/JTGestureEditorController.m" \
        "$repo_root/modern/settings/JTShortcutRecorderField.m" \
        "$repo_root/modern/settings/JTThreeFingerGestureSafety.m"; do
        name="settings-$(basename "${source%.m}").o"
        "$clang" "${common[@]}" -fobjc-arc -Wall -Wextra -c "$source" -o "$objects/$name"
        linked_objects+=("$objects/$name")
    done

    # The controller and retained legacy engine use manual reference counting.
    for source in \
        "$repo_root/modern/engine/JTEngineController.m" \
        "$repo_root/jitouch/Jitouch/Gesture.m" \
        "$repo_root/jitouch/Jitouch/JTCloseStrategy.m" \
        "$repo_root/jitouch/Jitouch/CursorWindow.m" \
        "$repo_root/jitouch/Jitouch/CursorView.m" \
        "$repo_root/jitouch/Jitouch/Settings.m" \
        "$repo_root/jitouch/Jitouch/GestureWindow.m" \
        "$repo_root/jitouch/Jitouch/GestureView.m" \
        "$repo_root/jitouch/Jitouch/SizeHistory.m" \
        "$repo_root/jitouch/Jitouch/KeyUtility.m"; do
        name="engine-$(basename "${source%.m}").o"
        "$clang" "${common[@]}" -fno-objc-arc -fobjc-weak -fobjc-exceptions \
            -Wno-deprecated-declarations -include "$repo_root/jitouch/Jitouch/Jitouch_Prefix.pch" \
            -c "$source" -o "$objects/$name"
        linked_objects+=("$objects/$name")
    done

    source="$repo_root/jitouch/Jitouch/JTThreeFingerDragPolicy.c"
    name="engine-$(basename "${source%.c}").o"
    "$clang" "${common[@]}" -std=c11 -Wall -Wextra -Werror \
        -c "$source" -o "$objects/$name"
    linked_objects+=("$objects/$name")

    source="$repo_root/jitouch/Jitouch/JTEdgeVolumeScrubPolicy.c"
    name="engine-$(basename "${source%.c}").o"
    "$clang" "${common[@]}" -std=c11 -Wall -Wextra -Werror \
        -c "$source" -o "$objects/$name"
    linked_objects+=("$objects/$name")

    source="$repo_root/jitouch/Jitouch/JTVolumeStepAccumulator.c"
    name="engine-$(basename "${source%.c}").o"
    "$clang" "${common[@]}" -std=c11 -Wall -Wextra -Werror \
        -c "$source" -o "$objects/$name"
    linked_objects+=("$objects/$name")

    for source in \
        "$repo_root/jitouch/Jitouch/JTCommandDispatchPolicy.c" \
        "$repo_root/jitouch/Jitouch/JTKeyboardEvent.c" \
        "$repo_root/jitouch/Jitouch/JTOneFixTapClassifier.c" \
        "$repo_root/jitouch/Jitouch/JTOneFixTapClickSuppression.c" \
        "$repo_root/jitouch/Jitouch/JTShortcutDispatchPolicy.c"; do
        name="engine-$(basename "${source%.c}").o"
        "$clang" "${common[@]}" -std=c11 -Wall -Wextra -Werror \
            -c "$source" -o "$objects/$name"
        linked_objects+=("$objects/$name")
    done

    "$clang" -arch arm64 -isysroot "$sdk" "${linked_objects[@]}" \
        -F"$framework_dir" -framework MultitouchSupport \
        -framework Cocoa -framework Carbon -framework IOKit -framework ScriptingBridge \
        -o "$binary"
    cp "$repo_root/packaging/Jitouch-Info.plist" "$app/Contents/Info.plist"
    cp "$repo_root/jitouch/jitouchicon.icns" "$resources/jitouchicon.icns"
    cp "$repo_root/jitouch/logosmall.png" "$repo_root/jitouch/logosmall@2x.png" "$resources/"
    cp "$repo_root/jitouch/logosmalloff.png" "$repo_root/jitouch/logosmalloff@2x.png" "$resources/"
    cp "$repo_root/jitouch/move.png" "$repo_root/jitouch/resize.png" "$repo_root/jitouch/tab.png" "$resources/"
    # Give personal ad-hoc builds a stable designated requirement.  Without an
    # explicit requirement, codesign falls back to the binary's CDHash, so every
    # rebuild looks like a different application to macOS privacy controls.
    codesign --force --sign - --timestamp=none \
        --requirements '=designated => identifier "com.jitouch.JitouchModern"' \
        "$app"
    printf 'built %s\n' "$app"
}

compile_engine_smoke() {
    preflight
    local output="$build_root/JitouchEngine-arm64"
    "$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 \
        -fblocks -fobjc-weak -fobjc-exceptions -O2 -Wno-deprecated-declarations \
        -include "$repo_root/jitouch/Jitouch/Jitouch_Prefix.pch" \
        -I "$repo_root/jitouch/Jitouch" -I "$repo_root/modern/settings" \
        "$repo_root"/jitouch/Jitouch/*.m \
        "$repo_root/jitouch/Jitouch/JTThreeFingerDragPolicy.c" \
        "$repo_root/jitouch/Jitouch/JTEdgeVolumeScrubPolicy.c" \
        "$repo_root/jitouch/Jitouch/JTVolumeStepAccumulator.c" \
        "$repo_root/jitouch/Jitouch/JTCommandDispatchPolicy.c" \
        "$repo_root/jitouch/Jitouch/JTKeyboardEvent.c" \
        "$repo_root/jitouch/Jitouch/JTOneFixTapClassifier.c" \
        "$repo_root/jitouch/Jitouch/JTOneFixTapClickSuppression.c" \
        "$repo_root/jitouch/Jitouch/JTShortcutDispatchPolicy.c" \
        "$repo_root/modern/settings/JTThreeFingerGestureSafety.m" \
        -F"$framework_dir" -framework MultitouchSupport \
        -framework Cocoa -framework Carbon -framework IOKit -framework ScriptingBridge \
        -o "$output"
    codesign --force --sign - --timestamp=none "$output"
    printf 'linked engine smoke binary %s\n' "$output"
}

verify_outputs() {
    local app="$build_root/Jitouch Modern.app"
    local binary="$app/Contents/MacOS/Jitouch Modern"
    [[ -d "$app" ]] || die "Jitouch Modern app is not built"
    [[ "$(lipo -archs "$binary")" == arm64 ]] || die "Jitouch Modern executable is not arm64-only"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == com.jitouch.JitouchModern ]] || die "unexpected bundle identifier"
    plutil -lint "$app/Contents/Info.plist"
    codesign --verify --deep --strict --verbose=2 "$app"
    codesign -d -r- "$app" 2>&1 | grep -Fq 'designated => identifier "com.jitouch.JitouchModern"' \
        || die "Jitouch Modern does not have the stable designated requirement"
    printf 'verified integrated arm64 app, plist identity, and ad-hoc signature\n'
}

build_probe() {
    preflight
    local output="$build_root/mt-link-probe"
    "$clang" -arch arm64 -isysroot "$sdk" -fobjc-arc \
        "$repo_root/tools/mt-link-probe.m" -framework Foundation \
        -F"$framework_dir" -framework MultitouchSupport -o "$output"
    "$output"
}

case "$mode" in
    app|settings) compile_app ;;
    engine-smoke) compile_engine_smoke ;;
    verify) verify_outputs ;;
    probe) build_probe ;;
    clean)
        [[ "$build_root" == "$repo_root" || "$build_root" == / ]] && die "refusing unsafe build directory"
        rm -rf "$build_root"
        ;;
    all) compile_app; verify_outputs ;;
    *) die "usage: $0 {app|settings|engine-smoke|verify|probe|clean|all}" ;;
esac
