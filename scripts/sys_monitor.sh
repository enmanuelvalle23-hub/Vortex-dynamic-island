#!/usr/bin/env bash
nmcli monitor 2>/dev/null | while read -r line; do
  echo "$line" | grep -qE "connected|conectado" && echo "WIFI|Connected|$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2)|100" || echo "WIFI|Disconnected|No network connection|0"
done &
dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null | while read -r line; do
  if echo "$line" | grep -q "Connected"; then
    sleep 1; BTI=$(bluetoothctl info); NAME=$(echo "$BTI" | grep "Alias:" | sed 's/.*Alias: //')
    BAT=$(echo "$BTI" | grep "Battery Percentage:" | sed -E 's/.*\(([0-9]+)\).*/\1/'); echo "BT_CONN|${NAME:-Headphones}|Connected · ${BAT:-85}%|${BAT:-85}"
  fi
done &
command -v wl-paste >/dev/null && wl-paste --type text --watch bash -c 'TXT=$(wl-paste -n | tr "\n\r\t" "   " | sed "s/  */ /g" | head -c 140); [ -n "$TXT" ] && echo "CLIP|$TXT"' 2>/dev/null &
while true; do
  CPUT=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -1)
  [ -n "$CPUT" ] && [ "$CPUT" -gt 1000 ] && CPUT=$((CPUT/1000)) || CPUT="45"
  GPUT=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); [ -z "$GPUT" ] && GPUT=$((CPUT-4))
  RAM=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{if(t>0){u=t-a;printf "%d|%.1fG",int(u*100/t),u/1048576}else{print "28|11.2G"}}' /proc/meminfo)
  BRP=75; CUR=$(brightnessctl g 2>/dev/null); MAX=$(brightnessctl m 2>/dev/null); [ -n "$CUR" ] && [ -n "$MAX" ] && [ "$MAX" -gt 0 ] && BRP=$((CUR*100/MAX))
  PROF="Balanced"; P=$(asusctl profile -p 2>/dev/null | awk '{print $NF}'); [ -n "$P" ] && PROF="$P"
  echo "TELEMETRY|${CPUT}|${GPUT}|${BRP}|${PROF}|${RAM}"
  sleep 3
done
