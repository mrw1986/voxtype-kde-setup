# Voxtype KDE Indicator

Recording indicator and OSD overlay for [Voxtype](https://github.com/voxtype/voxtype) on **KDE Plasma 6 / Wayland**.

## What it does

When you hold the push-to-talk key, a centered overlay appears showing the recording/transcribing state — without stealing keyboard focus. Text always goes where your cursor is.

- **OSD Overlay** — GTK4 + `zwlr_layer_shell_v1` ensures the compositor never gives the overlay focus
- **Microphone icon** with pulsing glow during recording
- **Bouncing dots** animation during transcription
- **Fade in/out** transitions
- **System tray icon** (optional) — gray/red/blue dot via PyQt6

## Screenshots

| Recording | Transcribing |
|-----------|-------------|
| ![Recording](screenshots/recording.png) | ![Transcribing](screenshots/transcribing.png) |

## Requirements

- **Fedora 43+** (or any distro with KDE Plasma 6 and Wayland)
- **Voxtype** installed and running (`systemctl --user status voxtype`)
- **KWin** with `zwlr_layer_shell_v1` support (Plasma 6.x has this)

### Packages

```bash
# Overlay dependencies
sudo dnf install gtk4-layer-shell python3-gobject

# Tray icon (optional)
pip install --user PyQt6
```

## Quick Install

```bash
git clone https://github.com/mrw1986/voxtype-kde-indicator.git
cd voxtype-kde-indicator
./install.sh
```

## Manual Install

### OSD Overlay

```bash
# Install the overlay script
install -m 755 scripts/voxtype-overlay ~/.local/bin/

# Install the systemd service
install -m 644 systemd/voxtype-overlay.service ~/.config/systemd/user/

# Verify the LD_PRELOAD path matches your system (Fedora default shown).
# Debian/Ubuntu may use: /usr/lib/x86_64-linux-gnu/libgtk4-layer-shell.so.0
# Find yours with: ldconfig -p | grep libgtk4-layer-shell
grep LD_PRELOAD ~/.config/systemd/user/voxtype-overlay.service

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now voxtype-overlay.service
```

### Suppress Voxtype's Built-in Notifications

Voxtype's binary calls `notify-send` regardless of config. A scoped shim intercepts and drops these:

```bash
# Install the shim
mkdir -p ~/.local/lib/voxtype-shims
install -m 755 scripts/notify-send-shim ~/.local/lib/voxtype-shims/notify-send

# Install the PATH override (scoped to voxtype service only)
mkdir -p ~/.config/systemd/user/voxtype.service.d
install -m 644 systemd/voxtype-no-notify.conf ~/.config/systemd/user/voxtype.service.d/no-notify.conf

# Reload
systemctl --user daemon-reload
systemctl --user restart voxtype.service
```

### System Tray Icon (Optional)

```bash
install -m 755 scripts/voxtype-indicator ~/.local/bin/
install -m 644 systemd/voxtype-indicator.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now voxtype-indicator.service
```

## How It Works

```
┌─────────────────────┐     ┌──────────────────────┐
│   voxtype daemon    │────▶│ state file (inotify)  │
│   (Whisper + PTT)   │     │ /run/user/UID/        │
└─────────────────────┘     │ voxtype/state         │
                            └──────┬───────┬────────┘
                                   │       │
                    ┌──────────────┘       └──────────────┐
                    ▼                                      ▼
        ┌───────────────────┐              ┌──────────────────────┐
        │ voxtype-indicator │              │   voxtype-overlay    │
        │ (PyQt6 tray icon) │              │ (GTK4 + layer-shell) │
        │ gray/red/blue dot │              │ centered OSD popup   │
        └───────────────────┘              │ pulsing animation    │
                                           └──────────────────────┘
```

Both watch the voxtype state file via inotify. The overlay uses `Gtk4LayerShell.KeyboardMode.NONE` which makes KWin enforce no-focus-stealing at the compositor level.

### Why GTK4 + layer-shell?

On KDE Wayland, Qt-based overlays steal focus regardless of window flags (`BypassWindowManagerHint`, KWin rules, `setWindowOpacity()` — none work). GTK4 with `gtk4-layer-shell` uses the `zwlr_layer_shell_v1` Wayland protocol directly, which is the only reliable way to create a non-focus-stealing overlay on KDE Plasma 6.

**Important:** GTK4 layer-shell requires `LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0` due to a [linking order requirement](https://github.com/wmww/gtk4-layer-shell/blob/main/linking.md). This is handled by the systemd service.

## Copilot Key Setup (ASUS laptops)

If you have an ASUS laptop with a Copilot key and want to use it as the PTT hotkey:

```bash
# Install keyd
sudo dnf install keyd

# Create /etc/keyd/default.conf:
# [ids]
# *
# [main]
# leftshift+leftmeta = rightcontrol

sudo systemctl enable --now keyd
```

Then set `key = "RIGHTCTRL"` in `~/.config/voxtype/config.toml`.

## Troubleshooting

### Overlay not appearing
- Check service: `journalctl --user -u voxtype-overlay --since "5 min ago"`
- Verify layer-shell: `wayland-info | grep layer_shell` (should show v4+)
- Ensure `LD_PRELOAD` is set in the service file

### Overlay steals focus
- This should not happen with layer-shell. If it does, check that `gtk4-layer-shell` is installed and `LD_PRELOAD` is set.

### Text not appearing at cursor
- Check voxtype logs: `journalctl --user -u voxtype --since "5 min ago"`
- Reset eitype token: `eitype --reset-token -k return`

## License

MIT
