#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-settings-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 -fobjc-arc \
    -Wall -Wextra -Werror \
    -I "$repo_root/modern/settings" \
    "$repo_root/modern/settings/JTSettingsStore.m" \
    "$repo_root/tests/JTSettingsStoreTests.m" \
    -framework Foundation \
    -o "$test_build/JTSettingsStoreTests"

mkdir -p "$test_build/home/Library/Preferences"
CFFIXED_USER_HOME="$test_build/home" "$test_build/JTSettingsStoreTests"
