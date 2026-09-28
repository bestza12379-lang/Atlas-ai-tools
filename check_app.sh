#!/data/data/com.termux/files/usr/bin/bash

PKG="$1"

if [ -z "$PKG" ]; then
    echo "Usage: check_app.sh <package>"
    exit 1
fi

PID=$(su -c "pidof $PKG" 2>/dev/null)

if [ -n "$PID" ]; then
    echo "RUNNING"
    echo "PID: $PID"
else
    echo "NOT_RUNNING"
fi


