#!/data/data/com.termux/files/usr/bin/bash

set -u

PROMPT="${1:-}"
EVIDENCE="$(cat)"

if [ -z "$PROMPT" ]; then
    echo "[TRIPLE] ERROR: missing prompt" >&2
    exit 1
fi

run_key() {
    local KEY_NAME="$1"
    local KEY_VALUE="$2"

    echo "[TRIPLE] Trying $KEY_NAME..." >&2

    if printf '%s\n' "$EVIDENCE" |
        GEMINI_API_KEY="$KEY_VALUE" \
        ~/ai-tools/ask_ai_auto.sh "$PROMPT"
    then
        echo "[TRIPLE] $KEY_NAME SUCCESS" >&2
        return 0
    fi

    echo "[TRIPLE] $KEY_NAME FAILED" >&2
    return 1
}

if [ -n "${GEMINI_API_KEY:-}" ]; then
    run_key "KEY1" "$GEMINI_API_KEY" && exit 0
fi

if [ -n "${GEMINI_API_KEY_2:-}" ]; then
    run_key "KEY2" "$GEMINI_API_KEY_2" && exit 0
fi

if [ -n "${GEMINI_API_KEY3:-}" ]; then
    run_key "KEY3" "$GEMINI_API_KEY3" && exit 0
fi

echo "[TRIPLE] ALL API KEYS FAILED" >&2
exit 1
