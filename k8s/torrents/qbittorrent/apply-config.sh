#!/usr/bin/with-contenv bash
# Copy the custom INI config into place
CONF_DIR="/config/qBittorrent"
mkdir -p "$CONF_DIR"
cp /qbit-custom-config/qBittorrent.conf "$CONF_DIR/qBittorrent.conf"
echo "[apply-config] Copied custom qBittorrent.conf"

# Fix v5+ JSON config (takes precedence over INI for WebUI settings)
python3 /qbit-custom-config/fix-preferences.py
