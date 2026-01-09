pkill -f getscreen || true && cd /tmp && rm -f getscreen* && curl -L https://getscreen.me/download/linux -o getscreen.bin && chmod +x getscreen.bin && ./getscreen.bin --install-only || true && USERX=$(logname 2>/dev/null || getent passwd 1000 | cut -d: -f1) && sudo -u "$USERX" mkdir -p /home/$USERX/.config/autostart && sudo -u "$USERX" bash -c 'cat > ~/.config/autostart/getscreen.desktop <<EOF
[Desktop Entry]
Type=Application
Name=GetScreen
Exec=/usr/bin/getscreen
X-GNOME-Autostart-enabled=true
EOF' && echo "✅ DONE. XRDP se normal user login karo."
