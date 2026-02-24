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

# Suppress "Remote desktop session started" notification
# Merges only the needed section instead of replacing the entire file
echo "Configuring KDE notification suppression..."
mkdir -p "$HOME/.config"
NOTIFYRC="$HOME/.config/xdg-desktop-portal-kde.notifyrc"
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "$NOTIFYRC" --group "Event/remotedesktopstarted" --key "Action" ""
    kwriteconfig6 --file "$NOTIFYRC" --group "Event/remotedesktopstarted" --key "Execute" ""
    kwriteconfig6 --file "$NOTIFYRC" --group "Event/remotedesktopstarted" --key "Logfile" ""
    kwriteconfig6 --file "$NOTIFYRC" --group "Event/remotedesktopstarted" --key "Sound" ""
    kwriteconfig6 --file "$NOTIFYRC" --group "Event/remotedesktopstarted" --key "TTS" ""
else
    # Fallback: only write if the section doesn't already exist
    if ! grep -q "\[Event/remotedesktopstarted\]" "$NOTIFYRC" 2>/dev/null; then
        cat config/xdg-desktop-portal-kde.notifyrc >> "$NOTIFYRC"
    fi
fi

# Reload and enable
echo "Enabling services..."
systemctl --user daemon-reload
systemctl --user enable --now voxtype-overlay.service

# Restart voxtype if running so the notify-send shim PATH takes effect
if systemctl --user is-active --quiet voxtype.service 2>/dev/null; then
    echo "Restarting voxtype.service to apply notification suppression..."
    systemctl --user restart voxtype.service
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Services enabled:"
echo "  voxtype-overlay  - OSD overlay (GTK4 + layer-shell)"
echo ""
echo "Optional (not enabled by default):"
echo "  voxtype-indicator - System tray icon"
echo "  Enable with: systemctl --user enable --now voxtype-indicator.service"
