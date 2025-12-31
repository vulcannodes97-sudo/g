#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 4.0 - Auto Image Detection + Windows RDP
# ============================================


# if you use Ubuntu


# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          LXC/LXD Container Manager + RDP                ║"
    echo "║               Mode BY - Nobita                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
}

# Default image database (fallback) - Added Windows images
declare -A DEFAULT_IMAGES=(
    ["1"]="ubuntu:22.04|Ubuntu 22.04 Jammy"
    ["2"]="almalinux/9|AlmaLinux 9"
    ["3"]="centos/stream-9|CentOS Stream 9"
    ["4"]="ubuntu:24.04|Ubuntu 24.04 Noble"
    ["5"]="rockylinux/9|Rocky Linux 9"
    ["6"]="fedora/40|Fedora 40"
    ["7"]="debian/11|Debian 11 Bullseye"
    ["8"]="debian/trixie-daily|Debian 13 Trixie"
    ["9"]="debian/12|Debian 12 Bookworm"
    ["10"]="windows:win10-ltsc|Windows 10 LTSC (via Distrobuilder)"
    ["11"]="windows:win11|Windows 11 (via Distrobuilder)"
)

# Function to check Windows RDP support
check_windows_rdp_support() {
    print_color "$CYAN" "🔍 Checking Windows RDP requirements..."
    
    # Check if we have necessary Windows images
    local has_windows_support=false
    
    # Check for Windows images from various sources
    print_color "$BLUE" "📦 Looking for Windows images..."
    
    # Check for Windows images from community
    if lxc image list images: | grep -i "windows" | head -5; then
        print_color "$GREEN" "✅ Windows images available"
        has_windows_support=true
    else
        print_color "$YELLOW" "⚠️  No Windows images found in default repository"
    fi
    
    # Check for distrobuilder (for creating Windows images)
    if command -v distrobuilder &> /dev/null; then
        print_color "$GREEN" "✅ Distrobuilder is installed (for custom Windows images)"
        has_windows_support=true
    else
        print_color "$YELLOW" "📝 Note: Install distrobuilder for custom Windows images:"
        echo "  snap install distrobuilder --classic"
    fi
    
    echo
    return 0
}

# Function to setup Windows RDP container
setup_windows_rdp() {
    local container_name=$1
    local windows_version=$2  # win10 or win11
    
    print_color "$CYAN" "🖥️  Setting up Windows RDP for $container_name..."
    echo "══════════════════════════════════════════════════════════"
    
    # Important note about Windows licensing
    print_color "$RED" "⚠️  IMPORTANT LEGAL NOTICE:"
    print_color "$YELLOW" "========================================"
    echo "Windows requires a valid license for use."
    echo "This setup is for TESTING and EVALUATION only."
    echo "You must provide your own Windows ISO and license."
    echo "========================================"
    echo
    
    read -p "📋 Do you have a valid Windows license? (y/N): " has_license
    if [[ ! "$has_license" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  Windows RDP setup cancelled."
        return 1
    fi
    
    # Method selection
    print_color "$BLUE" "🔄 Choose Windows RDP method:"
    echo "  1) Use pre-built Windows LXD image (if available)"
    echo "  2) Create Windows VM with virt-manager (Recommended)"
    echo "  3) Manual Windows VM setup"
    echo
    
    read -p "🎯 Select method (1-3): " method
    
    case $method in
        1)
            setup_windows_lxd_image "$container_name" "$windows_version"
            ;;
        2)
            setup_windows_virt_manager "$container_name" "$windows_version"
            ;;
        3)
            manual_windows_setup_guide
            ;;
        *)
            print_color "$RED" "❌ Invalid selection"
            return 1
            ;;
    esac
}

# Setup Windows using LXD image (if available)
setup_windows_lxd_image() {
    local container_name=$1
    local windows_version=$2
    
    print_color "$BLUE" "📦 Looking for Windows LXD images..."
    
    # Search for Windows images
    local windows_images=$(lxc image list images: | grep -i "windows" | head -5)
    
    if [[ -z "$windows_images" ]]; then
        print_color "$RED" "❌ No Windows images found in LXD repository"
        print_color "$YELLOW" "💡 Alternative options:"
        echo "  1. Use virt-manager for better Windows support"
        echo "  2. Build Windows image manually with distrobuilder"
        echo "  3. Use Windows Subsystem for Linux 2 (WSL2)"
        return 1
    fi
    
    echo "$windows_images"
    echo
    
    read -p "🔗 Enter Windows image name (from above): " win_image
    
    if [[ -z "$win_image" ]]; then
        print_color "$RED" "❌ No image selected"
        return 1
    fi
    
    # Create Windows container (VM)
    print_color "$GREEN" "🚀 Creating Windows VM..."
    
    # Create as VM (Windows requires full virtualization)
    if ! lxc launch images:"$win_image" "$container_name" --vm; then
        print_color "$RED" "❌ Failed to create Windows VM"
        print_color "$YELLOW" "💡 Try: lxc launch images:$win_image $container_name --vm --storage=your-storage-pool"
        return 1
    fi
    
    # Configure resources for Windows
    print_color "$BLUE" "⚙️  Configuring Windows VM resources..."
    lxc config set "$container_name" limits.cpu=4
    lxc config set "$container_name" limits.memory=8GB
    lxc config device override "$container_name" root size=50GB
    
    # Enable RDP
    print_color "$BLUE" "🌐 Enabling RDP..."
    lxc config device add "$container_name" rdp proxy listen=tcp:0.0.0.0:3389 connect=tcp:127.0.0.1:3389
    
    # Get IP address
    local vm_ip=""
    for i in {1..30}; do
        vm_ip=$(lxc list "$container_name" -c 4 --format csv)
        if [[ -n "$vm_ip" && "$vm_ip" != "-" ]]; then
            break
        fi
        echo "⏳ Waiting for IP address... ($i/30)"
        sleep 2
    done
    
    if [[ -n "$vm_ip" && "$vm_ip" != "-" ]]; then
        print_color "$GREEN" "✅ Windows VM created!"
        print_color "$CYAN" "🖥️  RDP Connection Details:"
        echo "  IP Address: $vm_ip"
        echo "  Port: 3389"
        echo "  Username: Administrator (default)"
        echo "  Password: Will be shown in VM console"
        echo
        print_color "$YELLOW" "📝 Next steps:"
        echo "  1. Connect via RDP: xfreerdp /v:$vm_ip"
        echo "  2. Or use: rdesktop $vm_ip"
        echo "  3. Install your Windows license"
        echo "  4. Change Administrator password"
    else
        print_color "$YELLOW" "⚠️  VM created but no IP assigned yet"
        echo "  Check: lxc console $container_name"
    fi
}

# Setup Windows using virt-manager (better for Windows)
setup_windows_virt_manager() {
    local container_name=$1
    local windows_version=$2
    
    print_color "$GREEN" "🎯 Recommended: Using virt-manager for Windows"
    echo "══════════════════════════════════════════════════════════"
    
    # Check for virt-manager
    if ! command -v virt-manager &> /dev/null; then
        print_color "$YELLOW" "📦 Installing virt-manager..."
        
        if [[ -f /etc/debian_version ]]; then
            sudo apt update
            sudo apt install -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
            sudo adduser $USER libvirt
            sudo adduser $USER libvirt-qemu
        elif [[ -f /etc/redhat-release ]]; then
            sudo dnf install -y virt-manager qemu-kvm libvirt
            sudo systemctl enable --now libvirtd
            sudo usermod -aG libvirt $USER
        fi
        
        print_color "$GREEN" "✅ virt-manager installed"
        print_color "$YELLOW" "⚠️  Log out and log back in for group changes"
    fi
    
    print_color "$BLUE" "📋 Windows VM Creation Guide:"
    echo "────────────────────────────────────────────"
    echo "1. Open virt-manager:"
    echo "   $ virt-manager"
    echo
    echo "2. Create new virtual machine:"
    echo "   • Click 'Create New Virtual Machine'"
    echo "   • Choose 'Local install media'"
    echo "   • Browse to your Windows ISO file"
    echo
    echo "3. Configure resources:"
    echo "   • RAM: 4096 MB or more"
    echo "   • CPUs: 2 or more"
    echo "   • Storage: 50GB or more"
    echo
    echo "4. Enable RDP in Windows:"
    echo "   • Open Windows Settings"
    echo "   • Go to System > Remote Desktop"
    echo "   • Enable 'Remote Desktop'"
    echo
    echo "5. Get IP address:"
    echo "   • In Windows, run: ipconfig"
    echo "   • Note the IPv4 address"
    echo
    print_color "$CYAN" "🔗 RDP Connection Command:"
    echo "  xfreerdp /v:[WINDOWS_IP] /u:Administrator"
    echo "  or"
    echo "  rdesktop [WINDOWS_IP]"
    
    read -p "⏎ Press Enter when ready to continue..."
}

# Manual Windows setup guide
manual_windows_setup_guide() {
    print_color "$CYAN" "📖 Manual Windows VM Setup Guide"
    echo "══════════════════════════════════════════════════════════"
    
    cat << 'EOF'

1. Download Windows ISO:
   • Windows 10: https://www.microsoft.com/software-download/windows10
   • Windows 11: https://www.microsoft.com/software-download/windows11

2. Install KVM/QEMU:
   Ubuntu/Debian:
     sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
   
   CentOS/RHEL:
     sudo dnf install qemu-kvm libvirt virt-install virt-manager
   
   Enable service:
     sudo systemctl enable --now libvirtd
     sudo usermod -aG libvirt $USER

3. Create Windows VM:
   Using virt-install:
     sudo virt-install \
       --name windows10-vm \
       --ram 4096 \
       --vcpus 2 \
       --disk size=50 \
       --os-variant win10 \
       --network bridge=virbr0 \
       --graphics spice \
       --cdrom /path/to/windows10.iso

4. Windows Setup:
   • Follow Windows installation wizard
   • When asked, enter your product key
   • Create user account

5. Enable RDP in Windows:
   • Open Settings > System > Remote Desktop
   • Turn on "Enable Remote Desktop"
   • Note the PC name for connection

6. Find VM IP:
   In Windows, open Command Prompt:
     ipconfig | findstr IPv4

7. Connect via RDP:
   On Linux host:
     xfreerdp /v:[WINDOWS_IP] /u:YourUsername
   
   Or install remmina:
     sudo apt install remmina remmina-plugin-rdp
     remmina

8. Security Note:
   • Change default Administrator password
   • Enable Windows Firewall
   • Install updates immediately

EOF
    
    print_color "$YELLOW" "📝 Quick RDP command generator:"
    read -p "Enter Windows VM IP: " win_ip
    if [[ -n "$win_ip" ]]; then
        echo
        print_color "$GREEN" "🔗 RDP Connection Commands:"
        echo "  xfreerdp /v:$win_ip /u:Administrator +clipboard /dynamic-resolution"
        echo "  rdesktop -u Administrator -p - $win_ip"
        echo "  remmina -c rdp://$win_ip"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Enhanced create_container function with Windows support
create_container() {
    # Detect available images first
    detect_available_images
    
    # Check for Windows RDP support
    check_windows_rdp_support
    
    while true; do
        show_image_menu
        read -p "🎯 Select image (1-${#AVAILABLE_IMAGES[@]}) or 0/r: " image_choice
        
        case $image_choice in
            0)
                return
                ;;
            r|R)
                detect_available_images
                continue
                ;;
        esac
        
        if [[ -n "${AVAILABLE_IMAGES[$image_choice]}" ]]; then
            IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$image_choice]}"
            break
        else
            print_color "$RED" "❌ Invalid selection!"
            sleep 2
        fi
    done
    
    print_header
    print_color "$CYAN" "🚀 Creating Container: $display_name"
    print_color "$BLUE" "📦 Image: $image_name"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Check if this is a Windows image
    local is_windows=false
    if [[ "$image_name" =~ [Ww]indows ]] || [[ "$display_name" =~ [Ww]indows ]]; then
        is_windows=true
        print_color "$YELLOW" "🖥️  Windows image detected - RDP setup available"
    fi
    
    # Get container name
    while true; do
        read -p "🏷️  Enter container name: " container_name
        
        # Check if empty
        if [[ -z "$container_name" ]]; then
            print_color "$RED" "❌ Container name cannot be empty!"
            continue
        fi
        
        # Validate name format
        if [[ ! "$container_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]{1,}$ ]]; then
            print_color "$RED" "❌ Invalid name! Must start with letter, can contain letters, numbers, hyphens, underscores"
            continue
        fi
        
        # Check if container already exists
        if lxc list -c n --format csv 2>/dev/null | grep -q "^$container_name$"; then
            print_color "$RED" "❌ Container '$container_name' already exists!"
            
            read -p "🔄 Use different name? (y/N): " rename_choice
            if [[ ! "$rename_choice" =~ ^[Yy]$ ]]; then
                return
            fi
            continue
        fi
        
        break
    done
    
    # Get container type
    echo
    print_color "$YELLOW" "💻 Container Type:"
    echo "  1) Container (Default) - Lightweight, shares host kernel"
    echo "  2) Virtual Machine - Full VM with its own kernel"
    
    if [[ "$is_windows" == true ]]; then
        print_color "$RED" "  ⚠️  Windows requires Virtual Machine (Option 2)"
    fi
    
    read -p "Select type (1-2, default: 1): " container_type
    container_type=${container_type:-1}
    
    local type_flag=""
    case $container_type in
        1) 
            if [[ "$is_windows" == true ]]; then
                print_color "$RED" "❌ Windows cannot run as container! Switching to VM mode."
                container_type=2
                type_flag="--vm"
                sleep 2
            else
                type_flag=""
                print_color "$BLUE" "📦 Selected: Container (lightweight)"
            fi
            ;;
        2) 
            type_flag="--vm"
            print_color "$BLUE" "💻 Selected: Virtual Machine"
            ;;
        *) 
            type_flag=""
            print_color "$YELLOW" "⚠️  Using default: Container"
            ;;
    esac
    
    # Get resources
    echo
    print_color "$YELLOW" "⚙️  Resource Configuration:"
    
    if [[ "$is_windows" == true ]]; then
        print_color "$RED" "⚠️  Windows requires minimum 2GB RAM, 20GB disk"
        disk_size_default="50GB"
        memory_default="4GB"
        cpu_default="2"
    else
        disk_size_default="10GB"
        memory_default="2GB"
        cpu_default="2"
    fi
    
    read -p "💾 Disk size (default: $disk_size_default): " disk_size
    disk_size=${disk_size:-$disk_size_default}
    
    read -p "🧠 Memory (default: $memory_default): " memory
    memory=${memory:-$memory_default}
    
    read -p "⚡ CPU cores (default: $cpu_default): " cpu_count
    cpu_count=${cpu_count:-$cpu_default}
    
    # For Windows, ask about RDP setup
    local setup_rdp=false
    if [[ "$is_windows" == true ]]; then
        echo
        print_color "$CYAN" "🌐 Remote Desktop (RDP) Setup"
        read -p "Configure RDP access for this Windows VM? (Y/n): " setup_rdp_choice
        setup_rdp_choice=${setup_rdp_choice:-Y}
        
        if [[ "$setup_rdp_choice" =~ ^[Yy]$ ]]; then
            setup_rdp=true
        fi
    fi
    
    # Summary
    echo
    print_color "$CYAN" "📋 Creation Summary:"
    echo "──────────────────────────────────────"
    echo "🏷️  Name: $container_name"
    echo "📦 Image: $image_name"
    echo "💻 Type: $([ "$type_flag" == "--vm" ] && echo "Virtual Machine" || echo "Container")"
    echo "💾 Disk: $disk_size"
    echo "🧠 Memory: $memory"
    echo "⚡ CPU: $cpu_count cores"
    
    if [[ "$is_windows" == true && "$setup_rdp" == true ]]; then
        echo "🌐 RDP: Enabled (Port 3389)"
    fi
    
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
    print_color "$BLUE" "📦 Creating container '$container_name'..."
    echo
    
    # Try different approaches to launch container
    local launch_success=false
    
    # Approach 1: Direct launch
    print_color "$CYAN" "🔄 Attempt 1: Direct launch..."
    if lxc launch $type_flag "$image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
        launch_success=true
    else
        # For Windows images, try special handling
        if [[ "$is_windows" == true ]]; then
            print_color "$YELLOW" "🔄 Windows image detected, trying alternative..."
            
            # Check if we need to add images: prefix
            if [[ ! "$image_name" =~ ^images: ]]; then
                local image_with_prefix="images:$image_name"
                print_color "$BLUE" "   Trying: $image_with_prefix"
                if lxc launch $type_flag "$image_with_prefix" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                    launch_success=true
                fi
            fi
        else
            # For Linux images, try other approaches
            local error_msg=$(cat /tmp/lxc_launch.log)
            
            # Approach 2: Try with images: prefix
            if [[ "$error_msg" == *"not found"* ]] || [[ "$error_msg" == *"couldn't be found"* ]]; then
                print_color "$YELLOW" "🔄 Attempt 2: Trying with 'images:' prefix..."
                
                if [[ ! "$image_name" =~ ^images: ]]; then
                    local image_with_prefix="images:$image_name"
                    if lxc launch $type_flag "$image_with_prefix" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                        launch_success=true
                    fi
                fi
            fi
        fi
    fi
    
    if [[ "$launch_success" == false ]]; then
        print_color "$RED" "❌ Failed to create container!"
        echo
        
        if [[ "$is_windows" == true ]]; then
            print_color "$YELLOW" "💡 Windows-specific troubleshooting:"
            echo "1. Windows images may not be available in default repos"
            echo "2. Try using virt-manager instead: sudo apt install virt-manager"
            echo "3. Or use Windows Subsystem for Linux 2 (WSL2)"
        else
            print_color "$YELLOW" "💡 Troubleshooting tips:"
            echo "1. Check if LXD is initialized: sudo lxd init --auto"
            echo "2. List available images: lxc image list images:"
            echo "3. Try a different image name"
            echo "4. Check internet connection"
        fi
        
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Set resource limits
    print_color "$BLUE" "⚙️  Configuring resources..."
    
    # Set CPU
    if lxc config set "$container_name" limits.cpu="$cpu_count" 2>/dev/null; then
        print_color "$GREEN" "✅ CPU set to: $cpu_count cores"
    else
        print_color "$YELLOW" "⚠️  Could not set CPU limit"
    fi
    
    # Set Memory
    if lxc config set "$container_name" limits.memory="$memory" 2>/dev/null; then
        print_color "$GREEN" "✅ Memory set to: $memory"
    else
        print_color "$YELLOW" "⚠️  Could not set memory limit"
    fi
    
    # Set Disk
    if lxc config device set "$container_name" root size="$disk_size" 2>/dev/null; then
        print_color "$GREEN" "✅ Disk set to: $disk_size"
    fi
    
    # Setup RDP for Windows
    if [[ "$is_windows" == true && "$setup_rdp" == true ]]; then
        setup_windows_rdp "$container_name" "$image_name"
    fi
    
    # Wait for container to be ready
    print_color "$BLUE" "⏳ Waiting for container to initialize..."
    sleep 8
    
    # Show container info
    echo
    print_color "$CYAN" "📊 Container Information:"
    echo "──────────────────────────────────────"
    lxc list "$container_name"
    
    # Get IP address
    local container_ip=$(lxc list "$container_name" -c 4 --format csv | head -1)
    
    echo
    print_color "$GREEN" "🎉 Container '$container_name' created successfully!"
    
    if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
        print_color "$BLUE" "🌐 IP Address: $container_ip"
        
        # Show connection info
        echo
        print_color "$YELLOW" "🔗 Connection Information:"
        
        if [[ "$is_windows" == true ]]; then
            echo "  RDP: xfreerdp /v:$container_ip /u:Administrator"
            echo "  Username: Administrator"
            echo "  Password: Check console for initial password"
            if [[ "$setup_rdp" == true ]]; then
                echo "  RDP Port: 3389"
            fi
        else
            # Determine OS type for default username
            local default_user=""
            if [[ "$image_name" =~ ubuntu ]]; then
                default_user="ubuntu"
            elif [[ "$image_name" =~ debian ]]; then
                default_user="debian"
            elif [[ "$image_name" =~ centos|rocky|alma|fedora ]]; then
                default_user="root"
            fi
            
            if [[ -n "$default_user" ]]; then
                echo "  SSH: ssh $default_user@$container_ip"
                echo "  Username: $default_user"
                
                if [[ "$default_user" == "root" ]]; then
                    echo "  Password: Set during first boot or use SSH keys"
                else
                    echo "  Password: No password by default (use SSH keys)"
                fi
            fi
        fi
    fi
    
    # Offer to start shell (not for Windows)
    if [[ "$is_windows" != true ]]; then
        echo
        read -p "💻 Open shell in container? (y/N): " open_shell
        if [[ "$open_shell" =~ ^[Yy]$ ]]; then
            echo "📝 Type 'exit' to return to menu"
            lxc exec "$container_name" -- /bin/bash || lxc exec "$container_name" -- /bin/sh
        fi
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to install RDP tools
install_rdp_tools() {
    print_header
    print_color "$CYAN" "📦 Installing RDP Client Tools"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    print_color "$YELLOW" "🔧 Available RDP clients:"
    echo "  1) FreeRDP (xfreerdp) - Lightweight, command-line"
    echo "  2) Remmina - Full-featured GUI client"
    echo "  3) rdesktop - Legacy but reliable"
    echo "  4) Install all"
    echo
    
    read -p "🎯 Select client to install (1-4): " rdp_choice
    
    case $rdp_choice in
        1)
            print_color "$BLUE" "📥 Installing FreeRDP..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt update
                sudo apt install -y freerdp2-x11
            elif [[ -f /etc/redhat-release ]]; then
                sudo dnf install -y freerdp
            fi
            print_color "$GREEN" "✅ FreeRDP installed!"
            echo "Usage: xfreerdp /v:[IP_ADDRESS] /u:[USERNAME]"
            ;;
        2)
            print_color "$BLUE" "📥 Installing Remmina..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt update
                sudo apt install -y remmina remmina-plugin-rdp
            elif [[ -f /etc/redhat-release ]]; then
                sudo dnf install -y remmina remmina-plugins-rdp
            fi
            print_color "$GREEN" "✅ Remmina installed!"
            echo "Launch with: remmina"
            ;;
        3)
            print_color "$BLUE" "📥 Installing rdesktop..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt update
                sudo apt install -y rdesktop
            elif [[ -f /etc/redhat-release ]]; then
                sudo dnf install -y rdesktop
            fi
            print_color "$GREEN" "✅ rdesktop installed!"
            echo "Usage: rdesktop [IP_ADDRESS]"
            ;;
        4)
            print_color "$BLUE" "📥 Installing all RDP clients..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt update
                sudo apt install -y freerdp2-x11 remmina remmina-plugin-rdp rdesktop
            elif [[ -f /etc/redhat-release ]]; then
                sudo dnf install -y freerdp remmina remmina-plugins-rdp rdesktop
            fi
            print_color "$GREEN" "✅ All RDP clients installed!"
            ;;
        *)
            print_color "$RED" "❌ Invalid selection!"
            ;;
    esac
    
    echo
    print_color "$CYAN" "🔗 Quick RDP connection examples:"
    echo "  xfreerdp /v:192.168.1.100 /u:Administrator +clipboard"
    echo "  rdesktop -u Administrator -p - 192.168.1.100"
    echo "  remmina (then create new RDP connection)"
    
    read -p "⏎ Press Enter to continue..."
}

# Enhanced main menu with RDP option
main_menu() {
    while true; do
        print_header
        
        # Get container count
        local container_count=0
        if command -v lxc &> /dev/null; then
            container_count=$(lxc list --format csv 2>/dev/null | wc -l)
        fi
        
        print_color "$GREEN" "🏠 Main Menu"
        print_color "$BLUE" "📦 Active Containers: $container_count"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        echo "  1) 🚀 Create New Container"
        echo "  2) 📋 List Containers"
        echo "  3) ⚙️  Manage Container"
        echo "  4) 📦 Image Management"
        echo "  5) 🌐 RDP Tools & Windows Support"
        echo "  6) 🔧 Check Installation"
        echo "  7) 📊 System Information"
        echo "  8) ⚡ Install Dependencies"
        echo "  0) 👋 Exit"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1) create_container ;;
            2) list_containers ;;
            3) manage_container ;;
            4) image_management ;;
            5) 
                # Sub-menu for RDP tools
                while true; do
                    print_header
                    print_color "$CYAN" "🌐 RDP Tools & Windows Support"
                    echo "══════════════════════════════════════════════════════════"
                    echo
                    echo "  1) 📥 Install RDP Clients"
                    echo "  2) 🖥️  Windows RDP Setup Guide"
                    echo "  3) 🔗 RDP Connection Helper"
                    echo "  0) ↩️  Back"
                    echo
                    
                    read -p "🎯 Select option: " rdp_choice
                    
                    case $rdp_choice in
                        1) install_rdp_tools ;;
                        2) manual_windows_setup_guide ;;
                        3)
                            print_color "$CYAN" "🔗 RDP Connection Helper"
                            read -p "Enter Windows VM IP: " win_ip
                            if [[ -n "$win_ip" ]]; then
                                echo
                                print_color "$GREEN" "🔗 Connection commands:"
                                echo "  xfreerdp /v:$win_ip /u:Administrator /p:[PASSWORD] +clipboard"
                                echo "  rdesktop -u Administrator -p - $win_ip -g 90%"
                                echo "  remmina -c rdp://user:pass@$win_ip"
                            fi
                            read -p "⏎ Press Enter to continue..."
                            ;;
                        0) break ;;
                        *) print_color "$RED" "❌ Invalid option!" ;;
                    esac
                done
                ;;
            6) check_installation ;;
            7) show_system_info ;;
            8) install_dependencies ;;
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

# [Keep all other existing functions as they are...]

# Enhanced detect_available_images to look for Windows images
detect_available_images() {
    print_color "$CYAN" "🔍 Scanning for available images..."
    echo
    
    # Clear previous image list
    declare -gA AVAILABLE_IMAGES
    AVAILABLE_IMAGES=()
    
    # List of remotes to check (added windows remote)
    local remotes=("images" "ubuntu" "debian" "fedora" "centos" "almalinux" "rockylinux")
    local image_count=0
    
    # First add our default Windows images
    for key in "${!DEFAULT_IMAGES[@]}"; do
        IFS='|' read -r image_name display_name <<< "${DEFAULT_IMAGES[$key]}"
        if [[ "$display_name" =~ [Ww]indows ]]; then
            ((image_count++))
            AVAILABLE_IMAGES["$image_count"]="$image_name|$display_name"
        fi
    done
    
    # Try to get images from remotes
    for remote in "${remotes[@]}"; do
        print_color "$BLUE" "📡 Checking remote: $remote"
        
        # Try to list images from this remote
        local remote_images=$(timeout 10 lxc image list "$remote:" 2>/dev/null | grep -E "^\| [a-zA-Z0-9/:-]+ \|" | head -20)
        
        if [[ -n "$remote_images" ]]; then
            while IFS= read -r line; do
                # Extract image name from line
                local image_name=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
                local description=$(echo "$line" | awk -F'|' '{print $3}' | xargs | cut -c1-50)
                
                if [[ -n "$image_name" && ! "$image_name" =~ "ALIAS" && ! "$image_name" =~ "FINGERPRINT" ]]; then
                    ((image_count++))
                    AVAILABLE_IMAGES["$image_count"]="$remote:$image_name|$description"
                    echo "  ✅ Found: $remote:$image_name"
                fi
            done <<< "$remote_images"
        else
            echo "  ⚠️  No images found or remote not accessible"
        fi
    done
    
    # If no images found, use defaults
    if [[ ${#AVAILABLE_IMAGES[@]} -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  Could not detect images automatically. Using defaults..."
        AVAILABLE_IMAGES=()
        for key in "${!DEFAULT_IMAGES[@]}"; do
            AVAILABLE_IMAGES["$key"]="${DEFAULT_IMAGES[$key]}"
        done
    fi
    
    echo
    print_color "$GREEN" "✅ Found ${#AVAILABLE_IMAGES[@]} available images"
    sleep 1
}

# Enhanced system info to show RDP info
show_system_info() {
    print_header
    print_color "$CYAN" "📊 System Information"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # LXC/LXD Info
    print_color "$YELLOW" "🚀 LXC/LXD Information:"
    echo "──────────────────────────────────────"
    if command -v lxc &> /dev/null; then
        echo -n "📦 LXC Version: "
        lxc version 2>/dev/null || echo "Unknown"
        
        # Container count
        local container_count=$(lxc list --format csv 2>/dev/null | wc -l)
        echo "📦 Containers: $container_count"
        
        # Check for Windows containers
        local windows_containers=$(lxc list --format csv 2>/dev/null | grep -i windows | wc -l)
        if [[ $windows_containers -gt 0 ]]; then
            echo "🖥️  Windows Containers: $windows_containers"
        fi
        
        # Storage pools
        echo "💾 Storage Pools:"
        lxc storage list 2>/dev/null | head -5 || echo "  Not available"
        
        # Networks
        echo "🌐 Networks:"
        lxc network list 2>/dev/null | head -5 || echo "  Not available"
    else
        echo "❌ LXC not installed"
    fi
    
    # RDP Tools check
    echo
    print_color "$YELLOW" "🌐 RDP Support:"
    echo "──────────────────────────────────────"
    if command -v xfreerdp &> /dev/null; then
        echo "✅ FreeRDP installed"
    else
        echo "❌ FreeRDP not installed"
    fi
    
    if command -v remmina &> /dev/null; then
        echo "✅ Remmina installed"
    else
        echo "❌ Remmina not installed"
    fi
    
    # Windows virtualization support
    echo
    print_color "$YELLOW" "🖥️  Windows Virtualization:"
    echo "──────────────────────────────────────"
    if command -v virt-manager &> /dev/null; then
        echo "✅ virt-manager installed"
    else
        echo "❌ virt-manager not installed (recommended for Windows)"
    fi
    
    if [[ -c /dev/kvm ]]; then
        echo "✅ KVM acceleration available"
    else
        echo "⚠️  KVM not available (Windows VMs may be slow)"
    fi
    
    # System Info
    echo
    print_color "$YELLOW" "💻 System Information:"
    echo "──────────────────────────────────────"
    
    # OS info
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "🏷️  OS: $PRETTY_NAME"
    fi
    
    # Kernel
    echo "🐧 Kernel: $(uname -r)"
    
    # CPU
    echo "⚡ CPU: $(nproc) cores"
    echo "💾 Memory: $(free -h | awk '/^Mem:/ {print $2}') total"
    echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"
    
    echo
    print_color "$CYAN" "🔧 Quick Commands:"
    echo "  lxc list                   # List all containers"
    echo "  xfreerdp /v:[IP] /u:[USER] # Connect via RDP"
    echo "  virt-manager               # GUI for Windows VMs"
    echo "  sudo lxd init --auto       # Initialize LXD"
    
    read -p "⏎ Press Enter to continue..."
}

# Main function
main() {
    # Check if in terminal
    if [[ ! -t 0 ]]; then
        print_color "$RED" "❌ This script must be run in a terminal!"
        exit 1
    fi
    
    # Welcome
    print_header
    print_color "$GREEN" "🌟 Welcome to LXC/LXD Container Manager"
    print_color "$CYAN" "📦 Auto Image Detection | RDP Support | Windows VMs"
    echo
    
    # Check system
    check_system_ready
    
    # Initial image detection
    detect_available_images
    
    # Start main menu
    main_menu
}

# Run main
main
