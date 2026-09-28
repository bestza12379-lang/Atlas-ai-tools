#!/data/data/com.termux/files/usr/bin/bash

if [ -z "$GEMINI_API_KEY" ]; then
    echo "ERROR: GEMINI_API_KEY not set"
    exit 1
fi

PROMPT="${1:-}"
EVIDENCE="$(cat)"

CONTRACT="$(~/ai-tools/tool_contracts.sh)"

if [ -z "$PROMPT" ]; then
    echo "ERROR: prompt required"
    exit 1
fi

PAYLOAD=$(python - "$PROMPT" "$EVIDENCE" "$CONTRACT" <<'PY'
import json
import sys

prompt = sys.argv[1]
evidence = sys.argv[2]
contract = sys.argv[3]

system = """You are an evidence-driven investigation planner.

You do NOT execute tools yourself.
You only select the next TOOL and ARG.

Use ONLY:
1. TARGET
2. EVIDENCE
3. EXECUTED_TOOLS
4. TOOL CONTRACTS

Never invent classes, methods, packages, paths, arguments, or evidence.

The TOOL CONTRACT defines the valid syntax for each tool.
Evidence determines which actual value should be used.

Rules:
- Never use ARG=target or ARG=TARGET.
- Never invent a class/method/package/path.
- Never repeat an already executed TOOL + ARG.
- If there is no evidence-supported valid next check, return TOOL: NONE.
- Contract is NOT Evidence.
- Do not claim something is confirmed unless Evidence supports it.

Return exactly:

SOURCE:
...

CONFIRMED:
...

NOT_CONFIRMED:
...

EVIDENCE_GAP:
...

NEXT_CHECK:
TOOL: <tool>
ARG: <arg>
REASON: <reason>

If no valid next check exists:

NEXT_CHECK:
TOOL: NONE
ARG: NONE
REASON: <reason>
"""

user = f"""QUESTION:
{prompt}

=== TOOL CONTRACTS ===
{contract}

=== EVIDENCE ===
{evidence}

Choose the next investigation tool."""
    
contents = [
    {
        "role": "user",
        "parts": [{"text": system + "\n\n" + user}]
    }
]

print(json.dumps({"contents": contents}, ensure_ascii=False))
PY
)

MODELS=(
    "gemini-3.8-flash"
    "gemini-3.5-flash"
)

MAX_RETRIES=1

for MODEL in "${MODELS[@]}"; do
    for RETRY in $(seq 0 "$MAX_RETRIES"); do

        RESPONSE_FILE="$(mktemp)"

        HTTP_STATUS=$(curl -sS \
            -o "$RESPONSE_FILE" \
            -w '%{http_code}' \
            -X POST \
            -H "Content-Type: application/json" \
            -H "x-goog-api-key: $GEMINI_API_KEY" \
            "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
            -d "$PAYLOAD")

        RESPONSE="$(cat "$RESPONSE_FILE")"
        rm -f "$RESPONSE_FILE"

        TEXT=$(printf '%s' "$RESPONSE" | python -c '
import json
import sys

try:
    d = json.load(sys.stdin)
    print(d["candidates"][0]["content"]["parts"][0]["text"])
except Exception:
    pass
')

        if [ -n "$TEXT" ]; then
            echo "$TEXT"
            exit 0
        fi

        # Daily project quota cannot be fixed by short retries.
        if printf '%s' "$RESPONSE" | grep -Eq 'GenerateRequestsPerDayPer.*FreeTier'; then
            QUOTA_VALUE=$(printf '%s' "$RESPONSE" | python -c '
import json,sys
try:
    d=json.load(sys.stdin)
    for x in d.get("error",{}).get("details",[]):
        for v in x.get("violations",[]):
            if str(v.get("quotaId", "")).startswith("GenerateRequestsPerDayPer") and str(v.get("quotaId", "")).endswith("FreeTier"):
                print(v.get("quotaValue","unknown"))
                raise SystemExit
except Exception:
    pass
')

            RETRY_DELAY=$(printf '%s' "$RESPONSE" | python -c '
import json,sys
try:
    d=json.load(sys.stdin)
    for x in d.get("error",{}).get("details",[]):
        if x.get("@type","").endswith("/RetryInfo"):
            print(x.get("retryDelay","unknown"))
            raise SystemExit
except Exception:
    pass
')

            echo "[GEMINI] DAILY QUOTA EXHAUSTED" >&2
            echo "[GEMINI] MODEL=$MODEL QUOTA=${QUOTA_VALUE:-unknown} RETRY_DELAY=${RETRY_DELAY:-unknown}" >&2
            echo "[GEMINI] STOP RETRY/FALLBACK: daily project quota is exhausted" >&2
            exit 1
        fi

        if [ "$HTTP_STATUS" = "429" ] || \
           [ "$HTTP_STATUS" = "408" ] || \
           [ "$HTTP_STATUS" = "500" ] || \
           [ "$HTTP_STATUS" = "502" ] || \
           [ "$HTTP_STATUS" = "503" ] || \
           [ "$HTTP_STATUS" = "504" ]; then

            if [ "$RETRY" -lt "$MAX_RETRIES" ]; then
                DELAY=$((2 ** RETRY))
                JITTER=$((RANDOM % 2))
                WAIT=$((DELAY + JITTER))

                echo "[GEMINI] MODEL=$MODEL HTTP=$HTTP_STATUS RETRY=$((RETRY+1))/$MAX_RETRIES WAIT=${WAIT}s" >&2
                sleep "$WAIT"
                continue
            fi

            echo "[GEMINI] MODEL=$MODEL HTTP=$HTTP_STATUS RETRIES_EXHAUSTED" >&2
            echo "[GEMINI] RESPONSE:" >&2
            printf '%s\n' "$RESPONSE" >&2
            break
        fi

        echo "[GEMINI] MODEL=$MODEL HTTP=$HTTP_STATUS REQUEST_FAILED" >&2
        echo "[GEMINI] RESPONSE:" >&2
        printf '%s\n' "$RESPONSE" >&2
        break
    done
done

echo "ERROR: Gemini returned no usable response"
exit 1
