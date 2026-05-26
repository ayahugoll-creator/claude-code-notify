#!/bin/bash
# Set terminal window title to "claude: <topic>" for session identification
TOPIC=$(osascript -e 'text returned of (display dialog "What is this session about?" default answer "" with title "Claude Code" buttons {"Skip", "OK"} default button "OK")' 2>/dev/null)
if [ -n "$TOPIC" ]; then
  printf '\033]0;claude: %s\007' "$TOPIC"
else
  printf '\033]0;claude\007'
fi
