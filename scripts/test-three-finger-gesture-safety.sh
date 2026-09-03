#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-three-finger-safety-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 -fobjc-arc \
    -Wall -Wextra -Werror \
    -I "$repo_root/modern/settings" \
    "$repo_root/modern/settings/JTThreeFingerGestureSafety.m" \
    "$repo_root/tests/JTThreeFingerGestureSafetyTests.m" \
    -framework Foundation \
    -o "$test_build/JTThreeFingerGestureSafetyTests"

"$test_build/JTThreeFingerGestureSafetyTests"
