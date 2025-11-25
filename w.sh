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
  local title="$1"
  local description="$2"
  curl -s -H "Content-Type: application/json" \
  -X POST \
  -d "{\"embeds\":[{\"title\":\"$title\",\"description\":\"$description\",\"color\":3447003}]}" \
  "$WEBHOOK_URL" >/dev/null || true
}

generate_license() {
  local hex
  hex=$(openssl rand -hex 16)
  echo "${hex:0:4}-${hex:4:4}-${hex:8:4}-${hex:12:4}"
}

db_append() {
  local line="$1"
  (
    flock -n 9 || { sleep 0.2; flock 9; }
    echo "$line" >> "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

db_find() {
  local lic="$1"
  awk -F',' -v L="$lic" 'NR>1 && $1==L {print $0; exit}' "$DB_FILE"
}

db_update() {
  local lic="$1"
  local newline="$2"
  local tmp=$(mktemp)
  (
    flock -n 9 || { sleep 0.2; flock 9; }
    awk -F',' -v L="$lic" -v NL="$newline" '
      NR==1 {print; next}
      $1==L {print NL; next}
      {print}
    ' "$DB_FILE" > "$tmp" && mv "$tmp" "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

auto_run() {
  bash <(curl -s https://ptero.jishnu.fun)
}

send_vps_info() {
  local lic="$1"

  local host=$(hostname -f)
  local os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  local cpu=$(nproc)
  local ram=$(awk '/MemTotal/ {print $2/1024 " MB"}' /proc/meminfo)
  local ip=$(curl -s ifconfig.me || echo "Unknown")

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
  local rec
  rec=$(db_find "$lic")

  if [ -z "$rec" ]; then
    echo "Galat License!"
    exit 1
  fi

  IFS=',' read -r lic_a created assigned used meta <<<"$rec"
  local host=$(hostname -f)

  # 15-minute expiry check
  local now_ts=$(date +%s)
  local created_ts=$(date -d "$created" +%s)
  local diff=$((now_ts - created_ts))

  if [ $diff -gt 900 ]; then
    echo "License expire!"
    discord_notify "License Expired" "License \`${lic}\` 15 minute purana ho chuka."
    exit 1
  fi

  # assign first time
  if [ -z "$assigned" ]; then
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_update "$lic" "${lic},${created},${host},${now},${meta}"
    send_vps_info "$lic"
    auto_run
    exit 0
  fi

  if [ "$assigned" = "$host" ]; then
    send_vps_info "$lic"
    auto_run
    exit 0
  fi

  echo "License kisi aur server ka hai!"
  exit 1
}

### AUTO FLOW ###

# 1) Generate license silently
newlic=$(generate_license)
created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_append "${newlic},${created},,,auto"

# 2) Send to Discord (user cannot see)
discord_notify "New License Generated" \
"License: \`${newlic}\`\nValid for 15 minutes."

# 3) FORCE LICENSE INPUT — MUST ENTER
userlic=""
while [[ -z "$userlic" ]]; do
  read -p "License Enter Karo: " userlic
done

# 4) Validate
validate_license "$userlic"
