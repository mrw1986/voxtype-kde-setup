#!/bin/bash
# Voxtype KDE Setup - Installer
# Installs the overlay, indicator, and supporting config for voxtype on KDE Plasma 6 Wayland.
set -euo pipefail

SCRIPTS_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SHIMS_DIR="$HOME/.local/lib/voxtype-shims"

echo "=== Voxtype KDE Setup Installer ==="
echo ""

# Check dependencies
echo "Checking dependencies..."
missing=()
command -v voxtype >/dev/null 2>&1 || missing+=("voxtype")
python3 -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Gtk4LayerShell', '1.0')" 2>/dev/null || missing+=("gtk4-layer-shell / python3-gobject")
python3 -c "from PyQt6.QtWidgets import QApplication" 2>/dev/null || missing+=("PyQt6")

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing dependencies: ${missing[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo dnf install gtk4-layer-shell python3-gobject"
    echo "  pip install --user PyQt6"
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Install scripts
echo "Installing scripts to $SCRIPTS_DIR..."
mkdir -p "$SCRIPTS_DIR"
install -m 755 scripts/voxtype-overlay "$SCRIPTS_DIR/voxtype-overlay"
install -m 755 scripts/voxtype-indicator "$SCRIPTS_DIR/voxtype-indicator"

# Install notify-send shim
echo "Installing notify-send shim to $SHIMS_DIR..."
mkdir -p "$SHIMS_DIR"
install -m 755 scripts/notify-send-shim "$SHIMS_DIR/notify-send"

# Install systemd services
echo "Installing systemd services..."
mkdir -p "$SYSTEMD_DIR" "$SYSTEMD_DIR/voxtype.service.d"
install -m 644 systemd/voxtype-overlay.service "$SYSTEMD_DIR/"
install -m 644 systemd/voxtype-indicator.service "$SYSTEMD_DIR/"
install -m 644 systemd/voxtype-no-notify.conf "$SYSTEMD_DIR/voxtype.service.d/no-notify.conf"

# Fix paths in service files
sed -i "s|/home/mrw1986|$HOME|g" "$SYSTEMD_DIR/voxtype-overlay.service"
sed -i "s|/home/mrw1986|$HOME|g" "$SYSTEMD_DIR/voxtype-indicator.service"
sed -i "s|/home/mrw1986|$HOME|g" "$SYSTEMD_DIR/voxtype.service.d/no-notify.conf"

# Install KDE notification suppression
echo "Installing KDE notification config..."
install -m 644 config/xdg-desktop-portal-kde.notifyrc "$HOME/.config/"

# Reload and enable
echo "Enabling services..."
systemctl --user daemon-reload
systemctl --user enable --now voxtype-overlay.service
echo ""
echo "=== Installation complete ==="
echo ""
echo "Services enabled:"
echo "  voxtype-overlay  - OSD overlay (GTK4 + layer-shell)"
echo ""
echo "Optional (not enabled by default):"
echo "  voxtype-indicator - System tray icon"
echo "  Enable with: systemctl --user enable --now voxtype-indicator.service"
