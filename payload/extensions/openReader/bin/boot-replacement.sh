#!/bin/sh
# OpenReader Boot Replacement Script
# Prevents Amazon framework from starting and launches OpenReader instead
# Part of the "Amazon-Free Boot" system

LAUNCHER_DIR="/mnt/us/extensions/openReader"
LOG_FILE="/mnt/us/.openreader/debug.log"

# Logging function
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Diagnostic signal traps for K5 persistent boot.
# Log and ignore common asynchronous signals during bootstrap.
trap 'log_msg "SIGNAL: HUP received and ignored"' HUP
trap 'log_msg "SIGNAL: INT received and ignored"' INT
trap 'log_msg "SIGNAL: QUIT received and ignored"' QUIT
trap 'log_msg "SIGNAL: TERM received and ignored"' TERM



log_msg "=== OpenReader Boot Replacement Starting ==="

# Emergency Recovery System

# Check for USB override file (user can create this to boot to KindleOS)
if [ -f /mnt/us/BOOT_KINDLEOS ]; then
    log_msg "USB override detected: BOOT_KINDLEOS file exists"
    mv /mnt/us/BOOT_KINDLEOS /mnt/us/BOOT_KINDLEOS.used
    log_msg "Allowing framework to start normally"
    exit 0
fi

# Persistent recovery state.
# /var/tmp is volatile on the Kindle, so anything that must survive
# a reboot belongs on /mnt/us.
STATE_DIR="/mnt/us/.openreader"
mkdir -p "$STATE_DIR"

BOOT_ONCE_FILE="$STATE_DIR/boot-kindleos-once"
BOOT_COUNT_FILE="$STATE_DIR/boot-count"
BOOT_FAILED_FILE="$STATE_DIR/boot-failed"

# Check for one-time KindleOS boot request.
# Consume it once, then allow stock KindleOS to boot normally.
if [ -f "$BOOT_ONCE_FILE" ]; then
    log_msg "One-time KindleOS boot requested from settings"
    rm -f "$BOOT_ONCE_FILE"
    log_msg "Allowing framework to start normally"
    exit 0
fi

# A repeated-failure condition is deliberately latched.
# OpenReader remains bypassed until boot-failed is manually removed.
if [ -f "$BOOT_FAILED_FILE" ]; then
    log_msg "Persistent boot failure flag detected - skipping OpenReader"
    log_msg "Remove $BOOT_FAILED_FILE to re-enable OpenReader boot"
    exit 0
fi

# Increment boot counter
BOOT_COUNT=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
BOOT_COUNT=$((BOOT_COUNT + 1))
echo "$BOOT_COUNT" > "$BOOT_COUNT_FILE"
log_msg "Boot attempt #$BOOT_COUNT"

# Too many boots in 60 seconds = problem, fall back to KindleOS
if [ "$BOOT_COUNT" -gt 3 ]; then
    log_msg "ERROR: Too many boot attempts ($BOOT_COUNT) - failing safe to KindleOS"
    touch "$BOOT_FAILED_FILE"
    exit 0
fi

# Reset counter once boot-critical initialization completes.
# A reboot before that point leaves the incremented count in place.

# System Initialization

timed_stop() {
    JOB="$1"
    START_TS=$(date +%s)
    log_msg "STOP BEGIN: $JOB"

    stop "$JOB" >/dev/null 2>&1
    RC=$?

    END_TS=$(date +%s)
    ELAPSED=$((END_TS - START_TS))
    log_msg "STOP END: $JOB rc=$RC elapsed=${ELAPSED}s"

    return 0
}

log_msg "Stopping framework from starting..."

# Aggressively stop all framework-related services
# Kindle Upstart may send SIGTERM during lab126_gui teardown.
# Ignore TERM while stopping Amazon GUI services, just as KOReader does.
trap "" TERM
log_msg "SIGTERM temporarily ignored during framework teardown"

timed_stop lab126_gui
timed_stop framework
timed_stop pillow
timed_stop blanket
# timed_stop cmd  # retained for Wi-Fi routing/DNS
timed_stop phd
timed_stop pmond
timed_stop tmd
timed_stop webreader
timed_stop kfxreader

# Keep SIGTERM ignored for the lifetime of the OpenReader boot process.
# On this K5, framework teardown can deliver TERM after the stop commands
# themselves have already returned.
log_msg "SIGTERM remains ignored for OpenReader boot process"


# Kill any already-running framework processes immediately
killall -STOP cvm 2>/dev/null || true
killall -STOP lipc-wait-event 2>/dev/null || true
killall -STOP framework 2>/dev/null || true
killall -STOP pillow 2>/dev/null || true

log_msg "Framework services stopped"

log_msg "POSTSTOP: before settle sleep"
sleep 1
log_msg "POSTSTOP: after settle sleep"

# Unlock input devices
log_msg "POSTSTOP: beginning input initialization"
if [ -e /proc/keypad ]; then
    echo unlock > /proc/keypad
    log_msg "Unlocked keypad"
fi

if [ -e /proc/fiveway ]; then
    echo unlock > /proc/fiveway
    log_msg "Unlocked fiveway"
fi

# Prevent screensaver
log_msg "POSTSTOP: setting preventScreenSaver"
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
log_msg "POSTSTOP: preventScreenSaver returned"
log_msg "Disabled screensaver"

# Framework Keeper (Continuous Monitoring)

log_msg "Starting framework keeper..."

# Background process to keep framework components suspended
(
    while true; do
        # Check if we should pause (KOReader running)
        if [ ! -f /var/tmp/koreader-pause-keeper ]; then
            # No pause flag - do normal work
            # Suspend any framework components that try to start
            for service in cvm lipc-wait-event framework pillow webreader kfxreader; do
                if pidof "$service" >/dev/null 2>&1; then
                    killall -STOP "$service" 2>/dev/null
                fi
            done
        fi
        # If pause flag exists, skip suspension (KOReader manages its own services)
        sleep 5
    done
) &

KEEPER_PID=$!
echo "$KEEPER_PID" > /var/tmp/openreader-keeper.pid
log_msg "Framework keeper started (PID: $KEEPER_PID)"

# Launch OpenReader

log_msg "Launching OpenReader..."

# Ensure launcher directory exists
if [ ! -d "$LAUNCHER_DIR" ]; then
    log_msg "ERROR: Launcher directory not found: $LAUNCHER_DIR"
    log_msg "Falling back to KindleOS"
    kill "$KEEPER_PID" 2>/dev/null
    exit 0
fi

# Ensure launcher script exists and is executable
LAUNCHER_SCRIPT="$LAUNCHER_DIR/bin/touch-launcher.sh"
if [ ! -x "$LAUNCHER_SCRIPT" ]; then
    log_msg "ERROR: Launcher script not found or not executable: $LAUNCHER_SCRIPT"
    log_msg "Falling back to KindleOS"
    kill "$KEEPER_PID" 2>/dev/null
    exit 0
fi

# Mark that we're in boot mode (for launcher's service management)
export OPENREADER_BOOT_MODE=1
log_msg "Set OPENREADER_BOOT_MODE=1"

# Initialize state file
echo "RUNNING" > /var/tmp/openreader-state
log_msg "Initialized state file"

# Boot-critical initialization has succeeded.
echo "0" > "$BOOT_COUNT_FILE"
sync
log_msg "Boot count reset: initialization completed successfully"

# OpenReader Watchdog (Monitors and Auto-Restarts)

log_msg "Starting OpenReader watchdog..."

# Get fbink path for watchdog
FBINK_PATH="/mnt/us/koreader/fbink"
[ ! -f "$FBINK_PATH" ] && FBINK_PATH="/usr/bin/fbink"

# Background watchdog process - state-aware
(
    while true; do
        sleep 3  # Check every 3 seconds
        
        # Check the state file
        STATE=$(cat /var/tmp/openreader-state 2>/dev/null || echo "RUNNING")
        
        
        # Simple check: is the launcher running?
        if ! pgrep -f touch-launcher.sh >/dev/null 2>&1; then
            # Launcher not running - check state
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: Launcher not running, STATE=$STATE" >> "$LOG_FILE"
            
            case "$STATE" in
                EXIT)
                    # Intentional exit to KindleOS - don't restart
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: Exited to KindleOS, stopping..." >> "$LOG_FILE"
                    rm -f /var/tmp/openreader-state
                    exit 0
                    ;;
                    
                KOREADER|KTERM)
                    # Application running - check more frequently
                    # Don't wait in a loop, just check again next cycle
                    ;;
                    
                RESTART)
                    # Explicit restart request
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: Restart requested..." >> "$LOG_FILE"
                    rm -f /var/tmp/openreader-state
                    killall -9 koreader 2>/dev/null
                    killall -9 reader.lua 2>/dev/null
                    killall -9 touch_reader 2>/dev/null
                    
                    "$FBINK_PATH" -c 2>/dev/null
                    "$FBINK_PATH" -y 15 -pm "OpenReader restarting..." 2>/dev/null
                    sleep 1
                    
                    cd "$LAUNCHER_DIR" 2>/dev/null || continue
                    echo "RUNNING" > /var/tmp/openreader-state
                    OPENREADER_BOOT_MODE=1 "$LAUNCHER_SCRIPT" &
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: OpenReader restarted" >> "$LOG_FILE"
                    ;;
                    
                *)
                    # Unknown state or crash - restart
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: Launcher crashed (state: $STATE), restarting..." >> "$LOG_FILE"
                    
                    rm -f /var/tmp/openreader-state
                    killall -9 touch_reader 2>/dev/null
                    
                    "$FBINK_PATH" -c 2>/dev/null
                    "$FBINK_PATH" -y 15 -pm "OpenReader restarting..." 2>/dev/null
                    sleep 1
                    
                    cd "$LAUNCHER_DIR" 2>/dev/null || continue
                    echo "RUNNING" > /var/tmp/openreader-state
                    OPENREADER_BOOT_MODE=1 "$LAUNCHER_SCRIPT" &
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog: OpenReader restarted" >> "$LOG_FILE"
                    ;;
            esac
        fi
    done
) &

WATCHDOG_PID=$!
echo "$WATCHDOG_PID" > /var/tmp/openreader-watchdog.pid
log_msg "Watchdog started (PID: $WATCHDOG_PID)"

# Launch OpenReader (Initial Start)

# Change to launcher directory
cd "$LAUNCHER_DIR" || exit 0

# Launch OpenReader
log_msg "Launching OpenReader (initial start)..."

# K5 can occasionally reach OpenReader startup while the EPDC
# pause state is still changing. Guard the first 10 seconds
# without delaying the initial OpenReader paint.
EPDC_RESUME="$LAUNCHER_DIR/epdc-resume.sh"
if [ -x "$EPDC_RESUME" ]; then
    "$EPDC_RESUME" 10 >> "$LOG_FILE" 2>&1 &
fi

"$LAUNCHER_SCRIPT" &

# Re-establish NiLuJe custom screensaver mount.
LINKSS="/mnt/us/linkss/bin/linkss"

if [ -x "$LINKSS" ]; then
    if ! grep -q "^fsp /usr/share/blanket/screensaver" /proc/mounts; then
        "$LINKSS"
        log_msg "Custom screensaver mount initialized"
    else
        log_msg "Custom screensaver mount already active"
    fi
else
    log_msg "WARNING: linkss not found or not executable"
fi

# Start lightweight OpenReader wake watcher.
WAKE_WATCHER="/mnt/us/extensions/openReader/bin/wake-watcher.sh"

if [ -x "$WAKE_WATCHER" ]; then
    /usr/bin/setsid "$WAKE_WATCHER" </dev/null >/dev/null 2>&1 &
    log_msg "Wake watcher started (PID: $!)"
else
    log_msg "WARNING: wake watcher not found or not executable"
fi

log_msg "OpenReader boot sequence complete"

# Keep this script running so watchdog stays alive
wait

