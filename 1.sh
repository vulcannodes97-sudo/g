#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 6.0 - Windows & Linux with VNC
# ============================================


# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables
declare -gA DETECTED_IMAGES
declare -gA MENU_OPTIONS
declare -g CONTAINER_COUNT=0

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            LXC/LXD Container Manager v6.0                    ║"
    echo "║         Windows 10/11 & Linux with VNC/RDP                   ║"
    echo "║               Mode BY - Nobita                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

# Default image database (fallback with Windows)
declare -A DEFAULT_IMAGES=(
    ["ubuntu:22.04"]="Ubuntu 22.04 Jammy"
    ["ubuntu:24.04"]="Ubuntu 24.04 Noble"
    ["debian/12"]="Debian 12 Bookworm"
    ["debian/11"]="Debian 11 Bullseye"
    ["almalinux/9"]="AlmaLinux 9"
    ["rockylinux/9"]="Rocky Linux 9"
    ["centos/stream-9"]="CentOS Stream 9"
    ["fedora/40"]="Fedora 40"
    ["archlinux"]="Arch Linux"
    ["opensuse/tumbleweed"]="openSUSE Tumbleweed"
    ["windows-10"]="Windows 10 Professional (Manual Setup)"
    ["windows-11"]="Windows 11 Professional (Manual Setup)"
)

# Function to show image selection menu
show_image_menu() {
    local total_images=$1
    
    print_header
    print_color "$CYAN" "📦 Available Container Images"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    local index=1
    declare -A local_menu_options
    
    # Show Windows images first (special section)
    print_color "$PURPLE" "🪟 Windows Images (VM only):"
    echo
    
    for image_key in "${!DEFAULT_IMAGES[@]}"; do
        if [[ "$image_key" == "windows-10" || "$image_key" == "windows-11" ]]; then
            local_menu_options[$index]="$image_key"
            print_color "$PURPLE" "  $index) ${DEFAULT_IMAGES[$image_key]}"
            print_color "$BLUE" "     💻 Requires: 4GB+ RAM, 50GB+ Disk, Manual ISO setup"
            echo
            ((index++))
        fi
    done
    
    # Show detected Linux images
    if [[ ${#DETECTED_IMAGES[@]} -gt 0 ]]; then
        print_color "$GREEN" "🔍 Auto-Detected Linux Images:"
        echo
        
        for image_key in "${!DETECTED_IMAGES[@]}"; do
            local_menu_options[$index]="$image_key"
            print_color "$GREEN" "  $index) ${DETECTED_IMAGES[$image_key]}"
            print_color "$BLUE" "     📦 Image: $image_key"
            echo
            ((index++))
        done
    fi
    
    # Show other Linux images
    print_color "$YELLOW" "📚 Other Linux Images:"
    echo
    
    for image_key in "${!DEFAULT_IMAGES[@]}"; do
        # Skip Windows and already shown images
        if [[ "$image_key" == "windows-10" || "$image_key" == "windows-11" ]] || \
           [[ -n "${DETECTED_IMAGES[$image_key]}" ]]; then
            continue
        fi
        
        local_menu_options[$index]="$image_key"
        print_color "$YELLOW" "  $index) ${DEFAULT_IMAGES[$image_key]}"
        print_color "$BLUE" "     📦 Image: $image_key"
        echo
        ((index++))
    done
    
    echo "══════════════════════════════════════════════════════════════"
    echo "  0) ↩️  Back to Main Menu"
    echo "  r) 🔄 Refresh Image List"
    echo "  s) 🔍 Search Images"
    echo "  w) 🪟 Windows Setup Guide"
    echo
    
    # Store menu options globally for selection
    MENU_OPTIONS=()
    for i in $(seq 1 $((index-1))); do
        MENU_OPTIONS[$i]="${local_menu_options[$i]}"
    done
    
    return $((index-1))
}

# Smart function to detect available images
detect_available_images() {
    print_header
    print_color "$CYAN" "🔍 Smart Image Detection"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    # Clear previous detected images
    DETECTED_IMAGES=()
    
    local total_found=0
    
    print_color "$BLUE" "📡 Checking LXD image remotes..."
    echo
    
    # Check if LXC is available
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        print_color "$YELLOW" "Please install LXC/LXD first (option 8 in main menu)"
        read -p "⏎ Press Enter to continue..."
        return 0
    fi
    
    # Method 1: Check if LXD is initialized
    if ! lxc cluster list 2>&1 | grep -q "no such file or directory" && \
       ! lxc cluster list 2>&1 | grep -q "not initialized"; then
        
        print_color "$GREEN" "✅ LXD is initialized. Checking images..."
        
        # Try to list local images
        print_color "$CYAN" "📥 Checking local images..."
        local local_images=$(timeout 5 lxc image list --format csv 2>/dev/null)
        
        if [[ -n "$local_images" ]]; then
            while IFS= read -r line; do
                IFS=',' read -r fingerprint alias description _ <<< "$line"
                
                if [[ -n "$alias" && "$alias" != "ALIAS" ]]; then
                    ((total_found++))
                    DETECTED_IMAGES["$alias"]="${description:-$alias}"
                    print_color "$GREEN" "  ✅ Local: $alias"
                fi
            done <<< "$local_images"
        fi
        
        # Method 2: Try to list from default remote (images:)
        print_color "$CYAN" "🌐 Checking cloud images..."
        
        local cloud_images=$(timeout 15 lxc image list images: --format csv 2>/dev/null | head -20)
        
        if [[ -n "$cloud_images" ]]; then
            while IFS= read -r line; do
                IFS=',' read -r fingerprint alias description _ <<< "$line"
                
                if [[ -n "$alias" && "$alias" != "ALIAS" && ! "$alias" =~ "fingerprint" ]]; then
                    ((total_found++))
                    local full_alias="images:$alias"
                    DETECTED_IMAGES["$full_alias"]="${description:-$alias}"
                    print_color "$GREEN" "  ✅ Cloud: $full_alias"
                fi
            done <<< "$cloud_images"
        else
            print_color "$YELLOW" "  ⚠️  Could not fetch cloud images"
            print_color "$CYAN" "    Trying common images directly..."
            
            # Test common images
            local common_images=(
                "ubuntu:22.04"
                "ubuntu:24.04"
                "debian/12"
                "centos/stream-9"
                "almalinux/9"
                "rockylinux/9"
                "archlinux"
            )
            
            for image in "${common_images[@]}"; do
                if timeout 10 lxc image show "images:$image" 2>/dev/null | grep -q "architecture"; then
                    ((total_found++))
                    DETECTED_IMAGES["images:$image"]="$image"
                    print_color "$GREEN" "    ✅ Available: $image"
                fi
            done
        fi
    else
        print_color "$YELLOW" "⚠️  LXD is not initialized or not ready"
        print_color "$CYAN" "💡 Please run 'lxd init --auto' first"
    fi
    
    # Always add Windows options (they need manual setup)
    DETECTED_IMAGES["windows-10"]="Windows 10 Professional (Manual Setup)"
    DETECTED_IMAGES["windows-11"]="Windows 11 Professional (Manual Setup)"
    total_found=$((total_found + 2))
    
    echo
    if [[ $total_found -gt 0 ]]; then
        print_color "$GREEN" "✅ Found $total_found available images"
    else
        print_color "$YELLOW" "⚠️  No images detected automatically"
        print_color "$CYAN" "💡 Using default image list"
    fi
    
    # Update container count
    if command -v lxc &> /dev/null; then
        CONTAINER_COUNT=$(lxc list --format csv 2>/dev/null | wc -l)
    fi
    
    return $total_found
}

# Function to install VNC in Linux container
install_vnc_linux() {
    local container_name=$1
    local vnc_password=$2
    local vnc_port=$3
    
    print_color "$CYAN" "👁️  Installing VNC on Linux container..."
    
    # Detect container OS
    local os_type="unknown"
    if lxc exec "$container_name" -- bash -c "command -v apt" &>/dev/null; then
        os_type="debian"
    elif lxc exec "$container_name" -- bash -c "command -v yum" &>/dev/null; then
        os_type="redhat"
    elif lxc exec "$container_name" -- bash -c "command -v dnf" &>/dev/null; then
        os_type="fedora"
    elif lxc exec "$container_name" -- bash -c "command -v pacman" &>/dev/null; then
        os_type="arch"
    fi
    
    case $os_type in
        debian)
            # Install for Debian/Ubuntu
            lxc exec "$container_name" -- bash -c "
                apt update && apt install -y tightvncserver xfce4 xfce4-goodies firefox
                mkdir -p ~/.vnc
                echo '$vnc_password' | vncpasswd -f > ~/.vnc/passwd
                chmod 600 ~/.vnc/passwd
                
                cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF
                chmod +x ~/.vnc/xstartup
                echo 'VNC server installed. Start with: vncserver :1 -geometry 1280x800' > /tmp/vnc-info.txt
            "
            ;;
        redhat|fedora)
            # Install for RHEL/CentOS/Fedora
            lxc exec "$container_name" -- bash -c "
                yum install -y tigervnc-server @xfce firefox || dnf install -y tigervnc-server @xfce-desktop firefox
                mkdir -p ~/.vnc
                echo '$vnc_password' | vncpasswd -f > ~/.vnc/passwd
                chmod 600 ~/.vnc/passwd
                echo 'VNC server installed.' > /tmp/vnc-info.txt
            "
            ;;
        arch)
            # Install for Arch Linux
            lxc exec "$container_name" -- bash -c "
                pacman -Syu --noconfirm tigervnc xfce4 xfce4-goodies firefox
                mkdir -p ~/.vnc
                echo '$vnc_password' | vncpasswd -f > ~/.vnc/passwd
                chmod 600 ~/.vnc/passwd
                echo 'VNC server installed.' > /tmp/vnc-info.txt
            "
            ;;
        *)
            print_color "$YELLOW" "⚠️  Unknown OS type. VNC installation may require manual setup."
            return 1
            ;;
    esac
    
    # Configure VNC port in container
    lxc config device add "$container_name" vncproxy proxy \
        listen="tcp:0.0.0.0:$vnc_port" \
        connect="tcp:127.0.0.1:5901" 2>/dev/null || true
    
    print_color "$GREEN" "✅ VNC server installed in container"
    print_color "$CYAN" "💡 To start VNC: lxc exec $container_name -- vncserver :1"
    print_color "$CYAN" "💡 Connect via: VNC viewer to host port $vnc_port"
    
    return 0
}

# Function to configure Windows VM for RDP
configure_windows_rdp() {
    local vm_name=$1
    
    print_color "$PURPLE" "🪟 Configuring Windows VM for RDP..."
    
    # Add VirtIO devices for better performance
    lxc config device add "$vm_name" root disk path=/ pool=default 2>/dev/null || true
    
    # Configure display (SPICE for better Windows support)
    lxc config device add "$vm_name" spice serial= spice.agent.enabled=true \
        listen=type=address,address=0.0.0.0,port=5900 2>/dev/null || true
    
    # Add GPU support
    lxc config device add "$vm_name" gpu gpu \
        driver=virtio-gpu accel3d=true 2>/dev/null || true
    
    # Enable RDP port forwarding
    lxc config device add "$vm_name" rdpproxy proxy \
        listen="tcp:0.0.0.0:3389" \
        connect="tcp:127.0.0.1:3389" 2>/dev/null || true
    
    print_color "$GREEN" "✅ Windows VM configured for remote access"
    print_color "$CYAN" "💡 Remote Desktop (RDP): Connect to host port 3389"
    print_color "$CYAN" "💡 SPICE/VNC: Connect to host port 5900"
    print_color "$YELLOW" "⚠️  Note: You need to enable RDP in Windows settings"
}

# Function to create Windows VM from ISO
create_windows_vm_from_iso() {
    local vm_name=$1
    local windows_version=$2
    
    print_header
    print_color "$PURPLE" "🪟 Windows VM Creation Wizard"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    print_color "$YELLOW" "📋 Windows VM Requirements:"
    echo "  • 4GB+ RAM (8GB recommended)"
    echo "  • 50GB+ disk space"
    echo "  • Windows ISO file"
    echo "  • Virtualization enabled in BIOS"
    echo
    
    read -p "Do you have Windows ISO ready? (y/N): " has_iso
    if [[ ! "$has_iso" =~ ^[Yy]$ ]]; then
        print_color "$RED" "❌ You need Windows ISO to create Windows VM"
        print_color "$CYAN" "💡 Download Windows ISO from Microsoft website"
        read -p "⏎ Press Enter to continue..."
        return 1
    fi
    
    read -p "📁 Path to Windows ISO: " iso_path
    if [[ ! -f "$iso_path" ]]; then
        print_color "$RED" "❌ ISO file not found: $iso_path"
        read -p "⏎ Press Enter to continue..."
        return 1
    fi
    
    # Get resources
    echo
    print_color "$CYAN" "⚙️  VM Resource Configuration:"
    read -p "💾 Disk size (default: 50GB): " disk_size
    disk_size=${disk_size:-50GB}
    
    read -p "🧠 Memory (default: 4GB): " memory
    memory=${memory:-4GB}
    
    read -p "⚡ CPU cores (default: 2): " cpu_count
    cpu_count=${cpu_count:-2}
    
    # Create empty VM
    print_color "$BLUE" "🔄 Creating Windows VM..."
    lxc init images:empty --vm "$vm_name" 2>/dev/null || lxc init --vm "$vm_name" --empty
    
    # Attach ISO as CD-ROM
    lxc config device add "$vm_name" iso disk \
        source="$iso_path" \
        boot.priority=10
    
    # Configure resources
    lxc config set "$vm_name" limits.cpu="$cpu_count"
    lxc config set "$vm_name" limits.memory="$memory"
    lxc config device override "$vm_name" root size="$disk_size"
    
    # Configure for Windows
    lxc config set "$vm_name" security.secureboot=false
    
    print_color "$GREEN" "✅ Windows VM '$vm_name' created!"
    echo
    print_color "$CYAN" "📋 Next steps:"
    echo "  1. Start VM: lxc start $vm_name"
    echo "  2. Connect to console: lxc console $vm_name"
    echo "  3. Complete Windows installation"
    echo "  4. Install VirtIO drivers from ISO"
    echo "  5. Enable RDP in Windows settings"
    echo
    
    # Configure RDP
    read -p "Configure RDP access now? (Y/n): " configure_rdp
    configure_rdp=${configure_rdp:-Y}
    
    if [[ "$configure_rdp" =~ ^[Yy]$ ]]; then
        configure_windows_rdp "$vm_name"
    fi
    
    read -p "⏎ Press Enter to continue..."
    return 0
}

# Function to create container
create_container() {
    # Detect available images first
    detect_available_images
    local total_images=$?
    
    if [[ $total_images -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  No images available. Please check LXD installation."
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    while true; do
        show_image_menu "$total_images"
        read -p "🎯 Select image (1-$total_images) or 0/r/s/w: " image_choice
        
        case $image_choice in
            0)
                return
                ;;
            r|R)
                detect_available_images
                total_images=$?
                continue
                ;;
            s|S)
                # Implement search function
                print_color "$YELLOW" "🔍 Search function coming soon..."
                sleep 2
                continue
                ;;
            w|W)
                show_windows_guide
                continue
                ;;
        esac
        
        # Validate selection
        if [[ -z "${MENU_OPTIONS[$image_choice]}" ]]; then
            print_color "$RED" "❌ Invalid selection!"
            sleep 2
            continue
        fi
        
        local selected_image="${MENU_OPTIONS[$image_choice]}"
        local display_name=""
        
        # Get display name
        if [[ -n "${DETECTED_IMAGES[$selected_image]}" ]]; then
            display_name="${DETECTED_IMAGES[$selected_image]}"
        elif [[ -n "${DEFAULT_IMAGES[$selected_image]}" ]]; then
            display_name="${DEFAULT_IMAGES[$selected_image]}"
        else
            display_name="$selected_image"
        fi
        
        break
    done
    
    print_header
    print_color "$CYAN" "🚀 Creating: $display_name"
    print_color "$BLUE" "📦 Image: $selected_image"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    # Get container name
    while true; do
        read -p "🏷️  Enter container/VM name: " container_name
        
        if [[ -z "$container_name" ]]; then
            print_color "$RED" "❌ Name cannot be empty!"
            continue
        fi
        
        if [[ ! "$container_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]{1,}$ ]]; then
            print_color "$RED" "❌ Invalid name! Use letters, numbers, hyphens, underscores"
            continue
        fi
        
        # Check if exists
        if lxc list -c n --format csv 2>/dev/null | grep -q "^$container_name$"; then
            print_color "$RED" "❌ '$container_name' already exists!"
            read -p "Use different name? (y/N): " rename_choice
            if [[ ! "$rename_choice" =~ ^[Yy]$ ]]; then
                return
            fi
            continue
        fi
        
        break
    done
    
    # Check if Windows image
    local is_windows=false
    if [[ "$selected_image" == "windows-10" || "$selected_image" == "windows-11" ]]; then
        is_windows=true
    fi
    
    # For Windows, use special setup
    if [ "$is_windows" = true ]; then
        create_windows_vm_from_iso "$container_name" "$selected_image"
        return
    fi
    
    # For Linux containers
    echo
    print_color "$YELLOW" "💻 Container Type:"
    echo "  1) Container (Default) - Lightweight, shares host kernel"
    echo "  2) Virtual Machine - Full VM with isolated kernel"
    
    read -p "Select type (1-2, default: 1): " container_type
    container_type=${container_type:-1}
    
    local type_flag=""
    case $container_type in
        1) 
            type_flag=""
            print_color "$GREEN" "📦 Selected: Container"
            ;;
        2) 
            type_flag="--vm"
            print_color "$PURPLE" "💻 Selected: Virtual Machine"
            ;;
        *) 
            type_flag=""
            print_color "$YELLOW" "⚠️  Using default: Container"
            ;;
    esac
    
    # Get resources
    echo
    print_color "$CYAN" "⚙️  Resource Configuration:"
    read -p "💾 Disk size (default: 10GB): " disk_size
    disk_size=${disk_size:-10GB}
    
    read -p "🧠 Memory (default: 2GB): " memory
    memory=${memory:-2GB}
    
    read -p "⚡ CPU cores (default: 2): " cpu_count
    cpu_count=${cpu_count:-2}
    
    # VNC configuration
    local enable_vnc=false
    local vnc_password=""
    local vnc_port="5901"
    
    echo
    print_color "$CYAN" "👁️  Remote Access:"
    read -p "Enable VNC remote desktop? (y/N): " vnc_choice
    
    if [[ "$vnc_choice" =~ ^[Yy]$ ]]; then
        enable_vnc=true
        read -p "🔒 VNC password (default: vncpassword): " vnc_password
        vnc_password=${vnc_password:-vncpassword}
        
        read -p "🔌 VNC port (default: 5901): " vnc_port
        vnc_port=${vnc_port:-5901}
    fi
    
    # Summary
    echo
    print_color "$CYAN" "📋 Creation Summary:"
    echo "──────────────────────────────────────"
    echo "🏷️  Name: $container_name"
    echo "📦 Image: $selected_image"
    echo "💻 Type: $([ "$type_flag" == "--vm" ] && echo "VM" || echo "Container")"
    echo "💾 Disk: $disk_size"
    echo "🧠 Memory: $memory"
    echo "⚡ CPU: $cpu_count cores"
    [ "$enable_vnc" = true ] && echo "👁️  VNC: Port $vnc_port"
    echo "──────────────────────────────────────"
    echo
    
    read -p "✅ Proceed with creation? (Y/n): " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  Creation cancelled."
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Create container
    print_color "$BLUE" "🔄 Creating container..."
    
    if [[ "$selected_image" == images:* ]]; then
        # Image already has remote prefix
        lxc launch $type_flag "$selected_image" "$container_name"
    elif lxc image show "images:$selected_image" &>/dev/null; then
        # Try with images: prefix
        lxc launch $type_flag "images:$selected_image" "$container_name"
    else
        # Try without prefix
        lxc launch $type_flag "$selected_image" "$container_name"
    fi
    
    if [[ $? -ne 0 ]]; then
        print_color "$RED" "❌ Failed to create container!"
        echo
        print_color "$YELLOW" "💡 Troubleshooting:"
        echo "1. Check if LXD is initialized: lxd init --auto"
        echo "2. Check image availability: lxc image list images:"
        echo "3. Try different image name"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Configure resources
    lxc config set "$container_name" limits.cpu="$cpu_count"
    lxc config set "$container_name" limits.memory="$memory"
    lxc config device override "$container_name" root size="$disk_size"
    
    # Install VNC if requested
    if [ "$enable_vnc" = true ]; then
        print_color "$CYAN" "🔄 Installing VNC..."
        install_vnc_linux "$container_name" "$vnc_password" "$vnc_port"
    fi
    
    # Wait and show info
    sleep 3
    echo
    print_color "$GREEN" "✅ Container '$container_name' created successfully!"
    
    # Show IP and connection info
    local container_ip=$(lxc list "$container_name" -c 4 --format csv 2>/dev/null | head -1)
    
    if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
        print_color "$BLUE" "🌐 IP Address: $container_ip"
        echo
        
        # Determine default user
        local default_user="root"
        if [[ "$selected_image" =~ ubuntu ]]; then
            default_user="ubuntu"
        elif [[ "$selected_image" =~ debian ]]; then
            default_user="debian"
        fi
        
        print_color "$CYAN" "🔗 Connection Info:"
        echo "  SSH: ssh $default_user@$container_ip"
        [ "$enable_vnc" = true ] && echo "  VNC: Connect to host port $vnc_port"
    fi
    
    # Offer shell access
    echo
    if [ "$enable_vnc" != true ]; then
        read -p "💻 Open shell in container? (y/N): " open_shell
        if [[ "$open_shell" =~ ^[Yy]$ ]]; then
            echo "📝 Type 'exit' to return"
            lxc exec "$container_name" -- /bin/bash || lxc exec "$container_name" -- /bin/sh
        fi
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to show Windows setup guide
show_windows_guide() {
    print_header
    print_color "$PURPLE" "🪟 Windows VM Setup Guide"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    print_color "$CYAN" "📋 Prerequisites:"
    echo "──────────────────────────────────────"
    echo "✅ 1. Virtualization enabled in BIOS"
    echo "✅ 2. Windows ISO file (from Microsoft)"
    echo "✅ 3. At least 8GB RAM recommended"
    echo "✅ 4. 50GB+ free disk space"
    echo
    
    print_color "$GREEN" "📥 Step 1: Download Windows ISO"
    echo "• Windows 10: https://www.microsoft.com/software-download/windows10"
    echo "• Windows 11: https://www.microsoft.com/software-download/windows11"
    echo
    
    print_color "$BLUE" "⚙️  Step 2: Create Windows VM"
    echo "1. Select 'Windows 10' or 'Windows 11' from image list"
    echo "2. Enter VM name and path to ISO"
    echo "3. Set resources (min: 4GB RAM, 50GB disk)"
    echo
    
    print_color "$YELLOW" "🔧 Step 3: Install Windows"
    echo "1. Start VM: lxc start <vm-name>"
    echo "2. Connect to console: lxc console <vm-name>"
    echo "3. Complete Windows installation"
    echo "4. Install VirtIO drivers for better performance"
    echo
    
    print_color "$PURPLE" "👁️  Step 4: Enable Remote Access"
    echo "• RDP: Built-in to Windows"
    echo "• VNC: Optional for Linux hosts"
    echo "• SPICE: Best for Linux hosts with virt-viewer"
    echo
    
    print_color "$RED" "⚠️  Important Notes:"
    echo "• Windows requires license activation"
    echo "• Regular Windows updates recommended"
    echo "• Enable Windows Defender for security"
    echo "• Create snapshots before major changes"
    
    echo
    read -p "⏎ Press Enter to continue..."
}

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Dependencies..."
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$ID
    else
        print_color "$RED" "❌ Cannot detect OS!"
        exit 1
    fi
    
    print_color "$BLUE" "📊 Detected: $PRETTY_NAME"
    echo
    
    case $OS_NAME in
        ubuntu|debian)
            print_color "$GREEN" "📦 Installing for Ubuntu/Debian..."
            echo
            
            # Update
            sudo apt update -y
            
            # Install LXC
            sudo apt install -y lxc lxc-utils bridge-utils uidmap
            
            # Install virtualization tools for Windows
            sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
                virtinst virt-manager
            
            # Install VNC tools
            sudo apt install -y tigervnc-viewer novnc websockify
            
            # Install snap for LXD
            if ! command -v snap &> /dev/null; then
                sudo apt install -y snapd
                sudo systemctl enable --now snapd.socket
            fi
            
            # Install LXD
            sudo snap install lxd
            
            # Add user to groups
            sudo usermod -aG lxd $USER
            sudo usermod -aG kvm $USER 2>/dev/null || true
            sudo usermod -aG libvirt $USER 2>/dev/null || true
            
            # Initialize LXD
            sudo lxd init --auto
            
            print_color "$GREEN" "✅ Dependencies installed!"
            echo
            print_color "$YELLOW" "⚠️  Log out and back in for group changes!"
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS"
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        print_header
        
        print_color "$GREEN" "🏠 Main Menu"
        print_color "$BLUE" "📦 Active Containers: $CONTAINER_COUNT"
        echo "══════════════════════════════════════════════════════════════"
        echo
        
        echo "  1) 🚀 Create New Container/VM"
        echo "  2) 📋 List Containers"
        echo "  3) ⚙️  Manage Container"
        echo "  4) 🪟 Windows Setup Guide"
        echo "  5) 🔧 Check Installation"
        echo "  6) 📊 System Info"
        echo "  7) ⚡ Install Dependencies"
        echo "  0) 👋 Exit"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1) 
                create_container 
                # Refresh container count
                if command -v lxc &> /dev/null; then
                    CONTAINER_COUNT=$(lxc list --format csv 2>/dev/null | wc -l)
                fi
                ;;
            2) 
                print_header
                print_color "$CYAN" "📋 Container List"
                echo "══════════════════════════════════════════════════════════════"
                echo
                lxc list 2>/dev/null || print_color "$RED" "❌ LXC not available"
                read -p "⏎ Press Enter to continue..."
                ;;
            3) 
                print_color "$YELLOW" "⚙️  Management coming soon..."
                sleep 2
                ;;
            4) 
                show_windows_guide
                ;;
            5) 
                print_header
                print_color "$CYAN" "🔧 System Check"
                echo "══════════════════════════════════════════════════════════════"
                echo
                if command -v lxc &> /dev/null; then
                    print_color "$GREEN" "✅ LXC installed"
                    lxc --version
                else
                    print_color "$RED" "❌ LXC not installed"
                fi
                echo
                read -p "⏎ Press Enter to continue..."
                ;;
            6) 
                print_header
                print_color "$CYAN" "📊 System Information"
                echo "══════════════════════════════════════════════════════════════"
                echo
                echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
                echo "Kernel: $(uname -r)"
                echo "CPU: $(nproc) cores"
                echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
                echo
                read -p "⏎ Press Enter to continue..."
                ;;
            7) 
                install_dependencies
                ;;
            0)
                print_header
                print_color "$GREEN" "👋 Goodbye! Happy containerizing! 🐳"
                echo
                exit 0
                ;;
            *)
                print_color "$RED" "❌ Invalid option!"
                sleep 1
                ;;
        esac
    done
}

# Main function
main() {
    # Check terminal
    if [[ ! -t 0 ]]; then
        print_color "$RED" "❌ Run in terminal!"
        exit 1
    fi
    
    # Welcome
    print_header
    print_color "$GREEN" "🌟 Welcome to LXC/LXD Container Manager v6.0"
    print_color "$PURPLE" "🪟 Windows 10/11 & Linux with VNC/RDP support"
    echo
    
    # Check if LXC installed
    if ! command -v lxc &> /dev/null; then
        print_color "$YELLOW" "⚠️  LXC/LXD not detected"
        read -p "Install dependencies now? (Y/n): " install_now
        install_now=${install_now:-Y}
        
        if [[ "$install_now" =~ ^[Yy]$ ]]; then
            install_dependencies
            print_color "$GREEN" "✅ Please log out and log back in, then run script again"
            exit 0
        fi
    fi
    
    # Initial detection
    detect_available_images
    
    # Start menu
    main_menu
}

# Run
main
