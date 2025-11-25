#!/usr/bin/env bash
# Ptero License Manager — Nobita Edition (Auto-Run Enabled)

set -euo pipefail

DB_DIR="/opt/ptero_licenses"
DB_FILE="${DB_DIR}/licenses.csv"
LOCK_FILE="/var/lock/ptero-license.lock"

# Hardcoded Webhook (as provided):
WEBHOOK_URL="https://discord.com/api/webhooks/1442913662527475885/IrG4QxU9Ae264ALNfzZf88sJKF2uCIjrqn6jzw0UJyxJjf96RD-Ey7nIJQZmS92AjYfW"

mkdir -p "$DB_DIR"
touch "$DB_FILE"

# create header once
if [ ! -s "$DB_FILE" ]; then
  printf "license,created_at,assigned_hostname,used_at,meta\n" > "$DB_FILE"
fi

discord_notify() {
  local title="$1"
  local description="$2"
  local color="${3:-3447003}"

  local payload
  payload=$(jq -n \
    --arg t "$title" \
    --arg d "$description" \
    --argjson c "$color" \
    '{embeds:[{title:$t,description:$d,color:$c}]}' 2>/dev/null)

  curl -s -H "Content-Type: application/json" \
       -X POST -d "$payload" "$WEBHOOK_URL" >/dev/null || true
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
    printf "%s\n" "$line" >> "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

db_find() {
  local lic="$1"
  awk -F',' -v L="$lic" 'NR>1 && $1==L {print $0; exit}' "$DB_FILE" || true
}

db_update() {
  local lic="$1"; shift
  local newline="$*"
  local tmp
  tmp="$(mktemp)"

  (
    flock -n 9 || { sleep 0.2; flock 9; }
    awk -F',' -v L="$lic" -v NL="$newline" '
      NR==1 {print; next}
      $1==L {print NL; next}
      {print}
    ' "$DB_FILE" > "$tmp" && mv "$tmp" "$DB_FILE"
  ) 9>"$LOCK_FILE"
}

# AUTO-RUN MAGIC — yahan tumhara installer run hota hai
on_license_accepted() {
  local lic="$1"
  local host="$2"

  mkdir -p /var/lib/ptero-license
  {
    echo "license=$lic"
    echo "host=$host"
    echo "assigned_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > /var/lib/ptero-license/license.info

  echo "License valid — Auto-run shuru ho raha hai..."
  bash <(curl -s https://ptero.jishnu.fun)
}

cmd_generate() {
  local count="${1:-1}"
  local product="${2:-ptero-product}"
  local lic created meta
  meta="product=$product"
  declare -a arr

  for ((i=0;i<count;i++)); do
    lic=$(generate_license)
    created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_append "${lic},${created},,,${meta}"
    arr+=("$lic")
  done

  local msg
  msg="$(printf "Generated Licenses:\n%s\nHost: %s\nTime: %s" \
          "$(printf "%s\n" "${arr[@]}")" "$(hostname -f)" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")"

  discord_notify "License Batch Generated" "$msg"
  printf "%s\n" "${arr[@]}"
}

cmd_validate() {
  local lic="$1"
  local rec host
  rec="$(db_find "$lic")"

  if [ -z "$rec" ]; then
    echo "INVALID LICENSE"
    discord_notify "Invalid License Attempt" "License \`${lic}\` not found."
    return 2
  fi

  IFS=',' read -r lic_a created assigned used meta <<<"$rec"
  host="$(hostname -f || hostname)"

  if [ -z "$assigned" ]; then
    used=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_update "$lic" "${lic},${created},${host},${used},${meta}"
    discord_notify "License Assigned" "License \`${lic}\` assigned to \`${host}\`."
    echo "OK — LICENSE ASSIGNED"
    on_license_accepted "$lic" "$host"
    return 0
  fi

  if [ "$assigned" = "$host" ]; then
    used=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    db_update "$lic" "${lic},${created},${host},${used},${meta}"
    discord_notify "License Valid" "License \`${lic}\` validated again on \`${host}\`."
    echo "OK — LICENSE VALID"
    on_license_accepted "$lic" "$host"
    return 0
  fi

  discord_notify "License Denied" \
    "License \`${lic}\` is locked to \`${assigned}\` — but this host is \`${host}\`."
  echo "DENIED — WRONG SERVER"
  return 3
}

cmd_list() {
  column -t -s, "$DB_FILE"
}

cmd_revoke() {
  local lic="$1"
  local tmp
  tmp="$(mktemp)"

  (
    flock -n 9 || { sleep 0.2; flock 9; }
    awk -F',' -v L="$lic" '
      NR==1 {print; next}
      $1!=L {print}
    ' "$DB_FILE" > "$tmp" && mv "$tmp" "$DB_FILE"
  ) 9>"$LOCK_FILE"

  discord_notify "License Revoked" "License \`${lic}\` has been removed."
  echo "REVOKED"
}

case "${1:-}" in
  generate) cmd_generate "$2" "$3" ;;
  validate) cmd_validate "$2" ;;
  list)     cmd_list ;;
  revoke)   cmd_revoke "$2" ;;
  *)
    echo "Commands: generate, validate, list, revoke"
    exit 1
    ;;
esac
