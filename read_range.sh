#!/data/data/com.termux/files/usr/bin/bash
INPUT="$1"
FILE="${INPUT%%|*}"
REST="${INPUT#*|}"
START="${REST%%|*}"
END="${REST#*|}"

FILE="${FILE/#\~/$HOME}"

case "$FILE" in
  "$HOME"/ai-tools/*) ;;
  *) echo "ERROR: file not allowed"; exit 1 ;;
esac

[ -f "$FILE" ] || { echo "ERROR: file not found"; exit 1; }

sed -n "${START},${END}p" "$FILE"
