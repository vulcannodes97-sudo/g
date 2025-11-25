#!/bin/bash

# ========================
#  CONFIG
# ========================
WEBHOOK_URL="https://discord.com/api/webhooks/1442913662527475885/IrG4QxU9Ae264ALNfzZf88sJKF2uCIjrqn6jzw0UJyxJjf96RD-Ey7nIJQZmS92AjYfW"
LICENSE_FILE="/root/MY-License"
# ========================


# --- VPS INFO ---
vps_info() {
    VPS_IP=$(hostname -I | awk '{print $1}')
    VPS_ID=$(hostname)
    USER_RAND=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
}

# --- SEND TO DISCORD WEBHOOK ---
send_webhook() {
    curl -s -X POST -H "Content-Type: application/json" \
    -d "{
        \"content\": \"$USER_ID  🔔 License Active\",
        \"embeds\": [{
            \"title\": \"License Event\",
            \"description\": \"License Key: $LICENSE_KEY\nVPS: $VPS_ID ($VPS_IP)\nUserTag: $USER_RAND\",
            \"color\": 65280
        }]
    }" "$WEBHOOK_URL" >/dev/null 2>&1
}

# --- SAVE LICENSE FILE ---
save_license() {
    vps_info

    echo "LICENSE_KEY=$LICENSE_KEY" > $LICENSE_FILE
    echo "VPS_ID=$VPS_ID" >> $LICENSE_FILE
    echo "VPS_IP=$VPS_IP" >> $LICENSE_FILE
    echo "USER_RAND=$USER_RAND" >> $LICENSE_FILE
    echo "USER_ID=$USER_ID" >> $LICENSE_FILE

    send_webhook
}

# --- AUTO CHECK SYSTEM ---
auto_check() {
    # FIRST RUN → Ask user id + license
    if [ ! -f "$LICENSE_FILE" ]; then
        echo "----------------------------------------"
        echo "   FIRST RUN • LICENSE ACTIVATION"
        echo "----------------------------------------"

        read -p "Enter Discord User ID (example: <@123456789>): " USER_ID
        read -p "Enter Your License Key: " LICENSE_KEY

        save_license
        exit
    fi

    # If file exists → auto-run
    source $LICENSE_FILE
    send_webhook
}

# --- RUN AUTO ---
auto_check
