#!/data/data/com.termux/files/usr/bin/bash

INPUT="$1"
FILE="${INPUT%%|*}"
PATTERN="${INPUT#*|}"

FILE="${FILE/#\~/$HOME}"

case "$FILE" in
  "$HOME"/ai-tools/*) ;;
  *) echo "ERROR: file not allowed"; exit 1 ;;
esac

[ -f "$FILE" ] || { echo "ERROR: file not found"; exit 1; }
[ -n "$PATTERN" ] || { echo "ERROR: pattern required"; exit 1; }

grep -n -i -- "$PATTERN" "$FILE"
