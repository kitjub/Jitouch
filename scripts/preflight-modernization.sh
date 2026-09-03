#!/bin/bash

set -u

failures=0

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   %s\n' "$label"
    else
        printf 'FAIL %s\n' "$label"
        failures=$((failures + 1))
    fi
}

printf 'Jitouch modernization preflight\n'
printf 'architecture: %s\n' "$(uname -m)"
printf 'macOS: %s\n' "$(sw_vers -productVersion)"

check 'Apple Silicon host' test "$(uname -m)" = arm64
check 'Apple Command Line Tools selected' test -d "$(xcode-select -p 2>/dev/null)/SDKs"
check 'clang available' xcrun --sdk macosx --find clang
check 'macOS SDK available' xcrun --sdk macosx --show-sdk-path
check 'codesign available' command -v codesign
check 'system MultitouchSupport framework present' test -d /System/Library/PrivateFrameworks/MultitouchSupport.framework

if (( failures > 0 )); then
    printf '\n%d prerequisite(s) failed; build was not attempted.\n' "$failures"
    exit 1
fi

printf '\nPreflight passed. Run make, make verify, and make probe.\n'
