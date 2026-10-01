#!/bin/bash
# Builds, verifies and zips Jitouch Modern.app for a GitHub release.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${BUILD_DIR:-$repo_root/build}"
app="$build_root/Jitouch Modern.app"

BUILD_DIR="$build_root" "$repo_root/scripts/build-clt.sh" all

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
archive="$build_root/Jitouch-Modern-$version-arm64.zip"
rm -f "$archive"
# ditto keeps the code signature and bundle metadata intact.
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"

printf 'packaged %s\n' "$archive"
shasum -a 256 "$archive"
