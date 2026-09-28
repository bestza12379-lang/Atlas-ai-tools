#!/data/data/com.termux/files/usr/bin/bash

DEX="$HOME/ai-tools/classes4.dex"

if [ ! -f "$DEX" ]; then
    echo "ERROR: classes4.dex not found"
    exit 1
fi

MODE="$1"

if [ "$MODE" = "method_exists" ]; then
    TARGET="$2"
    if ! printf '%s' "$TARGET" | grep -qE '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name.method เช่น Lgz/d.d"
        exit 2
    fi
    if ! printf "%s" "$TARGET" | grep -qE '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name.method เช่น Lgz/d.d"
        exit 2
    fi

    CLASS="${TARGET%%.*}"
    CLASS="${CLASS%;}"
    METHOD="${TARGET#*.}"
    echo "=== METHOD EXISTS: $CLASS.$METHOD ==="
    if dexdump -d "$DEX" 2>/dev/null | awk -v c="$CLASS" -v m="$METHOD" '
        /Class descriptor[[:space:]]*:/ {
            cls=$0
            sub(/^[^:]*:[[:space:]]*/, "", cls)
            gsub(/\047/, "", cls)
        }
        /^[[:space:]]*name[[:space:]]*:/ {
            n=$0
            sub(/^[^:]*:[[:space:]]*/, "", n)
            gsub(/\047/, "", n)
            if ((cls == c || cls == c ";") && n == m) found=1
        }
        END { exit(found ? 0 : 1) }
    '; then
        echo "STATUS: FOUND"
    else
        echo "STATUS: NOT_FOUND"
    fi
    exit 0
fi

if [ "$MODE" = "list_methods" ]; then
    TARGET="$2"

    if ! printf '%s' "$TARGET" | grep -qE '^L[^;]+;?$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name or Lclass/name;"
        exit 2
    fi

    CLASS="$TARGET"
    CLASS="${CLASS%;}"

    echo "=== LIST METHODS: $CLASS ==="

    RESULT=$(dexdump -d "$DEX" 2>/dev/null |
    awk -v target="$CLASS" '
        /Class descriptor[[:space:]]*:/ {
            cls=$0
            sub(/^[^:]*:[[:space:]]*/, "", cls)
            gsub(/\047/, "", cls)
            sub(/;$/, "", cls)
            active=(cls == target)
        }

        active && /^[[:space:]]*name[[:space:]]*:/ {
            name=$0
            sub(/^[^:]*:[[:space:]]*/, "", name)
            gsub(/\047/, "", name)
            if (name != "") {
                if (name != "" && !seen[name]) {
                    seen[name]=1
                print "METHOD: " target "." name
                    found=1
                }
            }
        }

        END {
            if (!found) exit 7
        }
    ')

    if [ -n "$RESULT" ]; then
        echo "STATUS: FOUND"
        echo "$RESULT"
    else
        echo "STATUS: NOT_FOUND"
        echo "No methods found for this class in this DEX."
    fi
    exit 0
fi

if [ "$MODE" = "interface_callers" ]; then
    TARGET="$2"
    if [ -z "$TARGET" ]; then
        echo "Usage: apk_search.sh interface_callers <interface.method>"
        exit 1
    fi
    if ! printf '%s' "$TARGET" | grep -qE '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name.method เช่น Lw00/f.b"
        exit 2
    fi
    CLASS="${TARGET%%.*}"
    CLASS="${CLASS%;}"
    METHOD="${TARGET#*.}"
    echo "=== INTERFACE CALLERS: $CLASS.$METHOD ==="
    RESULT=$(dexdump -d "$DEX" 2>/dev/null | awk -v target_class="$CLASS" -v target_method="$METHOD" '
        /Class descriptor[[:space:]]*:/ {
            cls=$0
            sub(/^[^:]*:[[:space:]]*/, "", cls)
            gsub(/\047/, "", cls)
        }
        /^[[:space:]]*name[[:space:]]*:/ {
            name=$0
            sub(/^[^:]*:[[:space:]]*/, "", name)
            gsub(/\047/, "", name)
            if (name != "<clinit>" && name != "<init>") current_method=cls "." name
        }
        /invoke-interface/ {
            pattern=target_class ";." target_method ":"
            if (index($0, pattern)) {
                print "CALLER: " current_method
                print $0
                print "--------------------------------"
            }
        }
    ')
    if [ -n "$RESULT" ]; then
        echo "STATUS: FOUND"
        echo "$RESULT"
        if printf "%s\n" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
            CALLEES=$(printf "%s\n" "$RESULT" | sed -n "s/^CALLER: //p")
        fi
    else
        echo "STATUS: NOT_FOUND"
        echo "No interface call found in this DEX."
    fi
    exit 0
fi

if [ "$MODE" = "caller" ] || [ "$MODE" = "callers" ]; then
    TARGET="$2"

    if ! printf '%s' "$TARGET" | grep -qE '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name.method เช่น Lgz/d.d"
        exit 2
    fi


    if [ -z "$TARGET" ]; then
        echo "Usage: apk_search.sh caller <class.method>"
        exit 1
    fi

    CLASS="${TARGET%%.*}"
    CLASS="${CLASS%;}"
    METHOD="${TARGET#*.}"

    echo "=== CALLER SEARCH: $CLASS.$METHOD ==="

    RESULT=$(dexdump -d "$DEX" 2>/dev/null |
    awk -v target_class="$CLASS" -v target_method="$METHOD" '
        /Class descriptor[[:space:]]*:/ {
            cls=$0
            sub(/^[^:]*:[[:space:]]*/, "", cls)
            gsub(/\047/, "", cls)
        }

        /^[[:space:]]*name[[:space:]]*:/ {
            name=$0
            sub(/^[^:]*:[[:space:]]*/, "", name)
            gsub(/\047/, "", name)

            if (name != "<clinit>" && name != "<init>") {
                sub(/;$/, "", cls)
                current_method=cls "." name
            }
        }

        /invoke-(virtual|interface|direct|static)/ {
            pattern=target_class ";." target_method ":"

            if (index($0, pattern) && current_method != target_class "." target_method) {
                print "CALLER: " current_method
                print $0
                print "--------------------------------"
            }
        }
    ')

    if [ -n "$RESULT" ]; then
        echo "STATUS: FOUND"
        echo "$RESULT"
        if printf "%s\n" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
            CALLEES=$(printf "%s\n" "$RESULT" | sed -n "s/^CALLER: //p")
        fi
    else
        echo "STATUS: NOT_FOUND_DIRECT_CALLER"
        echo "No direct invoke found in this DEX."
    fi

    exit 0
fi

if [ "$MODE" = "callee" ]; then
    TARGET="$2"

    if [ -z "$TARGET" ]; then
        echo "Usage: apk_search.sh callee <class.method>"
        exit 1
    fi

    if ! printf '%s' "$TARGET" | grep -qE '^L[^.]+/.+\.[A-Za-z_$<>][A-Za-z0-9_$<>]*$'; then
        echo "STATUS: INVALID_ARGUMENT"
        echo "Expected: Lclass/name.method เช่น Lgz/d.b"
        exit 2
    fi

    echo "=== CALLEE SEARCH: $TARGET ==="

    RESULT=$(dexdump -d "$DEX" 2>/dev/null |
    awk -v target="$TARGET" '
        /\|\[[0-9a-f]+\] / {
            line=$0
            sub(/^.*\|\[/, "", line)
            sub(/^[0-9a-f]+\] /, "", line)
            sub(/:.*/, "", line)

            n=split(line, parts, ".")
            if (n >= 2) {
                meth=parts[n]
                cls=""
                for (i=1; i<n; i++) {
                    if (i > 1) cls=cls "/"
                    cls=cls parts[i]
                }
                normalized="L" cls "." meth
                active=(normalized == target)
            } else {
                active=0
            }
        }

        active && /invoke-(virtual|interface|direct|static)/ {
            print $0
        }
    ')

    if [ -n "$RESULT" ]; then
        echo "STATUS: FOUND"
        echo "$RESULT"
        if printf "%s\n" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
            CALLEES=$(printf "%s\n" "$RESULT" | sed -n "s/^CALLER: //p")
        fi
    else
        echo "STATUS: NOT_FOUND"
        echo "No direct invoke found in this method."
    fi

    exit 0
fi

if [ "$MODE" = "chain" ]; then
    TARGET="$2"
    DEPTH="${3:-3}"

    if [ -z "$TARGET" ]; then
        echo "Usage: apk_search.sh chain <class.method> [depth]"
        exit 1
    fi

    case "$DEPTH" in
        ''|*[!0-9]*) DEPTH=3 ;;
    esac

    [ "$DEPTH" -gt 5 ] && DEPTH=5

    echo "=== CALL CHAIN: $TARGET (depth=$DEPTH) ==="

    CURRENT="$TARGET"

    for ((LEVEL=1; LEVEL<=DEPTH; LEVEL++)); do
        echo "=== LEVEL $LEVEL: $CURRENT ==="

        RESULT=$(~/ai-tools/apk_search.sh caller "$CURRENT")

        echo "$RESULT"
        if printf "%s\n" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
            CALLEES=$(printf "%s\n" "$RESULT" | sed -n "s/^CALLER: //p")
        fi

        NEXT=$(echo "$RESULT" |
        if printf "%s\n" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
            CALLEES=$(printf "%s\n" "$RESULT" | sed -n "s/^CALLER: //p")
        fi
            sed -n 's/^CALLER: //p' |
            head -1 |
            sed 's/;//g')

        if [ -z "$NEXT" ]; then
            echo "CHAIN END"
            break
        fi

        CURRENT="$NEXT"
    done

    exit 0
fi

if [ "$MODE" = "call_graph" ]; then
    TARGET="$2"
    DEPTH="${3:-2}"
    [ "$DEPTH" -gt 3 ] && DEPTH=3
    QUEUE="$TARGET"
    echo "=== CALL GRAPH: $TARGET (depth=$DEPTH) ==="
    VISITED=""
    for ((LEVEL=1; LEVEL<=DEPTH; LEVEL++)); do
        [ -z "$QUEUE" ] && break
        NEXT_QUEUE=""
        for CURRENT in $QUEUE; do
            echo "=== LEVEL $LEVEL: $CURRENT ==="
            RESULT=$(~/ai-tools/router.sh debug_tool callee "$CURRENT")
            echo "$RESULT"
            CALLEES=$(printf "%s
" "$RESULT" | grep "invoke-" | grep -o "L[^ ;]*;.[A-Za-z_$<>][A-Za-z0-9_$<>]*:" | sed "s/;//; s/:$//" | grep "^Lgz/" | sort -u)
            if printf "%s
" "$RESULT" | grep -q "METHOD_STATUS: METHOD_DECLARED_NO_BODY"; then
                CALLEES=$(printf "%s
" "$RESULT" | sed -n "s/^CALLER: //p" | sed "s/;././" | grep "^Lgz/")
            fi
        case " $VISITED " in *" $CURRENT "*) continue;; esac
        VISITED="$VISITED $CURRENT"
              echo "=== CALLEES ==="
              for NEXT in $CALLEES; do echo "$CURRENT -> $NEXT"; done
              if [ "$LEVEL" -lt "$DEPTH" ]; then
                  for NEXT in $CALLEES; do
                      case " $VISITED " in *" $NEXT "*) continue;; esac
                      NEXT_QUEUE="$NEXT_QUEUE $NEXT"
                  done
              fi
        done
        QUEUE="$NEXT_QUEUE"
    done
      echo "=== GRAPH SUMMARY ==="
      echo "TARGET: $TARGET"
      echo "DEPTH: $DEPTH"
      echo "DEPTH_REACHED: $DEPTH"
    echo "=== GRAPH END ==="
    exit 0
fi
