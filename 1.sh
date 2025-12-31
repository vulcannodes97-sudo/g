cat <<'EOF' > win-menu-lxc-resources.sh
#!/bin/bash
set -e

IMAGE="ubuntu:22.04"

is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

clear
echo "======================================"
echo "   WINDOWS AUTO MENU (LXC REAL MODE)"
echo "======================================"
echo "1) Windows 10"
echo "2) Windows 11"
echo "======================================"
read -p "Select Windows version: " OPT

case $OPT in
  1)
    WIN_NAME="win10"
    ISO_URL="https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso"
    ;;
  2)
    WIN_NAME="win11"
    ISO_URL="https://software-download.microsoft.com/db/Win11_23H2_English_x64.iso"
    ;;
  *)
    echo "❌ Invalid option"
    exit 1
    ;;
esac

# ===== CONTAINER COUNT =====
while true; do
  read -p "How many containers? (default 1): " COUNT
  COUNT=${COUNT:-1}
  is_number "$COUNT" && [ "$COUNT" -ge 1 ] && break
  echo "❌ Number only"
done

# ===== RESOURCE INPUT =====
while true; do
  read -p "RAM per container (MB, e.g. 2048): " RAM
  is_number "$RAM" && break
  echo "❌ Number only"
done

while true; do
  read -p "CPU cores per container (e.g. 2): " CPU
  is_number "$CPU" && break
  echo "❌ Number only"
done

while true; do
  read -p "SSD size per container (GB, e.g. 40): " SSD
  is_number "$SSD" && break
  echo "❌ Number only"
done

echo "--------------------------------------"
echo "OS    : $WIN_NAME"
echo "COUNT : $COUNT"
echo "RAM   : ${RAM}MB"
echo "CPU   : $CPU cores"
echo "SSD   : ${SSD}GB"
echo "--------------------------------------"
sleep 1

for i in $(seq 1 "$COUNT"); do
  CT="${WIN_NAME}-${i}"

  echo "=============================="
  echo "[+] Creating container: $CT"
  echo "=============================="

  lxc launch $IMAGE $CT \
    -c security.privileged=true \
    -c limits.memory=${RAM}MB \
    -c limits.cpu=$CPU \
    -c limits.disk=${SSD}GB || true

  lxc exec $CT -- bash <<INNER
set -e
apt update
apt install -y qemu-kvm qemu-utils wget

if [ ! -e /dev/kvm ]; then
  echo "❌ /dev/kvm not available"
  exit 1
fi

mkdir -p /win && cd /win

[ ! -f win.iso ] && wget -O win.iso "$ISO_URL"
[ ! -f disk.qcow2 ] && qemu-img create -f qcow2 disk.qcow2 ${SSD}G

nohup qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp $CPU \
  -m $RAM \
  -drive file=disk.qcow2,format=qcow2 \
  -cdrom win.iso \
  -boot d \
  -net nic \
  -net user,hostfwd=tcp::3389-:3389,hostfwd=tcp::5900-:5900 \
  -vnc :0 \
  > /win/qemu.log 2>&1 &

echo "✅ Windows installer started"
INNER

  IP=$(lxc list $CT -c 4 --format csv)
  echo "➡️ $CT READY"
  echo "   IP  : $IP"
  echo "   VNC : $IP:5900"
  echo "   RDP : $IP:3389 (after install)"
done

echo "======================================"
echo " ALL WINDOWS SETUP STARTED"
echo "======================================"
EOF

chmod +x win-menu-lxc-resources.sh
./win-menu-lxc-resources.sh
