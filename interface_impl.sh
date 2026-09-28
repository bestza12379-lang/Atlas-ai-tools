#!/data/data/com.termux/files/usr/bin/bash

DEX="$HOME/ai-tools/classes4.dex"
TARGET="$1"

if [ -z "$TARGET" ]; then
    echo "STATUS: INVALID_ARGUMENT"
    echo "Usage: interface_impl <interface>"
    exit 1
fi

if ! printf '%s' "$TARGET" | grep -qE '^L[^;]+;?$'; then
    echo "STATUS: INVALID_ARGUMENT"
    echo "Expected: Lgz/e หรือ Lgz/e;"
    exit 2
fi

TARGET="${TARGET%;}"

echo "=== INTERFACE IMPLEMENTATIONS: $TARGET ==="

RESULT=$(dexdump -d "$DEX" 2>/dev/null |
awk -v target="$TARGET" '
/Class descriptor[[:space:]]*:/ {
    cls=$0
    sub(/^[^:]*:[[:space:]]*/, "", cls)
    gsub(/\047/, "", cls)
    in_interfaces=0
}

/^[[:space:]]*Interfaces[[:space:]]+-/ {
    in_interfaces=1
    next
}

/^[[:space:]]*(Static fields|Instance fields|Direct methods|Virtual methods|source_file_idx)[[:space:]]*/ {
    in_interfaces=0
}

in_interfaces && /#[0-9]+[[:space:]]*:[[:space:]]*\047?L[^;]+;\047?/ {
    iface=$0
    sub(/^.*:[[:space:]]*/, "", iface)
    gsub(/\047/, "", iface)

    if (iface == target ";") {
        print "IMPLEMENTATION: " cls
    }
}
')

if [ -n "$RESULT" ]; then
    echo "STATUS: FOUND"
    printf '%s\n' "$RESULT" | sort -u

    # Report methods actually declared by each discovered implementation class.
    # This does not infer which method implements which interface member.
    printf '%s\n' "$RESULT" |
    sed 's/^IMPLEMENTATION: //' |
    sort -u |
    while IFS= read -r IMPL; do
        [ -n "$IMPL" ] || continue
        dexdump -d "$DEX" 2>/dev/null |
        awk -v target="$IMPL" '
            /Class descriptor[[:space:]]*:/ {
                cls=$0
                sub(/^[^:]*:[[:space:]]*/, "", cls)
                gsub(/\047/, "", cls)
                in_target=(cls == target)
                in_methods=0
                next
            }
            in_target && /^[[:space:]]*(Direct methods|Virtual methods)[[:space:]]*-/ {
                in_methods=1
                next
            }
            in_target && /^[[:space:]]*(Static fields|Instance fields|source_file_idx|Annotations)[[:space:]]*/ {
                in_methods=0
            }
            in_target && in_methods && /^[[:space:]]*name[[:space:]]*:/ {
                name=$0
                sub(/^[^:]*:[[:space:]]*/, "", name)
                gsub(/\047/, "", name)
                if (name != "") {
                    impl_cls=cls
                    sub(/;$/, "", impl_cls)
                    print "IMPLEMENTATION_METHOD: " impl_cls "." name
                }
            }
        '
    done | sort -u
else
    echo "STATUS: NOT_FOUND"
    echo "No class directly implementing $TARGET found in this DEX."
fi
