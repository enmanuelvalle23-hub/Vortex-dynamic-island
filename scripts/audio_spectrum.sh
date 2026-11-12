#!/usr/bin/env bash
export LC_ALL=C

is_audio_playing() {
    # 1. Nivel Kernel ALSA (Detecta cualquier tarjeta de sonido o audífono USB/Bluetooth en estado RUNNING)
    if grep -q "RUNNING" /proc/asound/card*/pcm*p/sub*/status 2>/dev/null; then
        return 0
    fi
    # 2. Nivel PipeWire nativo (pw-cli / wpctl)
    if command -v pw-dump >/dev/null 2>&1; then
        if pw-dump 2>/dev/null | grep -q '"state": "running"'; then
            return 0
        fi
    fi
    # 3. Nivel PulseAudio / PipeWire-Pulse
    if pactl list sink-inputs 2>/dev/null | grep -iq "Corked: no"; then
        return 0
    fi
    # 4. Nivel MPRIS (playerctl)
    if command -v playerctl >/dev/null 2>&1; then
        if playerctl status 2>/dev/null | grep -iq "Playing"; then
            return 0
        fi
    fi
    return 1
}

while true; do
    if is_audio_playing; then
        # Generar 6 frames rápidos seguidos (~60 FPS) por cada chequeo positivo para no gastar CPU
        for _ in 1 2 3 4 5 6; do
            b1=$((20 + RANDOM % 75))
            b2=$((30 + RANDOM % 70))
            b3=$((40 + RANDOM % 60))
            b4=$((30 + RANDOM % 70))
            b5=$((20 + RANDOM % 75))
            printf "%d;%d;%d;%d;%d;\n" "$b1" "$b2" "$b3" "$b4" "$b5"
            sleep 0.055
        done
    else
        printf "0;0;0;0;0;\n"
        sleep 0.2
    fi
done
