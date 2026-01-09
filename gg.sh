#!/bin/bash
set -e

EMAIL="nn8109239@gmail.com"
DEVICE_NAME="My Computer"
SERVER="getscreen.me"

# detect main user (XRDP/desktop user)
USERX=$(logname 2>/dev/null || getent passwd 1000 | cut -d: -f1)
HOME_DIR="/home/$USERX"

echo "[+] Using user: $USERX"

# --- install agent (auto deb/rpm/binary) ---
cd /tmp
curl -L https://getscreen.me/download/linux -o getscreen
chmod +x getscreen
./getscreen -install || ./getscreen --install-only || true

# --- run all commands as desktop user ---
sudo -u "$USERX" bash <<EOF
set -e

# wait for display (XRDP safety)
export DISPLAY=\${DISPLAY:-:10}
export XDG_SESSION_TYPE=x11

# register account (Permanent Access)
getscreen -register "$EMAIL" || true

# preset configuration
getscreen -config "name='$DEVICE_NAME' control=true fast_access=false file_transfer=true disable_confirmation=true"

# set server
getscreen -set-server $SERVER

# autostart on login (XRDP / XFCE safe)
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/getscreen.desktop <<EOL
[Desktop Entry]
Type=Application
Name=GetScreen
Exec=/usr/bin/getscreen
X-GNOME-Autostart-enabled=true
EOL
EOF

echo "✅ GetScreen AUTO SETUP COMPLETE"
echo "➡ Login via XRDP as $USERX"
echo "➡ Open GetScreen dashboard → Permanent Access"
