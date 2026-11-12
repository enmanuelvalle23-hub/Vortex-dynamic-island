#!/bin/bash
# sys_helper.sh - Lightweight system event monitor for Nusa notch
# Outputs events to stdout in format: TYPE:value1:value2:...
# Uses inotifywait for zero-CPU polling of brightness and CapsLock
# Uses dbus-monitor for Bluetooth events

set -euo pipefail

# Paths (auto-detect)
BACKLIGHT_PATH="/sys/class/backlight"
CAPSLOCK_PATH="/sys/class/leds"

# Find actual paths
find_backlight() {
    for dir in "$BACKLIGHT_PATH"/*/; do
        if [[ -f "${dir}brightness" && -f "${dir}max_brightness" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

find_capslock() {
    for dir in "$CAPSLOCK_PATH"/*/; do
        if [[ -f "${dir}brightness" ]] && grep -qi "capslock\|kbd::capslock" "${dir}device/name" 2>/dev/null || \
           [[ "${dir}" == *capslock* ]]; then
            echo "$dir"
            return 0
        fi
    done
    # Fallback: any LED with brightness
    for dir in "$CAPSLOCK_PATH"/*/; do
        if [[ -f "${dir}brightness" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

BACKLIGHT_DIR=$(find_backlight)
CAPSLOCK_DIR=$(find_capslock)

# Read initial values
read_brightness() {
    if [[ -n "$BACKLIGHT_DIR" && -f "${BACKLIGHT_DIR}brightness" ]]; then
        local current max
        current=$(cat "${BACKLIGHT_DIR}brightness")
        max=$(cat "${BACKLIGHT_DIR}max_brightness")
        echo $(( current * 100 / max ))
    fi
}

read_capslock() {
    if [[ -n "$CAPSLOCK_DIR" && -f "${CAPSLOCK_DIR}brightness" ]]; then
        cat "${CAPSLOCK_DIR}brightness"
    fi
}

# Output event to stdout (consumed by QML Process)
output_event() {
    echo "$1"
}

# Monitor brightness
monitor_brightness() {
    if [[ -z "$BACKLIGHT_DIR" ]]; then
        echo "No backlight device found" >&2
        return
    fi
    echo "Monitoring brightness: $BACKLIGHT_DIR" >&2
    inotifywait -m -e modify "${BACKLIGHT_DIR}brightness" --format '%f' 2>/dev/null | while read -r; do
        local pct=$(read_brightness)
        output_event "BRIGHTNESS:$pct"
    done
}

# Monitor capslock
monitor_capslock() {
    if [[ -z "$CAPSLOCK_DIR" ]]; then
        echo "No capslock LED found" >&2
        return
    fi
    echo "Monitoring capslock: $CAPSLOCK_DIR" >&2
    local last_state=""
    inotifywait -m -e modify "${CAPSLOCK_DIR}brightness" --format '%f' 2>/dev/null | while read -r; do
        local state=$(read_capslock)
        if [[ "$state" != "$last_state" ]]; then
            last_state="$state"
            if [[ "$state" == "1" ]]; then
                output_event "CAPSLOCK:ON"
            else
                output_event "CAPSLOCK:OFF"
            fi
        fi
    done
}

# Monitor Bluetooth (using dbus-monitor for BlueZ)
monitor_bluetooth() {
    echo "Monitoring Bluetooth..." >&2
    # Monitor BlueZ device property changes
    dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null | while read -r line; do
        if [[ "$line" == *"Connected"* ]]; then
            # Extract device path from the signal
            local device_path=""
            if [[ "$line" == *"object path"* ]]; then
                device_path=$(echo "$line" | grep -o '/org/bluez/[^ ]*')
            fi
            if [[ -n "$device_path" ]]; then
                # Get device alias and battery
                local alias=$(dbus-send --system --print-reply --dest=org.bluez "$device_path" org.freedesktop.DBus.Properties.Get string:"org.bluez.Device1" string:"Alias" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
                local battery=$(dbus-send --system --print-reply --dest=org.bluez "$device_path" org.freedesktop.DBus.Properties.Get string:"org.bluez.Device1" string:"BatteryPercentage" 2>/dev/null | grep -o '[0-9]*' | head -1)
                if [[ -z "$alias" ]]; then
                    alias=$(dbus-send --system --print-reply --dest=org.bluez "$device_path" org.freedesktop.DBus.Properties.Get string:"org.bluez.Device1" string:"Name" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
                fi
                if [[ -n "$line" && "$line" == *"true"* ]]; then
                    output_event "BLUETOOTH:CONNECTED:$alias:$battery"
                else
                    output_event "BLUETOOTH:DISCONNECTED:$alias"
                fi
            fi
        fi
    done
}

# Main
echo "Nusa sys_helper starting..." >&2
echo "Backlight: ${BACKLIGHT_DIR:-none}" >&2
echo "CapsLock: ${CAPSLOCK_DIR:-none}" >&2

# Output initial state
if [[ -n "$BACKLIGHT_DIR" ]]; then
    output_event "BRIGHTNESS:$(read_brightness)"
fi
if [[ -n "$CAPSLOCK_DIR" ]]; then
    local caps=$(read_capslock)
    if [[ "$caps" == "1" ]]; then
        output_event "CAPSLOCK:ON"
    else
        output_event "CAPSLOCK:OFF"
    fi
fi

# Run monitors in background
monitor_brightness &
PID_BRIGHT=$!

monitor_capslock &
PID_CAPS=$!

monitor_bluetooth &
PID_BT=$!

# Cleanup on exit
cleanup() {
    kill $PID_BRIGHT $PID_CAPS $PID_BT 2>/dev/null || true
    exit 0
}
trap cleanup INT TERM EXIT

# Wait for children
wait $PID_BRIGHT $PID_CAPS $PID_BT