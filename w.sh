#!/usr/bin/env bash
set -euo pipefail

DB_DIR="/opt/ptero_licenses"
DB_FILE="${DB_DIR}/licenses.csv"
LOCK_FILE="/var/lock/ptero-license.lock"

WEBHOOK_URL="https://discord.com/api/webhooks/1442913662527475885/IrG4QxU9Ae264ALNfzZf88sJKF2uCIjrqn6jzw0UJyxJjf96RD-Ey7nIJQZmS92AjYfW"

mkdir -p "$DB_DIR"
touch "$DB_FILE"

if [ ! -s "$DB_FILE" ]; then
  printf "license,created_at,assigned_hostname,used_at,meta\n" > "$DB_FILE"
fi

discord_notify() {
  local t="$1"
  local d="$2"
  curl -s -H "Content-Type: application/json" \
  -X POST \
  -d "{\"embeds\":[{\"title\":\"$t\",\"description\":\"$d\",\"color\":3447003}]}" \
  "$WEBHOOK_URL" >/dev/null || true
}

generate_license() {
  local hex=$(openssl rand -hex 16)
  echo "${hex:0:4}-${hex:4:4}-${hex:8:4}-${hex:12:4}"
}

db_append() {
  (
    flock -n 9 || sleep 0.2
    echo "$1" >> "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

db_find() {
  awk -F',' -v L="$1" 'NR>1 && $1==L {print; exit}' "$DB_FILE"
}

db_update() {
  local lic="$1"
  local newline="$2"
  local tmp=$(mktemp)

  (
    flock 9
    awk -F',' -v L="$lic" -v NL="$newline" '
      NR==1 {print; next}
      $1==L {print NL; next}
      {print}
    ' "$DB_FILE" > "$tmp"

    mv "$tmp" "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

auto_run() {
  whiptail --title "Installing..." --msgbox "License valid.\nInstallation shuru ho rahi hai..." 10 60
  bash <(curl -s https://ptero.jishnu.fun)
}

send_vps_info() {
  local lic="$1"
  local host=$(hostname -f)
  local os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  local cpu=$(nproc)
  local ram=$(awk '/MemTotal/ {print $2/1024 " MB"}' /proc/meminfo)
  local ip=$(curl -s ifconfig.me)

  discord_notify "License Validated" \
"**License:** \`${lic}\`
**Host:** $host
**OS:** $os
**CPU:** $cpu
**RAM:** $ram
**IP:** $ip"
}

validate_license() {
  local lic="$1"
  local rec=$(db_find "$lic")

  if [ -z "$rec" ]; then
    whiptail --title "Error" --msgbox "Galat License!" 10 50
    exit 1
  fi

  IFS=',' read -r licx created assigned used meta <<<"$rec"

  # 15m expiry
  local now_ts=$(date +%s)
  local created_ts=$(date -d "$created" +%s)
  if (( now_ts - created_ts > 900 )); then
    whiptail --title "Expired!" --msgbox "Yeh license expire ho chuka hai." 10 50
    exit 1
  fi

  local host=$(hostname -f)
  local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [ -z "$assigned" ]; then
    db_update "$lic" "$lic,$created,$host,$now,$meta"
    send_vps_info "$lic"
    auto_run
    exit 0
  fi

  if [ "$assigned" = "$host" ]; then
    send_vps_info "$lic"
    auto_run
    exit 0
  fi

  whiptail --title "Blocked" --msgbox "Yeh license kisi aur VPS ka hai!" 10 50
  exit 1
}

######## AUTO MODE ########

# Generate license silently
newlic=$(generate_license)
created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_append "$newlic,$created,,,auto"

# Send to Discord only
discord_notify "New License Generated" \
"License: \`${newlic}\`\nValid for 15 minutes."

# UI Prompt to enter license
while true; do
  userlic=$(whiptail --title "License Required" --inputbox "Apna License Enter Karo:" 10 60 3>&1 1>&2 2>&3)

  if [ -z "$userlic" ]; then
    whiptail --title "Required" --msgbox "License dalna zaroori hai." 10 50
  else
    break
  fi
done

whiptail --title "Validating" --msgbox "License check ho raha hai..." 10 50

validate_license "$userlic"
