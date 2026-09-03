#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-shortcut-recorder-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 -fobjc-arc \
    -Wall -Wextra -Werror \
    -I "$repo_root/modern/settings" \
    "$repo_root/modern/settings/JTShortcutRecorderField.m" \
    "$repo_root/tests/JTShortcutRecorderFieldTests.m" \
    -framework Cocoa -framework ApplicationServices \
    -o "$test_build/JTShortcutRecorderFieldTests"

"$test_build/JTShortcutRecorderFieldTests"
