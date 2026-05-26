# Claude Code Notify

Smart macOS notifications for Claude Code that **know which session you're looking at**.

Unlike other notification tools that fire unconditionally, this uses TTY-level detection to skip notifications when you're watching the *specific* Claude Code session that triggered the event.

## Features

- **Session-level precision** — TTY-based detection; only notifies when you're NOT looking at the triggering session
- **Reply summaries** — Stop notifications show a 120-char preview of Claude's response
- **Click-to-jump** — clicking a notification activates Terminal.app and selects the exact tab
- **Multi-session safe** — run multiple Claude Code windows; notifications only fire when you're away from the right one
- **Zero dependencies** (beyond `terminal-notifier`) — pure bash + AppleScript

## Requirements

- macOS + Terminal.app
- `brew install terminal-notifier`

## Install

```bash
# 1. Install terminal-notifier
brew install terminal-notifier

# 2. Copy the script
mkdir -p ~/.claude/scripts
cp scripts/notify-if-away.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/notify-if-away.sh

# 3. Add hooks to ~/.claude/settings.json
```

Add this to your `~/.claude/settings.json`:

```json
"hooks": {
    "PermissionRequest": [{
        "matcher": "",
        "hooks": [{
            "type": "command",
            "command": "bash ~/.claude/scripts/notify-if-away.sh \"Claude Code\" \"Glass\""
        }]
    }],
    "Stop": [{
        "matcher": "",
        "hooks": [{
            "type": "command",
            "command": "bash ~/.claude/scripts/notify-if-away.sh \"Claude Code\" \"Pop\" --summary"
        }]
    }]
}
```

The `--summary` flag parses `last_assistant_message` from the Stop hook's stdin JSON.

## How it works

1. Hook fires (PermissionRequest / Stop)
2. Script walks up the process tree to find the owning `claude` process
3. Reads its TTY (e.g., `ttys003`)
4. Checks the frontmost Terminal.app tab's TTY via `osascript`
5. Match → you're looking at this exact session → **skip**
6. No match → fire `terminal-notifier` with click-to-jump action

The jump action iterates all Terminal windows/tabs to find the matching TTY and focuses it.

## Optional: Session naming

Copy `scripts/session-title.sh` to `~/.claude/scripts/` and add a `SessionStart` hook if you want a dialog to name each session at startup.

## Related

- [CCNotify](https://github.com/dazuiba/CCNotify) — Python + terminal-notifier
- [claude-code-notification](https://github.com/wyattjoh/claude-code-notification) — Rust, cross-platform
- [agent-notify](https://github.com/cfngc4594/agent-notify) — Multi-channel (sound, voice, ntfy)
