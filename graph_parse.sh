#!/data/data/com.termux/files/usr/bin/bash
INPUT="$1"
[ -n "$INPUT" ] || { echo "STATUS: INVALID_ARGUMENT"; exit 1; }
EDGES=$(printf "%s\n" "$INPUT" | grep -E "^Lgz/[^ ]+ -> Lgz/" | sort -u)
echo "=== GRAPH PARSED ==="
printf "%s\n" "$INPUT" | grep -E "^=== LEVEL [0-9]+: Lgz/" | sed "s/^=== LEVEL [0-9]*: /NODE: /" | sort -u
echo
printf "%s\n" "$EDGES" | while IFS= read -r EDGE; do [ -n "$EDGE" ] && echo "EDGE: $EDGE"; done
echo
NODE_COUNT=$(printf "%s\n" "$INPUT" | grep -E "^=== LEVEL [0-9]+: Lgz/" | sed "s/^=== LEVEL [0-9]*: //" | sort -u | wc -l)
EDGE_COUNT=$(printf "%s\n" "$EDGES" | grep -c "^Lgz/" || true)
DEPTH=$(printf "%s\n" "$INPUT" | sed -n "s/^DEPTH: //p" | tail -n 1)
echo "NODES: $NODE_COUNT"
echo "EDGES: $EDGE_COUNT"
echo "DEPTH: ${DEPTH:-0}"
