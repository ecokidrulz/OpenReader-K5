#!/bin/sh

FBINK="/mnt/us/koreader/fbink"

PIDFILE="/var/tmp/openreader-display-clock.pid"
SCREEN_STATE="/var/tmp/openreader-screen"
OPENREADER_STATE="/var/tmp/openreader-state"

ROTATE="/sys/class/graphics/fb0/rotate"
INPUT="/dev/input/event3"

ORIGINAL_ROTATE="1"
TOUCH_PID=""


draw_clock() {
    "$FBINK" -c

    "$FBINK" \
        -m -M -y -1 \
        -S 15 -F TERMINUSB \
        "$(date '+%H:%M')"

    "$FBINK" \
        -m -M -y 2 \
        -S 4 -F TALL \
        "$(date '+%A, %B %d')"

    "$FBINK" -f 2>/dev/null || true
}


cleanup() {
    # Prevent EXIT from recursively calling cleanup.
    trap - INT TERM EXIT

    #
    # Stop the one-shot touchscreen reader if it is still blocked.
    # It is deliberately disposable; do not wait on it.
    #
    if [ -n "$TOUCH_PID" ]; then
        if kill -0 "$TOUCH_PID" 2>/dev/null; then
            kill -9 "$TOUCH_PID" 2>/dev/null || true
        fi
        TOUCH_PID=""
    fi

    if [ -w "$ROTATE" ]; then
        echo "$ORIGINAL_ROTATE" > "$ROTATE"
    fi

    lipc-set-prop com.lab126.powerd preventScreenSaver 0 \
        2>/dev/null || true

    echo "MAIN" > "$SCREEN_STATE"
    echo "RUNNING" > "$OPENREADER_STATE"

    rm -f "$PIDFILE"
}


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
trap cleanup INT TERM EXIT


# Preserve OpenReader's current orientation.
if [ -r "$ROTATE" ]; then
    ORIGINAL_ROTATE="$(cat "$ROTATE" 2>/dev/null)"
fi

case "$ORIGINAL_ROTATE" in
    0|1|2|3)
        ;;
    *)
        ORIGINAL_ROTATE="1"
        ;;
esac


echo "CLOCK" > "$SCREEN_STATE"

lipc-set-prop com.lab126.powerd preventScreenSaver 1 \
    2>/dev/null || true

# Landscape framebuffer.
echo 0 > "$ROTATE"

sleep 1

draw_clock

LAST_KEY="$(date '+%Y%m%d%H%M')"


#
# One-shot touch watcher.
#
# This is the ONLY background process in Display Clock.
# It exits as soon as one 16-byte Linux input_event is received.
#
dd if="$INPUT" of=/dev/null bs=16 count=1 2>/dev/null &
TOUCH_PID=$!


#
# Main process owns the clock update loop.
#
while true; do

    #
    # Detect whether the touch-reader child has completed.
    #
    # Normally the child disappears after a touch. Handle a zombie
    # explicitly as well for old BusyBox/kernel process semantics.
    #
    if [ ! -d "/proc/$TOUCH_PID" ]; then
        break
    fi

    TOUCH_STATE="$(
        grep '^State:' "/proc/$TOUCH_PID/status" 2>/dev/null |
        awk '{print $2}'
    )"

    if [ "$TOUCH_STATE" = "Z" ]; then
        break
    fi


    #
    # Update the display only when the civil minute/date changes.
    #
    KEY="$(date '+%Y%m%d%H%M')"

    if [ "$KEY" != "$LAST_KEY" ]; then
        draw_clock
        LAST_KEY="$KEY"
    fi

    sleep 1
done


# Reap the completed touchscreen reader if possible.
wait "$TOUCH_PID" 2>/dev/null || true
TOUCH_PID=""

cleanup
exit 0
