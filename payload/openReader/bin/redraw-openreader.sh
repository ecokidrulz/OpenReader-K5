#!/bin/sh

FBINK="/mnt/us/koreader/fbink"
[ -f "$FBINK" ] || FBINK="/usr/bin/fbink"

# Do not paint over KOReader, KTerm, or an intentional exit.
STATE="$(cat /var/tmp/openreader-state 2>/dev/null)"

[ "$STATE" = "RUNNING" ] || exit 0
[ -e /var/tmp/koreader-pause-keeper ] && exit 0

"$FBINK" -c 2>/dev/null

"$FBINK" -x 2 -y 3 -h "OPENREADER"
CURRENT_TIME=$(date "+%H:%M")
"$FBINK" -x 31 -y 3 "$CURRENT_TIME"
"$FBINK" -x 2 -y 5 "Kindle Touch / K5"
"$FBINK" -x 2 -y 7 "──────────────────────────────────"

"$FBINK" -x 2 -y 14 "KOReader"
"$FBINK" -x 2 -y 22 "System Info"
"$FBINK" -x 2 -y 30 "Boot KindleOS Once"
"$FBINK" -x 2 -y 38 "Reboot"

"$FBINK" -x 2 -y 43 "──────────────────────────────────"
"$FBINK" -x 1 -y 45 "Refresh"
"$FBINK" -x 12 -y 45 "Net"
"$FBINK" -x 19 -y 45 "Storage"
"$FBINK" -x 30 -y 45 "Off"

"$FBINK" -f 2>/dev/null || true

exit 0
