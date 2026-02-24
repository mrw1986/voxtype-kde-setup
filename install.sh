#!/bin/bash
# Voxtype KDE Setup - Installer
# Installs the overlay, indicator, and supporting config for voxtype on KDE Plasma 6 Wayland.
set -euo pipefail

SCRIPTS_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SHIMS_DIR="$HOME/.local/lib/voxtype-shims"

echo "=== Voxtype KDE Setup Installer ==="
echo ""

# Check required dependencies
echo "Checking dependencies..."
missing=()
command -v voxtype >/dev/null 2>&1 || missing+=("voxtype")
python3 -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Gtk4LayerShell', '1.0')" 2>/dev/null || missing+=("gtk4-layer-shell / python3-gobject")

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing required dependencies: ${missing[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo dnf install gtk4-layer-shell python3-gobject"
    echo ""
    if [ -t 0 ]; then
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    else
        echo "Run interactively to bypass, or install dependencies first."
        exit 1
    fi
fi

# Check optional dependencies
if ! python3 -c "from PyQt6.QtWidgets import QApplication" 2>/dev/null; then
    echo "  Note: PyQt6 not found (optional, needed for tray icon only)"
    echo "  Install with: pip install --user PyQt6"
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

# Resolve gtk4-layer-shell library path for LD_PRELOAD
LAYER_SHELL_LIB=""
if command -v pkg-config >/dev/null 2>&1; then
    libdir=$(pkg-config --variable=libdir gtk4-layer-shell-0 2>/dev/null || true)
    if [ -n "$libdir" ] && [ -f "$libdir/libgtk4-layer-shell.so.0" ]; then
        LAYER_SHELL_LIB="$libdir/libgtk4-layer-shell.so.0"
    fi
fi
if [ -z "$LAYER_SHELL_LIB" ]; then
    # Fallback: search common paths
    for candidate in /usr/lib64/libgtk4-layer-shell.so.0 /usr/lib/libgtk4-layer-shell.so.0 /usr/lib/x86_64-linux-gnu/libgtk4-layer-shell.so.0; do
        if [ -f "$candidate" ]; then
            LAYER_SHELL_LIB="$candidate"
            break
        fi
    done
fi
if [ -z "$LAYER_SHELL_LIB" ]; then
    echo "Warning: could not find libgtk4-layer-shell.so.0 — using default Fedora path"
    LAYER_SHELL_LIB="/usr/lib64/libgtk4-layer-shell.so.0"
fi

# Template the overlay service with the resolved library path
sed "s|Environment=LD_PRELOAD=.*|Environment=LD_PRELOAD=$LAYER_SHELL_LIB|" \
    systemd/voxtype-overlay.service > "$SYSTEMD_DIR/voxtype-overlay.service"
chmod 644 "$SYSTEMD_DIR/voxtype-overlay.service"

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
    # Fallback: replace section in-place or append if missing
    if grep -q "\[Event/remotedesktopstarted\]" "$NOTIFYRC" 2>/dev/null; then
        # Clear existing keys in the section
        sed -i '/^\[Event\/remotedesktopstarted\]/,/^\[/{
            s/^Action=.*/Action=/
            s/^Execute=.*/Execute=/
            s/^Logfile=.*/Logfile=/
            s/^Sound=.*/Sound=/
            s/^TTS=.*/TTS=/
        }' "$NOTIFYRC"
    else
        # Ensure trailing newline before appending
        [ -s "$NOTIFYRC" ] && [ -n "$(tail -c1 "$NOTIFYRC")" ] && printf '\n' >> "$NOTIFYRC"
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
