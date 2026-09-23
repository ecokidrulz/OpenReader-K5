#!/bin/sh

REDRAW="/mnt/us/extensions/openReader/bin/redraw-openreader.sh"
EPDC_RESUME="/mnt/us/extensions/openReader/bin/epdc-resume.sh"
PIDFILE="/var/tmp/openreader-wake-watcher.pid"
LOG="/mnt/us/.openreader/wake-watcher.log"

# Prevent duplicate watchers.
if [ -f "$PIDFILE" ]; then
    OLD_PID="$(cat "$PIDFILE" 2>/dev/null)"

    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi

    rm -f "$PIDFILE"
fi

echo $$ > "$PIDFILE"

cleanup() {
    rm -f "$PIDFILE"
}

trap cleanup EXIT INT TERM

SAW_NONACTIVE=0
LAST_STATE=""

while true; do
    POWER_STATE="$(
        lipc-get-prop com.lab126.powerd state 2>/dev/null |
        tr '[:upper:]' '[:lower:]'
    )"

    # Ignore transient failures to read powerd.
    if [ -z "$POWER_STATE" ]; then
        sleep 2
        continue
    fi

    # Log state transitions only, not every poll.
    if [ "$POWER_STATE" != "$LAST_STATE" ]; then
        echo "[$(date)] powerd: '$LAST_STATE' -> '$POWER_STATE'" >> "$LOG"
        LAST_STATE="$POWER_STATE"
    fi

    if [ "$POWER_STATE" != "active" ]; then
        SAW_NONACTIVE=1

    elif [ "$SAW_NONACTIVE" -eq 1 ]; then
        #
        # powerd has just returned from Screen Saver / suspend to Active.
        #
        SAW_NONACTIVE=0

        OR_STATE="$(cat /var/tmp/openreader-state 2>/dev/null)"

        if [ "$OR_STATE" = "RUNNING" ] &&
           [ ! -e /var/tmp/koreader-pause-keeper ]; then

            echo "[$(date)] wake detected; repainting OpenReader" >> "$LOG"

            # Give the framebuffer/power stack a moment to settle.
            sleep 1

            # K5 may return from suspend with the EPDC framebuffer
            # becoming paused shortly after powerd reports Active.
            # Guard the first 10 seconds without delaying the repaint.
            if [ -x "$EPDC_RESUME" ]; then
                "$EPDC_RESUME" 10 >> "$LOG" 2>&1 &
            fi

            "$REDRAW"
        else
            echo "[$(date)] wake detected; repaint skipped (state='$OR_STATE')" >> "$LOG"
        fi
    fi

    sleep 2
done
