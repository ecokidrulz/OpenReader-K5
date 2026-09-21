#!/bin/sh
#
# OpenReader-K5 v0.1.0 installer
#
# Supported target:
#   Kindle Touch / K5 (yoshi)
#   Firmware 5.3.7.3
#
# Requirements:
#   - root shell / jailbreak already available
#   - KOReader installed at /mnt/us/koreader
#
# Installation is staged on /mnt/us before the active runtime is replaced.
# /etc/upstart is modified only after the staged runtime has been verified.
# The installer never reboots automatically.
#

VERSION="0.1.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"

TARGET="/mnt/us/extensions/openReader"
TARGET_PARENT="/mnt/us/extensions"
UPSTART_TARGET="/etc/upstart/openreader-boot.conf"

BACKUP_ROOT="/mnt/us/openreader-k5-backups"

STAGE="$TARGET_PARENT/.openReader.stage.$$"
OLD_TARGET="$TARGET_PARENT/.openReader.preinstall.$$"

ROOT_RW=0
SUCCESS=0
OLD_MOVED=0
ACTIVATED=0
UPSTART_TOUCHED=0
HAD_UPSTART=0
BACKUP=""

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

rollback() {
    RC=$?

    trap - EXIT INT TERM

    if [ "$SUCCESS" != "1" ]; then
        echo
        echo "Installation did not complete."

        #
        # Restore the previous Upstart configuration if we touched it.
        #
        if [ "$UPSTART_TOUCHED" = "1" ] && [ "$ROOT_RW" = "1" ]; then
            if [ "$HAD_UPSTART" = "1" ] &&
               [ -n "$BACKUP" ] &&
               [ -f "$BACKUP/openreader-boot.conf" ]; then

                cp "$BACKUP/openreader-boot.conf" "$UPSTART_TARGET" \
                    >/dev/null 2>&1 || true
                chmod 644 "$UPSTART_TARGET" 2>/dev/null || true
            else
                rm -f "$UPSTART_TARGET" 2>/dev/null || true
            fi
        fi

        #
        # Restore previous OpenReader runtime if activation had started.
        #
        if [ "$ACTIVATED" = "1" ]; then
            rm -rf "$TARGET" 2>/dev/null || true
        fi

        if [ "$OLD_MOVED" = "1" ] && [ -d "$OLD_TARGET" ]; then
            mv "$OLD_TARGET" "$TARGET" 2>/dev/null || true
        fi

        rm -rf "$STAGE" 2>/dev/null || true

        echo "Rollback attempted; previous installation preserved where possible."
    fi

    restore_root_ro

    exit "$RC"
}

trap rollback EXIT
trap 'exit 130' INT TERM

echo "========================================"
echo " OpenReader-K5 v${VERSION} installer"
echo "========================================"
echo

# ------------------------------------------------------------
# Root / environment checks
# ------------------------------------------------------------

[ "$(id -u)" = "0" ] ||
    fail "Installer must be run as root."

case "$SCRIPT_DIR" in
    "$TARGET"|"$TARGET"/*)
        fail "Do not run the release package from inside $TARGET."
        ;;
esac

#
# Do not replace files underneath a running OpenReader session.
#
if [ -s /var/tmp/openreader-state ]; then
    OR_STATE="$(cat /var/tmp/openreader-state 2>/dev/null)"
    fail "OpenReader is active (state: ${OR_STATE:-unknown}). Boot KindleOS once before installing."
fi

if pgrep -f '/mnt/us/extensions/openReader/bin/touch-launcher.sh' \
    >/dev/null 2>&1; then
    fail "OpenReader launcher is currently running. Boot KindleOS once before installing."
fi

# ------------------------------------------------------------
# Device / firmware check
# ------------------------------------------------------------

[ -f /etc/version.txt ] ||
    fail "/etc/version.txt not found."

[ -f /etc/prettyversion.txt ] ||
    fail "/etc/prettyversion.txt not found."

grep -q 'yoshi' /etc/version.txt 2>/dev/null ||
    fail "This does not appear to be a Kindle Touch / K5 (yoshi)."

FIRMWARE="$(awk 'NR==1 { print $2 }' /etc/prettyversion.txt 2>/dev/null)"

[ "$FIRMWARE" = "5.3.7.3" ] ||
    fail "Unsupported firmware: ${FIRMWARE:-unknown}. This release is tested only on 5.3.7.3."

echo "Device check: PASS"
echo "Firmware:     $FIRMWARE"

# ------------------------------------------------------------
# Release payload validation
# ------------------------------------------------------------

[ -d "$PAYLOAD/extensions/openReader" ] ||
    fail "OpenReader payload not found."

[ -f "$PAYLOAD/extensions/openReader/openreader-boot.conf" ] ||
    fail "OpenReader boot configuration missing from runtime payload."

[ -f "$PAYLOAD/upstart/openreader-boot.conf" ] ||
    fail "Upstart configuration missing from payload."

[ -f "$PAYLOAD/SHA256SUMS" ] ||
    fail "payload/SHA256SUMS not found."

cmp \
    "$PAYLOAD/extensions/openReader/openreader-boot.conf" \
    "$PAYLOAD/upstart/openreader-boot.conf" \
    >/dev/null 2>&1 ||
    fail "Release contains mismatched OpenReader boot configurations."

echo
echo "Verifying release payload..."

(
    cd "$SCRIPT_DIR" || exit 1

    while read EXPECTED FILE; do
        [ -n "$EXPECTED" ] || continue
        [ -n "$FILE" ] || exit 1

        ACTUAL="$(sha256sum "$FILE" 2>/dev/null | awk '{print $1}')"

        if [ "$ACTUAL" != "$EXPECTED" ]; then
            echo "$FILE: FAILED"
            exit 1
        fi

        echo "$FILE: OK"
    done < payload/SHA256SUMS
) || fail "Payload checksum verification failed."

echo "Payload verification: PASS"

# ------------------------------------------------------------
# KOReader requirements
# ------------------------------------------------------------

[ -x /mnt/us/koreader/koreader.sh ] ||
    fail "KOReader not found at /mnt/us/koreader."

[ -x /mnt/us/koreader/fbink ] ||
    fail "FBInk not found at /mnt/us/koreader/fbink."

KOREADER_VERSION="unknown"

if [ -f /mnt/us/koreader/git-rev ]; then
    KOREADER_VERSION="$(cat /mnt/us/koreader/git-rev 2>/dev/null)"
fi

echo "KOReader:      $KOREADER_VERSION"

if [ -x /mnt/us/usbnet/bin/usbnetwork ]; then
    echo "USBNetwork:    present"
else
    echo "USBNetwork:    not detected (Net toolbar unavailable)"
fi

if [ -d /mnt/us/linkss ]; then
    echo "linkss:        present"
else
    echo "linkss:        not detected (custom screensavers unavailable)"
fi

# ------------------------------------------------------------
# Validate release scripts
# ------------------------------------------------------------

echo
echo "Checking release shell scripts..."

for F in "$PAYLOAD"/extensions/openReader/bin/*.sh; do
    [ -f "$F" ] || continue

    sh -n "$F" ||
        fail "Syntax check failed: $F"
done

echo "Script syntax: PASS"

# ------------------------------------------------------------
# Backup current installation
# ------------------------------------------------------------

STAMP="$(date '+%Y%m%d-%H%M%S' 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="unknown-time"

BACKUP="$BACKUP_ROOT/$STAMP"

mkdir -p "$BACKUP" ||
    fail "Could not create backup directory: $BACKUP"

if [ -d "$TARGET" ]; then
    echo
    echo "Backing up existing OpenReader installation..."

    cp -R "$TARGET" "$BACKUP/openReader" ||
        fail "Failed to back up existing OpenReader installation."
fi

if [ -f "$UPSTART_TARGET" ]; then
    HAD_UPSTART=1

    cp "$UPSTART_TARGET" "$BACKUP/openreader-boot.conf" ||
        fail "Failed to back up existing Upstart configuration."
fi

# ------------------------------------------------------------
# Stage new runtime while rootfs remains read-only
# ------------------------------------------------------------

echo
echo "Staging OpenReader runtime..."

mkdir -p "$TARGET_PARENT" ||
    fail "Could not create $TARGET_PARENT."

rm -rf "$STAGE" "$OLD_TARGET"

cp -R "$PAYLOAD/extensions/openReader" "$STAGE" ||
    fail "Failed to stage OpenReader payload."

chmod 755 "$STAGE/bin/"*.sh 2>/dev/null ||
    fail "Could not set script permissions."

chmod 755 "$STAGE/bin/touch_reader" 2>/dev/null ||
    fail "Could not set touch_reader permissions."

#
# Verify required runtime components in the staged tree.
#
for F in \
    bin/boot-replacement.sh \
    bin/clock-updater.sh \
    bin/display-clock.sh \
    bin/openreader-upstart-launch.sh \
    bin/redraw-openreader.sh \
    bin/timekeeper.sh \
    bin/touch-launcher.sh \
    bin/touch_reader \
    bin/wake-watcher.sh \
    openreader-boot.conf
do
    [ -f "$STAGE/$F" ] ||
        fail "Staged runtime is missing: $F"
done

for F in "$STAGE"/bin/*.sh; do
    [ -f "$F" ] || continue

    sh -n "$F" ||
        fail "Staged script failed syntax check: $F"
done

cmp \
    "$STAGE/openreader-boot.conf" \
    "$PAYLOAD/upstart/openreader-boot.conf" \
    >/dev/null 2>&1 ||
    fail "Staged boot configuration failed verification."

echo "Staged runtime verification: PASS"

# ------------------------------------------------------------
# Atomically activate the staged runtime
# ------------------------------------------------------------

echo
echo "Activating OpenReader runtime..."

if [ -d "$TARGET" ]; then
    mv "$TARGET" "$OLD_TARGET" ||
        fail "Could not move existing OpenReader installation aside."

    OLD_MOVED=1
fi

mv "$STAGE" "$TARGET" ||
    fail "Could not activate staged OpenReader runtime."

ACTIVATED=1

# ------------------------------------------------------------
# Install Upstart configuration LAST
# ------------------------------------------------------------

echo "Installing Upstart boot configuration..."

mntroot rw ||
    fail "Could not remount root filesystem read-write."

ROOT_RW=1
UPSTART_TOUCHED=1

cp "$PAYLOAD/upstart/openreader-boot.conf" "$UPSTART_TARGET" ||
    fail "Failed to install $UPSTART_TARGET."

chmod 644 "$UPSTART_TARGET" ||
    fail "Could not set Upstart configuration permissions."

cmp \
    "$TARGET/openreader-boot.conf" \
    "$UPSTART_TARGET" \
    >/dev/null 2>&1 ||
    fail "Installed Upstart configuration failed verification."

# ------------------------------------------------------------
# Installation metadata
# ------------------------------------------------------------

mkdir -p /mnt/us/.openreader ||
    fail "Could not create OpenReader state directory."

echo "$VERSION" > /mnt/us/.openreader/openreader-k5-version ||
    fail "Could not write installed version."

echo "$BACKUP" > /mnt/us/.openreader/installation-backup ||
    fail "Could not record installation backup."

sync

restore_root_ro

#
# The persistent backup is sufficient now that installation succeeded.
#
rm -rf "$OLD_TARGET" 2>/dev/null || true

SUCCESS=1
trap - EXIT INT TERM

echo
echo "========================================"
echo " Installation complete"
echo "========================================"
echo
echo "OpenReader-K5: v$VERSION"
echo "Firmware:      $FIRMWARE"
echo "KOReader:      $KOREADER_VERSION"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "The Kindle has NOT been rebooted."
echo
echo "Recovery:"
echo "  Create /mnt/us/BOOT_KINDLEOS before reboot"
echo "  to request one stock KindleOS boot."
echo
echo "When ready:"
echo
echo "  sync"
echo "  /sbin/reboot"
echo

exit 0
