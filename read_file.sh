#!/data/data/com.termux/files/usr/bin/bash
FILE="$1"
FILE="${FILE/#\~/$HOME}"
case "$FILE" in
  "$HOME"/ai-tools/*) ;;
  *) echo "ERROR: file not allowed"; exit 1 ;;
esac
[ -f "$FILE" ] || { echo "ERROR: file not found"; exit 1; }
sed -n '1,200p' "$FILE"
