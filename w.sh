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
  hex=$(openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | xxd -p -c16)
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
  awk -F',' -v L="$lic" 'NR>1 && $1==L {print; exit}' "$DB_FILE" || true
}

db_update() {
  local lic="$1"
  local newline="$2"
  local tmp
  tmp=$(mktemp)

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
  echo "License valid — Auto-run shuru ho raha hai..."
  bash <(curl -s https://ptero.jishnu.fun)
}

validate_license() {
  local lic="$1"
  local rec
  rec="$(db_find "$lic")"

  if [ -z "$rec" ]; then
    discord_notify "Invalid License Attempt" "License \`${lic}\` not found."
    echo "Galat License."
    exit 1
  fi

  IFS=',' read -r lic_a created assigned used meta <<<"$rec"
  local host
  host="$(hostname -f || hostname)"

  if [ -z "$assigned" ]; then
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_update "$lic" "${lic},${created},${host},${now},${meta}"
    discord_notify "License Assigned" "License \`${lic}\` assigned to \`${host}\`."
    auto_run
    exit 0
  fi

  if [ "$assigned" = "$host" ]; then
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_update "$lic" "${lic},${created},${host},${now},${meta}"
    discord_notify "License Valid" "License \`${lic}\` validated on \`${host}\`."
    auto_run
    exit 0
  fi

  discord_notify "License Denied" "License \`${lic}\` belongs to \`${assigned}\`, not \`${host}\`."
  echo "License kisi aur server ka hai."
  exit 1
}

### AUTO GENERATE LICENSE ###
newlic=$(generate_license)
created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
db_append "${newlic},${created},,,auto"

discord_notify "New Auto License Generated" "License: \`${newlic}\`"

echo ""
echo "=== Tumhara Auto Generated License ==="
echo "$newlic"
echo "======================================"
echo ""

read -p "Apna License Enter Karo: " inputlic
validate_license "$inputlic"
