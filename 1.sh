cat <<'EOF' > win-menu-lxc.sh
#!/bin/bash
set -e

IMAGE="ubuntu:22.04"

clear
echo "======================================"
echo "   WINDOWS AUTO MENU (LXC LAB MODE)"
echo "======================================"
echo "1) Windows 10"
echo "2) Windows 11"
echo "3) Custom Windows ISO"
echo "======================================"
read -p "Select option: " OPT

case $OPT in
  1)
    WIN_NAME="win10"
    ISO_URL="https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso"
    ;;
  2)
    WIN_NAME="win11"
    ISO_URL="https://software-download.microsoft.com/db/Win11_23H2_English_x64.iso"
    ;;
  3)
    WIN_NAME="custom"
    read -p "Enter Windows ISO URL: " ISO_URL
    ;;
  *)
    echo "❌ Invalid option"
    exit 1
    ;;
esac

read -p "How many containers? " COUNT

echo "--------------------------------------"
echo "OS   : $WIN_NAME"
echo "ISO  : $ISO_URL"
echo "COUNT: $COUNT"
echo "--------------------------------------"
sleep 1

for i in $(seq 1 $COUNT); do
  CT="${WIN_NAME}-${i}"

  echo "=============================="
  echo "[+] Creating container: $CT"
  echo "=============================="

  lxc launch $IMAGE $CT -c security.privileged=true || true

  lxc exec $CT -- bash <<INNER
set -e
apt update
apt install -y qemu-kvm qemu-utils wget bc net-tools

if [ ! -e /dev/kvm ]; then
  echo "❌ /dev/kvm not available (nested virtualization disabled)"
  exit 1
fi

# ===== AUTO DETECT FROM LXC =====
RAM=\$(awk '/MemTotal/ {print int(\$2/1024*0.8)}' /proc/meminfo)
CPU=\$(nproc)
DISK=\$(df -BG / | awk 'NR==2 {gsub("G",""); print int(\$4*0.7)}')G

echo "[+] Auto Detected → RAM=\${RAM}MB CPU=\${CPU} DISK=\${DISK}"

mkdir -p /win && cd /win

[ ! -f win.iso ] && wget -O win.iso "$ISO_URL"
[ ! -f disk.qcow2 ] && qemu-img create -f qcow2 disk.qcow2 \$DISK

nohup qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp \$CPU \
  -m \$RAM \
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
echo " ALL WINDOWS SETUP STARTED (LAB MODE)"
echo "======================================"
EOF

chmod +x win-menu-lxc.sh
./win-menu-lxc.sh
