#!/bin/sh
#
# OpenReader-K5 v0.1.0 automatic-boot uninstaller
#
# Removes OpenReader's Upstart integration so the next reboot starts
# normal KindleOS.
#
# OpenReader, KOReader and user data on /mnt/us are retained.
#

UPSTART="/etc/upstart/openreader-boot.conf"
BACKUP_ROOT="/mnt/us/openreader-k5-backups"

ROOT_RW=0

fail() {
    echo
    echo "ERROR: $*"
    exit 1
}

restore_root_ro() {
    if [ "$ROOT_RW" = "1" ]; then
        sync
        mntroot ro >/dev/null 2>&1
        ROOT_RW=0
    fi
}

cleanup() {
    RC=$?
    trap - EXIT INT TERM
    restore_root_ro
    exit "$RC"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

echo "========================================"
echo " OpenReader-K5 automatic-boot removal"
echo "========================================"
echo

[ "$(id -u)" = "0" ] ||
    fail "Uninstaller must be run as root."

#
# Do not alter boot configuration underneath a live OpenReader session.
#
if [ -s /var/tmp/openreader-state ]; then
    OR_STATE="$(cat /var/tmp/openreader-state 2>/dev/null)"
    fail "OpenReader is active (state: ${OR_STATE:-unknown}). Boot KindleOS once before uninstalling."
fi

if pgrep -f '/mnt/us/extensions/openReader/bin/touch-launcher.sh' \
    >/dev/null 2>&1; then
    fail "OpenReader launcher is currently running. Boot KindleOS once before uninstalling."
fi

if [ ! -f "$UPSTART" ]; then
    echo "OpenReader automatic boot is already disabled."
    trap - EXIT INT TERM
    exit 0
fi

STAMP="$(date '+%Y%m%d-%H%M%S' 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="unknown-time"

BACKUP="$BACKUP_ROOT/uninstall-$STAMP"

mkdir -p "$BACKUP" ||
    fail "Could not create backup directory."

cp "$UPSTART" "$BACKUP/openreader-boot.conf" ||
    fail "Could not back up current Upstart configuration."

echo "Making root filesystem writable..."

mntroot rw ||
    fail "Could not remount root filesystem read-write."

ROOT_RW=1

rm -f "$UPSTART" ||
    fail "Could not remove OpenReader Upstart configuration."

sync
restore_root_ro

#
# Runtime files on /mnt/us are deliberately retained.
#
rm -f \
    /var/tmp/openreader-bootstrap-once \
    /var/tmp/openreader-detached.pid \
    /var/tmp/openreader-clock-updater.pid \
    /var/tmp/openreader-display-clock.pid \
    /var/tmp/openreader-timekeeper.pid \
    /var/tmp/openreader-wake-watcher.pid \
    /var/tmp/openreader-keeper.pid \
    /var/tmp/openreader-watchdog.pid \
    /var/tmp/openreader-screen \
    /var/tmp/openreader-state \
    /var/tmp/koreader-pause-keeper \
    2>/dev/null

trap - EXIT INT TERM

echo
echo "========================================"
echo " OpenReader automatic boot disabled"
echo "========================================"
echo
echo "Upstart backup:"
echo "  $BACKUP/openreader-boot.conf"
echo
echo "Retained:"
echo "  /mnt/us/extensions/openReader"
echo "  /mnt/us/koreader"
echo "  /mnt/us/.openreader"
echo
echo "The Kindle has NOT been rebooted."
echo
echo "The next reboot should start normal KindleOS."
echo
echo "When ready:"
echo
echo "  sync"
echo "  /sbin/reboot"
echo

exit 0
