#!/data/data/com.termux/files/usr/bin/bash
set -u

QUESTION="${1:-}"
TARGET="${2:-}"

MAX_ROUNDS=8
ROUND=0
ALL_RESULTS=""
EXEC_HISTORY=""

# Persistent investigation evidence: one state file per TARGET.
STATE_DIR="$HOME/ai-tools/evidence_state"
mkdir -p "$STATE_DIR"
STATE_KEY="$(printf "%s" "$TARGET" | tr "/;|: " "_____")"
STATE_FILE="$STATE_DIR/${STATE_KEY}.evidence"
if [ -s "$STATE_FILE" ]; then
    ALL_RESULTS="$(cat "$STATE_FILE")"
    echo "[PERSISTENT EVIDENCE] LOADED: $STATE_FILE"
else
    ALL_RESULTS=""
fi
REJECTION_FEEDBACK=""

if [ -z "$QUESTION" ]; then
    echo "ERROR: missing question"
    echo
    echo "Usage:"
    echo "  ai_agent_auto.sh \"QUESTION\" \"TARGET\""
    exit 1
fi

if [ -z "$TARGET" ]; then
    echo "ERROR: missing TARGET"
    echo
    echo "Usage:"
    echo "  ai_agent_auto.sh \"QUESTION\" \"TARGET\""
    exit 1
fi

extract_tool() {
    printf '%s\n' "$1" |
        sed -n 's/^TOOL:[[:space:]]*//p' |
        head -1 |
        xargs
}

extract_arg() {
    printf '%s\n' "$1" |
        sed -n 's/^ARG:[[:space:]]*//p' |
        head -1 |
        xargs
}

normalize_method_token() {
    local X="$1"
    case "$X" in
        *'|'*)
            local BASE="${X%%|*}"
            local SUFFIX="${X#*|}"
            BASE="${BASE//;./.}"
            X="$BASE|$SUFFIX"
            ;;
        *)
            X="${X//;./.}"
            ;;
    esac
    printf "%s" "$X"
}

# Explicit method/class targets written by the user in QUESTION.
# These are valid provenance just like TARGET and prior Evidence.
EXPLICIT_TARGETS="$(
    printf '%s\n' "$QUESTION" |
    grep -oE 'L[A-Za-z0-9_$]+/[A-Za-z0-9_$]+(\$[A-Za-z0-9_$]+)?\.[A-Za-z_$<>][A-Za-z0-9_$<>]*' |
    sort -u |
    tr '\n' ' '
)"

validate_arg_evidence() {
    local ARG="$1"
    local TARGET="$2"
    local EVIDENCE="$3"
    local EXPLICIT="${4:-}"
    local TOOL="${5:-}"

    local EVIDENCE_ARG="$ARG"

    case "$TOOL" in
        call_graph)
            EVIDENCE_ARG="${ARG%%|*}"
            ;;
        apk_search)
            APK_SUBCOMMAND="${ARG%% *}"
            APK_REST="${ARG#* }"

            case "$APK_SUBCOMMAND" in
                method_exists|interface_callers|caller|callee)
                    EVIDENCE_ARG="${APK_REST%% *}"
                    ;;
                call_graph|chain)
                    EVIDENCE_ARG="${APK_REST%% *}"
                    EVIDENCE_ARG="${EVIDENCE_ARG%%|*}"
                    ;;
            esac
            ;;
    esac

    NORMALIZED_EVIDENCE="$(printf "%s\n" "$EVIDENCE" | sed "s/;\././g")"
    NORMALIZED_EVIDENCE_ARG="$(printf "%s" "$EVIDENCE_ARG" | sed "s/;\././g")"

    if printf '%s\n' "$TARGET" | grep -Fqx "$EVIDENCE_ARG"; then
        return 0
    fi

    if printf '%s\n' "$EXPLICIT" | tr ' ' '\n' | grep -Fqx "$EVIDENCE_ARG"; then
        return 0
    fi

    if printf '%s\n' "$NORMALIZED_EVIDENCE" | grep -Fq -- "$NORMALIZED_EVIDENCE_ARG"; then
        return 0
    fi

    return 1
}

validate_tool_contract() {
    local TOOL="$1"
    local ARG="$2"

    case "$TOOL" in

        check_app)
            # Android package name
            printf '%s\n' "$ARG" |
                grep -Eq '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+'
            ;;

        get_app_state|get_ram|list_tools)
            [ -z "$ARG" ] || [ "$ARG" = "all" ]
            ;;

        get_logcat)
            printf '%s\n' "$ARG" |
                grep -Eq '^[0-9]+$'
            ;;

        method_exists|caller|callee|interface_callers)
            # Actual apk_search syntax: Lclass/name.method
            printf '%s\n' "$ARG" |
                grep -Eq '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'
            ;;

        list_methods)
            # Class only; method names must be obtained from DEX by the tool.
            printf '%s\n' "$ARG" |
                grep -Eq '^L[^;]+;?$'
            ;;

        interface_impl)
            # Actual interface_impl.sh accepts Linterface/name; or without final ;
            printf '%s\n' "$ARG" |
                grep -Eq '^L[^;]+;?$'
            ;;

        call_graph)
            # Actual apk_search syntax: Lclass/name.method [depth]
            TARGET_ARG="$ARG"
            DEPTH_ARG=""
            case "$ARG" in
                *'|'*)
                    TARGET_ARG="${ARG%%|*}"
                    DEPTH_ARG="${ARG#*|}"
                    ;;
            esac

            printf '%s\n' "$TARGET_ARG" |
                grep -Eq '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$' || return 1

            if [ -n "$DEPTH_ARG" ]; then
                printf '%s\n' "$DEPTH_ARG" |
                    grep -Eq '^[0-9]+$' || return 1
            fi
            ;;

        *)
            # Tools whose exact syntax is defined by their own tool.
            return 0
            ;;
    esac
}

echo "=== AUTONOMOUS EVIDENCE AGENT ==="
echo "[TARGET] $TARGET"
echo "[MAX ROUNDS] $MAX_ROUNDS"
echo "[EVIDENCE STATE] $STATE_FILE"

save_persistent_evidence() {
    if [ -n "$ALL_RESULTS" ]; then
        printf "%s\n" "$ALL_RESULTS" > "$STATE_FILE"
    fi
}

while [ "$ROUND" -lt "$MAX_ROUNDS" ]; do

    ROUND=$((ROUND + 1))

    echo
    echo "=== ROUND $ROUND ==="

    if [ -z "$ALL_RESULTS" ]; then
        PROMPT="เป้าหมาย:
$QUESTION

TARGET:
$TARGET

นี่คือการตรวจรอบแรก
เลือก Tool แรกที่สามารถใช้ TARGET โดยตรงได้
ห้ามใช้คำว่า target เป็น ARG"

    else
        PROMPT="เป้าหมาย:
$QUESTION

TARGET:
$TARGET

EXECUTED_TOOLS:
$EXEC_HISTORY

EVIDENCE:
$ALL_RESULTS

CONTROLLER_REJECTION:
$REJECTION_FEEDBACK

เลือก NEXT_CHECK เพียงหนึ่งรายการ
ห้ามเลือก TOOL+ARG ที่อยู่ใน EXECUTED_TOOLS
ห้ามสร้าง ARG ใหม่
ARG ต้องปรากฏใน TARGET หรือ Evidence เท่านั้น"
    fi

    # Controller investigation rules
    PROMPT="$PROMPT

CONTROLLER INVESTIGATION RULES:
If a previous Tool returns NOT_FOUND, do not treat that alone as proof that the investigation is finished.
You may reuse the exact TARGET as ARG with a different Tool when that TOOL+ARG is not in EXECUTED_TOOLS.
For example, caller|TARGET being executed does not prevent callee|TARGET or call_graph|TARGET.
Do not invent ARG values. Every ARG must appear exactly in TARGET or EVIDENCE.
Use TOOL: NONE only when no valid, unexecuted TOOL+ARG remains under these rules.
CALL DIRECTION RULES:
- callee A means A calls the methods returned by the callee search: A -> B.
- caller B returning CALLER: A means A calls B: A -> B.
- Never reverse CALLER: A into B -> A.
- NOT_FOUND_DIRECT_CALLER means no direct caller was found in the searched DEX; it does not prove no caller exists elsewhere.

PLANNER COMPLETENESS RULES:
- NOT_FOUND_DIRECT_CALLER is a local search result, not proof that the investigation is complete.
- Do not choose TOOL: NONE merely because caller/callee checks for TARGET are exhausted.
- Before TOOL: NONE, inspect EVIDENCE for confirmed method targets discovered from previous results, especially methods returned by callee or call_graph.
- If a discovered method is relevant to the requested call path and has not yet been checked with an applicable unexecuted Tool, consider that method for the next check.
- Prefer continuing the graph from a confirmed edge: if A -> B is confirmed and the goal is to trace the call path, B is a valid next investigation target.
- Do not invent a method. A method is eligible only when its exact signature appears in TARGET or EVIDENCE.
- Respect duplicate protection: do not select an already executed TOOL+ARG in the current run.
- TOOL: NONE is appropriate only when no relevant, evidence-backed, unexecuted investigation remains under the Tool Contract.

INTERFACE IMPLEMENTATION RULES:
- If Evidence contains METHOD_STATUS: METHOD_DECLARED_NO_BODY for a method on an interface, do not treat that declaration as the concrete implementation.
- When the interface type is explicitly present in TARGET or EVIDENCE and interface_impl has not been executed for that interface, consider interface_impl as the next investigation.
- For an interface method such as Lgz/e.a or Lgz/e.b, the eligible interface ARG is Lgz/e; only use it when that exact interface form appears in TARGET or EVIDENCE.
- Do not invent an implementation class or method. interface_impl must discover it.
- Do not send a concrete class such as Lgz/c; or Lgz/c to call_graph; call_graph requires class.method.
- After interface_impl discovers an implementation class, use the IMPLEMENTATION_METHOD entries returned by interface_impl as the only evidence-backed method candidates.
- Do not assume Lgz/c.a or Lgz/c.b merely because the interface has methods a or b; select them only if an IMPLEMENTATION_METHOD entry explicitly lists that method.
- A METHOD_DECLARED_NO_BODY result is an evidence gap about implementation, not proof that the call path ends.

"

PROMPT="${PROMPT}

EXECUTED TOOL HISTORY:
${EXEC_HISTORY}

DUPLICATE TOOL RULE:
- Never select the exact same TOOL+ARG already listed in EXECUTED TOOL HISTORY.
- If a discovered method is already executed, select another evidence-backed unexecuted method.
- Do not report an already executed method as an EVIDENCE_GAP.
- If a class is present in Evidence but its concrete method list is unknown, use list_methods on that class before inventing or assuming a method name.
- After list_methods returns METHOD entries, use only those exact METHOD entries as subsequent callee/caller targets.

"

    PLAN=$(printf '%s\n' "$ALL_RESULTS" |
        ~/ai-tools/ask_ai_triple.sh "$PROMPT")

    echo "[GEMINI RESPONSE]"
    echo "$PLAN"

    TOOL=$(extract_tool "$PLAN")
    ARG=$(extract_arg "$PLAN")
    ARG="$(normalize_method_token "$ARG")"

    if [ -z "$TOOL" ] || [ "$TOOL" = "NONE" ]; then
        echo "[STOP] Gemini returned no next tool"
        break
    fi

    # Tools ที่ไม่ต้องใช้ ARG สามารถรับ NONE จาก Gemini ได้
    case "$TOOL" in
        get_app_state|get_ram)
            if [ -z "$ARG" ] || [ "$ARG" = "NONE" ]; then
                ARG=""
            fi
            ;;
        list_tools)
            if [ "$ARG" = "NONE" ]; then
                ARG=""
            elif [ -z "$ARG" ] || [ "$ARG" = "all" ]; then
                :
            else
                echo "[CONTROLLER] REJECTED: list_tools accepts NONE or all"
                break
            fi
            ;;
        *)
            if [ -z "$ARG" ] || [ "$ARG" = "NONE" ]; then
                echo "[CONTROLLER] REJECTED: empty ARG"
                break
            fi
            ;;
    esac

    if [ "$ARG" = "target" ] || [ "$ARG" = "TARGET" ]; then
        echo "[CONTROLLER] REJECTED: placeholder ARG=$ARG"
        break
    fi

    # Evidence validation ใช้เฉพาะ Tool ที่มี ARG จริง
    case "$TOOL" in
        get_app_state|get_ram)
            echo "[CONTROLLER] ARG VALIDATED: TOOL REQUIRES NO ARG"
            ;;
        list_tools)
            echo "[CONTROLLER] ARG VALIDATED: TOOL CONTRACT"
            ;;
        *)
            if ! validate_arg_evidence "$ARG" "$TARGET" "$ALL_RESULTS" "$EXPLICIT_TARGETS" "$TOOL"; then
                echo "[CONTROLLER] REJECTED: ARG not found in TARGET/EVIDENCE"
                echo "[ARG] $ARG"
                REJECTION_FEEDBACK="REJECTED: ARG was not found exactly in TARGET or EVIDENCE. Do not reuse this ARG. Choose a corrected ARG only from exact text present in TARGET/EVIDENCE."
                continue
            fi
            echo "[CONTROLLER] ARG VALIDATED FROM EVIDENCE"
            ;;
    esac

    if ! validate_tool_contract "$TOOL" "$ARG"; then
        echo "[CONTROLLER] REJECTED: ARG violates TOOL CONTRACT"
        echo "[TOOL] $TOOL"
        echo "[ARG] $ARG"
        REJECTION_FEEDBACK="REJECTED: TOOL/ARG violates the tool contract. Do not reuse this TOOL+ARG. Choose another valid TOOL/ARG supported by TARGET/EVIDENCE and the contract."
        continue
    fi

    echo "[CONTROLLER] TOOL CONTRACT VALIDATED"

    case "|check_app|get_app_state|get_ram|get_logcat|apk_search|list_methods|method_exists|interface_callers|interface_impl|caller|callee|call_graph|graph_parse|read_file|list_tools|search_file|read_range|" in
        *"|$TOOL|"*)
            ;;
        *)
            echo "[CONTROLLER] REJECTED TOOL=$TOOL"
            break
            ;;
    esac

    KEY="$TOOL|$ARG"

    if printf '%s\n' "$EXEC_HISTORY" |
        grep -Fqx "$KEY"; then

        echo "[CONTROLLER] DUPLICATE -> STOP: $KEY"
        break
    fi

    echo "[CONTROLLER] AUTHORIZED"
    echo "[EXECUTE] TOOL=$TOOL ARG=$ARG"
    REJECTION_FEEDBACK=""

    RESULT=$(~/ai-tools/router.sh "$TOOL" "$ARG" 2>&1)
    RC=$?

    echo "[TOOL RESULT]"
    echo "$RESULT"
    echo "[EXIT CODE] $RC"

    EXEC_HISTORY="${EXEC_HISTORY}${EXEC_HISTORY:+$'\n'}$KEY"

    ALL_RESULTS="${ALL_RESULTS}${ALL_RESULTS:+$'\n\n'}=== ROUND $ROUND : $TOOL $ARG ===
$RESULT"

    save_persistent_evidence

done

echo
echo "=== FINAL EVIDENCE REVIEW ==="

printf '%s\n' "$ALL_RESULTS" |
    ~/ai-tools/ask_ai_triple.sh \
    "เป้าหมาย:
$QUESTION

TARGET:
$TARGET

สรุป Evidence ทั้งหมดเท่านั้น
แยก CONFIRMED, NOT_CONFIRMED และ EVIDENCE_GAP
ห้ามเสนอ Tool ใหม่
กติกาทิศทางการเรียก:
- callee A = A เรียก B (A -> B)
- caller B ที่คืนค่า CALLER: A = A เรียก B (A -> B)
- ห้ามกลับทิศ CALLER: A เป็น B -> A
- NOT_FOUND_DIRECT_CALLER = ไม่พบ caller โดยตรงใน DEX ที่ค้น ไม่ใช่หลักฐานว่าไม่มี caller อยู่เลย
- การไม่พบ direct caller ของ TARGET ไม่ได้แปลว่าเส้นทางการเรียกถูกสำรวจครบทุกโหนด
- ถ้า Evidence ยืนยัน edge A -> B และยังมี Tool ที่เกี่ยวข้องกับ B ซึ่งยังไม่ได้ใช้ ห้ามสรุปว่า call path ครบถ้วนเพียงเพราะ Planner หยุด
- ถ้าเจอ METHOD_STATUS: METHOD_DECLARED_NO_BODY บน interface ให้ระบุว่า implementation ยังไม่ถูกค้น และอย่าถือว่าการประกาศนั้นคือ implementation จริง
- ถ้า interface_impl ยังไม่ถูกใช้และชื่อ interface ปรากฏใน Evidence ให้ถือเป็น EVIDENCE_GAP ที่ตรวจต่อได้
"

echo "=============================="
