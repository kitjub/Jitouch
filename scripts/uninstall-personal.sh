#!/bin/bash

set -euo pipefail

installed_app="$HOME/Applications/Jitouch Modern.app"
agent="$HOME/Library/LaunchAgents/com.jitouch.JitouchModern.agent.plist"
trash_dir="$HOME/.Trash"
stamp="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$trash_dir"
if [[ -e "$agent" ]]; then
    launchctl bootout "gui/$UID" "$agent" >/dev/null 2>&1 || true
    mv "$agent" "$trash_dir/com.jitouch.JitouchModern.agent.$stamp.plist"
fi

if [[ -d "$installed_app" ]]; then
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_app/Contents/Info.plist" 2>/dev/null || true)"
    [[ "$bundle_id" == com.jitouch.JitouchModern ]] || {
        printf 'error: refusing to move app with unexpected bundle identifier: %s\n' "$bundle_id" >&2
        exit 1
    }
    mv "$installed_app" "$trash_dir/Jitouch-Modern-uninstalled-$stamp.app"
fi

printf 'personal Jitouch Modern app and login item moved to Trash when present\n'
printf 'preferences, launch-agent backups, and legacy preference panes were preserved\n'
