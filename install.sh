#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Claude Code Notify Installer ===${NC}\n"

# --- Platform check ---
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo -e "${YELLOW}Note: macOS-only for now. See scripts/notify-if-away.ps1 for Windows.${NC}"
  echo "Skipping macOS-specific setup..."
fi

# --- terminal-notifier ---
if ! command -v terminal-notifier &>/dev/null; then
  echo "Installing terminal-notifier..."
  if command -v brew &>/dev/null; then
    brew install terminal-notifier
  else
    echo -e "${RED}Homebrew not found. Install it first: https://brew.sh${NC}"
    echo "Then run: brew install terminal-notifier"
    exit 1
  fi
else
  echo -e "${GREEN}✓${NC} terminal-notifier found"
fi

# --- Copy scripts ---
SCRIPTS_DIR="$HOME/.claude/scripts"
mkdir -p "$SCRIPTS_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/scripts"
cp "$SCRIPT_DIR/notify-if-away.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR/notify-if-away.sh"
echo -e "${GREEN}✓${NC} notify-if-away.sh installed to $SCRIPTS_DIR"

if [ -f "$SCRIPT_DIR/session-title.sh" ]; then
  cp "$SCRIPT_DIR/session-title.sh" "$SCRIPTS_DIR/"
  chmod +x "$SCRIPTS_DIR/session-title.sh"
  echo -e "${GREEN}✓${NC} session-title.sh installed to $SCRIPTS_DIR"
fi

# --- Merge hooks into settings.json ---
SETTINGS_FILE="$HOME/.claude/settings.json"

# Our hooks definition
HOOKS_JSON=$(cat <<'HOOKS'
{
  "PermissionRequest": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/scripts/notify-if-away.sh \"Claude Code\" \"Glass\""
        }
      ]
    }
  ],
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "bash ~/.claude/scripts/notify-if-away.sh \"Claude Code\" \"Pop\" --summary"
        }
      ]
    }
  ]
}
HOOKS
)

python3 - "$SETTINGS_FILE" "$HOOKS_JSON" <<'PYEOF'
import sys, json, os, shutil

settings_file = sys.argv[1]
hooks_to_add = json.loads(sys.argv[2])

# Load existing or create default
if os.path.exists(settings_file):
    with open(settings_file) as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as e:
            print(f"\033[0;31mError: {settings_file} is not valid JSON: {e}\033[0m")
            print("Fix the file and re-run the installer, or add hooks manually:")
            print("https://github.com/ayahugoll-creator/claude-code-notify#install")
            sys.exit(1)
else:
    config = {}

# Backup
backup = settings_file + ".bak"
shutil.copy2(settings_file, backup) if os.path.exists(settings_file) else None

# Merge hooks
existing_hooks = config.get("hooks", {})
changed = False
for event, entries in hooks_to_add.items():
    if event not in existing_hooks:
        existing_hooks[event] = []
    # Check if our command already exists
    our_cmd = entries[0]["hooks"][0]["command"]
    already_there = any(
        h["hooks"][0]["command"] == our_cmd
        for h in existing_hooks[event]
        if h.get("hooks") and h["hooks"][0].get("command")
    )
    if not already_there:
        existing_hooks[event].extend(entries)
        changed = True

if not changed:
    print("\033[1;33mHooks already configured — nothing to merge.\033[0m")
else:
    config["hooks"] = existing_hooks
    with open(settings_file, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"\033[0;32m✓\033[0m Hooks merged into {settings_file}")
    if os.path.exists(backup):
        print(f"  Backup saved to {backup}")

PYEOF

echo ""
echo -e "${GREEN}=== Done! ===${NC}"
echo "Hooks will activate on next Claude Code session."
echo ""
echo "Test it: start a new Claude Code session, switch to another app,"
echo "and wait for Claude to finish — you should see a notification."
echo ""
echo "For details: https://github.com/ayahugoll-creator/claude-code-notify"
