#!/data/data/com.termux/files/usr/bin/bash

LINES="${1:-50}"

case "$LINES" in
    ''|*[!0-9]*)
        echo "ERROR: lines ต้องเป็นตัวเลข"
        exit 1
        ;;
esac

[ "$LINES" -gt 200 ] && LINES=200

su -c "logcat -d -t $LINES"
