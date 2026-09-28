#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TOOL="$1"
ARG="${*:2}"

case "$TOOL" in
    check_app)
        ./check_app.sh "$ARG"
        ;;
    get_ram)
        ./get_ram.sh
        ;;
    get_logcat)
        ./get_logcat.sh "$ARG"
        ;;
    apk_search)
        ./apk_search.sh $ARG
        ;;
    interface_callers)
        ./apk_search.sh interface_callers $ARG
        ;;
    list_methods)
        ./apk_search.sh list_methods "$ARG"
        ;;
    interface_impl)
        ./interface_impl.sh "$ARG"
        ;;
    method_exists)
        ./apk_search.sh method_exists $ARG
        ;;
    callee)
        ./apk_search.sh callee $ARG
        ;;
    caller)
        ./apk_search.sh caller $ARG
        ;;
    call_graph)
        TARGET="${ARG%%|*}"
        DEPTH=""
        case "$ARG" in
            *'|'*) DEPTH="${ARG#*|}" ;;
        esac

        if [ -n "$DEPTH" ]; then
            ./apk_search.sh call_graph "$TARGET" "$DEPTH"
        else
            ./apk_search.sh call_graph "$TARGET"
        fi
        ;;
      graph_parse)
          ./graph_parse.sh "$ARG"
          ;;
    read_range)
        ./read_range.sh "$ARG"
        ;;
    list_tools)
        ./list_tools.sh
        ;;
    search_file)
        ./search_file.sh "$ARG"
        ;;
    read_file)
        ./read_file.sh "$ARG"
        ;;
    get_app_state)
        ./get_app_state.sh
        ;;
    debug_tool)
        TOOL="$2"
        TARGET="$3"
        case "$TOOL" in
            callee)
                RESULT=$(./apk_search.sh callee "$TARGET")
                echo "$RESULT"
                if printf "%s\n" "$RESULT" | grep -q "STATUS: NOT_FOUND"; then
                echo "METHOD_STATUS: METHOD_DECLARED_NO_BODY"
                echo "NEXT: USE_CALLER"
                    echo "=== FALLBACK: caller ==="
                    ./apk_search.sh caller "$TARGET"
                fi
                ;;
            *)
                echo "STATUS: UNSUPPORTED_DEBUG_TOOL"
                ;;
        esac
        ;;
    *)
        echo "ERROR: Tool not allowed"
        echo "Allowed tools: check_app, get_app_state, get_ram, get_logcat, apk_search, method_exists, interface_callers, interface_impl, caller, callee, call_graph, graph_parse, read_file, list_tools, search_file, read_range"
        exit 1
        ;;
esac

