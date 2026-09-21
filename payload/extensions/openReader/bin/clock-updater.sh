#!/bin/sh

FBINK="/mnt/us/koreader/fbink"
[ -x "$FBINK" ] || FBINK="/usr/bin/fbink"

PIDFILE="/var/tmp/openreader-clock-updater.pid"
STATEFILE="/var/tmp/openreader-state"
SCREENFILE="/var/tmp/openreader-screen"
FORCE_FILE="/var/tmp/openreader-clock-refresh"

# Single-instance guard.
if [ -f "$PIDFILE" ]; then
    OLD_PID="$(cat "$PIDFILE" 2>/dev/null)"

    if [ -n "$OLD_PID" ] &&
       kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi

    rm -f "$PIDFILE"
fi

echo $$ > "$PIDFILE"

cleanup() {
    rm -f "$PIDFILE"
}

trap cleanup INT TERM EXIT

LAST_TIME=""
LAST_BATTERY=""

while true; do
    STATE="$(cat "$STATEFILE" 2>/dev/null)"
    SCREEN="$(cat "$SCREENFILE" 2>/dev/null)"
    POWER_STATE="$(lipc-get-prop com.lab126.powerd state 2>/dev/null)"

    if [ "$STATE" = "RUNNING" ] &&
       [ "$SCREEN" = "MAIN" ] &&
       [ "$POWER_STATE" = "active" ] &&
       [ ! -e /var/tmp/koreader-pause-keeper ]; then

        NOW="$(date '+%H:%M')"
        BATTERY="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null)"

        case "$BATTERY" in
            ''|*[!0-9]*)
                BATTERY=""
                ;;
        esac

        FORCE=0
        if [ -e "$FORCE_FILE" ]; then
            FORCE=1
        fi

        # Clock: repaint only on minute change or forced refresh.
        if [ "$NOW" != "$LAST_TIME" ] ||
           [ "$FORCE" -eq 1 ]; then

            "$FBINK" \
                -x 31 -y 1 \
                -F TALL -S 2 \
                "$NOW" \
                2>/dev/null || true

            LAST_TIME="$NOW"
        fi

        # Battery: repaint only when percentage changes or on forced refresh.
        if [ -n "$BATTERY" ]; then
            if [ "$BATTERY" != "$LAST_BATTERY" ] ||
               [ "$FORCE" -eq 1 ]; then

                "$FBINK" \
                    -x 33 -y 2 \
                    -F TALL -S 2 \
                    "${BATTERY}%" \
                    2>/dev/null || true

                LAST_BATTERY="$BATTERY"
            fi
        fi

        if [ "$FORCE" -eq 1 ]; then
            rm -f "$FORCE_FILE"
        fi

    else
        #
        # OpenReader does not own the framebuffer while sleeping,
        # in KOReader, or on another OpenReader screen.
        #
        # Forget dynamic values so both are repainted immediately
        # when MAIN becomes active again.
        #
        LAST_TIME=""
        LAST_BATTERY=""
    fi

    sleep 10
done
