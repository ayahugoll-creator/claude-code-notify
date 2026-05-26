---
name: claude-code-notify
description: Smart macOS notifications for Claude Code — only alerts when you're not looking. Uses TTY-based session detection to skip notifications when the Claude Code window is frontmost. Supports reply summaries in Stop notifications. Use when user wants Claude Code notifications, away alerts, or "notify me when done".
---

# Claude Code Notify

Smart macOS notifications that know which session you're looking at.

## Quick start

Copy `scripts/notify-if-away.sh` to `~/.claude/scripts/` and add these hooks to `~/.claude/settings.json`:

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

The `--summary` flag extracts `last_assistant_message` from the Stop hook's stdin JSON and shows it as notification body.

## How it works

1. Walks up the process tree from the hook to find the owning `claude` process
2. Reads its TTY (e.g., `ttys003`)
3. Checks the frontmost Terminal.app tab's TTY via `osascript`
4. Match → you're looking at this session → skip notification
5. No match → you're away → fire macOS notification

## Requirements

- macOS only + Terminal.app (not iTerm2, not Warp, not VS Code terminal)
- `brew install terminal-notifier`

## Features

- **Session-level precision** — TTY-based detection skips notification only when you're looking at the *specific* session that triggered the event
- **Reply summaries** — Stop notifications show the last assistant message (truncated 120 chars)
- **Click to jump** — clicking a notification activates Terminal and selects the exact tab that triggered it

## Advanced

See [scripts/notify-if-away.sh](scripts/notify-if-away.sh) for implementation details.

See [scripts/session-title.sh](scripts/session-title.sh) for optional session naming via `SessionStart` hook.
