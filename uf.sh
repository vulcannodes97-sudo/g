#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 4.1 - Auto Image Detection + Windows RDP
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

# Default image database (fallback)
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
    ["10"]="images:windows/10|Windows 10 (Community Images)"
    ["11"]="images:windows/11|Windows 11 (Community Images)"
)

# Function to show image selection menu
show_image_menu() {
    print_header
    print_color "$CYAN" "📦 Available Container Images"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Sort image keys numerically
    mapfile -t sorted_keys < <(printf '%s\n' "${!AVAILABLE_IMAGES[@]}" | sort -n)
    
    for key in "${sorted_keys[@]}"; do
        IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$key]}"
        print_color "$GREEN" "  $key) $display_name"
        print_color "$BLUE" "     📦 Image: $image_name"
        echo
    done
    
    echo "══════════════════════════════════════════════════════════"
    echo "  0) ↩️  Back to Main Menu"
    echo "  r) 🔄 Refresh Image List"
    echo "  s) 🔍 Search Images"
    echo
}

# Function to detect available images
detect_available_images() {
    print_color "$CYAN" "🔍 Scanning for available images..."
    echo
    
    # Clear previous image list
    declare -gA AVAILABLE_IMAGES
    AVAILABLE_IMAGES=()
    
    # List of remotes to check
    local remotes=("images" "ubuntu" "debian")
    local image_count=0
    
    # First add our default images
    for key in "${!DEFAULT_IMAGES[@]}"; do
        ((image_count++))
        AVAILABLE_IMAGES["$image_count"]="${DEFAULT_IMAGES[$key]}"
    done
    
    # Try to get images from remotes
    for remote in "${remotes[@]}"; do
        print_color "$BLUE" "📡 Checking remote: $remote"
        
        # Try to list images from this remote
        local remote_images=$(timeout 10 lxc image list "$remote:" 2>/dev/null | grep -E "^\| [a-zA-Z0-9/:-]+ \|" | head -10 2>/dev/null || true)
        
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
    
    echo
    print_color "$GREEN" "✅ Found ${#AVAILABLE_IMAGES[@]} available images"
    sleep 1
}

# Function to check Windows RDP support
check_windows_rdp_support() {
    print_color "$CYAN" "🔍 Checking Windows RDP requirements..."
    
    # Check for Windows images from community
    print_color "$BLUE" "📦 Looking for Windows images..."
    
    local windows_found=false
    
    # Check for Windows images in the images remote
    if lxc image list images: 2>/dev/null | grep -i "windows" | head -5; then
        print_color "$GREEN" "✅ Windows images available in 'images' remote"
        windows_found=true
    else
        print_color "$YELLOW" "⚠️  No Windows images found in default repository"
    fi
    
    # Check for distrobuilder
    if command -v distrobuilder &> /dev/null; then
        print_color "$GREEN" "✅ Distrobuilder is available for custom images"
    else
        print_color "$YELLOW" "📝 Note: Install distrobuilder for custom Windows images:"
        echo "  snap install distrobuilder --classic"
    fi
    
    if [[ "$windows_found" == false ]]; then
        print_color "$YELLOW" "💡 To get Windows images, add the community repository:"
        echo "  lxc remote add community https://images.linuxcontainers.org"
        echo "  lxc remote list"
    fi
    
    echo
    return 0
}

# Function to setup Windows RDP container
setup_windows_rdp() {
    local container_name=$1
    local windows_version=$2
    
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
    echo "  0) ↩️  Skip RDP setup"
    echo
    
    read -p "🎯 Select method (0-3): " method
    
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
        0)
            print_color "$YELLOW" "⚠️  Skipping RDP setup."
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
    local windows_images=$(lxc image list images: 2>/dev/null | grep -i "windows" | head -5)
    
    if [[ -z "$windows_images" ]]; then
        print_color "$RED" "❌ No Windows images found in LXD repository"
        print_color "$YELLOW" "💡 Alternative options:"
        echo "  1. Use virt-manager for better Windows support"
        echo "  2. Use Windows Subsystem for Linux 2 (WSL2)"
        echo "  3. Try adding community images: lxc remote add community https://images.linuxcontainers.org"
        return 1
    fi
    
    echo "$windows_images"
    echo
    
    read -p "🔗 Enter Windows image name exactly as shown above: " win_image
    
    if [[ -z "$win_image" ]]; then
        print_color "$RED" "❌ No image selected"
        return 1
    fi
    
    # Create Windows container (VM)
    print_color "$GREEN" "🚀 Creating Windows VM..."
    
    # Create as VM (Windows requires full virtualization)
    if ! lxc launch "images:$win_image" "$container_name" --vm 2>&1 | tee /tmp/lxc_launch.log; then
        print_color "$RED" "❌ Failed to create Windows VM"
        local error_msg=$(cat /tmp/lxc_launch.log)
        print_color "$YELLOW" "💡 Error details: $error_msg"
        print_color "$YELLOW" "💡 Try: lxc launch images:$win_image $container_name --vm --storage=local"
        return 1
    fi
    
    # Configure resources for Windows
    print_color "$BLUE" "⚙️  Configuring Windows VM resources..."
    lxc config set "$container_name" limits.cpu=4 2>/dev/null || print_color "$YELLOW" "⚠️  Could not set CPU"
    lxc config set "$container_name" limits.memory=8GB 2>/dev/null || print_color "$YELLOW" "⚠️  Could not set memory"
    lxc config device override "$container_name" root size=50GB 2>/dev/null || print_color "$YELLOW" "⚠️  Could not set disk size"
    
    # Enable RDP
    print_color "$BLUE" "🌐 Enabling RDP..."
    lxc config device add "$container_name" rdp proxy listen=tcp:0.0.0.0:3389 connect=tcp:127.0.0.1:3389 2>/dev/null || print_color "$YELLOW" "⚠️  Could not add RDP proxy"
    
    # Get IP address
    local vm_ip=""
    print_color "$BLUE" "⏳ Waiting for IP address..."
    for i in {1..30}; do
        vm_ip=$(lxc list "$container_name" -c 4 --format csv 2>/dev/null)
        if [[ -n "$vm_ip" && "$vm_ip" != "-" ]]; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo
    
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
        echo "  To see VM output"
    fi
    
    return 0
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
            print_color "$GREEN" "✅ virt-manager installed"
            print_color "$YELLOW" "⚠️  Log out and log back in for group changes"
        elif [[ -f /etc/redhat-release ]]; then
            sudo dnf install -y virt-manager qemu-kvm libvirt
            sudo systemctl enable --now libvirtd
            sudo usermod -aG libvirt $USER
            print_color "$GREEN" "✅ virt-manager installed"
        else
            print_color "$RED" "❌ Could not install virt-manager on this system"
            return 1
        fi
    else
        print_color "$GREEN" "✅ virt-manager is already installed"
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
    return 0
}

# Manual Windows setup guide
manual_windows_setup_guide() {
    print_header
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
    return 0
}

# Enhanced create_container function with better error handling
create_container() {
    # Detect available images first
    detect_available_images
    
    while true; do
        show_image_menu
        read -p "🎯 Select image (1-${#AVAILABLE_IMAGES[@]}) or 0/r/s: " image_choice
        
        case $image_choice in
            0)
                return
                ;;
            r|R)
                detect_available_images
                continue
                ;;
            s|S)
                search_images
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
        print_color "$YELLOW" "🖥️  Windows image detected - Checking RDP support..."
        check_windows_rdp_support
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
        echo "🌐 RDP: Will be configured after creation"
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
    
    # Try to launch container
    print_color "$CYAN" "🔄 Launching container..."
    if lxc launch $type_flag "$image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
        print_color "$GREEN" "✅ Container launched successfully!"
        
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
        sleep 5
        
    else
        local error_msg=$(cat /tmp/lxc_launch.log)
        print_color "$RED" "❌ Failed to create container!"
        echo "Error: $error_msg"
        
        # Special handling for Windows images
        if [[ "$is_windows" == true ]]; then
            echo
            print_color "$YELLOW" "💡 Windows-specific troubleshooting:"
            echo "1. The 'windows:' remote might not exist"
            echo "2. Try using 'images:' prefix instead: images:windows/10"
            echo "3. Add community images: lxc remote add community https://images.linuxcontainers.org"
            echo "4. Use virt-manager instead for better Windows support"
            
            read -p "🔄 Try with 'images:' prefix? (y/N): " retry_choice
            if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
                local new_image_name=""
                if [[ "$image_name" == "windows:win10-ltsc" ]]; then
                    new_image_name="images:windows/10"
                elif [[ "$image_name" == "windows:win11" ]]; then
                    new_image_name="images:windows/11"
                elif [[ ! "$image_name" =~ ^images: ]]; then
                    new_image_name="images:$image_name"
                fi
                
                if [[ -n "$new_image_name" ]]; then
                    print_color "$BLUE" "🔄 Retrying with: $new_image_name"
                    if lxc launch $type_flag "$new_image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                        print_color "$GREEN" "✅ Container launched successfully!"
                    else
                        print_color "$RED" "❌ Still failed. Please check your LXD setup."
                    fi
                fi
            fi
        else
            echo
            print_color "$YELLOW" "💡 Troubleshooting tips:"
            echo "1. Check if LXD is initialized: sudo lxd init --auto"
            echo "2. List available images: lxc image list images:"
            echo "3. Try a different image name"
            echo "4. Check internet connection"
        fi
        
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
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
            echo "  Username: Administrator (default)"
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
            else
                default_user="root"
            fi
            
            echo "  SSH: ssh $default_user@$container_ip"
            echo "  Username: $default_user"
            
            if [[ "$default_user" == "root" ]]; then
                echo "  Password: Set during first boot or use SSH keys"
            else
                echo "  Password: No password by default (use SSH keys)"
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

# [Keep all other functions the same as before...]
# Function to search for specific images
search_images() {
    print_header
    print_color "$CYAN" "🔍 Search Images"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    read -p "🔎 Enter search term (e.g., ubuntu, debian, centos): " search_term
    
    if [[ -z "$search_term" ]]; then
        return
    fi
    
    print_color "$BLUE" "🔍 Searching for '$search_term'..."
    echo
    
    local search_results=()
    local result_count=0
    
    # Search in available images
    for key in "${!AVAILABLE_IMAGES[@]}"; do
        IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$key]}"
        if [[ "$image_name" =~ $search_term || "$display_name" =~ $search_term ]]; then
            ((result_count++))
            search_results["$result_count"]="$image_name|$display_name"
            print_color "$GREEN" "  $result_count) $display_name"
            print_color "$BLUE" "     📦 Image: $image_name"
            echo
        fi
    done
    
    if [[ $result_count -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  No images found matching '$search_term'"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to list containers
list_containers() {
    print_header
    print_color "$CYAN" "📋 Container List"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # List all containers with formatting
    if ! lxc list; then
        print_color "$YELLOW" "⚠️  Could not list containers. Is LXD running?"
        echo "Try: sudo systemctl start snap.lxd.daemon"
    fi
    
    echo
    print_color "$YELLOW" "📊 Legend:"
    echo "  🟢 RUNNING - Container is active"
    echo "  🔴 STOPPED - Container is not running"
    echo "  ⚪ FROZEN  - Container is paused"
    echo "  🟡 ERROR   - Container has issues"
    
    read -p "⏎ Press Enter to continue..."
}

# Function to manage containers
manage_container() {
    print_header
    print_color "$CYAN" "⚙️  Container Management"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Get container list
    local containers=$(lxc list -c n --format csv 2>/dev/null)
    if [[ -z "$containers" ]]; then
        print_color "$YELLOW" "📭 No containers found!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Display containers
    print_color "$BLUE" "📋 Available Containers:"
    echo
    local i=1
    declare -A container_map
    for container in $containers; do
        container_map[$i]=$container
        local status=$(lxc list $container -c s --format csv 2>/dev/null || echo "UNKNOWN")
        local status_icon="❓"
        [[ "$status" == "RUNNING" ]] && status_icon="🟢"
        [[ "$status" == "STOPPED" ]] && status_icon="🔴"
        [[ "$status" == "FROZEN" ]] && status_icon="⚪"
        echo "  $i) $status_icon $container ($status)"
        ((i++))
    done
    
    echo
    read -p "🎯 Select container number: " container_num
    
    if [[ -z "${container_map[$container_num]}" ]]; then
        print_color "$RED" "❌ Invalid selection!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    local container_name=${container_map[$container_num]}
    container_management_menu "$container_name"
}

# Container management sub-menu
container_management_menu() {
    local container_name=$1
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  Managing: $container_name"
        
        # Get container status
        local container_status=$(lxc list "$container_name" -c s --format csv 2>/dev/null || echo "UNKNOWN")
        local container_ip=$(lxc list "$container_name" -c 4 --format csv 2>/dev/null | head -1)
        
        print_color "$BLUE" "📊 Status: $container_status"
        if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
            print_color "$GREEN" "🌐 IP: $container_ip"
        fi
        echo "══════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Operations:"
        echo "  1) ▶️  Start Container"
        echo "  2) ⏹️  Stop Container"
        echo "  3) 🔄 Restart Container"
        echo "  4) ⏸️  Pause/Freeze"
        echo "  5) ⏯️  Resume/Unfreeze"
        echo "  6) 💻 Open Shell"
        echo "  7) 📊 Show Info"
        echo "  8) 📝 View Logs"
        echo "  9) ⚙️  Configure Resources"
        echo "  10) 📦 Take Snapshot"
        echo "  11) 🗑️  Delete Container"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select operation: " operation
        
        case $operation in
            1)
                print_color "$GREEN" "▶️  Starting container..."
                if lxc start "$container_name"; then
                    print_color "$GREEN" "✅ Container started!"
                else
                    print_color "$RED" "❌ Failed to start container"
                fi
                sleep 2
                ;;
            2)
                print_color "$YELLOW" "⏹️  Stopping container..."
                if lxc stop "$container_name"; then
                    print_color "$GREEN" "✅ Container stopped!"
                else
                    print_color "$RED" "❌ Failed to stop container"
                fi
                sleep 2
                ;;
            3)
                print_color "$BLUE" "🔄 Restarting container..."
                if lxc restart "$container_name"; then
                    print_color "$GREEN" "✅ Container restarted!"
                else
                    print_color "$RED" "❌ Failed to restart container"
                fi
                sleep 2
                ;;
            4)
                print_color "$PURPLE" "⏸️  Freezing container..."
                if lxc freeze "$container_name"; then
                    print_color "$GREEN" "✅ Container frozen!"
                else
                    print_color "$RED" "❌ Failed to freeze container"
                fi
                sleep 2
                ;;
            5)
                print_color "$PURPLE" "⏯️  Unfreezing container..."
                if lxc unfreeze "$container_name"; then
                    print_color "$GREEN" "✅ Container unfrozen!"
                else
                    print_color "$RED" "❌ Failed to unfreeze container"
                fi
                sleep 2
                ;;
            6)
                print_color "$CYAN" "💻 Opening shell..."
                echo "📝 Type 'exit' to return to menu"
                if ! lxc exec "$container_name" -- /bin/bash; then
                    print_color "$YELLOW" "⚠️  Trying /bin/sh instead..."
                    lxc exec "$container_name" -- /bin/sh
                fi
                ;;
            7)
                print_color "$BLUE" "📊 Container Information:"
                lxc info "$container_name" || echo "Could not get container info"
                read -p "⏎ Press Enter to continue..."
                ;;
            8)
                print_color "$BLUE" "📝 Container Logs (last 50 lines):"
                lxc info "$container_name" --show-log | tail -50 || echo "Could not get logs"
                read -p "⏎ Press Enter to continue..."
                ;;
            9)
                configure_container "$container_name"
                ;;
            10)
                read -p "📸 Snapshot name: " snapshot_name
                if lxc snapshot "$container_name" "$snapshot_name"; then
                    print_color "$GREEN" "✅ Snapshot created: $snapshot_name"
                else
                    print_color "$RED" "❌ Failed to create snapshot"
                fi
                sleep 2
                ;;
            11)
                print_color "$RED" "⚠️  ⚠️  ⚠️  WARNING: This will permanently delete '$container_name'!"
                read -p "🗑️  Are you sure? (type 'DELETE' to confirm): " confirm
                if [[ "$confirm" == "DELETE" ]]; then
                    print_color "$RED" "🗑️  Deleting container..."
                    if lxc delete "$container_name" --force; then
                        print_color "$GREEN" "✅ Container deleted!"
                        read -p "⏎ Press Enter to continue..."
                        return
                    else
                        print_color "$RED" "❌ Failed to delete container"
                    fi
                else
                    print_color "$YELLOW" "⚠️  Deletion cancelled"
                fi
                sleep 2
                ;;
            0)
                return
                ;;
            *)
                print_color "$RED" "❌ Invalid operation!"
                sleep 1
                ;;
        esac
    done
}

# Function to configure container resources
configure_container() {
    local container_name=$1
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  Configuring: $container_name"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Resource Configuration:"
        echo "  1) ⚡ Set CPU Limits"
        echo "  2) 🧠 Set Memory Limits"
        echo "  3) 💾 Set Disk Limits"
        echo "  4) 🌐 Network Settings"
        echo "  5) 👁️  View Current Configuration"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select option: " config_opt
        
        case $config_opt in
            1)
                read -p "⚡ Enter CPU limit (e.g., 2 or 0-4): " cpu_limit
                if lxc config set "$container_name" limits.cpu="$cpu_limit"; then
                    print_color "$GREEN" "✅ CPU limit set to: $cpu_limit"
                else
                    print_color "$RED" "❌ Failed to set CPU limit"
                fi
                ;;
            2)
                read -p "🧠 Enter memory limit (e.g., 2GB or 512MB): " mem_limit
                if lxc config set "$container_name" limits.memory="$mem_limit"; then
                    print_color "$GREEN" "✅ Memory limit set to: $mem_limit"
                else
                    print_color "$RED" "❌ Failed to set memory limit"
                fi
                ;;
            3)
                read -p "💾 Enter disk limit (e.g., 20GB): " disk_limit
                if lxc config device set "$container_name" root size="$disk_limit"; then
                    print_color "$GREEN" "✅ Disk limit set to: $disk_limit"
                else
                    print_color "$RED" "❌ Failed to set disk limit"
                fi
                ;;
            4)
                echo "🌐 Available networks:"
                lxc network list || echo "Could not list networks"
                read -p "Network name to attach (default: lxdbr0): " net_name
                net_name=${net_name:-lxdbr0}
                if lxc network attach "$net_name" "$container_name" eth0; then
                    print_color "$GREEN" "✅ Attached to network: $net_name"
                else
                    print_color "$RED" "❌ Failed to attach network"
                fi
                ;;
            5)
                print_color "$BLUE" "👁️  Current Configuration:"
                lxc config show "$container_name" || echo "Could not get configuration"
                ;;
            0)
                return
                ;;
            *)
                print_color "$RED" "❌ Invalid option!"
                ;;
        esac
        
        read -p "⏎ Press Enter to continue..."
    done
}

# Function to show system info
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

# Function to refresh images
refresh_images() {
    print_header
    print_color "$CYAN" "🔄 Refreshing Available Images..."
    echo "══════════════════════════════════════════════════════════"
    echo
    
    detect_available_images
    
    print_color "$GREEN" "✅ Image list refreshed!"
    read -p "⏎ Press Enter to continue..."
}

# Function to show image management
image_management() {
    while true; do
        print_header
        print_color "$CYAN" "📦 Image Management"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Operations:"
        echo "  1) 🔍 List Available Images"
        echo "  2) 🔄 Refresh Image List"
        echo "  3) 🔎 Search Images"
        echo "  4) 📥 Import Custom Image"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1)
                detect_available_images
                show_image_menu
                read -p "⏎ Press Enter to continue..."
                ;;
            2)
                refresh_images
                ;;
            3)
                search_images
                ;;
            4)
                print_color "$BLUE" "📥 Import Custom Image"
                read -p "Enter image URL or local path: " image_url
                if [[ -n "$image_url" ]]; then
                    read -p "Enter alias for image: " image_alias
                    if lxc image import "$image_url" --alias "$image_alias"; then
                        print_color "$GREEN" "✅ Image imported as: $image_alias"
                    else
                        print_color "$RED" "❌ Failed to import image"
                    fi
                fi
                read -p "⏎ Press Enter to continue..."
                ;;
            0)
                return
                ;;
            *)
                print_color "$RED" "❌ Invalid option!"
                sleep 1
                ;;
        esac
    done
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
    echo "  0) ↩️  Back"
    echo
    
    read -p "🎯 Select client to install (0-4): " rdp_choice
    
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
        0)
            return
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

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Dependencies..."
    echo "══════════════════════════════════════════════════════════"
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$ID
    else
        print_color "$RED" "❌ Cannot detect OS distribution!"
        exit 1
    fi
    
    print_color "$BLUE" "📊 Detected: $PRETTY_NAME"
    echo
    
    case $OS_NAME in
        ubuntu|debian)
            print_color "$GREEN" "📦 Installing for Ubuntu/Debian..."
            echo
            
            # Update package lists
            print_color "$CYAN" "🔄 Updating package lists..."
            sudo apt update -y
            
            # Install LXC
            print_color "$CYAN" "📥 Installing LXC..."
            sudo apt install -y lxc lxc-utils lxc-templates bridge-utils uidmap
            
            # Install and configure snapd for LXD
            if ! command -v snap &> /dev/null; then
                print_color "$CYAN" "📦 Installing snapd..."
                sudo apt install -y snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
                echo "⚠️  Please log out and log back in for snap to work properly"
            fi
            
            # Install LXD
            print_color "$CYAN" "🚀 Installing LXD..."
            sudo snap install lxd
            
            # Add user to lxd group
            print_color "$CYAN" "👤 Adding user to lxd group..."
            sudo usermod -aG lxd $USER
            
            # Initialize LXD
            print_color "$CYAN" "⚙️  Initializing LXD..."
            echo "This will set up LXD with default settings..."
            sudo lxd init --auto
            
            # Start LXD service
            print_color "$CYAN" "▶️  Starting LXD service..."
            sudo systemctl start snap.lxd.daemon 2>/dev/null || sudo systemctl start lxd 2>/dev/null
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  IMPORTANT: Please log out and log back in for group changes!"
            print_color "$YELLOW" "   Then run this script again."
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo "For Ubuntu/Debian:"
            echo "  sudo apt install lxc lxc-utils bridge-utils snapd"
            echo "  sudo snap install lxd"
            echo "  sudo usermod -aG lxd \$USER"
            echo "  sudo lxd init --auto"
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
    exit 0
}

# Function to check installation
check_installation() {
    print_header
    print_color "$CYAN" "🔍 Checking Installation..."
    echo "══════════════════════════════════════════════════════════"
    echo
    
    local checks_passed=0
    local total_checks=5
    
    # Check LXC
    if command -v lxc &> /dev/null; then
        print_color "$GREEN" "✅ LXC is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXC is NOT installed"
    fi
    
    # Check LXD
    if command -v lxd &> /dev/null; then
        print_color "$GREEN" "✅ LXD is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD is NOT installed"
    fi
    
    # Check if user is in lxd group
    if groups $USER | grep -q '\blxd\b'; then
        print_color "$GREEN" "✅ User is in lxd group"
        ((checks_passed++))
    else
        print_color "$YELLOW" "⚠️  User is NOT in lxd group"
    fi
    
    # Check LXD service
    if systemctl is-active --quiet snap.lxd.daemon 2>/dev/null || systemctl is-active --quiet lxd 2>/dev/null; then
        print_color "$GREEN" "✅ LXD service is running"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD service is NOT running"
    fi
    
    # Check if LXD is initialized
    if lxc cluster list 2>&1 | grep -q "no such file or directory" || lxc cluster list 2>&1 | grep -q "not initialized"; then
        print_color "$YELLOW" "⚠️  LXD is not initialized"
    else
        print_color "$GREEN" "✅ LXD is initialized"
        ((checks_passed++))
    fi
    
    echo
    print_color "$BLUE" "📊 Status: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_color "$GREEN" "🎉 All systems go! LXC/LXD is ready."
    elif [[ $checks_passed -ge 3 ]]; then
        print_color "$YELLOW" "⚠️  Some issues detected. Check below:"
        echo
        print_color "$CYAN" "💡 Troubleshooting tips:"
        echo "1. If not in lxd group, run: sudo usermod -aG lxd $USER"
        echo "2. If LXD not initialized, run: sudo lxd init --auto"
        echo "3. If service not running: sudo systemctl start snap.lxd.daemon"
        echo "4. Log out and log back in after adding to lxd group"
    else
        print_color "$RED" "🚨 Major issues detected. Please reinstall dependencies."
    fi
    
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

# Function to check if LXC/LXD is ready
check_system_ready() {
    if ! command -v lxc &> /dev/null; then
        print_header
        print_color "$YELLOW" "⚠️  LXC/LXD Not Installed"
        echo "══════════════════════════════════════════════════════════"
        echo
        print_color "$CYAN" "This script requires LXC/LXD to be installed."
        echo "Would you like to install it now?"
        echo
        
        read -p "📦 Install dependencies? (Y/n): " install_choice
        install_choice=${install_choice:-Y}
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_dependencies
        else
            print_color "$YELLOW" "⚠️  Please install LXC/LXD manually first."
            echo "Run option 8 from the main menu later."
            sleep 2
        fi
    elif ! groups $USER | grep -q '\blxd\b'; then
        print_header
        print_color "$YELLOW" "⚠️  User Not in LXD Group"
        echo "══════════════════════════════════════════════════════════"
        echo
        print_color "$CYAN" "Your user is not in the 'lxd' group."
        echo "This is required to manage containers."
        echo
        print_color "$GREEN" "💡 Solution:"
        echo "  1. Run: sudo usermod -aG lxd $USER"
        echo "  2. Log out and log back in"
        echo "  3. Run this script again"
        echo
        read -p "⏎ Press Enter to continue..."
        exit 0
    fi
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
