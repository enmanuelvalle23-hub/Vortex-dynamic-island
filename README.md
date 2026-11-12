# Vortex Dynamic Island

An OLED top-bar dynamic island and system command center built with **Quickshell (Qt6/QML)** for **Wayland & Hyprland**.

## Features

- **Vortex Core (Telemetry & Power):**
  - Real-time CPU & GPU utilization, thermals, disk usage (`/`), and RAM monitoring.
  - **Power Profile Switcher:** Toggle between *Quiet*, *Balanced*, and *Performance* (`asusctl` / `powerprofilesctl`).
  - **Native Battery Charge Limit:** Cycle physical battery charge thresholds (`60%` / `80%` / `100%`) directly from the battery card.
- **Net & Sec Module:**
  - Live local `LISTEN` ports counter (`ss -tuln`).
  - **1-Click Tailscale / VPN Control:** View tunnel status, left-click the IP to copy it to the clipboard, or use the `ON`/`OFF` button to toggle the tunnel.
- **Media Player & Live Audio Spectrum:**
  - 15-bar reactive spectrum visualizer + compact 5-bar island equalizer (`PipeWire` / `ALSA` / `Cava`).
  - Synced `.lrc` lyrics viewer (`LRCLIB`) and floating **Pill Bar** lyrics mode.
- **Weather Forecast:**
  - Current conditions, humidity, wind speed, sunrise/sunset times, and 7-day forecast.
- **Bento File Shelf & Smart Clipboard:**
  - Drag-and-drop file shelf with quick system folder launchers.
  - **Smart Clipboard Actions:** Automatically detects IPs/domains (`Ping`), Base64 strings (`B64`), and hashes (`MD5/SHA`), plus an **🕵 Incognito Mode** to pause clipboard history.
- **Todo List, Agenda & Focus Timer:**
  - Task manager, scheduled agenda events with desktop notifications, and an integrated **Pomodoro Timer**.
- **Touchpad Gestures & CLI (`vortex-ctl`):**
  - Two-finger touchpad swipe (horizontal or vertical) to cycle smoothly across all 6 tabs.
  - Full IPC control via `vortex-ctl` for scripts and Hyprland keybindings.

---

## Dependencies

Install the required packages on Arch Linux:

```bash
sudo pacman -S quickshell wl-clipboard jq curl playerctl libnotify iproute2
```

*(Optional)*: `cava` (for raw audio frequency spectrum), `tailscale` (for VPN module), `asusctl` or `power-profiles-daemon` (for power profiles and battery charge limits).

---

## Installation

### 1. Clone and run the installer

```bash
git clone [https://github.com/enmanuelvalle23-hub/Vortex-dynamic-island.git](https://github.com/enmanuelvalle23-hub/Vortex-dynamic-island.git) ~/.config/quickshell/vortex
cd ~/.config/quickshell/vortex
chmod +x install.sh
./install.sh
```

2. Launch Vortex

```bash
~/.config/quickshell/vortex/launch.sh
```

### 3. Autostart on Hyprland (Optional)

Add the following line to your `~/.config/hypr/hyprland.conf`:

```ini
exec-once = ~/.config/quickshell/vortex/launch.sh
```

> **Note:** Ensure `~/.local/bin` is in your `$PATH` to run `vortex-ctl` from any terminal.

---

## 🛠 CLI Usage (`vortex-ctl`)

Control Vortex directly from the terminal or bind these commands in Hyprland:

```bash
vortex-ctl tab 0                              # Open Vortex on tab 0..5
vortex-ctl alert "Build Ready" "Compiled OK"  # Trigger custom OSD notification
vortex-ctl limit 80                           # Set battery charge limit (60/80/100)
vortex-ctl incognito                          # Toggle clipboard incognito mode
vortex-ctl minimal                            # Toggle minimal bar mode
vortex-ctl restart                            # Restart Vortex
```
