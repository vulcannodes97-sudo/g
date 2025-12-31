#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 4.3 - LXC/LXD Only (No Windows)
# ============================================


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
    echo "║               LXC/LXD Container Manager                 ║"
    echo "║                 Mode BY - Nobita                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
}

# Default Linux images only (no Windows)
declare -A DEFAULT_IMAGES=(
    ["1"]="ubuntu:22.04|Ubuntu 22.04 Jammy"
    ["2"]="ubuntu:20.04|Ubuntu 20.04 Focal"
    ["3"]="ubuntu:24.04|Ubuntu 24.04 Noble"
    ["4"]="debian/11|Debian 11 Bullseye"
    ["5"]="debian/12|Debian 12 Bookworm"
    ["6"]="centos/7|CentOS 7"
    ["7"]="centos/stream-8|CentOS Stream 8"
    ["8"]="centos/stream-9|CentOS Stream 9"
    ["9"]="almalinux/9|AlmaLinux 9"
    ["10"]="rockylinux/9|Rocky Linux 9"
    ["11"]="fedora/40|Fedora 40"
    ["12"]="fedora/39|Fedora 39"
    ["13"]="archlinux|Arch Linux"
    ["14"]="opensuse/15.5|openSUSE Leap 15.5"
    ["15"]="opensuse/tumbleweed|openSUSE Tumbleweed"
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
    
    # First add our default Linux images
    for key in "${!DEFAULT_IMAGES[@]}"; do
        ((image_count++))
        AVAILABLE_IMAGES["$image_count"]="${DEFAULT_IMAGES[$key]}"
    done
    
    # Try to get images from remotes
    for remote in "${remotes[@]}"; do
        print_color "$BLUE" "📡 Checking remote: $remote"
        
        # Try to list images from this remote
        local remote_images=$(timeout 10 lxc image list "$remote:" 2>/dev/null | grep -E "^\| [a-zA-Z0-9/:-]+ \|" | head -15 2>/dev/null || true)
        
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

# Enhanced create_container function - Linux only
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
            print_color "$RED" "❌ Invalid name! Use letters, numbers, hyphens, underscores"
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
    
    read -p "Select type (1-2, default: 1): " container_type
    container_type=${container_type:-1}
    
    local type_flag=""
    case $container_type in
        1) 
            type_flag=""
            print_color "$BLUE" "📦 Selected: Container (lightweight)"
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
    
    disk_size_default="10GB"
    memory_default="2GB"
    cpu_default="2"
    
    read -p "💾 Disk size (default: $disk_size_default): " disk_size
    disk_size=${disk_size:-$disk_size_default}
    
    read -p "🧠 Memory (default: $memory_default): " memory
    memory=${memory:-$memory_default}
    
    read -p "⚡ CPU cores (default: $cpu_default): " cpu_count
    cpu_count=${cpu_count:-$cpu_default}
    
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
    
    # Try to launch container with proper image handling
    print_color "$CYAN" "🔄 Launching container..."
    
    # Clean up image name
    local clean_image_name="$image_name"
    
    # Remove duplicate remote prefixes
    if [[ "$clean_image_name" =~ ^images:images: ]]; then
        clean_image_name="${clean_image_name#images:}"
    fi
    
    # Ensure proper remote prefix
    if [[ ! "$clean_image_name" =~ ^[a-zA-Z]+: ]]; then
        # If no remote specified, try images: first
        clean_image_name="images:$clean_image_name"
    fi
    
    print_color "$BLUE" "📦 Using image: $clean_image_name"
    
    if lxc launch $type_flag "$clean_image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
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
        
        # Wait for container to be ready
        print_color "$BLUE" "⏳ Waiting for container to initialize..."
        sleep 5
        
    else
        local error_msg=$(cat /tmp/lxc_launch.log)
        print_color "$RED" "❌ Failed to create container!"
        echo "Error: $error_msg"
        
        echo
        print_color "$YELLOW" "💡 Troubleshooting tips:"
        echo "1. Check available images: lxc image list images:"
        echo "2. Try a different image name"
        echo "3. Check if LXD is initialized: lxd init --auto"
        echo "4. Check internet connection"
        echo "5. Try without remote prefix: lxc launch ubuntu:22.04 $container_name"
        
        read -p "🔄 Try alternative image format? (y/N): " retry_choice
        if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
            # Try alternative formats
            local alt_images=()
            
            # Extract base image name
            if [[ "$image_name" =~ : ]]; then
                local base_name="${image_name#*:}"
                alt_images=("$base_name" "images:$base_name" "ubuntu:$base_name" "debian:$base_name")
            else
                alt_images=("images:$image_name" "ubuntu:$image_name" "debian:$image_name")
            fi
            
            for alt_image in "${alt_images[@]}"; do
                print_color "$BLUE" "🔄 Trying: $alt_image"
                if lxc launch $type_flag "$alt_image" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                    print_color "$GREEN" "✅ Container launched successfully with: $alt_image"
                    break
                fi
            done
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
        
        # Determine OS type for default username
        local default_user="root"
        if [[ "$image_name" =~ ubuntu ]]; then
            default_user="ubuntu"
        elif [[ "$image_name" =~ debian ]]; then
            default_user="debian"
        elif [[ "$image_name" =~ centos|rocky|alma|fedora ]]; then
            default_user="root"
        elif [[ "$image_name" =~ archlinux ]]; then
            default_user="arch"
        elif [[ "$image_name" =~ opensuse ]]; then
            default_user="root"
        fi
        
        echo "  SSH: ssh $default_user@$container_ip"
        echo "  Username: $default_user"
        
        if [[ "$default_user" == "root" ]]; then
            echo "  Password: Set during first boot or use SSH keys"
        else
            echo "  Password: No password by default (use SSH keys)"
        fi
        
        # Show quick commands
        echo
        print_color "$CYAN" "🔧 Quick Commands:"
        echo "  Shell access: lxc exec $container_name -- bash"
        echo "  View logs: lxc info $container_name --show-log"
        echo "  Stop container: lxc stop $container_name"
    fi
    
    # Offer to start shell
    echo
    read -p "💻 Open shell in container? (y/N): " open_shell
    if [[ "$open_shell" =~ ^[Yy]$ ]]; then
        echo "📝 Type 'exit' to return to menu"
        echo "🔧 Installing basic packages first..."
        
        # Try to install basic packages
        lxc exec "$container_name" -- bash -c "
            if command -v apt &> /dev/null; then
                apt update && apt install -y sudo curl wget net-tools
            elif command -v dnf &> /dev/null; then
                dnf install -y sudo curl wget net-tools
            elif command -v yum &> /dev/null; then
                yum install -y sudo curl wget net-tools
            elif command -v pacman &> /dev/null; then
                pacman -Sy --noconfirm sudo curl wget net-tools
            elif command -v zypper &> /dev/null; then
                zypper install -y sudo curl wget net-tools
            fi
        " 2>/dev/null || true
        
        lxc exec "$container_name" -- /bin/bash || lxc exec "$container_name" -- /bin/sh
    fi
    
    read -p "⏎ Press Enter to continue..."
}

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
        print_color "$BLUE" "💡 Try searching LXD images directly:"
        echo "  lxc image list images: | grep -i '$search_term'"
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
        echo "Try: systemctl start snap.lxd.daemon"
    fi
    
    echo
    print_color "$YELLOW" "📊 Legend:"
    echo "  🟢 RUNNING - Container is active"
    echo "  🔴 STOPPED - Container is not running"
    echo "  ⚪ FROZEN  - Container is paused"
    echo "  🟡 ERROR   - Container has issues"
    
    # Show quick stats
    local total_containers=$(lxc list --format csv 2>/dev/null | wc -l)
    local running_containers=$(lxc list --format csv 2>/dev/null | grep -c "RUNNING" || echo "0")
    
    echo
    print_color "$BLUE" "📈 Container Statistics:"
    echo "  Total containers: $total_containers"
    echo "  Running containers: $running_containers"
    
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
        local ip=$(lxc list $container -c 4 --format csv 2>/dev/null | head -1)
        local status_icon="❓"
        [[ "$status" == "RUNNING" ]] && status_icon="🟢"
        [[ "$status" == "STOPPED" ]] && status_icon="🔴"
        [[ "$status" == "FROZEN" ]] && status_icon="⚪"
        echo "  $i) $status_icon $container ($status)"
        if [[ -n "$ip" && "$ip" != "-" ]]; then
            echo "     IP: $ip"
        fi
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
        echo "  11) 🌐 Configure Network"
        echo "  12) 💾 Backup Container"
        echo "  13) 🗑️  Delete Container"
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
                
                echo
                print_color "$CYAN" "📈 Resource Usage:"
                lxc info "$container_name" --resources 2>/dev/null || echo "Resource stats not available"
                
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
                if [[ -z "$snapshot_name" ]]; then
                    snapshot_name="snapshot-$(date +%Y%m%d-%H%M%S)"
                fi
                
                if lxc snapshot "$container_name" "$snapshot_name"; then
                    print_color "$GREEN" "✅ Snapshot created: $snapshot_name"
                    echo "💡 Restore with: lxc restore $container_name $snapshot_name"
                else
                    print_color "$RED" "❌ Failed to create snapshot"
                fi
                sleep 2
                ;;
            11)
                configure_network "$container_name"
                ;;
            12)
                backup_container "$container_name"
                ;;
            13)
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
        
        # Get current config
        print_color "$BLUE" "📋 Current Configuration:"
        lxc config show "$container_name" 2>/dev/null | grep -E "(limits\.|boot\.|environment\.)" || echo "  Default configuration"
        echo
        
        print_color "$YELLOW" "📋 Resource Configuration:"
        echo "  1) ⚡ Set CPU Limits"
        echo "  2) 🧠 Set Memory Limits"
        echo "  3) 💾 Set Disk Limits"
        echo "  4) 🔄 Set Auto-start"
        echo "  5) 🛠️  Set Security Options"
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
                read -p "🔄 Enable auto-start? (y/N): " autostart
                if [[ "$autostart" =~ ^[Yy]$ ]]; then
                    lxc config set "$container_name" boot.autostart=true
                    print_color "$GREEN" "✅ Auto-start enabled"
                else
                    lxc config set "$container_name" boot.autostart=false
                    print_color "$YELLOW" "✅ Auto-start disabled"
                fi
                ;;
            5)
                print_color "$BLUE" "🛠️  Security Options:"
                echo "  1) Enable nesting (run containers inside container)"
                echo "  2) Disable nesting"
                echo "  3) Set privileged mode"
                echo "  4) Set unprivileged mode"
                read -p "Select option: " security_opt
                
                case $security_opt in
                    1)
                        lxc config set "$container_name" security.nesting=true
                        print_color "$GREEN" "✅ Nesting enabled"
                        ;;
                    2)
                        lxc config set "$container_name" security.nesting=false
                        print_color "$GREEN" "✅ Nesting disabled"
                        ;;
                    3)
                        lxc config set "$container_name" security.privileged=true
                        print_color "$YELLOW" "⚠️  Privileged mode enabled (security risk)"
                        ;;
                    4)
                        lxc config set "$container_name" security.privileged=false
                        print_color "$GREEN" "✅ Unprivileged mode enabled"
                        ;;
                esac
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

# Function to configure network
configure_network() {
    local container_name=$1
    
    print_header
    print_color "$CYAN" "🌐 Network Configuration: $container_name"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Show current network
    print_color "$BLUE" "📶 Current Network Configuration:"
    lxc config device list "$container_name" | grep -E "(eth|net)" || echo "  No network devices configured"
    echo
    
    print_color "$YELLOW" "📋 Network Options:"
    echo "  1) 🌐 List available networks"
    echo "  2) 🔌 Attach to network"
    echo "  3) 🔗 Detach from network"
    echo "  4) 📡 Configure static IP"
    echo "  0) ↩️  Back"
    echo
    
    read -p "🎯 Select option: " network_opt
    
    case $network_opt in
        1)
            print_color "$BLUE" "🌐 Available Networks:"
            lxc network list
            ;;
        2)
            echo "🌐 Available networks:"
            lxc network list --format csv | cut -d, -f1
            read -p "Enter network name to attach (default: lxdbr0): " net_name
            net_name=${net_name:-lxdbr0}
            
            # Find next available eth device
            local eth_device="eth0"
            for i in {0..9}; do
                if ! lxc config device get "$container_name" "eth$i" nictype 2>/dev/null; then
                    eth_device="eth$i"
                    break
                fi
            done
            
            if lxc network attach "$net_name" "$container_name" "$eth_device"; then
                print_color "$GREEN" "✅ Attached to network: $net_name as $eth_device"
                # Get new IP
                sleep 2
                local new_ip=$(lxc list "$container_name" -c 4 --format csv | head -1)
                if [[ -n "$new_ip" && "$new_ip" != "-" ]]; then
                    print_color "$BLUE" "📶 New IP: $new_ip"
                fi
            else
                print_color "$RED" "❌ Failed to attach network"
            fi
            ;;
        3)
            local devices=$(lxc config device list "$container_name" | grep -E "^eth[0-9]+$")
            if [[ -z "$devices" ]]; then
                print_color "$YELLOW" "⚠️  No network devices found"
            else
                echo "🔗 Current network devices: $devices"
                read -p "Enter device to detach (e.g., eth0): " detach_device
                if lxc config device remove "$container_name" "$detach_device"; then
                    print_color "$GREEN" "✅ Device $detach_device detached"
                else
                    print_color "$RED" "❌ Failed to detach device"
                fi
            fi
            ;;
        4)
            local current_ip=$(lxc list "$container_name" -c 4 --format csv | head -1)
            print_color "$BLUE" "📶 Current IP: ${current_ip:-(not assigned)}"
            
            read -p "Enter static IPv4 address (e.g., 10.0.0.10): " static_ip
            read -p "Enter gateway (e.g., 10.0.0.1): " gateway
            read -p "Enter network device (e.g., eth0): " net_device
            
            if lxc config device set "$container_name" "$net_device" ipv4.address="$static_ip"; then
                print_color "$GREEN" "✅ Static IP set: $static_ip"
            else
                print_color "$RED" "❌ Failed to set static IP"
            fi
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
}

# Function to backup container
backup_container() {
    local container_name=$1
    
    print_header
    print_color "$CYAN" "💾 Backup Container: $container_name"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Create backup directory
    local backup_dir="$HOME/lxc-backups"
    mkdir -p "$backup_dir"
    
    # Generate backup filename
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${container_name}_${timestamp}.tar.gz"
    
    print_color "$BLUE" "📦 Creating backup..."
    echo "Backup file: $backup_file"
    echo
    
    if lxc export "$container_name" "$backup_file"; then
        print_color "$GREEN" "✅ Backup created successfully!"
        echo
        print_color "$CYAN" "📋 Backup Information:"
        echo "  File: $(basename "$backup_file")"
        echo "  Size: $(du -h "$backup_file" | cut -f1)"
        echo "  Location: $backup_dir"
        echo
        print_color "$YELLOW" "💡 Restore command:"
        echo "  lxc import $backup_file --alias $container_name-restored"
    else
        print_color "$RED" "❌ Backup failed!"
    fi
    
    read -p "⏎ Press Enter to continue..."
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
        local running_count=$(lxc list --format csv 2>/dev/null | grep -c "RUNNING" || echo "0")
        echo "📦 Containers: $container_count (Running: $running_count)"
        
        # Storage pools
        echo "💾 Storage Pools:"
        lxc storage list 2>/dev/null | head -5 || echo "  Not available"
        
        # Networks
        echo "🌐 Networks:"
        lxc network list 2>/dev/null | head -5 || echo "  Not available"
        
        # Profiles
        echo "👤 Profiles:"
        lxc profile list 2>/dev/null | head -5 || echo "  Not available"
    else
        echo "❌ LXC not installed"
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
    echo "  lxc image list images:     # List available images"
    echo "  lxd init --auto            # Initialize LXD"
    echo "  lxc network list           # List networks"
    
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
        echo "  5) 🗑️  Delete Local Image"
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
            5)
                print_color "$YELLOW" "🗑️  Delete Local Image"
                echo "Available local images:"
                lxc image list --format csv | awk -F, '{print $2 " | " $3}' | head -10
                echo
                read -p "Enter image fingerprint or alias to delete: " image_to_delete
                if [[ -n "$image_to_delete" ]]; then
                    read -p "Are you sure you want to delete '$image_to_delete'? (y/N): " confirm_delete
                    if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
                        if lxc image delete "$image_to_delete"; then
                            print_color "$GREEN" "✅ Image deleted: $image_to_delete"
                        else
                            print_color "$RED" "❌ Failed to delete image"
                        fi
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

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Required Dependencies..."
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
            apt update -y
            
            # Install LXC
            print_color "$CYAN" "📥 Installing LXC..."
            apt install -y lxc lxc-utils lxc-templates bridge-utils uidmap
            
            # Install and configure snapd for LXD
            if ! command -v snap &> /dev/null; then
                print_color "$CYAN" "📦 Installing snapd..."
                apt install -y snapd
                systemctl enable --now snapd.socket
                ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
                echo "⚠️  Please log out and log back in for snap to work properly"
            fi
            
            # Install LXD
            print_color "$CYAN" "🚀 Installing LXD..."
            snap install lxd
            
            # Initialize LXD
            print_color "$CYAN" "⚙️  Initializing LXD..."
            echo "This will set up LXD with default settings..."
            lxd init --auto
            
            # Start LXD service
            print_color "$CYAN" "▶️  Starting LXD service..."
            systemctl start snap.lxd.daemon 2>/dev/null || systemctl start lxd 2>/dev/null
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  LXD initialization completed!"
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo "For Ubuntu/Debian:"
            echo "  apt install lxc lxc-utils bridge-utils snapd"
            echo "  snap install lxd"
            echo "  lxd init --auto"
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
    
    # Check storage pool
    if lxc storage list 2>/dev/null | grep -q "default"; then
        print_color "$GREEN" "✅ Storage pool configured"
        ((checks_passed++))
    else
        print_color "$YELLOW" "⚠️  No storage pool configured"
    fi
    
    echo
    print_color "$BLUE" "📊 Status: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_color "$GREEN" "🎉 All systems go! LXC/LXD is ready."
    elif [[ $checks_passed -ge 3 ]]; then
        print_color "$YELLOW" "⚠️  Some issues detected. Check below:"
        echo
        print_color "$CYAN" "💡 Troubleshooting tips:"
        echo "1. If LXD not initialized, run: lxd init --auto"
        echo "2. If service not running: systemctl start snap.lxd.daemon"
        echo "3. Check logs: journalctl -u snap.lxd.daemon"
    else
        print_color "$RED" "🚨 Major issues detected. Please reinstall dependencies."
    fi
    
    # Show quick test
    echo
    print_color "$CYAN" "🔧 Quick Test:"
    echo "Testing LXC commands..."
    if lxc list 2>/dev/null; then
        print_color "$GREEN" "✅ LXC commands working"
    else
        print_color "$RED" "❌ LXC commands failing"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Enhanced main menu
main_menu() {
    while true; do
        print_header
        
        # Get container count
        local container_count=0
        local running_count=0
        if command -v lxc &> /dev/null; then
            container_count=$(lxc list --format csv 2>/dev/null | wc -l)
            running_count=$(lxc list --format csv 2>/dev/null | grep -c "RUNNING" || echo "0")
        fi
        
        print_color "$GREEN" "🏠 LXC/LXD Container Manager"
        print_color "$BLUE" "📦 Containers: $container_count (🟢 $running_count running)"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        echo "  1) 🚀 Create New Container"
        echo "  2) 📋 List Containers"
        echo "  3) ⚙️  Manage Container"
        echo "  4) 📦 Image Management"
        echo "  5) 🔧 Check Installation"
        echo "  6) 📊 System Information"
        echo "  7) ⚡ Install Dependencies"
        echo "  0) 👋 Exit"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1) create_container ;;
            2) list_containers ;;
            3) manage_container ;;
            4) image_management ;;
            5) check_installation ;;
            6) show_system_info ;;
            7) install_dependencies ;;
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
            echo "Run option 7 from the main menu later."
            sleep 2
        fi
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
    print_color "$CYAN" "📦 Linux Containers Only | Easy Management"
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
