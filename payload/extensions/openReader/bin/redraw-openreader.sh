#!/bin/sh

FBINK="/mnt/us/koreader/fbink"
[ -f "$FBINK" ] || FBINK="/usr/bin/fbink"

STATE="$(cat /var/tmp/openreader-state 2>/dev/null)"
SCREEN="$(cat /var/tmp/openreader-screen 2>/dev/null)"

[ "$STATE" = "RUNNING" ] || exit 0
[ "$SCREEN" = "CLOCK" ] && exit 0
[ -e /var/tmp/koreader-pause-keeper ] && exit 0

"$FBINK" -c 2>/dev/null

"$FBINK" -x 2 -y 1 -F TALL -S 2 -h "OPENREADER-K5"

"$FBINK" -x 2 -y 6 "──────────────────────────────────"

"$FBINK" -x 2 -y 6  -F TALL -S 2 "KOReader"
"$FBINK" -x 2 -y 9  -F TALL -S 2 "Display Clock"
"$FBINK" -x 2 -y 12 -F TALL -S 2 "System Info"
"$FBINK" -x 2 -y 15 -F TALL -S 2 "Boot KindleOS Once"
"$FBINK" -x 2 -y 18 -F TALL -S 2 "Reboot"

"$FBINK" -x 2 -y 43 "──────────────────────────────────"

"$FBINK" -x 2  -y 22 -F TERMINUSB -S 2 "Refresh"
"$FBINK" -x 11 -y 22 -F TERMINUSB -S 2 "Net"
"$FBINK" -x 18 -y 22 -F TERMINUSB -S 2 "Storage"
"$FBINK" -x 29 -y 22 -F TERMINUSB -S 2 "Off"

"$FBINK" -f 2>/dev/null || true

touch /var/tmp/openreader-clock-refresh

exit 0
