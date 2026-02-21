#!/bin/bash
# ZZAR Flatpak wrapper script
# Sets up the environment so the PyInstaller binary can find runtime tools:
# ffmpeg, vgmstream-cli, Wine, GStreamer plugins, system SSL/wayland libs

# ── FFmpeg extension ──
if [ -d "/app/lib/ffmpeg/bin" ]; then
    export PATH="/app/lib/ffmpeg/bin:$PATH"
fi

# ── GStreamer ──
# Use runtime's GStreamer, not anything PyInstaller may have bundled
export GST_PLUGIN_SYSTEM_PATH="/usr/lib/x86_64-linux-gnu/gstreamer-1.0"
unset GST_PLUGIN_PATH

# ── Qt platform ──
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"

# ── Library paths ──
# Prepend runtime libs so system libwayland/libssl/libcrypto take priority
# over anything PyInstaller bundled
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/app/lib/ffmpeg/lib:${LD_LIBRARY_PATH}"

# ── Flatpak flag ──
# Tells the app it's running in a Flatpak (used for update notifications,
# writable tool paths, etc.)
export ZZAR_FLATPAK=1

# ── Launch ──
exec /app/bin/ZZAR.bin "$@"
