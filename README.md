#  Vortex Shell

A dynamic OLED top-bar island and system command center built with **Quickshell (Qt6/QML)** for **Wayland & Hyprland**.

##  Key Features

- **Vortex Core (Telemetry & Power):**
  - Real-time CPU & GPU usage, thermals, storage (`/`), and RAM monitoring.
  - **ASUS ROG / Power Profile switcher** (*Quiet / Balanced / Performance*).
  - **Native Battery Charge Limit toggle** (`60% / 80% / 100%`) directly from the battery card.
- **Net & Sec Module:**
  - Live local `LISTEN` ports counter (`ss -tuln`).
  - **1-Click Tailscale / VPN Manager:** View tunnel status, copy private VPN IP with left-click, or toggle the tunnel ON/OFF directly.
- **Media Player & Live Spectrum:**
  - 15-bar reactive audio spectrum visualizer + compact 5-bar island equalizer (`PipeWire / ALSA / Cava`).
  - Synced LRC lyrics viewer (`LRCLIB`) and floating **Pill Bar** lyrics mode.
- **Weather Forecast:**
  - Current conditions, humidity, wind, sunrise/sunset, and 7-day forecast.
- **Bento File Shelf & Smart Clipboard:**
  - Drag-and-drop file shelf with quick system folder launchers.
  - **Smart Clipboard Actions:** Auto-detects IPs/domains (`Ping`), Base64 strings (`Decode`), and hashes (`MD5/SHA`), plus an **Incognito Mode** to pause clipboard logging.
- **Todo List, Agenda & Focus Timer:**
  - Scheduled reminders with critical desktop notifications and integrated **Pomodoro Timer**.
- **Touchpad Gesture Navigation & IPC CLI (`vortex-ctl`):**
  - Two-finger horizontal/vertical touchpad swipe to cycle smoothly across all 6 tabs.
  - Control Vortex from terminal or Hyprland keybinds via `vortex-ctl`.

## Installation

```bash
git clone [https://github.com/enmanuelvalle23-hub/Vortex-dynamic-island.git](https://github.com/enmanuelvalle23-hub/Vortex-dynamic-island.git) ~/.config/quickshell/vortex
cd ~/.config/quickshell/vortex
./install.sh
cd ~/.config/quickshell/vortex

# 1. Guardar una copia del CLI vortex-ctl dentro del repositorio para que se suba también
mkdir -p bin
cp ~/.local/bin/vortex-ctl bin/vortex-ctl
chmod +x bin/vortex-ctl

# 2. Reemplazar rutas fijas '/home/valle' en QML por Quickshell.env("HOME") para que sea universal
sed -i 's|"/home/valle/|Quickshell.env("HOME") + "/|g' shell.qml Vortex/*.qml 2>/dev/null || true
sed -i 's|file:///home/valle/|"file://" + Quickshell.env("HOME") + "/|g' Vortex/*.qml 2>/dev/null || true

# 3. Crear archivo .gitignore para no subir archivos temporales ni copias .bak
cat > .gitignore << 'EOF'
*.bak
*.log
*.pyc
__pycache__/
.DS_Store
