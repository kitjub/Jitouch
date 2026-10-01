#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-settings-model-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"
swiftc="$(xcrun --sdk macosx --find swiftc)"
common=(-arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 -fobjc-arc
        -I "$repo_root/modern/settings" -I "$repo_root/modern/engine")

for source in \
    "$repo_root/modern/settings/JTSettingsStore.m" \
    "$repo_root/modern/settings/JTThreeFingerGestureSafety.m" \
    "$repo_root/tests/support/JTEngineControllerStub.m"; do
    "$clang" "${common[@]}" -c "$source" -o "$test_build/$(basename "${source%.m}").o"
done

"$swiftc" -target arm64-apple-macos13.0 -sdk "$sdk" -swift-version 5 \
    -import-objc-header "$repo_root/modern/settings/ui/JTSwiftBridge.h" \
    -Xcc -I"$repo_root/modern/settings" -Xcc -I"$repo_root/modern/engine" \
    "$repo_root/modern/settings/ui/AssignmentRules.swift" \
    "$repo_root/modern/settings/ui/SettingsModel.swift" \
    "$repo_root/tests/SettingsModelTests/main.swift" \
    "$test_build"/*.o \
    -framework Cocoa -framework SwiftUI \
    -o "$test_build/SettingsModelTests"

"$test_build/SettingsModelTests"
