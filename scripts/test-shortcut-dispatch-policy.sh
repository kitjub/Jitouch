#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-shortcut-dispatch-policy-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 \
    -std=c11 -Wall -Wextra -Werror \
    -I "$repo_root/jitouch/Jitouch" \
    "$repo_root/jitouch/Jitouch/JTShortcutDispatchPolicy.c" \
    "$repo_root/tests/JTShortcutDispatchPolicyTests.c" \
    -framework ApplicationServices \
    -o "$test_build/JTShortcutDispatchPolicyTests"

"$test_build/JTShortcutDispatchPolicyTests"
