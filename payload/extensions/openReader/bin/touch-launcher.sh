#!/bin/sh
# Kindle Touch-Enabled Launcher - CLEAN UI VERSION
# Uses compiled touch_reader binary for real touch input

SCRIPT_DIR="$(dirname "$0")"
FBINK="/mnt/us/koreader/fbink"
TOUCH_READER="$SCRIPT_DIR/touch_reader"
[ ! -f "$FBINK" ] && FBINK="/usr/bin/fbink"
OPENREADER_K5_VERSION="0.1.0"


# Global state variables
FRONTLIGHT_ENABLED=0
FRONTLIGHT_LAST_LEVEL=600  # Default to 50% brightness (600/1200)

# Detect frontlight device path
detect_frontlight() {
    if [ -f /sys/class/backlight/max77696-bl/brightness ]; then
        echo "/sys/class/backlight/max77696-bl/brightness"
    elif [ -f /sys/class/backlight/fp9967-bl1/brightness ]; then
        echo "/sys/class/backlight/fp9967-bl1/brightness"
    elif [ -f /sys/class/backlight/mxc_msp430.0/brightness ]; then
        echo "/sys/class/backlight/mxc_msp430.0/brightness"
    else
        echo ""
    fi
}

FL_PATH=$(detect_frontlight)

# Check if touch_reader exists
if [ ! -f "$TOUCH_READER" ]; then
    $FBINK -c
    $FBINK -y 10 -pmh "Error: touch_reader not compiled!"
    $FBINK -y 12 -pm "Please compile the touch input binary"
    $FBINK -y 13 -pm "See: src/README.md for instructions"
    sleep 3
    exit 1
fi

# Stop Kindle services (KOReader method - use SIGSTOP to prevent auto-restart)
stop_services() {
    # Check if we're in boot mode (framework never started)
    if [ "$OPENREADER_BOOT_MODE" = "1" ]; then
        # Boot mode: Framework never started, just prevent screensaver
        FRAMEWORK_WAS_RUNNING=0
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
        return
    fi
    
    # Check if framework is actually running
    if pidof cvm >/dev/null 2>&1; then
        # Framework is running, suspend it
        FRAMEWORK_WAS_RUNNING=1
        
        # Prevent screen saver
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
        
        # Suspend (SIGSTOP) all framework processes
        # Using SIGSTOP instead of SIGKILL prevents init from restarting them
        killall -STOP cvm 2>/dev/null
        killall -STOP lipc-wait-event 2>/dev/null
        killall -STOP webreader 2>/dev/null
        killall -STOP kfxreader 2>/dev/null
        killall -STOP kfxview 2>/dev/null
        killall -STOP mesquite 2>/dev/null
        killall -STOP browserd 2>/dev/null
        
        # Suspend background services (from KOReader's TOGGLED_SERVICES)
        killall -STOP stored 2>/dev/null
        killall -STOP todo 2>/dev/null
        killall -STOP tmd 2>/dev/null
        killall -STOP rcm 2>/dev/null
        killall -STOP archive 2>/dev/null
        killall -STOP scanner 2>/dev/null
        killall -STOP otav3 2>/dev/null
        killall -STOP otaupd 2>/dev/null
        killall -STOP volumd 2>/dev/null
        
        # Ensure clean framebuffer
        echo 1 > /proc/eink_fb/update_display 2>/dev/null || true
        
        # Small delay to ensure processes are fully stopped
        sleep 0.5
    else
        # Framework not running (we're in boot mode)
        FRAMEWORK_WAS_RUNNING=0
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
    fi
}

# Restore Kindle services (resume suspended processes)
restore_services() {
    # Signal watchdog NOT to restart (permanent exit to KindleOS)
    echo "EXIT" > /var/tmp/openreader-state
    
    # Kill touch reader
    killall -TERM touch_reader 2>/dev/null
    
    # Check if we're in boot mode
    if [ "$OPENREADER_BOOT_MODE" = "1" ]; then
        # Boot mode: Don't restore framework, we're staying in OpenReader
        # Just clean up
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
        return
    fi
    
    # Check if framework was actually running before
    if [ "$FRAMEWORK_WAS_RUNNING" = "1" ]; then
        # Framework was running, restore it
        
        # Re-enable screen saver
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
        
        # Resume (SIGCONT) all suspended processes
        killall -CONT cvm 2>/dev/null
        killall -CONT lipc-wait-event 2>/dev/null
        killall -CONT webreader 2>/dev/null
        killall -CONT kfxreader 2>/dev/null
        killall -CONT kfxview 2>/dev/null
        killall -CONT mesquite 2>/dev/null
        killall -CONT browserd 2>/dev/null
        killall -CONT stored 2>/dev/null
        killall -CONT todo 2>/dev/null
        killall -CONT tmd 2>/dev/null
        killall -CONT rcm 2>/dev/null
        killall -CONT archive 2>/dev/null
        killall -CONT scanner 2>/dev/null
        killall -CONT otav3 2>/dev/null
        killall -CONT otaupd 2>/dev/null
        killall -CONT volumd 2>/dev/null
        
        # Refresh display
        echo 1 > /proc/eink_fb/update_display 2>/dev/null || true
    else
        # Framework wasn't running, don't restore anything
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
    fi
}

# Get screen dimensions
get_screen_size() {
    # Kindle Touch/K5: visible panel is 600x800.
    # fb0 virtual_size is 608x3584 because of framebuffer stride/buffering,
    # and must not be treated as panel dimensions.
    SCREEN_WIDTH=600
    SCREEN_HEIGHT=800
    TOOLBAR_LINE=45
}

# Draw the menu
# Draw the menu
draw_menu() {
    SELECTED=$1

    $FBINK -c

    # Header: TALL size 2, shifted right and highlighted.
    $FBINK -x 2 -y 1 -F TALL -S 2 -h "OPENREADER-K5"

    $FBINK -x 2 -y 6 "──────────────────────────────────"

    if [ "$SELECTED" = "1" ]; then
        $FBINK -x 2 -y 6 -F TALL -S 2 -h "KOReader"
    else
        $FBINK -x 2 -y 6 -F TALL -S 2 "KOReader"
    fi

    if [ "$SELECTED" = "2" ]; then
        $FBINK -x 2 -y 9 -F TALL -S 2 -h "Display Clock"
    else
        $FBINK -x 2 -y 9 -F TALL -S 2 "Display Clock"
    fi

    if [ "$SELECTED" = "3" ]; then
        $FBINK -x 2 -y 12 -F TALL -S 2 -h "System Info"
    else
        $FBINK -x 2 -y 12 -F TALL -S 2 "System Info"
    fi

    if [ "$SELECTED" = "4" ]; then
        $FBINK -x 2 -y 15 -F TALL -S 2 -h "Boot KindleOS Once"
    else
        $FBINK -x 2 -y 15 -F TALL -S 2 "Boot KindleOS Once"
    fi

    if [ "$SELECTED" = "5" ]; then
        $FBINK -x 2 -y 18 -F TALL -S 2 -h "Reboot"
    else
        $FBINK -x 2 -y 18 -F TALL -S 2 "Reboot"
    fi

    $FBINK -x 2 -y 43 "──────────────────────────────────"

    if [ "$SELECTED" = "toolbar_refresh" ]; then
        $FBINK -x 2 -y 22 -F TERMINUSB -S 2 -h "Refresh"
    else
        $FBINK -x 2 -y 22 -F TERMINUSB -S 2 "Refresh"
    fi

    if [ "$SELECTED" = "toolbar_usbnet" ]; then
        $FBINK -x 11 -y 22 -F TERMINUSB -S 2 -h "Net"
    else
        $FBINK -x 11 -y 22 -F TERMINUSB -S 2 "Net"
    fi

    if [ "$SELECTED" = "toolbar_usbstorage" ]; then
        $FBINK -x 18 -y 22 -F TERMINUSB -S 2 -h "Storage"
    else
        $FBINK -x 18 -y 22 -F TERMINUSB -S 2 "Storage"
    fi

    if [ "$SELECTED" = "toolbar_poweroff" ]; then
        $FBINK -x 29 -y 22 -F TERMINUSB -S 2 -h "Off"
    else
        $FBINK -x 29 -y 22 -F TERMINUSB -S 2 "Off"
    fi
}

get_button_from_coords() {
    RAW_X=$1
    RAW_Y=$2

    X=$((RAW_X * 600 / 4095))
    Y=$((RAW_Y * 800 / 4095))

    # Bottom toolbar: shifted slightly right to align with labels.
    if [ "$Y" -ge 690 ]; then
        if [ "$X" -lt 20 ]; then
            echo "unknown"
        elif [ "$X" -lt 165 ]; then
            echo "toolbar_refresh"
        elif [ "$X" -lt 310 ]; then
            echo "toolbar_usbnet"
        elif [ "$X" -lt 455 ]; then
            echo "toolbar_usbstorage"
        else
            echo "toolbar_poweroff"
        fi
        return
    fi

    # Four main menu regions.
    if [ "$Y" -lt 175 ]; then
        echo "unknown"
    elif [ "$Y" -lt 270 ]; then
        echo "1"
    elif [ "$Y" -lt 365 ]; then
        echo "2"
    elif [ "$Y" -lt 460 ]; then
        echo "3"
    elif [ "$Y" -lt 575 ]; then
        echo "4"
    elif [ "$Y" -lt 690 ]; then
        echo "5"
    else
        echo "unknown"
    fi
}

# Show system info (with ASCII banner)
show_system_info() {
    echo "INFO" > /var/tmp/openreader-screen
    $FBINK -c
    
    # Kindle figlet banner - moved down with more spacing
    $FBINK -y 8 -pm ""
    $FBINK -y 9 -pm " _  ___           _ _      "
    $FBINK -y 10 -pm "| |/ (_)_ __   __| | | ___ "
    $FBINK -y 11 -pm "| ' /| | '_ \\ / _\` | |/ _ \\"
    $FBINK -y 12 -pm "| . \\| | | | | (_| | |  __/"
    $FBINK -y 13 -pm "|_|\\_\\_|_| |_|\\__,_|_|\\___|"
    
    # Get system information
    MODEL=$(cat /proc/usid 2>/dev/null | cut -c4- || echo "Unknown")
    KERNEL=$(uname -r)
    UPTIME=$(uptime | awk '{print $3}' | sed 's/,//')
    MEMORY=$(free -m | awk 'NR==2{printf "%.0f/%.0f MB", $3,$2}')
    STORAGE=$(df -h /mnt/us | tail -n 1 | awk '{print $3" / "$2" ("$5")"}')

    # Software versions
    FIRMWARE="$(awk 'NR==1 {print $2}' /etc/prettyversion.txt 2>/dev/null)"
    [ -n "$FIRMWARE" ] || FIRMWARE="N/A"

    if [ -f /mnt/us/koreader/git-rev ]; then
        KOREADER_VERSION="$(cat /mnt/us/koreader/git-rev 2>/dev/null)"
    else
        KOREADER_VERSION="N/A"
    fi

    LAUNCHER_VERSION="OpenReader-K5 v${OPENREADER_K5_VERSION}"
    
    # Battery info from Kindle powerd.
    BATTERY_LEVEL="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null)"
    CHARGING="$(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null)"

    case "$BATTERY_LEVEL" in
        ''|*[!0-9]*)
            BATTERY="N/A"
            ;;
        *)
            BATTERY="${BATTERY_LEVEL}%"
            ;;
    esac

    if [ "$CHARGING" = "1" ] && [ "$BATTERY" != "N/A" ]; then
        BATTERY="${BATTERY} (charging)"
    fi
    
    # Display system information - left justified
    $FBINK -x 2 -y 16 ""
    $FBINK -x 2 -y 17 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $FBINK -x 2 -y 19 "Device:   Kindle $MODEL"
    $FBINK -x 2 -y 20 "Firmware: $FIRMWARE"
    $FBINK -x 2 -y 21 "Launcher: $LAUNCHER_VERSION"
    $FBINK -x 2 -y 22 "KOReader: $KOREADER_VERSION"
    $FBINK -x 2 -y 23 "Kernel:   $KERNEL"
    $FBINK -x 2 -y 24 "Battery:  $BATTERY"
    $FBINK -x 2 -y 26 "Uptime:   $UPTIME"
    $FBINK -x 2 -y 27 "Memory:   $MEMORY"
    $FBINK -x 2 -y 28 "Storage:  $STORAGE"
    $FBINK -x 2 -y 30 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    $FBINK -x 2 -y 31 "Touch anywhere to return..."
    # Wait for touch
    "$TOUCH_READER" /dev/input/event3 2>/dev/null >/dev/null
}

# Settings menu (EXACT UI MATCH to main menu for coordinate reuse)
show_settings() {

    while true; do
        $FBINK -c
        
        # ═══════════════════════════════════════════════════
        # BANNER - Same as main menu (lines 5-16)
        # ═══════════════════════════════════════════════════
        $FBINK -y 5 -pm "██████╗ ██████╗ ███████╗███╗   ██╗"
        $FBINK -y 6 -pm "██╔═══██╗██╔══██╗██╔════╝████╗  ██║"
        $FBINK -y 7 -pm "██║   ██║██████╔╝█████╗  ██╔██╗ ██║"
        $FBINK -y 8 -pm "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║"
        $FBINK -y 9 -pm "╚██████╔╝██║     ███████╗██║ ╚████║"
        $FBINK -y 10 -pm " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝"
        $FBINK -y 11 -pm "██████╗ ███████╗ █████╗ ██████╗"
        $FBINK -y 12 -pm "██╔══██╗██╔════╝██╔══██╗██╔══██╗"
        $FBINK -y 13 -pm "██████╔╝█████╗  ███████║██║  ██║"
        $FBINK -y 14 -pm "██╔══██╗██╔══╝  ██╔══██║██║  ██║"
        $FBINK -y 15 -pm "██║  ██║███████╗██║  ██║██████╔╝"
        $FBINK -y 16 -pm "╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝"
        
        # Tagline replacement
        $FBINK -y 18 -pm ""
        $FBINK -y 19 -pm "                Settings!"
        
        # ═══════════════════════════════════════════════════
        # STATUS CHECKS
        # ═══════════════════════════════════════════════════
        
        # Check frontlight status and build slider
        FL_BRIGHT=0
        FL_MAX_HARDWARE=1200  # Kindle display max brightness
        FL_SLIDER_WIDTH=24    # Visual slider width in characters
        
        if [ -n "$FL_PATH" ] && [ -f "$FL_PATH" ]; then
            FL_BRIGHT=$(cat "$FL_PATH" 2>/dev/null || echo "0")
        fi
        
        # Build frontlight slider (24 chars wide)
        # Map hardware brightness (0-1200) to visual slider (0-24)
        FL_FILLED=$((FL_BRIGHT * FL_SLIDER_WIDTH / FL_MAX_HARDWARE))
        if [ $FL_FILLED -gt $FL_SLIDER_WIDTH ]; then FL_FILLED=$FL_SLIDER_WIDTH; fi
        FL_EMPTY=$((FL_SLIDER_WIDTH - FL_FILLED))
        
        # Build slider bar
        FL_SLIDER=""
        i=0
        while [ $i -lt $FL_FILLED ]; do
            FL_SLIDER="${FL_SLIDER}█"
            i=$((i + 1))
        done
        i=0
        while [ $i -lt $FL_EMPTY ]; do
            FL_SLIDER="${FL_SLIDER}░"
            i=$((i + 1))
        done
        
        # WiFi status removed - button is now static
        
        # ═══════════════════════════════════════════════════
        # SETTINGS BUTTONS - EXACT SAME LINES AS MAIN MENU
        # ═══════════════════════════════════════════════════
        
        # Button 1: Frontlight Slider (lines 21-24 - same as main Button 1)
        $FBINK -y 21 -pm "┌────────────────────────────────────┐"
        $FBINK -y 22 -pm "│                                      │"
        $FBINK -y 23 -pm "│  [LIGHT] [$FL_SLIDER]  │"
        $FBINK -y 24 -pm "└────────────────────────────────────┘"
        
        # Button 2: WiFi Settings (lines 27-30 - same as main Button 2)
        $FBINK -y 27 -pm "┌────────────────────────────────────┐"
        $FBINK -y 28 -pm "│  [WIFI]  WI-FI SETTINGS              │"
        $FBINK -y 29 -pm "│          Manage Wireless Network     │"
        $FBINK -y 30 -pm "└────────────────────────────────────┘"
        
        # Button 3: Boot to KindleOS (or Reboot if not in boot mode)
        if [ "$OPENREADER_BOOT_MODE" = "1" ]; then
            # Boot mode: Offer to boot to KindleOS once
            $FBINK -y 33 -pm "┌────────────────────────────────────┐"
            $FBINK -y 34 -pm "│  [KINDLE] BOOT TO KINDLEOS ONCE      │"
            $FBINK -y 35 -pm "│           Restart to Stock UI        │"
            $FBINK -y 36 -pm "└────────────────────────────────────┘"
        else
            # Normal mode: Regular reboot
            $FBINK -y 33 -pm "┌────────────────────────────────────┐"
            $FBINK -y 34 -pm "│     [BOOT]  REBOOT DEVICE            │"
            $FBINK -y 35 -pm "│             Restart Kindle           │"
            $FBINK -y 36 -pm "└────────────────────────────────────┘"
        fi
        
        # Button 4: Power Off (lines 39-42 - same as main Button 4)
        $FBINK -y 39 -pm "┌────────────────────────────────────┐"
        $FBINK -y 40 -pm "│     [PWROFF] POWER OFF               │"
        $FBINK -y 41 -pm "│              Shut Down Kindle        │"
        $FBINK -y 42 -pm "└────────────────────────────────────┘"
        
        # Button 5: Exit to Kindle OS (lines 45-48 - same as main Button 5)
        $FBINK -y 45 -pm "┌────────────────────────────────────┐"
        $FBINK -y 46 -pm "│     [EXIT]  EXIT TO KINDLE OS        │"
        $FBINK -y 47 -pm "│             Return to Stock UI       │"
        $FBINK -y 48 -pm "└────────────────────────────────────┘"
        
        # ═══════════════════════════════════════════════════
        # BOTTOM TOOLBAR - SAME AS MAIN MENU (lines 51-54)
        # ═══════════════════════════════════════════════════
        $FBINK -y 51 -pm "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        $FBINK -y 52 -pm "┌───────┬───────┬───────┬───────┬──────┐"
        $FBINK -y 53 -pm "│[LIGHT]│[WIFI ]│[REFRH]│[BOOT ]│[BACK]│"
        $FBINK -y 54 -pm "└───────┴───────┴───────┴───────┴──────┘"
        
        # Get touch input
        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)
        X=$(echo "$COORDS" | cut -d',' -f1)
        Y=$(echo "$COORDS" | cut -d',' -f2)
        
        # ═══════════════════════════════════════════════════
        # USE EXACT SAME COORDINATE DETECTION AS MAIN MENU
        # ═══════════════════════════════════════════════════
        BUTTON=$(get_button_from_coords "$X" "$Y")
        
        # Handle toolbar buttons (same as main menu)
        case "$BUTTON" in
            toolbar_light)
                toggle_frontlight
                continue
                ;;
            toolbar_wifi)
                toggle_wifi
                continue
                ;;
            toolbar_refresh)
                # Refresh display
                continue
                ;;
            toolbar_reboot)
                reboot_system
                ;;
            toolbar_poweroff)
                # Change last toolbar button to "Back" in settings
                # So toolbar_poweroff becomes "Back to main menu"
                return
                ;;
        esac
        
        # Handle main buttons (mapped to settings actions)
        case "$BUTTON" in
            1)
                # Button 1: Frontlight Slider
                # CALIBRATED: Oct 27, 2025 16:22:10 AST
                # Precise slider boundaries from 2-point calibration
                # Start: X=256, End: X=649, Width: 393px
                if [ -n "$FL_PATH" ] && [ -f "$FL_PATH" ]; then
                    # Calculate brightness from X position
                    # X range: 256-649 (393px), map to 0-1200
                    X_OFFSET=$((X - 256))
                    if [ $X_OFFSET -lt 0 ]; then X_OFFSET=0; fi
                    if [ $X_OFFSET -gt 393 ]; then X_OFFSET=393; fi
                    
                    # Calculate brightness (0-1200)
                    NEW_BRIGHT=$((X_OFFSET * 1200 / 393))
                    if [ $NEW_BRIGHT -lt 0 ]; then NEW_BRIGHT=0; fi
                    if [ $NEW_BRIGHT -gt 1200 ]; then NEW_BRIGHT=1200; fi
                    
                    # Set new brightness
                    echo "$NEW_BRIGHT" > "$FL_PATH" 2>/dev/null
                fi
                sleep 0.2
                ;;
            2)
                /mnt/us/extensions/openReader/bin/display-clock.sh
                CURRENT_SELECTION=""
                ;;

            3)
                # Button 2: Open Network Manager
                show_network_manager
                ;;
            4)
                # Button 3: Boot to KindleOS Once / Reboot
                if [ "$OPENREADER_BOOT_MODE" = "1" ]; then
                    # Boot mode: Set flag and reboot to KindleOS once
                    $FBINK -c
                    $FBINK -y 10 -pmh "⚠️  BOOTING TO KINDLEOS"
                    $FBINK -y 12 -pm "Next boot will use Amazon UI"
                    $FBINK -y 13 -pm "After that, OpenReader will resume"
                    sleep 2
                    
                    # Kill the framework keeper
                    KEEPER_PID=$(cat /var/tmp/openreader-keeper.pid 2>/dev/null)
                    [ -n "$KEEPER_PID" ] && kill "$KEEPER_PID" 2>/dev/null
                    
                    # Create persistent one-time boot override.
                    # /var/tmp is erased by reboot on the K5.
                    mkdir -p /mnt/us/.openreader
                    touch /mnt/us/.openreader/boot-kindleos-once
                    sync
                    
                    # Reboot
                    /sbin/reboot -f
                else
                    # Normal mode: Regular reboot
                    $FBINK -c
                    $FBINK -y 12 -pmh "⚠️  REBOOTING..."
                    sleep 2
                    restore_services
                    /sbin/reboot -f
                fi
                ;;
            5)
                # Button 4: Power Off
                $FBINK -c
                $FBINK -y 12 -pmh "⚠️  POWERING OFF..."
                sleep 2
                restore_services
                /sbin/poweroff -f
                ;;
            5)
                # Button 5: Exit to Kindle OS
                restore_services
                exit 0
                ;;
            unknown)
                # Invalid touch
                ;;
        esac
        
        sleep 0.2
    done
}

# Launch KOReader (no framework version)
launch_koreader() {
    if [ ! -f "/mnt/us/koreader/koreader.sh" ]; then
        $FBINK -c
        $FBINK -y 10 -pmh "KOReader not installed!"
        $FBINK -y 12 -pm "Touch anywhere to return..."
        "$TOUCH_READER" /dev/input/event3 2>/dev/null >/dev/null
        return
    fi

    # Stop any pending OpenReader touch reader before KOReader takes input.
    killall -TERM touch_reader 2>/dev/null

    # Tell the framework keeper not to interfere while KOReader is active.
    touch /var/tmp/koreader-pause-keeper

    echo "KOREADER" > /var/tmp/openreader-state

    $FBINK -c
    $FBINK -y 12 -pmh "Launching KOReader..."
    sleep 1

    # Run KOReader synchronously.
    # Do NOT use --framework_stop: OpenReader already owns framework state.
    cd /mnt/us/koreader || {
        rm -f /var/tmp/koreader-pause-keeper
        echo "RUNNING" > /var/tmp/openreader-state
        return
    }

    # OpenReader owns the Amazon/Upstart service state.
    # KOReader must not start or stop Amazon jobs while running under
    # persistent OpenReader boot.
    SHIM_DIR="/var/tmp/openreader-koreader-shims"
    rm -rf "$SHIM_DIR"
    mkdir -p "$SHIM_DIR"

    cat > "$SHIM_DIR/start" << 'SHIM_EOF'
#!/bin/sh
exit 0
SHIM_EOF

    cat > "$SHIM_DIR/stop" << 'SHIM_EOF'
#!/bin/sh
exit 0
SHIM_EOF

    chmod 755 "$SHIM_DIR/start" "$SHIM_DIR/stop"

    OLD_PATH="$PATH"
    export PATH="$SHIM_DIR:$PATH"

    # Tell KOReader the framework is intentionally unavailable.
    # The start/stop shims prevent its wrapper from actually changing
    # OpenReader's service state.
    ./koreader.sh --framework_stop
    KO_RC=$?

    PATH="$OLD_PATH"
    export PATH
    rm -rf "$SHIM_DIR"

    # KOReader may have restarted some Upstart jobs during its normal cleanup.
    # Reassert OpenReader's Amazon-free service state.
    stop lab126_gui 2>/dev/null || true
    stop framework 2>/dev/null || true
    stop pillow 2>/dev/null || true
    stop blanket 2>/dev/null || true
    stop cmd 2>/dev/null || true
    stop phd 2>/dev/null || true
    stop pmond 2>/dev/null || true
    stop tmd 2>/dev/null || true
    stop webreader 2>/dev/null || true
    stop kfxreader 2>/dev/null || true

    killall -STOP cvm 2>/dev/null || true
    killall -STOP lipc-wait-event 2>/dev/null || true
    killall -STOP framework 2>/dev/null || true
    killall -STOP pillow 2>/dev/null || true

    lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null

    rm -f /var/tmp/koreader-pause-keeper
    echo "RUNNING" > /var/tmp/openreader-state

    # Force a clean repaint before returning to the main loop.
    $FBINK -c 2>/dev/null
    $FBINK -f 2>/dev/null

    cd "$SCRIPT_DIR" 2>/dev/null || true

    return $KO_RC
}

# TOOLBAR BUTTON HANDLERS

# Toggle frontlight (with memory)
toggle_frontlight() {
    if [ -z "$FL_PATH" ]; then
        $FBINK -c
        $FBINK -y 15 -pmh "Frontlight not detected!"
        sleep 1
        return
    fi
    
    CURRENT=$(cat "$FL_PATH" 2>/dev/null || echo "0")
    
    if [ "$CURRENT" -eq 0 ]; then
        # Turn ON - restore last level
        echo "$FRONTLIGHT_LAST_LEVEL" > "$FL_PATH" 2>/dev/null
        FRONTLIGHT_ENABLED=1
    else
        # Turn OFF - remember current level
        FRONTLIGHT_LAST_LEVEL=$CURRENT
        echo 0 > "$FL_PATH" 2>/dev/null
        FRONTLIGHT_ENABLED=0
    fi
}

# Toggle WiFi
toggle_wifi() {
    if ! command -v lipc-get-prop >/dev/null 2>&1; then
        return
    fi
    
    if lipc-get-prop com.lab126.wifid cmState 2>/dev/null | grep -q CONNECTED; then
        lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null
    else
        lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
    fi
}

# Network Manager UI (EXACT UI MATCH for coordinate reuse)
show_network_manager() {

    while true; do
        $FBINK -c
        
        # ═══════════════════════════════════════════════════
        # BANNER - Same as main menu (lines 5-16)
        # ═══════════════════════════════════════════════════
        $FBINK -y 5 -pm "██████╗ ██████╗ ███████╗███╗   ██╗"
        $FBINK -y 6 -pm "██╔═══██╗██╔══██╗██╔════╝████╗  ██║"
        $FBINK -y 7 -pm "██║   ██║██████╔╝█████╗  ██╔██╗ ██║"
        $FBINK -y 8 -pm "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║"
        $FBINK -y 9 -pm "╚██████╔╝██║     ███████╗██║ ╚████║"
        $FBINK -y 10 -pm " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝"
        $FBINK -y 11 -pm "██████╗ ███████╗ █████╗ ██████╗"
        $FBINK -y 12 -pm "██╔══██╗██╔════╝██╔══██╗██╔══██╗"
        $FBINK -y 13 -pm "██████╔╝█████╗  ███████║██║  ██║"
        $FBINK -y 14 -pm "██╔══██╗██╔══╝  ██╔══██║██║  ██║"
        $FBINK -y 15 -pm "██║  ██║███████╗██║  ██║██████╔╝"
        $FBINK -y 16 -pm "╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝"
        
        $FBINK -y 18 -pm ""
        $FBINK -y 19 -pm "           Network Manager"
        
        # ═══════════════════════════════════════════════════
        # GET NETWORK STATUS
        # ═══════════════════════════════════════════════════
        
        # Get current connection info
        WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null || echo "UNKNOWN")
        WIFI_ENABLED=$(lipc-get-prop com.lab126.wifid enable 2>/dev/null || echo "0")
        
        if [ "$WIFI_STATE" = "CONNECTED" ]; then
            CURRENT_SSID=$(lipc-get-prop com.lab126.wifid currentEssid 2>/dev/null || echo "Unknown")
            SIGNAL=$(lipc-get-prop com.lab126.wifid signalStrength 2>/dev/null || echo "0/5")
            WIFI_STATUS="Connected: $CURRENT_SSID ($SIGNAL)"
        elif [ "$WIFI_ENABLED" = "1" ]; then
            WIFI_STATUS="WiFi On - Not Connected"
        else
            WIFI_STATUS="WiFi Disabled"
        fi
        
        # ═══════════════════════════════════════════════════
        # NETWORK BUTTONS - EXACT SAME LINES AS MAIN MENU
        # ═══════════════════════════════════════════════════
        
        # Button 1: Current Status (lines 21-24)
        # No box - just display status as text
        $FBINK -y 21 -pm ""
        $FBINK -y 22 -pmh "   CURRENT STATUS:"
        $FBINK -y 23 -pm "   $WIFI_STATUS"
        $FBINK -y 24 -pm ""
        
        # Button 2: Enable/Disable WiFi (lines 27-30)
        # Static text that doesn't change based on state
        $FBINK -y 27 -pm "┌────────────────────────────────────┐"
        $FBINK -y 28 -pm "│  [POWER] TOGGLE WI-FI                │"
        $FBINK -y 29 -pm "│          Enable / Disable Radio      │"
        $FBINK -y 30 -pm "└────────────────────────────────────┘"
        
        # Button 3: Scan Networks (lines 33-36)
        $FBINK -y 33 -pm "┌────────────────────────────────────┐"
        $FBINK -y 34 -pm "│  [SCAN]  SCAN FOR NETWORKS           │"
        $FBINK -y 35 -pm "│          Refresh WiFi List           │"
        $FBINK -y 36 -pm "└────────────────────────────────────┘"
        
        # Button 4: Reconnect (lines 39-42)
        $FBINK -y 39 -pm "┌────────────────────────────────────┐"
        $FBINK -y 40 -pm "│  [LINK]  RECONNECT                   │"
        $FBINK -y 41 -pm "│          Reconnect to Last Network   │"
        $FBINK -y 42 -pm "└────────────────────────────────────┘"
        
        # Button 5: Back to Settings (lines 45-48)
        $FBINK -y 45 -pm "┌────────────────────────────────────┐"
        $FBINK -y 46 -pm "│  [BACK]  BACK TO SETTINGS            │"
        $FBINK -y 47 -pm "│          Return to Settings Menu     │"
        $FBINK -y 48 -pm "└────────────────────────────────────┘"
        
        # ═══════════════════════════════════════════════════
        # BOTTOM TOOLBAR - SAME AS MAIN MENU (lines 51-54)
        # ═══════════════════════════════════════════════════
        $FBINK -y 51 -pm "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        $FBINK -y 52 -pm "┌───────┬───────┬───────┬───────┬──────┐"
        $FBINK -y 53 -pm "│[LIGHT]│[WIFI ]│[REFRH]│[BOOT ]│[BACK]│"
        $FBINK -y 54 -pm "└───────┴───────┴───────┴───────┴──────┘"
        
        # Get touch input
        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)
        X=$(echo "$COORDS" | cut -d',' -f1)
        Y=$(echo "$COORDS" | cut -d',' -f2)
        
        # Use same coordinate detection as main menu
        BUTTON=$(get_button_from_coords "$X" "$Y")
        
        # Handle toolbar buttons
        case "$BUTTON" in
            toolbar_light)
                toggle_frontlight
                continue
                ;;
            toolbar_wifi)
                toggle_wifi
                sleep 1
                continue
                ;;
            toolbar_refresh)
                # Refresh the network manager display
                continue
                ;;
            toolbar_reboot)
                reboot_system
                ;;
            toolbar_poweroff)
                # Back button in toolbar - return to settings
                return
                ;;
        esac
        
        # Handle main buttons
        case "$BUTTON" in
            1)
                # Button 1: Current Status - just refresh
                continue
                ;;
            2)
                /mnt/us/extensions/openReader/bin/display-clock.sh
                CURRENT_SELECTION=""
                ;;

            3)
                # Button 2: Enable/Disable WiFi
                toggle_wifi
                sleep 1
                ;;
            4)
                # Button 3: Scan for Networks
                $FBINK -c
                $FBINK -y 15 -pmh "Scanning for networks..."
                $FBINK -y 16 -pm "This may take a few seconds..."
                
                # Trigger scan
                lipc-set-prop com.lab126.wifid scan "" 2>/dev/null
                
                # Wait for scan to complete
                sleep 3
                
                $FBINK -y 18 -pm "Scan complete! Refreshing..."
                sleep 1
                ;;
            5)
                # Button 4: Reconnect
                if [ "$WIFI_ENABLED" = "1" ]; then
                    $FBINK -c
                    $FBINK -y 15 -pmh "Reconnecting..."
                    
                    # Try to reconnect to last network
                    if [ -n "$CURRENT_SSID" ] && [ "$CURRENT_SSID" != "Unknown" ]; then
                        lipc-set-prop com.lab126.cmd ensureConnection "wifi:$CURRENT_SSID" 2>/dev/null
                    fi
                    
                    sleep 2
                else
                    $FBINK -c
                    $FBINK -y 15 -pmh "WiFi is disabled!"
                    $FBINK -y 16 -pm "Enable WiFi first"
                    sleep 2
                fi
                ;;
            5)
                # Button 5: Back to Settings
                return
                ;;
            unknown)
                # Invalid touch
                ;;
        esac
        
        sleep 0.2
    done
}

# Open terminal
open_terminal() {
    # Find kterm
    KTERM="/mnt/us/extensions/kterm/bin/kterm.sh"
    if [ ! -f "$KTERM" ]; then
        $FBINK -c
        $FBINK -y 15 -pmh "kterm not found!"
        sleep 1
        return
    fi
    
    # Kill touch reader first
    killall -9 touch_reader 2>/dev/null
    
    # Signal watchdog NOT to restart (intentional exit for kterm)
    echo "KTERM" > /var/tmp/openreader-state
    
    # Show launching message
    $FBINK -c
    $FBINK -y 12 -pmh "Launching Terminal..."
    sleep 1
    
    # Create launcher script
    cat > /var/tmp/launch-kterm.sh << 'KTERM_EOF'
#!/bin/sh
# Wait for OpenReader to fully exit
sleep 3

# Launch kterm
/mnt/us/extensions/kterm/bin/kterm.sh

# When kterm exits, signal restart
echo "RESTART" > /var/tmp/openreader-state

# Clean up
rm -f /var/tmp/launch-kterm.sh
KTERM_EOF
    
    chmod +x /var/tmp/launch-kterm.sh
    
    # Launch detached
    /var/tmp/launch-kterm.sh </dev/null >/dev/null 2>&1 &
    
    # Exit launcher immediately
    exit 0
}

# Show settings (full settings menu)
show_settings_toolbar() {
    show_settings
}

# Confirmation dialog: boot stock KindleOS once
confirm_boot_kindleos_once() {
    echo "CONFIRM" > /var/tmp/openreader-screen
    $FBINK -c

    $FBINK -x 2 -y 3 -h "BOOT KINDLEOS ONCE?"
    $FBINK -x 2 -y 5 "──────────────────────────────────"

    $FBINK -x 2 -y 10 "Exit OpenReader runtime?"
    $FBINK -x 2 -y 14 "The Amazon interface will return."
    $FBINK -x 2 -y 18 "Cancel returns to OpenReader."

    $FBINK -x 2 -y 40 "──────────────────────────────────"
    $FBINK -x 2 -y 43 -h "Cancel"
    $FBINK -x 22 -y 43 -h "Boot KindleOS"

    while true; do
        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)
        [ -z "$COORDS" ] && continue

        RAW_X=$(echo "$COORDS" | cut -d',' -f1)
        RAW_Y=$(echo "$COORDS" | cut -d',' -f2)

        X=$((RAW_X * 600 / 4095))
        Y=$((RAW_Y * 800 / 4095))

        if [ "$Y" -ge 690 ]; then
            if [ "$X" -lt 300 ]; then
                $FBINK -x 2 -y 43 -h "Cancel"
                sleep 0.5
                return
            else
                $FBINK -x 22 -y 43 -h "Boot KindleOS"
                sleep 0.5
                boot_kindleos_once
                return
            fi
        fi
    done
}


# Confirmation dialog: reboot OpenReader
confirm_reboot() {
    echo "CONFIRM" > /var/tmp/openreader-screen
    $FBINK -c

    $FBINK -x 2 -y 3 -h "REBOOT TO OPENREADER?"
    $FBINK -x 2 -y 5 "──────────────────────────────────"

    $FBINK -x 2 -y 10 "Restart the Kindle now?"
    $FBINK -x 2 -y 14 "OpenReader should start again."
    $FBINK -x 2 -y 18 "Cancel returns to OpenReader."

    $FBINK -x 2 -y 40 "──────────────────────────────────"
    $FBINK -x 2 -y 43 -h "Cancel"
    $FBINK -x 28 -y 43 -h "Reboot"

    while true; do
        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)
        [ -z "$COORDS" ] && continue

        RAW_X=$(echo "$COORDS" | cut -d',' -f1)
        RAW_Y=$(echo "$COORDS" | cut -d',' -f2)

        X=$((RAW_X * 600 / 4095))
        Y=$((RAW_Y * 800 / 4095))

        if [ "$Y" -ge 690 ]; then
            if [ "$X" -lt 300 ]; then
                $FBINK -x 2 -y 43 -h "Cancel"
                sleep 0.5
                return
            else
                $FBINK -x 28 -y 43 -h "Reboot"
                sleep 0.5
                reboot_system
                return
            fi
        fi
    done
}


# Confirmation dialog: power off
confirm_poweroff() {
    echo "CONFIRM" > /var/tmp/openreader-screen
    $FBINK -c

    $FBINK -x 2 -y 3 -h "POWER OFF?"
    $FBINK -x 2 -y 5 "──────────────────────────────────"

    $FBINK -x 2 -y 10 "Turn the Kindle completely off?"
    $FBINK -x 2 -y 14 "Press power to start it again."
    $FBINK -x 2 -y 18 "Cancel returns to OpenReader."

    $FBINK -x 2 -y 40 "──────────────────────────────────"
    $FBINK -x 2 -y 43 -h "Cancel"
    $FBINK -x 25 -y 43 -h "Power Off"

    while true; do
        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)
        [ -z "$COORDS" ] && continue

        RAW_X=$(echo "$COORDS" | cut -d',' -f1)
        RAW_Y=$(echo "$COORDS" | cut -d',' -f2)

        X=$((RAW_X * 600 / 4095))
        Y=$((RAW_Y * 800 / 4095))

        if [ "$Y" -ge 690 ]; then
            if [ "$X" -lt 300 ]; then
                $FBINK -x 2 -y 43 -h "Cancel"
                sleep 0.5
                return
            else
                $FBINK -x 25 -y 43 -h "Power Off"
                sleep 0.5
                poweroff_system
                return
            fi
        fi
    done
}


# Boot stock KindleOS for one boot only
boot_kindleos_once() {
    $FBINK -c
    $FBINK -x 2 -y 13 -h "Booting KindleOS once..."
    $FBINK -x 2 -y 15 "OpenReader returns next reboot."

    echo "KINDLEOS" > /var/tmp/openreader-state

    /mnt/us/extensions/openReader/bin/timekeeper.sh checkpoint 2>/dev/null || true

    rm -f /mnt/us/BOOT_KINDLEOS.used
    touch /mnt/us/BOOT_KINDLEOS

    trap - INT TERM EXIT

    sync
    sleep 1
    /sbin/reboot -f
}

# Reboot system
reboot_system() {
    $FBINK -c
    $FBINK -x 2 -y 15 -h "Rebooting..."

    echo "REBOOT" > /var/tmp/openreader-state

    /mnt/us/extensions/openReader/bin/timekeeper.sh checkpoint 2>/dev/null || true
    trap - INT TERM EXIT

    sync
    sleep 1
    /sbin/reboot -f
}

# Power off system
poweroff_system() {
    $FBINK -c

    $FBINK -x 2 -y 5 -h "OPENREADER-K5"

    $FBINK -x 6 -y 15 "        /\\ /\\"
    $FBINK -x 6 -y 17 " Zzz...(-.- )____   Zzz..."
    $FBINK -x 6 -y 19 "       (_________)~"
    $FBINK -x 6 -y 21 "~~~~~~~~~~~~~~~~~~~~~~~~~~"

    $FBINK -x 2 -y 34 -h "Press power to wake"

    echo "POWEROFF" > /var/tmp/openreader-state

    /mnt/us/extensions/openReader/bin/timekeeper.sh checkpoint 2>/dev/null || true
    trap - INT TERM EXIT

    sync
    sleep 1
    /sbin/poweroff -f
}

# Show a short USB mode result/status page.
show_usb_result() {
    HEADING="$1"
    LINE_ONE="$2"
    LINE_TWO="$3"

    $FBINK -c

    $FBINK -x 2 -y 3 -h "$HEADING"
    $FBINK -x 2 -y 5 "──────────────────────────────────"

    $FBINK -x 2 -y 12 "$LINE_ONE"

    if [ -n "$LINE_TWO" ]; then
        $FBINK -x 2 -y 16 "$LINE_TWO"
    fi

    $FBINK -x 2 -y 34 "Returning to OpenReader..."

    sleep 5
}


# Force USB Network mode without accidentally toggling it off.
enable_usb_network() {
    USBNETWORK="/mnt/us/usbnet/bin/usbnetwork"

    if lsmod | grep -q '^g_ether ' ; then
        show_usb_result \
            "NETWORK ACTIVE" \
            "USBNetwork is already enabled." \
            "SSH remains available."
        return
    fi

    if [ ! -f "$USBNETWORK" ]; then
        show_usb_result \
            "NETWORK UNAVAILABLE" \
            "USBNetwork script was not found." \
            "No USB mode change was made."
        return
    fi

    $FBINK -c
    $FBINK -x 2 -y 3 -h "ENABLING USB NETWORK"
    $FBINK -x 2 -y 5 "──────────────────────────────────"
    $FBINK -x 2 -y 14 "Connect the USB cable for SSH."

    chmod +x "$USBNETWORK" 2>/dev/null
    "$USBNETWORK"

    sleep 2

    if lsmod | grep -q '^g_ether ' ; then
        show_usb_result \
            "NETWORK ENABLED" \
            "USB Ethernet is active." \
            "Connect the cable to use SSH."
    else
        show_usb_result \
            "NETWORK FAILED" \
            "USB Ethernet did not become active." \
            "No further change was attempted."
    fi
}


# Force USB Mass Storage mode without accidentally enabling USBNetwork.
enable_usb_storage() {
    USBNETWORK="/mnt/us/usbnet/bin/usbnetwork"

    if ! lsmod | grep -q '^g_ether ' ; then
        show_usb_result \
            "STORAGE MODE" \
            "USBNetwork is already inactive." \
            "Reconnect or unplug as needed."
        return
    fi

    if [ ! -f "$USBNETWORK" ]; then
        show_usb_result \
            "STORAGE UNAVAILABLE" \
            "USBNetwork script was not found." \
            "No USB mode change was made."
        return
    fi

    $FBINK -c

    $FBINK -x 2 -y 3 -h "USB STORAGE"
    $FBINK -x 2 -y 5 "──────────────────────────────────"

    $FBINK -x 2 -y 11 "SSH will disconnect."
    $FBINK -x 2 -y 15 "Safely eject on the computer,"
    $FBINK -x 2 -y 18 "then unplug the USB cable."

    $FBINK -x 2 -y 34 "OpenReader will return automatically."

    sync
    chmod +x "$USBNETWORK" 2>/dev/null
    "$USBNETWORK" usbms

    # USB mass-storage mode may temporarily remove /mnt/us.
    # Use only root-filesystem commands until userstore returns.
    while ! awk '$2 == "/mnt/us" { found=1 } END { exit !found }' \
              /proc/mounts 2>/dev/null; do
        sleep 2
    done

    sleep 2

    if lsmod | grep -q '^g_ether ' ; then
        show_usb_result \
            "STORAGE FAILED" \
            "USB mass storage did not activate." \
            "USBNetwork remains enabled."
    else
        show_usb_result \
            "STORAGE EJECTED" \
            "User storage is available again." \
            "Tap Net to restore USB networking."
    fi
}


# Main loop
main() {
    stop_services
    get_screen_size

    # Old Kindle firmware can restore stale wall-clock time automatically.
    lipc-set-prop com.lab126.system disableTimeAutoUpdate x 2>/dev/null || true

    # Maintain the top-right launcher clock without full-screen redraws.
    /usr/bin/setsid /mnt/us/extensions/openReader/bin/clock-updater.sh </dev/null >/dev/null 2>&1 &

    CURRENT_SELECTION=""

    # Do not restore services during intentional KOReader/KTerm handoff.
    trap 'STATE=$(cat /var/tmp/openreader-state 2>/dev/null); case "$STATE" in KOREADER|KTERM) ;; *) restore_services ;; esac' INT TERM EXIT

    # Clear any final boot-animation text written after OpenReader starts.
    (
        sleep 3
        /mnt/us/extensions/openReader/bin/redraw-openreader.sh
    ) &


    while true; do
        echo "MAIN" > /var/tmp/openreader-screen
        draw_menu "$CURRENT_SELECTION"


        COORDS=$("$TOUCH_READER" /dev/input/event3 2>/dev/null)

        if [ -z "$COORDS" ]; then
            continue
        fi

        X=$(echo "$COORDS" | cut -d',' -f1)
        Y=$(echo "$COORDS" | cut -d',' -f2)

        BUTTON=$(get_button_from_coords "$X" "$Y")

        # Toolbar buttons: 0.5 second feedback.
        case "$BUTTON" in
            toolbar_refresh)
                draw_menu "toolbar_refresh"
                sleep 0.5
                CURRENT_SELECTION=""
                continue
                ;;

            toolbar_usbnet)
                draw_menu "toolbar_usbnet"
                sleep 0.5
                enable_usb_network
                CURRENT_SELECTION=""
                continue
                ;;

            toolbar_usbstorage)
                draw_menu "toolbar_usbstorage"
                sleep 0.5
                enable_usb_storage
                CURRENT_SELECTION=""
                continue
                ;;

            toolbar_poweroff)
                draw_menu "toolbar_poweroff"
                sleep 0.5
                confirm_poweroff
                CURRENT_SELECTION=""
                continue
                ;;
        esac

        # Main menu buttons: 1 second feedback.
        case "$BUTTON" in
            1|2|3|4|5)
                CURRENT_SELECTION="$BUTTON"
                draw_menu "$CURRENT_SELECTION"
                sleep 1
                ;;
        esac

        case "$BUTTON" in
            1)
                launch_koreader
                ;;

            2)
                /mnt/us/extensions/openReader/bin/display-clock.sh
                CURRENT_SELECTION=""
                ;;

            3)
                show_system_info
                CURRENT_SELECTION=""
                ;;

            4)
                confirm_boot_kindleos_once
                CURRENT_SELECTION=""
                ;;

            5)
                confirm_reboot
                CURRENT_SELECTION=""
                ;;

            unknown)
                CURRENT_SELECTION=""
                ;;
        esac
    done
}

main
