#!/usr/bin/env bash
set -e

echo "⚡ Installing Vortex Shell for Quickshell (Wayland/Hyprland)..."
mkdir -p ~/.config/quickshell/vortex
mkdir -p ~/.local/share/vortex-linux
mkdir -p ~/.cache/vortex-linux/lyrics
mkdir -p ~/.local/bin

if [ "$(pwd)" != "$HOME/.config/quickshell/vortex" ]; then
    cp -rf ./* ~/.config/quickshell/vortex/
fi

cp -f ~/.config/quickshell/vortex/bin/vortex-ctl ~/.local/bin/vortex-ctl
chmod +x ~/.local/bin/vortex-ctl
chmod +x ~/.config/quickshell/vortex/launch.sh
chmod +x ~/.config/quickshell/vortex/scripts/*.sh

echo "✓ Vortex installed! Run '~/.config/quickshell/vortex/launch.sh' or 'vortex-ctl restart' to launch."
