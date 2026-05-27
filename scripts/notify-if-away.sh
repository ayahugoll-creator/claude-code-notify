#!/bin/bash
# Smart notification for Claude Code hooks.
# Usage: notify-if-away.sh <title> <sound> [--summary]
# Only notifies if the user is NOT looking at THIS Claude Code session.
# Click notification → jump back to the exact Terminal tab.

TITLE="$1"
SOUND="$2"
WANT_SUMMARY=0
if [ "$3" = "--summary" ]; then
  WANT_SUMMARY=1
fi

# Parse stdin JSON for summary text
SUMMARY=""
if [ $WANT_SUMMARY -eq 1 ]; then
  INPUT=$(cat)
  LAST_MSG=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_assistant_message',''))" 2>/dev/null)
  if [ -n "$LAST_MSG" ]; then
    if [ ${#LAST_MSG} -gt 120 ]; then
      SUMMARY="${LAST_MSG:0:120}..."
    else
      SUMMARY="$LAST_MSG"
    fi
  fi
else
  INPUT=$(cat)
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

# Fail safe: if TTY unknown, notify anyway (no click-to-jump)
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

# Notify with click-to-jump: activate Terminal and select the correct tab
JUMP_SCRIPT="tell application \"Terminal\"
    repeat with w in every window
        set i to 1
        repeat with t in every tab of w
            if (tty of t) as text is \"/dev/$OWN_TTY\" then
                set selected tab of w to t
                set frontmost of w to true
                activate
                return
            end if
            set i to i + 1
        end repeat
    end repeat
    activate
end tell"

terminal-notifier \
    -title "$TITLE" \
    -message "$SUMMARY" \
    -sound "$SOUND" \
    -activate "com.apple.Terminal" \
    -execute "osascript -e '$JUMP_SCRIPT'" \
    2>/dev/null &
