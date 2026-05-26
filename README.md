# Claude Code Notify

**CLI-native** session-aware notifications for Claude Code. Built for terminal power users who run multiple Claude Code sessions in parallel.

Unlike other notification tools, this doesn't just fire on every event — it checks whether you're already looking at the *specific* session that triggered it. Only notifies when you're truly away.

**[▶ Watch the animated demo](https://raw.githack.com/ayahugoll-creator/claude-code-notify/main/demo.html)** *(interactive, 4-step auto-play)*

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

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/ayahugoll-creator/claude-code-notify/main/install.sh | bash
```

### Manual

```bash
brew install terminal-notifier
mkdir -p ~/.claude/scripts
cp scripts/notify-if-away.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/notify-if-away.sh
```

Then add to `~/.claude/settings.json`:

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

## vs. Other Tools

| Feature | claude-code-notify | [CCNotify](https://github.com/dazuiba/CCNotify) | [agent-notify](https://github.com/cfngc4594/agent-notify) |
|---|---|---|---|
| Session-aware (skip when looking) | ✅ TTY-level | — | — |
| Click-to-jump | → exact Terminal tab | → VS Code project | — |
| Reply summary in notification | ✅ 120-char | — | — |
| Multi-session safe | ✅ | — | — |
| Multi-channel (sound/voice/ntfy) | — | — | ✅ |
| Task duration | — | ✅ | — |
| Cross-platform | macOS + Windows (beta) | macOS | macOS |
| **Target user** | **CLI power user** | VS Code user | Multi-platform generalist |

**claude-code-notify** is purpose-built for the terminal-native workflow: multiple Claude Code windows running in parallel, no IDE dependency, notifications that don't interrupt you when you're already watching.
