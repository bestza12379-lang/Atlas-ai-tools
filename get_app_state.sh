#!/data/data/com.termux/files/usr/bin/bash

PKG="com.shopee.foody.driver.th"

PID=$(su -c "pidof $PKG" 2>/dev/null)

if [ -z "$PID" ]; then
    echo "STATUS: NOT_RUNNING"
    exit 0
fi

echo "STATUS: RUNNING"
echo "PACKAGE: $PKG"
echo "PID: $PID"

echo "=== CONNECTIONS ==="
su -c "ss -tnp | grep 'pid=$PID,'"
