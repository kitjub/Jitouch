#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d "${TMPDIR:-/tmp}/jitouch-close-strategy-tests.XXXXXX")"
trap 'rm -rf "$test_build"' EXIT
sdk="$(xcrun --sdk macosx --show-sdk-path)"
clang="$(xcrun --sdk macosx --find clang)"

"$clang" -arch arm64 -isysroot "$sdk" -mmacosx-version-min=13.0 \
    -fno-objc-arc -Wall -Wextra -Werror \
    -I "$repo_root/jitouch/Jitouch" \
    "$repo_root/jitouch/Jitouch/JTCloseStrategy.m" \
    "$repo_root/tests/JTCloseStrategyTests.m" \
    -framework Cocoa -framework ApplicationServices \
    -o "$test_build/JTCloseStrategyTests"

"$test_build/JTCloseStrategyTests"
