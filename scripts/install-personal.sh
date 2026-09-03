#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_app="${BUILD_DIR:-$repo_root/build}/Jitouch Modern.app"
applications_dir="$HOME/Applications"
installed_app="$applications_dir/Jitouch Modern.app"
previous_personal_app="$applications_dir/Jitouch.app"
support_dir="$HOME/Library/Application Support/Jitouch Modern"
app_backups_dir="$support_dir/App Backups"
agent_backups_dir="$support_dir/LaunchAgent Backups"
agents_dir="$HOME/Library/LaunchAgents"
agent="$agents_dir/com.jitouch.JitouchModern.agent.plist"
legacy_agent="$agents_dir/com.jitouch.Jitouch.plist"
stamp="$(date +%Y%m%d-%H%M%S)"
auto_start="${AUTO_START:-1}"

[[ -d "$source_app" ]] || { printf 'error: build Jitouch Modern.app first\n' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")" == com.jitouch.JitouchModern ]] || {
    printf 'error: unexpected application bundle identifier\n' >&2; exit 1;
}

# Never replace the bundle underneath a running gesture engine. Ask Cocoa to
# terminate normally so it can release event taps and complete any simulated
# pointer-button transaction. Refuse the install instead of force-killing it.
if pgrep -f '/Jitouch Modern\.app/Contents/MacOS/Jitouch Modern$' >/dev/null 2>&1; then
    osascript -e 'tell application id "com.jitouch.JitouchModern" to quit' >/dev/null 2>&1 || true
    for _ in {1..30}; do
        if ! pgrep -f '/Jitouch Modern\.app/Contents/MacOS/Jitouch Modern$' >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
    if pgrep -f '/Jitouch Modern\.app/Contents/MacOS/Jitouch Modern$' >/dev/null 2>&1; then
        printf 'error: Jitouch Modern is still running; quit it normally before installing\n' >&2
        exit 1
    fi
fi

mkdir -p "$applications_dir" "$agents_dir" "$app_backups_dir" "$agent_backups_dir"
if [[ -e "$installed_app" ]]; then
    mv "$installed_app" "$app_backups_dir/Jitouch Modern.backup-$stamp.app"
    printf 'backed up existing app in Application Support as Jitouch Modern.backup-%s.app\n' "$stamp"
fi
cp -R "$source_app" "$installed_app"

# Migrate the first modernization build, which reused the legacy identity. Keep
# it as a recoverable backup so LaunchServices no longer sees two personal apps
# with the old bundle identifier.
if [[ -d "$previous_personal_app" ]] &&
   [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$previous_personal_app/Contents/Info.plist" 2>/dev/null || true)" == com.jitouch.Jitouch ]]; then
    mv "$previous_personal_app" "$app_backups_dir/Jitouch.previous-modern-$stamp.app"
    printf 'backed up the previous personal build in Application Support as Jitouch.previous-modern-%s.app\n' "$stamp"
fi

# Stop the legacy job when present, but leave its plist untouched so the old
# installation remains recoverable and distinguishable from this one.
launchctl bootout "gui/$UID/com.jitouch.Jitouch.agent" >/dev/null 2>&1 || {
    if [[ -e "$legacy_agent" ]]; then
        launchctl bootout "gui/$UID" "$legacy_agent" >/dev/null 2>&1 || true
    fi
}
launchctl bootout "gui/$UID/com.jitouch.Jitouch" >/dev/null 2>&1 || true

if [[ -e "$agent" ]]; then
    cp -p "$agent" "$agent_backups_dir/com.jitouch.JitouchModern.agent.plist.backup-$stamp"
    launchctl bootout "gui/$UID" "$agent" >/dev/null 2>&1 || true
fi

temporary_plist="$(mktemp "${TMPDIR:-/tmp}/jitouch-launchagent.XXXXXX")"
trap 'rm -f "$temporary_plist"' EXIT
plutil -create xml1 "$temporary_plist"
/usr/libexec/PlistBuddy -c 'Add :Label string com.jitouch.JitouchModern.agent' "$temporary_plist"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments array' "$temporary_plist"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string $installed_app/Contents/MacOS/Jitouch Modern" "$temporary_plist"
/usr/libexec/PlistBuddy -c 'Add :RunAtLoad bool true' "$temporary_plist"
/usr/libexec/PlistBuddy -c 'Add :KeepAlive bool false' "$temporary_plist"
plutil -convert xml1 "$temporary_plist"
cp "$temporary_plist" "$agent"
if [[ "$auto_start" == 1 ]]; then
    launchctl enable "gui/$UID/com.jitouch.JitouchModern.agent"
    launchctl bootstrap "gui/$UID" "$agent"
    printf 'installed %s and enabled login launch\n' "$installed_app"
else
    launchctl disable "gui/$UID/com.jitouch.JitouchModern.agent"
    printf 'installed %s in trial mode; it was not launched and login launch remains disabled\n' "$installed_app"
fi
printf 'legacy preference pane and preferences were preserved\n'
printf 'the legacy launch-agent plist was preserved and only its loaded job was stopped\n'
printf 'the previous Jitouch Modern launch agent was backed up before replacement when present\n'
