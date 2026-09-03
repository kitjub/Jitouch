#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-engine-settings-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 \
    -fno-objc-arc -fblocks -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -I "$repo_root/jitouch/Jitouch" \
    "$repo_root/jitouch/Jitouch/Settings.m" \
    "$repo_root/tests/JTEngineSettingsTests.m" \
    -framework Cocoa \
    -o "$test_build/JTEngineSettingsTests"

"$test_build/JTEngineSettingsTests"
