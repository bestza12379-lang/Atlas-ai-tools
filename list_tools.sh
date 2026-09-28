#!/data/data/com.termux/files/usr/bin/bash

FILE="$HOME/ai-tools/ai_agent_auto.sh"

LINE="$(grep -E '^[[:space:]]*case "\|check_app\|get_app_state\|get_ram\|' "$FILE" | head -1 || true)"

if [ -z "$LINE" ]; then
    echo "ERROR: Controller whitelist case not found"
    exit 1
fi

printf '%s\n' "$LINE" |
    sed 's/.*case "//; s/" in.*//' |
    tr '|' '\n' |
    sed '/^$/d'
