#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager
# Now with Windows 10 Support!
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
███████ ███████ ███    ███ ██    ██     ██     ██ ███    ██ 
██      ██      ████  ████  ██  ██      ██     ██ ████   ██ 
█████   █████   ██ ████ ██   ████       ██  █  ██ ██ ██  ██ 
██      ██      ██  ██  ██    ██        ██ ███ ██ ██  ██ ██ 
██      ███████ ██      ██    ██         ███ ███  ██   ████ 
                                                            
 ██████  ██████  ███    ███ ███    ██                       
██    ██ ██   ██ ████  ████ ████   ██                       
██    ██ ██████  ██ ████ ██ ██ ██  ██                       
██    ██ ██   ██ ██  ██  ██ ██  ██ ██                       
 ██████  ██████  ██      ██ ██   ████                       

 ██████  ██    ██ ███    ███  ██████  ███████ ███████       
██    ██ ██    ██ ████  ████ ██       ██      ██            
██    ██ ██    ██ ██ ████ ██ ██   ███ █████   ███████       
██    ██ ██    ██ ██  ██  ██ ██    ██ ██           ██       
 ██████   ██████  ██      ██  ██████  ███████ ███████       
EOF
    echo "                   🤖 Now with Windows 10 Support! 🪟"
    echo
}

# Function to display colored output with emojis
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m📋 [INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m⚠️  [WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m❌ [ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m✅ [SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m🎯 [INPUT]\033[0m $message" ;;
        "WINDOWS") echo -e "\033[1;35m🪟 [WINDOWS]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function for confirmation dialog
confirm_action() {
    local message=$1
    local default=${2:-"n"}
    
    if [[ "$default" == "y" ]]; then
        read -p "$(print_status "INPUT" "$message (Y/n): ")" -n 1 -r
        echo
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        read -p "$(print_status "INPUT" "$message (y/N): ")" -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# Function to display VM table
display_vm_table() {
    local vms=("$@")
    
    if [ ${#vms[@]} -eq 0 ]; then
        print_status "INFO" "📭 No VMs found"
        return
    fi
    
    echo "┌──────┬────────────────────┬──────────┬─────────────┬──────────┬──────────┬──────────┐"
    printf "│ %-4s │ %-18s │ %-8s │ %-11s │ %-8s │ %-8s │ %-8s │\n" "No." "VM Name" "Status" "OS Type" "Memory" "Disk" "Mode"
    echo "├──────┼────────────────────┼──────────┼─────────────┼──────────┼──────────┼──────────┤"
    
    for i in "${!vms[@]}"; do
        if load_vm_config "${vms[$i]}" 2>/dev/null; then
            local status="💤 Stopped"
            if is_vm_running "${vms[$i]}"; then
                status="🚀 Running"
            fi
            
            local vm_mode="CLI"
            if [[ "$GUI_MODE" == true ]]; then
                vm_mode="GUI"
            fi
            if [[ "$OS_TYPE" == "windows" ]]; then
                vm_mode="🪟 GUI"
            fi
            
            printf "│ %-4d │ %-18s │ %-8s │ %-11s │ %-8s │ %-8s │ %-8s │\n" \
                $((i+1)) "${vms[$i]}" "$status" "${OS_TYPE:0:11}" "$MEMORY MB" "$DISK_SIZE" "$vm_mode"
        else
            printf "│ %-4d │ %-18s │ %-8s │ %-11s │ %-8s │ %-8s │ %-8s │\n" \
                $((i+1)) "${vms[$i]}" "❓ Unknown" "N/A" "N/A" "N/A" "N/A"
        fi
    done
    
    echo "└──────┴────────────────────┴──────────┴─────────────┴──────────┴──────────┴──────────┘"
}

# Function to check if image file is locked
check_image_lock() {
    local img_file=$1
    local vm_name=$2
    
    # Check if QEMU is already using this image
    if lsof "$img_file" 2>/dev/null | grep -q qemu-system; then
        print_status "WARN" "🔒 Image file $img_file is already in use by another QEMU process"
        
        # Find the process ID
        local pid=$(lsof "$img_file" 2>/dev/null | grep qemu-system | awk '{print $2}' | head -1)
        if [[ -n "$pid" ]]; then
            print_status "INFO" "🔍 Process ID using the image: $pid"
            
            # Check if it's our own VM
            if ps -p "$pid" -o cmd= | grep -q "$vm_name"; then
                print_status "INFO" "🤔 This appears to be the same VM already running"
                if confirm_action "🔄 Kill existing process and restart?"; then
                    kill "$pid"
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -9 "$pid"
                        print_status "WARN" "⚠️  Forcefully terminated process $pid"
                    fi
                    return 0
                else
                    return 1
                fi
            else
                print_status "ERROR" "🚫 Another QEMU instance is using this image"
                return 1
            fi
        fi
        return 1
    fi
    
    # Check for lock files
    local lock_file="${img_file}.lock"
    if [[ -f "$lock_file" ]]; then
        print_status "WARN" "🔒 Lock file found: $lock_file"
        
        # Check if lock file is stale (older than 5 minutes)
        if [[ $(find "$lock_file" -mmin +5 2>/dev/null) ]]; then
            print_status "WARN" "⏰ Lock file appears stale (older than 5 minutes)"
            if confirm_action "🗑️  Remove stale lock file?"; then
                rm -f "$lock_file"
                print_status "SUCCESS" "✅ Removed stale lock file"
                return 0
            else
                return 1
            fi
        fi
        return 1
    fi
    return 0
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "❌ Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "❌ Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "❌ Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "❌ VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "❌ Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "qemu-img" "lsof")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check for cloud-localds only if not Windows
    if ! command -v "cloud-localds" &> /dev/null; then
        print_status "WARN" "⚠️  cloud-localds not found. Linux VMs will need manual setup."
        print_status "INFO" "💡 Install with: sudo apt install cloud-image-utils"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "🔧 Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "💡 On Ubuntu/Debian, try: sudo apt install qemu-system wget lsof"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to get all VM configurations
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Clear previous variables
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        unset ISO_FILE VM_TYPE VIRTIO_DRIVERS
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "📂 Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Function to save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
ISO_FILE="$ISO_FILE"
VM_TYPE="$VM_TYPE"
VIRTIO_DRIVERS="$VIRTIO_DRIVERS"
EOF
    
    print_status "SUCCESS" "💾 Configuration saved to $config_file"
}

# Function to create new VM
create_new_vm() {
    print_status "INFO" "🆕 Creating a new VM"
    
    # OS Selection with Windows option
    print_status "INFO" "🌍 Select an OS to set up:"
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    while true; do
        read -p "$(print_status "INPUT" "🎯 Enter your choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            
            # Check if Windows
            if [[ "$OS_TYPE" == "windows" ]]; then
                print_status "WINDOWS" "🪟 Windows 10 Lite Edition selected"
                VM_TYPE="windows"
            else
                VM_TYPE="linux"
            fi
            break
        else
            print_status "ERROR" "❌ Invalid selection. Try again."
        fi
    done

    # Custom Inputs with validation
    while true; do
        read -p "$(print_status "INPUT" "🏷️  Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            # Check if VM name already exists
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "⚠️  VM with name '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    # Different inputs for Windows vs Linux
    if [[ "$VM_TYPE" == "windows" ]]; then
        # Windows specific settings
        HOSTNAME="$VM_NAME"
        USERNAME="Administrator"
        PASSWORD="Passw0rd!"
        
        print_status "WINDOWS" "🪟 Windows VM Settings:"
        echo "  👤 Username: $USERNAME (default)"
        echo "  🔑 Password: $PASSWORD (default)"
        echo "  💡 You can change these during Windows installation"
    else
        # Linux settings
        while true; do
            read -p "$(print_status "INPUT" "🏠 Enter hostname (default: $VM_NAME): ")" HOSTNAME
            HOSTNAME="${HOSTNAME:-$VM_NAME}"
            if validate_input "name" "$HOSTNAME"; then
                break
            fi
        done

        while true; do
            read -p "$(print_status "INPUT" "👤 Enter username (default: $DEFAULT_USERNAME): ")" USERNAME
            USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
            if validate_input "username" "$USERNAME"; then
                break
            fi
        done

        while true; do
            read -s -p "$(print_status "INPUT" "🔑 Enter password (default: $DEFAULT_PASSWORD): ")" PASSWORD
            PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
            echo
            if [ -n "$PASSWORD" ]; then
                break
            else
                print_status "ERROR" "❌ Password cannot be empty"
            fi
        done
    fi

    # Common settings
    while true; do
        read -p "$(print_status "INPUT" "💾 Disk size (default: ${VM_TYPE}_DISK_DEFAULT): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-${VM_TYPE}_DISK_DEFAULT}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory in MB (default: ${VM_TYPE}_MEMORY_DEFAULT): ")" MEMORY
        MEMORY="${MEMORY:-${VM_TYPE}_MEMORY_DEFAULT}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "⚡ Number of CPUs (default: ${VM_TYPE}_CPUS_DEFAULT): ")" CPUS
        CPUS="${CPUS:-${VM_TYPE}_CPUS_DEFAULT}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    # SSH port only for Linux
    if [[ "$VM_TYPE" == "linux" ]]; then
        while true; do
            read -p "$(print_status "INPUT" "🔌 SSH Port (default: 2222): ")" SSH_PORT
            SSH_PORT="${SSH_PORT:-2222}"
            if validate_input "port" "$SSH_PORT"; then
                # Check if port is already in use
                if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                    print_status "ERROR" "🚫 Port $SSH_PORT is already in use"
                else
                    break
                fi
            fi
        done
    else
        SSH_PORT=""
    fi

    # GUI mode (always true for Windows, optional for Linux)
    if [[ "$VM_TYPE" == "windows" ]]; then
        GUI_MODE=true
        print_status "WINDOWS" "🖥️  Windows VMs always run in GUI mode"
    else
        while true; do
            read -p "$(print_status "INPUT" "🖥️  Enable GUI mode? (y/n, default: n): ")" gui_input
            GUI_MODE=false
            gui_input="${gui_input:-n}"
            if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
                GUI_MODE=true
                break
            elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                break
            else
                print_status "ERROR" "❌ Please answer y or n"
            fi
        done
    fi

    # Additional network options
    if [[ "$VM_TYPE" == "linux" ]]; then
        read -p "$(print_status "INPUT" "🌐 Additional port forwards (e.g., 8080:80, press Enter for none): ")" PORT_FORWARDS
    else
        # Default RDP port for Windows
        PORT_FORWARDS="3389:3389"
        print_status "WINDOWS" "🌐 RDP port 3389 will be forwarded for remote desktop access"
    fi

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    # Windows ISO file
    if [[ "$VM_TYPE" == "windows" ]]; then
        ISO_FILE="$VM_DIR/$VM_NAME.iso"
        VIRTIO_DRIVERS="$VM_DIR/virtio-win.iso"
    else
        ISO_FILE=""
        VIRTIO_DRIVERS=""
    fi

    # Download and setup VM image
    setup_vm_image
    
    # Save configuration
    save_vm_config
}

# Function to setup VM image
setup_vm_image() {
    print_status "INFO" "📥 Downloading and preparing image..."
    
    # Create VM directory if it doesn't exist
    mkdir -p "$VM_DIR"
    
    if [[ "$VM_TYPE" == "windows" ]]; then
        setup_windows_vm
    else
        setup_linux_vm
    fi
}

# Function to setup Linux VM
setup_linux_vm() {
    # Check if image already exists
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "✅ Image file already exists. Skipping download."
    else
        print_status "INFO" "🌐 Downloading image from $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp"; then
            print_status "ERROR" "❌ Failed to download image from $IMG_URL"
            exit 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Resize the disk image if needed
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "WARN" "⚠️  Failed to resize disk image. Creating new image with specified size..."
        # Create a new image with the specified size
        rm -f "$IMG_FILE"
        qemu-img create -f qcow2 -F qcow2 -b "$IMG_FILE" "$IMG_FILE.tmp" "$DISK_SIZE" 2>/dev/null || \
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        if [ -f "$IMG_FILE.tmp" ]; then
            mv "$IMG_FILE.tmp" "$IMG_FILE"
        fi
    fi

    # cloud-init configuration for Linux
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if command -v cloud-localds &> /dev/null; then
        if ! cloud-localds "$SEED_FILE" user-data meta-data; then
            print_status "ERROR" "❌ Failed to create cloud-init seed image"
            exit 1
        fi
    else
        print_status "WARN" "⚠️  cloud-localds not found. Creating empty seed image..."
        dd if=/dev/zero of="$SEED_FILE" bs=1M count=1
    fi
    
    print_status "SUCCESS" "🎉 Linux VM '$VM_NAME' created successfully."
    print_status "INFO" "🔑 Login with: username=$USERNAME, password=$PASSWORD"
    print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
}

# Function to setup Windows VM
setup_windows_vm() {
    print_status "WINDOWS" "🪟 Setting up Windows 10 VM..."
    
    # Download Windows ISO if needed
    if [[ ! -f "$ISO_FILE" ]]; then
        print_status "WINDOWS" "📥 Downloading Windows 10 Lite Edition ISO (3.5GB)..."
        print_status "WINDOWS" "⏳ This may take a while depending on your internet speed..."
        
        # Create download directory
        mkdir -p "$VM_DIR/downloads"
        
        if ! wget --progress=bar:force \
                  --timeout=60 \
                  --tries=3 \
                  "https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso" \
                  -O "$ISO_FILE.tmp"; then
            print_status "ERROR" "❌ Failed to download Windows ISO"
            print_status "INFO" "💡 You can manually download the ISO and place it at: $ISO_FILE"
            print_status "INFO" "🔗 URL: https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"
            exit 1
        fi
        mv "$ISO_FILE.tmp" "$ISO_FILE"
        print_status "SUCCESS" "✅ Windows ISO downloaded successfully"
    else
        print_status "INFO" "✅ Windows ISO already exists. Skipping download."
    fi
    
    # Download VirtIO drivers for Windows
    if [[ ! -f "$VIRTIO_DRIVERS" ]]; then
        print_status "WINDOWS" "📥 Downloading VirtIO drivers for Windows..."
        if ! wget --progress=bar:force \
                  "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" \
                  -O "$VIRTIO_DRIVERS.tmp"; then
            print_status "WARN" "⚠️  Failed to download VirtIO drivers"
            print_status "INFO" "💡 Windows installation may work without them, but performance will be better with VirtIO"
            VIRTIO_DRIVERS=""
        else
            mv "$VIRTIO_DRIVERS.tmp" "$VIRTIO_DRIVERS"
            print_status "SUCCESS" "✅ VirtIO drivers downloaded"
        fi
    fi
    
    # Create disk image
    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "WINDOWS" "💾 Creating $DISK_SIZE disk image..."
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
    else
        print_status "INFO" "✅ Disk image already exists."
    fi
    
    print_status "SUCCESS" "🎉 Windows VM '$VM_NAME' created successfully."
    print_status "WINDOWS" "🖥️  Start the VM to begin Windows installation"
    print_status "WINDOWS" "💡 During installation:"
    echo "   1. Select your language and region"
    echo "   2. When asked for product key, click 'I don't have a product key'"
    echo "   3. Select 'Windows 10 Pro' edition"
    echo "   4. Choose 'Custom: Install Windows only (advanced)'"
    echo "   5. Select the empty drive and click Next"
    echo "   6. Wait for installation to complete"
    echo "   7. Create user: $USERNAME with password: $PASSWORD"
    print_status "WINDOWS" "🌐 After installation, use RDP to connect:"
    echo "   Remote Desktop Connection -> localhost:3389"
}

# Function to start a VM
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Check if image is already in use
        if [[ -f "$IMG_FILE" ]] && ! check_image_lock "$IMG_FILE" "$vm_name"; then
            print_status "ERROR" "🔒 Cannot start VM: Image file is locked by another process"
            if confirm_action "🔄 Do you want to force kill all QEMU processes using this image?"; then
                pkill -f "qemu-system.*$IMG_FILE"
                sleep 2
                if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
                    pkill -9 -f "qemu-system.*$IMG_FILE"
                fi
                print_status "SUCCESS" "✅ Terminated processes using the image"
                # Remove any lock files
                rm -f "${IMG_FILE}.lock" 2>/dev/null
            else
                return 1
            fi
        fi
        
        # Check if VM is already running
        if is_vm_running "$vm_name"; then
            print_status "WARN" "⚠️  VM '$vm_name' is already running"
            if confirm_action "🔄 Stop and restart?"; then
                stop_vm "$vm_name"
                sleep 2
            else
                return 1
            fi
        fi
        
        if [[ "$VM_TYPE" == "windows" ]]; then
            start_windows_vm "$vm_name"
        else
            start_linux_vm "$vm_name"
        fi
    fi
}

# Function to start Linux VM
start_linux_vm() {
    local vm_name=$1
    
    print_status "INFO" "🚀 Starting Linux VM: $vm_name"
    print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    print_status "INFO" "🔑 Password: $PASSWORD"
    
    # Check if image file exists
    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "ERROR" "❌ VM image file not found: $IMG_FILE"
        return 1
    fi
    
    # Check if seed file exists
    if [[ ! -f "$SEED_FILE" ]]; then
        print_status "WARN" "⚠️  Seed file not found, recreating..."
        setup_vm_image
    fi
    
    # Base QEMU command for Linux
    local qemu_cmd=(
        qemu-system-x86_64
        -enable-kvm
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu host
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -boot order=c
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
    )

    # Add port forwards if specified
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            IFS=':' read -r host_port guest_port <<< "$forward"
            qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
            qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
        done
    fi

    # Add GUI or console mode
    if [[ "$GUI_MODE" == true ]]; then
        qemu_cmd+=(-vga virtio -display gtk,gl=on)
        print_status "INFO" "🖥️  Starting in GUI mode..."
    else
        qemu_cmd+=(-nographic -serial mon:stdio)
        print_status "INFO" "📟 Starting in console mode..."
        print_status "INFO" "🛑 Press Ctrl+A then X to exit QEMU console"
    fi

    # Add performance enhancements
    qemu_cmd+=(
        -device virtio-balloon-pci
        -object rng-random,filename=/dev/urandom,id=rng0
        -device virtio-rng-pci,rng=rng0
    )

    print_status "INFO" "⚡ Starting QEMU..."
    echo "📊 Configuration: ${MEMORY}MB RAM, ${CPUS} CPUs, ${DISK_SIZE} disk"
    
    # Start the VM
    if ! "${qemu_cmd[@]}"; then
        print_status "ERROR" "❌ Failed to start VM. There might be a problem with the image file or configuration."
        # Try to clean up lock files
        rm -f "${IMG_FILE}.lock" 2>/dev/null
        return 1
    fi
    
    print_status "INFO" "🛑 VM $vm_name has been shut down"
}

# Function to start Windows VM
start_windows_vm() {
    local vm_name=$1
    
    print_status "WINDOWS" "🚀 Starting Windows VM: $vm_name"
    print_status "WINDOWS" "🖥️  Windows installation will begin..."
    print_status "WINDOWS" "🌐 After installation, connect via RDP: localhost:3389"
    
    # Check if ISO exists
    if [[ ! -f "$ISO_FILE" ]]; then
        print_status "ERROR" "❌ Windows ISO file not found: $ISO_FILE"
        print_status "INFO" "💡 Download it manually from:"
        echo "   https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"
        echo "   And place it at: $ISO_FILE"
        return 1
    fi
    
    # Check if disk exists
    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "WINDOWS" "💾 Creating new disk image..."
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
    fi
    
    # Windows QEMU command
    local qemu_cmd=(
        qemu-system-x86_64
        -enable-kvm
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu host
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -cdrom "$ISO_FILE"
        -boot order=d
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp::3389-:3389"
    )
    
    # Add VirtIO drivers if available
    if [[ -f "$VIRTIO_DRIVERS" ]]; then
        qemu_cmd+=(-drive "file=$VIRTIO_DRIVERS,media=cdrom,readonly=on")
        print_status "WINDOWS" "🚀 VirtIO drivers loaded for better performance"
    fi
    
    # Windows always runs in GUI mode with better graphics
    qemu_cmd+=(
        -vga virtio
        -display gtk,gl=on
        -usb
        -device usb-tablet
        -device usb-kbd
        -soundhw hda
        -machine type=pc,accel=kvm
    )
    
    # Add port forwards if specified
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            IFS=':' read -r host_port guest_port <<< "$forward"
            qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
            qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
        done
    fi

    print_status "WINDOWS" "⚡ Starting QEMU with Windows..."
    echo "📊 Configuration: ${MEMORY}MB RAM, ${CPUS} CPUs, ${DISK_SIZE} disk"
    echo "💿 Boot device: CD-ROM (Windows ISO)"
    echo "🖥️  Display: GUI with hardware acceleration"
    
    # Important instructions
    print_status "WINDOWS" "📝 Installation Instructions:"
    echo "   1. Press any key to boot from CD when prompted"
    echo "   2. Follow Windows installation wizard"
    echo "   3. When asked for drivers, select VirtIO drivers from CD"
    echo "   4. Create user: Administrator (or your preferred username)"
    echo "   5. Password: Passw0rd! (or your preferred password)"
    echo "   6. After installation, install VirtIO drivers from CD for best performance"
    
    # Start the VM
    if ! "${qemu_cmd[@]}"; then
        print_status "ERROR" "❌ Failed to start Windows VM"
        return 1
    fi
    
    print_status "WINDOWS" "🛑 Windows VM $vm_name has been shut down"
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    
    print_status "WARN" "⚠️  ⚠️  ⚠️  This will permanently delete VM '$vm_name' and all its data!"
    if ! confirm_action "🗑️  Are you sure?"; then
        print_status "INFO" "👍 Deletion cancelled"
        return
    fi
    
    if load_vm_config "$vm_name"; then
        # Check if VM is running
        if is_vm_running "$vm_name"; then
            print_status "WARN" "⚠️  VM is currently running. Stopping it first..."
            stop_vm "$vm_name"
            sleep 2
        fi
        
        # Delete all VM files
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf" "${IMG_FILE}.lock" 2>/dev/null
        if [[ "$VM_TYPE" == "windows" ]]; then
            rm -f "$ISO_FILE" "$VIRTIO_DRIVERS" 2>/dev/null
        fi
        print_status "SUCCESS" "✅ VM '$vm_name' has been deleted"
    fi
}

# Function to show VM info
show_vm_info() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        echo
        if [[ "$VM_TYPE" == "windows" ]]; then
            print_status "WINDOWS" "📊 Windows VM Information: $vm_name"
        else
            print_status "INFO" "📊 Linux VM Information: $vm_name"
        fi
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        echo "🌍 OS Type: $OS_TYPE"
        echo "🏷️  VM Name: $VM_NAME"
        echo "🏠 Hostname: $HOSTNAME"
        echo "👤 Username: $USERNAME"
        echo "🔑 Password: $PASSWORD"
        if [[ "$VM_TYPE" == "linux" ]]; then
            echo "🔌 SSH Port: $SSH_PORT"
        else
            echo "🌐 RDP Port: 3389"
        fi
        echo "🧠 Memory: $MEMORY MB"
        echo "⚡ CPUs: $CPUS"
        echo "💾 Disk: $DISK_SIZE"
        echo "🖥️  GUI Mode: $GUI_MODE"
        echo "🌐 Port Forwards: ${PORT_FORWARDS:-None}"
        echo "📅 Created: $CREATED"
        echo "💿 Image File: $IMG_FILE"
        if [[ "$VM_TYPE" == "windows" ]]; then
            echo "📀 ISO File: $ISO_FILE"
            echo "🚀 VirtIO Drivers: ${VIRTIO_DRIVERS:-Not installed}"
        else
            echo "🌱 Seed File: $SEED_FILE"
        fi
        
        # Show lock status
        if [[ -f "$IMG_FILE" ]] && check_image_lock "$IMG_FILE" "$vm_name" >/dev/null 2>&1; then
            echo "🔓 Image Status: Unlocked"
        else
            echo "🔒 Image Status: Locked (possibly in use)"
        fi
        
        # Show if VM is running
        if is_vm_running "$vm_name"; then
            echo "🚀 Status: Running"
        else
            echo "💤 Status: Stopped"
        fi
        
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        
        # Connection instructions
        if [[ "$VM_TYPE" == "windows" ]] && is_vm_running "$vm_name"; then
            echo "🖥️  Connect via Remote Desktop:"
            echo "   Host: localhost"
            echo "   Port: 3389"
            echo "   Username: $USERNAME"
            echo "   Password: $PASSWORD"
        elif [[ "$VM_TYPE" == "linux" ]] && is_vm_running "$vm_name"; then
            echo "🔌 Connect via SSH:"
            echo "   ssh -p $SSH_PORT $USERNAME@localhost"
            echo "   Password: $PASSWORD"
        fi
        
        echo
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to check if VM is running
is_vm_running() {
    local vm_name=$1
    
    # First try to find by image file
    if pgrep -f "qemu-system.*$vm_name" >/dev/null; then
        return 0
    fi
    
    # Also check by image file path
    if load_vm_config "$vm_name" 2>/dev/null; then
        if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Function to stop a running VM
stop_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            if [[ "$VM_TYPE" == "windows" ]]; then
                print_status "WINDOWS" "🛑 Stopping Windows VM: $vm_name"
            else
                print_status "INFO" "🛑 Stopping VM: $vm_name"
            fi
            
            # Try graceful shutdown first
            pkill -f "qemu-system.*$IMG_FILE"
            sleep 2
            
            # Check if it stopped
            if is_vm_running "$vm_name"; then
                print_status "WARN" "⚠️  VM did not stop gracefully, forcing termination..."
                pkill -9 -f "qemu-system.*$IMG_FILE"
                sleep 1
            fi
            
            # Clean up lock files
            rm -f "${IMG_FILE}.lock" 2>/dev/null
            
            if is_vm_running "$vm_name"; then
                print_status "ERROR" "❌ Failed to stop VM"
                return 1
            else
                print_status "SUCCESS" "✅ VM $vm_name stopped"
            fi
        else
            print_status "INFO" "💤 VM $vm_name is not running"
            # Still try to clean up any lock files
            rm -f "${IMG_FILE}.lock" 2>/dev/null
        fi
    fi
}

# Function to edit VM configuration
edit_vm_config() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "✏️  Editing VM: $vm_name"
        
        while true; do
            echo "📝 What would you like to edit?"
            if [[ "$VM_TYPE" == "windows" ]]; then
                echo "  1) 🏷️  VM Name"
                echo "  2) 🧠 Memory (RAM)"
                echo "  3) ⚡ CPU Count"
                echo "  4) 💾 Disk Size"
                echo "  5) 🌐 Port Forwards"
                echo "  0) ↩️  Back to main menu"
            else
                echo "  1) 🏷️  Hostname"
                echo "  2) 👤 Username"
                echo "  3) 🔑 Password"
                echo "  4) 🔌 SSH Port"
                echo "  5) 🖥️  GUI Mode"
                echo "  6) 🌐 Port Forwards"
                echo "  7) 🧠 Memory (RAM)"
                echo "  8) ⚡ CPU Count"
                echo "  9) 💾 Disk Size"
                echo "  0) ↩️  Back to main menu"
            fi
            
            read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" edit_choice
            
            case $edit_choice in
                1)
                    if [[ "$VM_TYPE" == "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "🏷️  Enter new VM name (current: $VM_NAME): ")" new_vm_name
                            new_vm_name="${new_vm_name:-$VM_NAME}"
                            if validate_input "name" "$new_vm_name"; then
                                if [[ "$new_vm_name" != "$VM_NAME" ]] && [[ -f "$VM_DIR/$new_vm_name.conf" ]]; then
                                    print_status "ERROR" "⚠️  VM with name '$new_vm_name' already exists"
                                else
                                    # Rename files
                                    mv "$VM_DIR/$VM_NAME.conf" "$VM_DIR/$new_vm_name.conf" 2>/dev/null
                                    mv "$IMG_FILE" "$VM_DIR/$new_vm_name.img" 2>/dev/null
                                    if [[ -f "$ISO_FILE" ]]; then
                                        mv "$ISO_FILE" "$VM_DIR/$new_vm_name.iso" 2>/dev/null
                                    fi
                                    VM_NAME="$new_vm_name"
                                    IMG_FILE="$VM_DIR/$VM_NAME.img"
                                    ISO_FILE="$VM_DIR/$VM_NAME.iso"
                                    break
                                fi
                            fi
                        done
                    else
                        while true; do
                            read -p "$(print_status "INPUT" "🏷️  Enter new hostname (current: $HOSTNAME): ")" new_hostname
                            new_hostname="${new_hostname:-$HOSTNAME}"
                            if validate_input "name" "$new_hostname"; then
                                HOSTNAME="$new_hostname"
                                break
                            fi
                        done
                    fi
                    ;;
                2)
                    if [[ "$VM_TYPE" == "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "🧠 Enter new memory in MB (current: $MEMORY): ")" new_memory
                            new_memory="${new_memory:-$MEMORY}"
                            if validate_input "number" "$new_memory"; then
                                MEMORY="$new_memory"
                                break
                            fi
                        done
                    else
                        while true; do
                            read -p "$(print_status "INPUT" "👤 Enter new username (current: $USERNAME): ")" new_username
                            new_username="${new_username:-$USERNAME}"
                            if validate_input "username" "$new_username"; then
                                USERNAME="$new_username"
                                break
                            fi
                        done
                    fi
                    ;;
                3)
                    if [[ "$VM_TYPE" == "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "⚡ Enter new CPU count (current: $CPUS): ")" new_cpus
                            new_cpus="${new_cpus:-$CPUS}"
                            if validate_input "number" "$new_cpus"; then
                                CPUS="$new_cpus"
                                break
                            fi
                        done
                    else
                        while true; do
                            read -s -p "$(print_status "INPUT" "🔑 Enter new password (current: ****): ")" new_password
                            new_password="${new_password:-$PASSWORD}"
                            echo
                            if [ -n "$new_password" ]; then
                                PASSWORD="$new_password"
                                break
                            else
                                print_status "ERROR" "❌ Password cannot be empty"
                            fi
                        done
                    fi
                    ;;
                4)
                    if [[ "$VM_TYPE" == "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "💾 Enter new disk size (current: $DISK_SIZE): ")" new_disk_size
                            new_disk_size="${new_disk_size:-$DISK_SIZE}"
                            if validate_input "size" "$new_disk_size"; then
                                DISK_SIZE="$new_disk_size"
                                break
                            fi
                        done
                    else
                        while true; do
                            read -p "$(print_status "INPUT" "🔌 Enter new SSH port (current: $SSH_PORT): ")" new_ssh_port
                            new_ssh_port="${new_ssh_port:-$SSH_PORT}"
                            if validate_input "port" "$new_ssh_port"; then
                                # Check if port is already in use
                                if [ "$new_ssh_port" != "$SSH_PORT" ] && ss -tln 2>/dev/null | grep -q ":$new_ssh_port "; then
                                    print_status "ERROR" "🚫 Port $new_ssh_port is already in use"
                                else
                                    SSH_PORT="$new_ssh_port"
                                    break
                                fi
                            fi
                        done
                    fi
                    ;;
                5)
                    if [[ "$VM_TYPE" == "windows" ]]; then
                        read -p "$(print_status "INPUT" "🌐 Additional port forwards (current: ${PORT_FORWARDS:-3389:3389}): ")" new_port_forwards
                        PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                    else
                        while true; do
                            read -p "$(print_status "INPUT" "🖥️  Enable GUI mode? (y/n, current: $GUI_MODE): ")" gui_input
                            gui_input="${gui_input:-}"
                            if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
                                GUI_MODE=true
                                break
                            elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                                GUI_MODE=false
                                break
                            elif [ -z "$gui_input" ]; then
                                # Keep current value if user just pressed Enter
                                break
                            else
                                print_status "ERROR" "❌ Please answer y or n"
                            fi
                        done
                    fi
                    ;;
                6)
                    if [[ "$VM_TYPE" != "windows" ]]; then
                        read -p "$(print_status "INPUT" "🌐 Additional port forwards (current: ${PORT_FORWARDS:-None}): ")" new_port_forwards
                        PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                    fi
                    ;;
                7)
                    if [[ "$VM_TYPE" != "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "🧠 Enter new memory in MB (current: $MEMORY): ")" new_memory
                            new_memory="${new_memory:-$MEMORY}"
                            if validate_input "number" "$new_memory"; then
                                MEMORY="$new_memory"
                                break
                            fi
                        done
                    fi
                    ;;
                8)
                    if [[ "$VM_TYPE" != "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "⚡ Enter new CPU count (current: $CPUS): ")" new_cpus
                            new_cpus="${new_cpus:-$CPUS}"
                            if validate_input "number" "$new_cpus"; then
                                CPUS="$new_cpus"
                                break
                            fi
                        done
                    fi
                    ;;
                9)
                    if [[ "$VM_TYPE" != "windows" ]]; then
                        while true; do
                            read -p "$(print_status "INPUT" "💾 Enter new disk size (current: $DISK_SIZE): ")" new_disk_size
                            new_disk_size="${new_disk_size:-$DISK_SIZE}"
                            if validate_input "size" "$new_disk_size"; then
                                DISK_SIZE="$new_disk_size"
                                break
                            fi
                        done
                    fi
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "❌ Invalid selection"
                    continue
                    ;;
            esac
            
            # Recreate seed image with new configuration for Linux VMs
            if [[ "$VM_TYPE" == "linux" ]] && [[ "$edit_choice" -eq 1 || "$edit_choice" -eq 2 || "$edit_choice" -eq 3 ]]; then
                print_status "INFO" "🔄 Updating cloud-init configuration..."
                setup_vm_image
            fi
            
            # Save configuration
            save_vm_config
            
            if ! confirm_action "🔄 Continue editing?"; then
                break
            fi
        done
    fi
}

# Function to resize VM disk
resize_vm_disk() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Check if VM is running
        if is_vm_running "$vm_name"; then
            print_status "ERROR" "❌ Cannot resize disk while VM is running. Please stop the VM first."
            return 1
        fi
        
        print_status "INFO" "💾 Current disk size: $DISK_SIZE"
        
        while true; do
            read -p "$(print_status "INPUT" "📈 Enter new disk size (e.g., 50G): ")" new_disk_size
            if validate_input "size" "$new_disk_size"; then
                if [[ "$new_disk_size" == "$DISK_SIZE" ]]; then
                    print_status "INFO" "ℹ️  New disk size is the same as current size. No changes made."
                    return 0
                fi
                
                # Check if new size is smaller than current (not recommended)
                local current_size_num=${DISK_SIZE%[GgMm]}
                local new_size_num=${new_disk_size%[GgMm]}
                local current_unit=${DISK_SIZE: -1}
                local new_unit=${new_disk_size: -1}
                
                # Convert both to MB for comparison
                if [[ "$current_unit" =~ [Gg] ]]; then
                    current_size_num=$((current_size_num * 1024))
                fi
                if [[ "$new_unit" =~ [Gg] ]]; then
                    new_size_num=$((new_size_num * 1024))
                fi
                
                if [[ $new_size_num -lt $current_size_num ]]; then
                    print_status "WARN" "⚠️  Shrinking disk size is not recommended and may cause data loss!"
                    if ! confirm_action "⚠️  Are you sure you want to continue?"; then
                        print_status "INFO" "👍 Disk resize cancelled."
                        return 0
                    fi
                fi
                
                # Resize the disk
                print_status "INFO" "📈 Resizing disk to $new_disk_size..."
                if qemu-img resize "$IMG_FILE" "$new_disk_size"; then
                    DISK_SIZE="$new_disk_size"
                    save_vm_config
                    print_status "SUCCESS" "✅ Disk resized successfully to $new_disk_size"
                else
                    print_status "ERROR" "❌ Failed to resize disk"
                    return 1
                fi
                break
            fi
        done
    fi
}

# Function to show VM performance metrics
show_vm_performance() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "📊 Performance metrics for VM: $vm_name"
            echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
            
            # Get QEMU process ID
            local qemu_pid=$(pgrep -f "qemu-system.*$IMG_FILE")
            if [[ -n "$qemu_pid" ]]; then
                # Show process stats
                echo "⚡ QEMU Process Stats:"
                ps -p "$qemu_pid" -o pid,%cpu,%mem,sz,rss,vsz,cmd --no-headers
                echo
                
                # Show memory usage
                echo "🧠 Memory Usage:"
                free -h
                echo
                
                # Show disk usage
                echo "💾 Disk Usage:"
                df -h "$IMG_FILE" 2>/dev/null || du -h "$IMG_FILE"
            else
                print_status "ERROR" "❌ Could not find QEMU process for VM $vm_name"
            fi
        else
            print_status "INFO" "💤 VM $vm_name is not running"
            echo "⚙️  Configuration:"
            echo "  🧠 Memory: $MEMORY MB"
            echo "  ⚡ CPUs: $CPUS"
            echo "  💾 Disk: $DISK_SIZE"
        fi
        echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to fix VM issues
fix_vm_issues() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "🔧 Fixing issues for VM: $vm_name"
        
        echo "🔧 Select issue to fix:"
        echo "  1) 🔓 Remove lock files"
        if [[ "$VM_TYPE" == "linux" ]]; then
            echo "  2) 🗑️  Recreate seed image"
        fi
        echo "  3) 🔄 Recreate configuration"
        echo "  4) 💀 Kill stuck processes"
        if [[ "$VM_TYPE" == "windows" ]]; then
            echo "  5) 🔄 Redownload Windows ISO"
            echo "  6) 🔄 Redownload VirtIO drivers"
        fi
        echo "  0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" fix_choice
        
        case $fix_choice in
            1)
                print_status "INFO" "🔓 Removing lock files..."
                rm -f "${IMG_FILE}.lock" 2>/dev/null
                rm -f "${IMG_FILE}"*.lock 2>/dev/null
                print_status "SUCCESS" "✅ Lock files removed"
                ;;
            2)
                if [[ "$VM_TYPE" == "linux" ]]; then
                    print_status "INFO" "🔄 Recreating seed image..."
                    if [[ -f "$SEED_FILE" ]]; then
                        rm -f "$SEED_FILE"
                    fi
                    setup_vm_image
                    print_status "SUCCESS" "✅ Seed image recreated"
                fi
                ;;
            3)
                print_status "INFO" "🔄 Recreating configuration..."
                save_vm_config
                print_status "SUCCESS" "✅ Configuration recreated"
                ;;
            4)
                print_status "INFO" "💀 Killing stuck processes..."
                pkill -f "qemu-system.*$IMG_FILE" 2>/dev/null
                sleep 1
                if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
                    pkill -9 -f "qemu-system.*$IMG_FILE" 2>/dev/null
                    print_status "SUCCESS" "✅ Forcefully killed stuck processes"
                else
                    print_status "INFO" "💤 No stuck processes found"
                fi
                ;;
            5)
                if [[ "$VM_TYPE" == "windows" ]]; then
                    print_status "WINDOWS" "🔄 Redownloading Windows ISO..."
                    if [[ -f "$ISO_FILE" ]]; then
                        rm -f "$ISO_FILE"
                    fi
                    setup_vm_image
                    print_status "SUCCESS" "✅ Windows ISO redownloaded"
                fi
                ;;
            6)
                if [[ "$VM_TYPE" == "windows" ]]; then
                    print_status "WINDOWS" "🔄 Redownloading VirtIO drivers..."
                    if [[ -f "$VIRTIO_DRIVERS" ]]; then
                        rm -f "$VIRTIO_DRIVERS"
                    fi
                    setup_vm_image
                    print_status "SUCCESS" "✅ VirtIO drivers redownloaded"
                fi
                ;;
            0)
                return 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid selection"
                ;;
        esac
    fi
}

# Function to show help
show_help() {
    display_header
    cat << EOF
📚 VM Manager Help
===================

Quick Start:
1. Create a new VM with option 1
2. Start the VM with option 2
3. Connect using appropriate method

Linux VMs:
• SSH: ssh -p <port> <username>@localhost
• Common ports: Ubuntu/Debian: 2222
• Username/Password: As set during creation

Windows 10 VM:
• Remote Desktop: localhost:3389
• Default: Administrator / Passw0rd!
• Requires Windows installation on first run

Key Features:
• Create, start, stop, delete VMs
• Support for Linux and Windows 10
• Edit VM configuration
• Resize disk on the fly
• Monitor performance
• Fix common issues
• Both GUI and console modes

Windows Notes:
• First boot installs Windows (takes 15-30 mins)
• VirtIO drivers for better performance
• RDP enabled for remote access
• 3.5GB ISO download required

Tips:
• Use Ctrl+A then X to exit QEMU console
• VMs are stored in: $VM_DIR
• Windows ISO stored in same directory

Troubleshooting:
• If VM won't start: Check 'Fix VM issues'
• If port in use: Change SSH port
• If out of space: Resize disk
• Windows slow? Increase RAM/CPUs
EOF
    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        if [ $vm_count -gt 0 ]; then
            print_status "INFO" "📁 Found $vm_count existing VM(s):"
            display_vm_table "${vms[@]}"
            echo
        else
            print_status "INFO" "📭 No VMs found. Create one to get started!"
            echo
        fi
        
        echo "📋 Main Menu:"
        echo "  1) 🆕 Create a new VM"
        if [ $vm_count -gt 0 ]; then
            echo "  2) 🚀 Start a VM"
            echo "  3) 🛑 Stop a VM"
            echo "  4) 📊 Show VM info"
            echo "  5) ✏️  Edit VM configuration"
            echo "  6) 🗑️  Delete a VM"
            echo "  7) 📈 Resize VM disk"
            echo "  8) 📊 Show VM performance"
            echo "  9) 🔧 Fix VM issues"
            echo "  h) 📚 Help"
        else
            echo "  2-9) (Create a VM first)"
            echo "  h) 📚 Help"
        fi
        echo "  0) 👋 Exit"
        echo
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🚀 Enter VM number to start: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🛑 Enter VM number to stop: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter VM number to show info: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "✏️  Enter VM number to edit: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🗑️  Enter VM number to delete: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📈 Enter VM number to resize disk: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        resize_vm_disk "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter VM number to show performance: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_performance "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            9)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🔧 Enter VM number to fix issues: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        fix_vm_issues "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            h|H)
                show_help
                ;;
            0)
                print_status "INFO" "👋 Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid option"
                ;;
        esac
        
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    done
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# Default settings for different VM types
linux_DISK_DEFAULT="20G"
linux_MEMORY_DEFAULT="2048"
linux_CPUS_DEFAULT="2"
windows_DISK_DEFAULT="64G"
windows_MEMORY_DEFAULT="4096"
windows_CPUS_DEFAULT="4"

# Supported OS list - NOW WITH WINDOWS 10!
declare -A OS_OPTIONS=(
    ["Windows 10 Lite Edition"]="windows|10lite|https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso|win10|Administrator|Passw0rd!"
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# Start the main menu
main_menu
