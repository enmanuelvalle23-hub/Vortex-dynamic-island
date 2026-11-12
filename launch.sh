#!/usr/bin/env bash
pkill -f "quickshell.*/nusa/shell.qml" 2>/dev/null
pkill -f "quickshell.*/vortex/shell.qml" 2>/dev/null
pkill -f "nusa/scripts/audio_spectrum.sh" 2>/dev/null
pkill -f "vortex/scripts/audio_spectrum.sh" 2>/dev/null
sleep 0.25
export QML_IMPORT_PATH="$HOME/.config/quickshell/vortex"
nohup /usr/bin/quickshell -p "$HOME/.config/quickshell/vortex/shell.qml" >/dev/null 2>&1 & disown
