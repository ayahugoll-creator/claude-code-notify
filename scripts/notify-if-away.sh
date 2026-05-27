#!/bin/bash
# Smart notification for Claude Code hooks.
# Usage: notify-if-away.sh <title> <sound> [--summary] [--actions]
#   --summary   Parse stdin JSON for message text
#   --actions   Add Approve/Deny/Always buttons (for PermissionRequest)

TITLE="$1"
SOUND="$2"
WANT_SUMMARY=0
WANT_ACTIONS=0
for arg in "$@"; do
  [ "$arg" = "--summary" ] && WANT_SUMMARY=1
  [ "$arg" = "--actions" ]  && WANT_ACTIONS=1
done

# Parse stdin JSON
SUMMARY=""
EVENT_TYPE=""
INPUT=$(cat)

if [ $WANT_SUMMARY -eq 1 ]; then
  MSG=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Stop event
if 'last_assistant_message' in d:
    print('STOP|' + d['last_assistant_message'])
# PermissionRequest event
elif 'tool_name' in d:
    t = d.get('tool_name','')
    i = str(d.get('tool_input',''))
    if i and i != 'None' and i != '{}':
        if len(i) > 60:
            i = i[:60] + '...'
        print(f'PERM|[{t}] {i}')
    else:
        print(f'PERM|[{t}]')
elif 'message' in d:
    print('PERM|' + d['message'])
elif 'permission_rule' in d:
    print('PERM|' + d['permission_rule'])
else:
    # Unknown event — dump keys
    keys = list(d.keys())
    print('UNKNOWN|' + ','.join(keys[:5]))
" 2>/dev/null)

  EVENT_TYPE="${MSG%%|*}"
  SUMMARY="${MSG#*|}"
  if [ ${#SUMMARY} -gt 120 ]; then
    SUMMARY="${SUMMARY:0:120}..."
  fi
fi

# Walk up process tree to find owning claude process's TTY
PID=$$
OWN_TTY=""
while [ "$PID" -gt 1 ] 2>/dev/null; do
  COMM=$(ps -o comm= -p $PID 2>/dev/null)
  if [ "$COMM" = "claude" ]; then
    OWN_TTY=$(ps -o tty= -p $PID 2>/dev/null | tr -d ' ')
    break
  fi
  PID=$(ps -o ppid= -p $PID 2>/dev/null | tr -d ' ')
done

# If running inside tmux, resolve the real terminal TTY
if [ -n "$TMUX" ]; then
  REAL_TTY=$(tmux display-message -p '#{client_tty}' 2>/dev/null)
  if [ -n "$REAL_TTY" ]; then
    OWN_TTY="${REAL_TTY#/dev/}"
  fi
fi

# Fail safe: if TTY unknown, notify anyway
if [ -z "$OWN_TTY" ]; then
  terminal-notifier -title "$TITLE" -message "$SUMMARY" -sound "$SOUND" -activate "com.apple.Terminal" 2>/dev/null &
  exit 0
fi

# Check frontmost app
FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

if [ "$FRONT_APP" = "Terminal" ]; then
  FRONT_TTY=$(osascript -e 'tell application "Terminal" to return tty of selected tab of front window' 2>/dev/null)
  if [ "${FRONT_TTY#/dev/}" = "$OWN_TTY" ]; then
    exit 0
  fi
fi

# Jump script: focus the correct Terminal tab
JUMP_SCRIPT="tell application \"Terminal\"
    repeat with w in every window
        repeat with t in every tab of w
            if (tty of t) as text is \"/dev/$OWN_TTY\" then
                set selected tab of w to t
                set frontmost of w to true
                activate
                return
            end if
        end repeat
    end repeat
    activate
end tell"

# Auto-type helper (for action buttons)
make_action() {
  local KEY="$1"
  # Jump to tab, then type the response key
  echo "osascript -e 'tell application \"Terminal\"
    repeat with w in every window
        repeat with t in every tab of w
            if (tty of t) as text is \"/dev/$OWN_TTY\" then
                set selected tab of w to t
                set frontmost of w to true
                activate
                exit repeat
            end if
        end repeat
    end repeat
end tell' -e 'delay 0.3' -e 'tell application \"System Events\" to keystroke \"$KEY\"' -e 'tell application \"System Events\" to keystroke return'"
}

if [ $WANT_ACTIONS -eq 1 ]; then
  # PermissionRequest: show with action buttons
  APPROVE_CMD=$(make_action "y")
  DENY_CMD=$(make_action "n")
  ALWAYS_CMD=$(make_action "a")

  terminal-notifier \
      -title "$TITLE" \
      -message "$SUMMARY" \
      -subtitle "Permission required" \
      -sound "$SOUND" \
      -activate "com.apple.Terminal" \
      -actions "Approve (y);Always Allow (a);Deny (n)" \
      -execute "bash -c '$APPROVE_CMD'" \
      2>/dev/null &

  # Note: terminal-notifier -actions creates a dropdown.
  # The -execute only runs on the notification body click (default = approve).
  # For deny/always, we'd need separate listeners. The dropdown says what it does.
else
  # Stop event: simple click-to-jump
  terminal-notifier \
      -title "$TITLE" \
      -message "$SUMMARY" \
      -sound "$SOUND" \
      -activate "com.apple.Terminal" \
      -execute "osascript -e '$JUMP_SCRIPT'" \
      2>/dev/null &
fi
