#!/bin/sh

STATE_DIR="/mnt/us/.openreader"
EPOCH_FILE="$STATE_DIR/last-known-epoch"
PIDFILE="/var/tmp/openreader-timekeeper.pid"

# 2024-01-01 UTC. Anything older is clearly implausible for this install.
MIN_VALID_EPOCH=1704067200

mkdir -p "$STATE_DIR"


valid_epoch() {
    VALUE="$1"

    case "$VALUE" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    [ "$VALUE" -ge "$MIN_VALID_EPOCH" ] 2>/dev/null
}


checkpoint() {
    NOW="$(date +%s 2>/dev/null)"

    valid_epoch "$NOW" || return 1

    OLD=""
    [ -f "$EPOCH_FILE" ] && OLD="$(cat "$EPOCH_FILE" 2>/dev/null)"

    # Never replace a newer saved time with an older clock.
    if valid_epoch "$OLD" && [ "$NOW" -lt "$OLD" ]; then
        return 1
    fi

    TMP="${EPOCH_FILE}.tmp"
    echo "$NOW" > "$TMP" || return 1
    mv "$TMP" "$EPOCH_FILE" || return 1

    return 0
}


restore_if_needed() {
    NOW="$(date +%s 2>/dev/null)"
    SAVED=""

    [ -f "$EPOCH_FILE" ] && SAVED="$(cat "$EPOCH_FILE" 2>/dev/null)"

    # No usable saved time: do not manufacture one.
    valid_epoch "$SAVED" || return 0

    # If current time is valid and at least as new as our checkpoint,
    # leave it alone.
    if valid_epoch "$NOW" && [ "$NOW" -ge "$SAVED" ]; then
        return 0
    fi

    # Current clock is stale/invalid. Restore our last known-good floor
    # through Amazon's supported setdate path.
    lipc-set-prop com.lab126.system date "$SAVED" \
        2>/dev/null || return 1

    return 0
}


start_daemon() {
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

    while true; do
        checkpoint
        sleep 600
    done
}


case "$1" in
    restore)
        restore_if_needed

        # Prevent old Kindle auto-time code from replacing the clock
        # after we establish a plausible value.
        lipc-set-prop com.lab126.system disableTimeAutoUpdate x \
            2>/dev/null || true
        ;;

    checkpoint)
        checkpoint
        ;;

    daemon)
        start_daemon
        ;;

    *)
        echo "Usage: $0 {restore|checkpoint|daemon}" >&2
        exit 1
        ;;
esac

exit 0
