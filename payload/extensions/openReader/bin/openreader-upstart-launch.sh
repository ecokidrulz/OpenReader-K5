#!/bin/sh

# Only allow one OpenReader takeover attempt per boot.
# /var/tmp is volatile, so this automatically resets on reboot.
ONCE_FLAG="/var/tmp/openreader-bootstrap-once"

if [ -f "$ONCE_FLAG" ]; then
    exit 0
fi

touch "$ONCE_FLAG"


SCRIPT="/mnt/us/extensions/openReader/bin/boot-replacement.sh"
LOG="/mnt/us/.openreader/bootstrap.log"

mkdir -p /mnt/us/.openreader

TIMEKEEPER="/mnt/us/extensions/openReader/bin/timekeeper.sh"

# Recover the last known-good wall clock before OpenReader renders.
if [ -x "$TIMEKEEPER" ]; then
    "$TIMEKEEPER" restore

    # Run periodic checkpoints in a separate session so the daemon
    # survives after this Upstart bootstrap exits.
    /usr/bin/setsid "$TIMEKEEPER" daemon </dev/null >>"$LOG" 2>&1 &
fi


# One-shot USBNetwork rescue diagnostic.
if [ -f /mnt/us/USBNet-rescue.run ] && [ -f /mnt/us/USBNet-rescue.sh ]; then
    /bin/sh /mnt/us/USBNet-rescue.sh
fi

# One-shot direct USBNetwork enable.
if [ -f /mnt/us/USBNet-enable.run ] && [ -f /mnt/us/USBNet-enable.sh ]; then
    /bin/sh /mnt/us/USBNet-enable.sh
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] bootstrap starting" >> "$LOG"

# Let the K5 Amazon GUI/framework stack reach a stable running state.
sleep 5
echo "[$(date '+%Y-%m-%d %H:%M:%S')] settle delay complete" >> "$LOG"

if [ ! -x "$SCRIPT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $SCRIPT not executable" >> "$LOG"
    exit 1
fi

# Detach OpenReader from the Upstart job's process group/session.
# The bootstrap itself can then exit without taking OpenReader with it.
/usr/bin/setsid "$SCRIPT" </dev/null >>"$LOG" 2>&1 &

CHILD=$!
echo "$CHILD" > /var/tmp/openreader-detached.pid
echo "[$(date '+%Y-%m-%d %H:%M:%S')] detached PID=$CHILD" >> "$LOG"

exit 0
