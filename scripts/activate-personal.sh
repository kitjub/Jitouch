#!/bin/bash

set -euo pipefail

agent="$HOME/Library/LaunchAgents/com.jitouch.JitouchModern.agent.plist"
label="com.jitouch.JitouchModern.agent"

[[ -f "$agent" ]] || {
    printf 'error: install Jitouch Modern before activating it\n' >&2
    exit 1
}

launchctl enable "gui/$UID/$label"
if pgrep -f '/Jitouch Modern\.app/Contents/MacOS/Jitouch Modern$' >/dev/null 2>&1; then
    printf 'enabled login launch; the already-running trial was left untouched\n'
else
    launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$UID" "$agent"
    printf 'enabled login launch and started Jitouch Modern\n'
fi
