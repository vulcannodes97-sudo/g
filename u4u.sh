#!/bin/bash

# =============================
# LXC CONTAINER MANAGER
# Enhanced with Beautiful UI
# =============================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Paths
LXC_DIR="/var/lib/lxc"
CONFIG_DIR="$HOME/.lxc-manager"

# Function to display header
display_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════╗
║                    LXC CONTAINER MANAGEMENT PANEL                      ║
║                     Lightweight Container Excellence                   ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Function to show submenu with borders
show_submenu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║           $(printf '%-30s' "$title") ║"
    echo "╠════════════════════════════════════════╣"
    
    for option in "${options[@]}"; do
        echo "║ $option"
    done
    
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to print status with emojis
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "${BLUE}📋 [INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}⚠️  [WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}❌ [ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}✅ [SUCCESS]${NC} $message" ;;
        "INPUT") echo -e "${CYAN}🎯 [INPUT]${NC} $message" ;;
        "PROGRESS") echo -e "${PURPLE}⏳ [PROGRESS]${NC} $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_status "ERROR" "Please run as root (use: sudo $0)"
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in lxc grep awk tr curl wget; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, run: apt update && apt install lxd lxc-client curl wget"
        exit 1
    fi
}

# Function to initialize LXC
initialize_lxc() {
    print_status "INFO" "Checking LXC/LXD initialization..."
    
    if ! command -v lxd &> /dev/null; then
        print_status "WARN" "LXD not installed. Installing..."
        apt-get update && apt-get install -y lxd
    fi
    
    if [ ! -d "$LXC_DIR" ]; then
        print_status "INFO" "Initializing LXC..."
        lxd init --auto
    fi
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
}

# Function to get all containers
get_container_list() {
    lxc list --format csv | awk -F, '{print $1}' | sort
}

# Function to get container status
get_container_status() {
    local container_name=$1
    lxc list "$container_name" --format csv 2>/dev/null | awk -F, '{print $2}'
}

# Function to get container IP
get_container_ip() {
    local container_name=$1
    lxc list "$container_name" --format csv 2>/dev/null | awk -F, '{print $6}' | tr -d ' '
}

# Function to show container summary
show_container_summary() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        local status=$(get_container_status "$container_name")
        local ip=$(get_container_ip "$container_name")
        
        echo -e "${CYAN}"
        echo "╔════════════════════════════════════════╗"
        echo "║         CONTAINER SUMMARY              ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ Name: $container_name"
        echo "║ Status: $status"
        echo "║ IP Address: ${ip:-Not Assigned}"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMmKk]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 10G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (1-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,61}[a-zA-Z0-9]$ ]]; then
                print_status "ERROR" "Container name must be 1-63 chars, alphanumeric with hyphens"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to get input with defaults
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local validation="${4:-none}"
    
    while true; do
        read -p "$(print_status "INPUT" "$prompt (default: $default): ")" input
        if [ -z "$input" ]; then
            eval "$var_name=\"$default\""
            break
        else
            if [ "$validation" != "none" ]; then
                if validate_input "$validation" "$input"; then
                    eval "$var_name=\"$input\""
                    break
                fi
            else
                eval "$var_name=\"$input\""
                break
            fi
        fi
    done
}

# Function to select OS type
select_os() {
    show_submenu "SELECT OPERATING SYSTEM" \
        " 1) Ubuntu 22.04 LTS (Jammy) - Server" \
        " 2) Ubuntu 24.04 LTS (Noble) - Server" \
        " 3) Ubuntu 22.04 LTS - Desktop" \
        " 4) Ubuntu 24.04 LTS - Desktop" \
        " 5) Debian 11 (Bullseye) - Server" \
        " 6) Debian 12 (Bookworm) - Server" \
        " 7) Debian 13 (Trixie) - Server" \
        " 8) Debian 11 - Desktop" \
        " 9) Debian 12 - Desktop" \
        "10) CentOS Stream 9" \
        "11) AlmaLinux 9" \
        "12) Rocky Linux 9" \
        "13) Fedora 40" \
        "14) Kali Linux" \
        " 0) Back to Main Menu"
    
    while true; do
        read -p "$(print_status "INPUT" "🎯 Enter your choice (0-14): ")" choice
        case $choice in
            1) 
                IMAGE="ubuntu:22.04"
                OS_NAME="Ubuntu 22.04 Server"
                DESKTOP=false
                break
                ;;
            2) 
                IMAGE="ubuntu:24.04"
                OS_NAME="Ubuntu 24.04 Server"
                DESKTOP=false
                break
                ;;
            3) 
                IMAGE="ubuntu:22.04"
                OS_NAME="Ubuntu 22.04 Desktop"
                DESKTOP=true
                break
                ;;
            4) 
                IMAGE="ubuntu:24.04"
                OS_NAME="Ubuntu 24.04 Desktop"
                DESKTOP=true
                break
                ;;
            5)
                IMAGE="debian:11"
                OS_NAME="Debian 11 Server"
                DESKTOP=false
                break
                ;;
            6)
                IMAGE="debian:12"
                OS_NAME="Debian 12 Server"
                DESKTOP=false
                break
                ;;
            7)
                IMAGE="debian:13"
                OS_NAME="Debian 13 Server"
                DESKTOP=false
                break
                ;;
            8)
                IMAGE="debian:11"
                OS_NAME="Debian 11 Desktop"
                DESKTOP=true
                break
                ;;
            9)
                IMAGE="debian:12"
                OS_NAME="Debian 12 Desktop"
                DESKTOP=true
                break
                ;;
            10)
                IMAGE="centos-stream:9"
                OS_NAME="CentOS Stream 9"
                DESKTOP=false
                break
                ;;
            11)
                IMAGE="almalinux:9"
                OS_NAME="AlmaLinux 9"
                DESKTOP=false
                break
                ;;
            12)
                IMAGE="rockylinux:9"
                OS_NAME="Rocky Linux 9"
                DESKTOP=false
                break
                ;;
            13)
                IMAGE="fedora:40"
                OS_NAME="Fedora 40"
                DESKTOP=false
                break
                ;;
            14)
                IMAGE="images:kali/current"
                OS_NAME="Kali Linux"
                DESKTOP=false
                break
                ;;
            0) return 1 ;;
            *) print_status "ERROR" "Invalid choice" ;;
        esac
    done
    return 0
}

# Function to create new container
create_new_container() {
    display_header
    print_status "INFO" "🆕 Creating a new LXC container"
    
    # OS Selection
    if ! select_os; then
        return
    fi

    # Get container details
    get_input "🏷️  Enter container name" "${OS_NAME// /-}-$(date +%s)" "CONTAINER_NAME" "name"
    
    # Check if container already exists
    if lxc info "$CONTAINER_NAME" &>/dev/null; then
        print_status "ERROR" "Container '$CONTAINER_NAME' already exists"
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
        return
    fi

    get_input "🏠 Enter hostname" "$CONTAINER_NAME" "HOSTNAME" "name"
    get_input "👤 Enter username" "admin" "USERNAME" "username"
    
    # Password input
    while true; do
        read -s -p "$(print_status "INPUT" "🔑 Enter password (default: password123): ")" PASSWORD
        PASSWORD="${PASSWORD:-password123}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "Password cannot be empty"
        fi
    done

    get_input "💾 Disk size (e.g., 10GB)" "10GB" "DISK_SIZE" "size"
    get_input "🧠 Memory in MB" "2048" "MEMORY" "number"
    get_input "⚡ Number of CPUs" "2" "CPUS" "number"
    
    # SSH Port with validation
    while true; do
        get_input "🔌 SSH Port" "2222" "SSH_PORT" "port"
        # Check if port is already in use
        if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
            print_status "ERROR" "Port $SSH_PORT is already in use"
        else
            break
        fi
    done

    # Additional network options
    read -p "$(print_status "INPUT" "🌐 Additional port forwards (e.g., 8080:80, press Enter for none): ")" PORT_FORWARDS

    # Show summary
    echo -e "${YELLOW}"
    echo "╔════════════════════════════════════════╗"
    echo "║     CONTAINER CREATION SUMMARY        ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ OS: $OS_NAME"
    echo "║ Container Name: $CONTAINER_NAME"
    echo "║ Hostname: $HOSTNAME"
    echo "║ Username: $USERNAME"
    echo "║ Disk: $DISK_SIZE"
    echo "║ Memory: ${MEMORY}MB"
    echo "║ CPUs: $CPUS"
    echo "║ SSH Port: $SSH_PORT"
    echo "║ Desktop: $DESKTOP"
    echo "║ Port Forwards: ${PORT_FORWARDS:-None}"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "$(print_status "INPUT" "Proceed with creation? (y/N): ")" confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "INFO" "Creation cancelled"
        return
    fi
    
    # Create container
    print_status "PROGRESS" "📥 Creating container '$CONTAINER_NAME'..."
    
    if lxc launch "$IMAGE" "$CONTAINER_NAME" \
        --config limits.cpu="$CPUS" \
        --config limits.memory="${MEMORY}MB" \
        --config limits.memory.swap=true \
        --config boot.autostart=true \
        --config security.nesting=true \
        --config raw.lxc="lxc.cgroup2.devices.allow = a\nlxc.cap.drop =" ; then
        
        print_status "SUCCESS" "Container created successfully!"
        
        # Wait for container to start
        print_status "PROGRESS" "⏳ Waiting for container to initialize..."
        sleep 5
        
        # Set up user account
        if [ "$USERNAME" != "root" ]; then
            print_status "PROGRESS" "👤 Creating user account..."
            lxc exec "$CONTAINER_NAME" -- useradd -m -s /bin/bash "$USERNAME"
            lxc exec "$CONTAINER_NAME" -- usermod -aG sudo "$USERNAME"
        fi
        
        # Set password
        print_status "PROGRESS" "🔑 Setting passwords..."
        lxc exec "$CONTAINER_NAME" -- bash -c "echo -e '$PASSWORD\n$PASSWORD' | passwd root"
        if [ "$USERNAME" != "root" ]; then
            lxc exec "$CONTAINER_NAME" -- bash -c "echo -e '$PASSWORD\n$PASSWORD' | passwd $USERNAME"
        fi
        
        # Configure SSH
        print_status "PROGRESS" "🔌 Configuring SSH..."
        lxc exec "$CONTAINER_NAME" -- apt-get update
        lxc exec "$CONTAINER_NAME" -- apt-get install -y openssh-server sudo
        lxc exec "$CONTAINER_NAME" -- systemctl enable ssh
        
        # Set hostname
        lxc exec "$CONTAINER_NAME" -- hostnamectl set-hostname "$HOSTNAME"
        
        # Configure port forwarding
        if [ ! -z "$SSH_PORT" ]; then
            print_status "PROGRESS" "🔧 Configuring SSH port forward..."
            lxc config device add "$CONTAINER_NAME" ssh-proxy proxy \
                listen=tcp:0.0.0.0:$SSH_PORT \
                connect=tcp:127.0.0.1:22
        fi
        
        # Additional port forwards
        if [ ! -z "$PORT_FORWARDS" ]; then
            IFS=',' read -ra PORTS <<< "$PORT_FORWARDS"
            for port in "${PORTS[@]}"; do
                local_port=$(echo $port | cut -d: -f1)
                container_port=$(echo $port | cut -d: -f2)
                lxc config device add "$CONTAINER_NAME" "port-$local_port" proxy \
                    listen=tcp:0.0.0.0:$local_port \
                    connect=tcp:127.0.0.1:$container_port
                print_status "INFO" "Port $local_port forwarded to container port $container_port"
            done
        fi
        
        # Install desktop if selected
        if [ "$DESKTOP" = true ]; then
            print_status "PROGRESS" "🖥️  Installing desktop environment..."
            lxc exec "$CONTAINER_NAME" -- apt-get install -y ubuntu-desktop-minimal xrdp
            lxc exec "$CONTAINER_NAME" -- systemctl enable xrdp
            print_status "INFO" "Remote desktop available via RDP (port 3389)"
        fi
        
        # Get container IP
        CONTAINER_IP=$(get_container_ip "$CONTAINER_NAME")
        
        # Show success message
        echo -e "${GREEN}"
        echo "╔════════════════════════════════════════╗"
        echo "║   CONTAINER CREATED SUCCESSFULLY      ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ Name: $CONTAINER_NAME"
        echo "║ IP Address: $CONTAINER_IP"
        echo "║ SSH: ssh $USERNAME@localhost -p $SSH_PORT"
        echo "║ Password: $PASSWORD"
        if [ "$DESKTOP" = true ]; then
            echo "║ RDP: Connect to localhost:3389"
        fi
        if [ ! -z "$PORT_FORWARDS" ]; then
            echo "║ Port Forwards: $PORT_FORWARDS"
        fi
        echo "║"
        echo "║ Commands:"
        echo "║ - Shell: lxc exec $CONTAINER_NAME -- bash"
        echo "║ - Stop: lxc stop $CONTAINER_NAME"
        echo "║ - Start: lxc start $CONTAINER_NAME"
        echo "║ - Delete: lxc delete $CONTAINER_NAME"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        
    else
        print_status "ERROR" "Failed to create container"
    fi
    
    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
}

# Function to list containers
list_containers() {
    display_header
    
    local containers=($(get_container_list))
    local count=${#containers[@]}
    
    if [ $count -gt 0 ]; then
        print_status "INFO" "📁 Found $count container(s):"
        echo
        
        for container in "${containers[@]}"; do
            local status=$(get_container_status "$container")
            local ip=$(get_container_ip "$container")
            local status_icon="💤"
            local status_color="${YELLOW}"
            
            if [ "$status" = "RUNNING" ]; then
                status_icon="🚀"
                status_color="${GREEN}"
            elif [ "$status" = "STOPPED" ]; then
                status_icon="⏹️"
                status_color="${RED}"
            elif [ "$status" = "FROZEN" ]; then
                status_icon="❄️"
                status_color="${BLUE}"
            fi
            
            echo -e "  ${status_color}${status_icon} ${container}${NC}"
            echo -e "    📍 Status: $status"
            echo -e "    🌐 IP: ${ip:-Not Assigned}"
            echo -e "    ─────────────────────────────"
        done
    else
        print_status "INFO" "📭 No containers found"
    fi
    
    echo
    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
}

# Function to start container
start_container() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        local status=$(get_container_status "$container_name")
        
        if [ "$status" = "RUNNING" ]; then
            print_status "WARN" "Container '$container_name' is already running"
        else
            print_status "PROGRESS" "🚀 Starting container '$container_name'..."
            if lxc start "$container_name"; then
                print_status "SUCCESS" "Container started successfully"
                
                # Wait for network
                sleep 3
                local ip=$(get_container_ip "$container_name")
                if [ -n "$ip" ]; then
                    print_status "INFO" "IP Address: $ip"
                fi
            else
                print_status "ERROR" "Failed to start container"
            fi
        fi
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to stop container
stop_container() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        local status=$(get_container_status "$container_name")
        
        if [ "$status" != "RUNNING" ]; then
            print_status "WARN" "Container '$container_name' is not running"
        else
            print_status "PROGRESS" "🛑 Stopping container '$container_name'..."
            if lxc stop "$container_name"; then
                print_status "SUCCESS" "Container stopped successfully"
            else
                print_status "ERROR" "Failed to stop container"
            fi
        fi
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to restart container
restart_container() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        print_status "PROGRESS" "🔄 Restarting container '$container_name'..."
        if lxc restart "$container_name"; then
            print_status "SUCCESS" "Container restarted successfully"
        else
            print_status "ERROR" "Failed to restart container"
        fi
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to delete container
delete_container() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        echo -e "${RED}"
        echo "╔════════════════════════════════════════╗"
        echo "║           ⚠️  WARNING! ⚠️             ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ This will permanently delete           ║"
        echo "║ container '$container_name'!           ║"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "$(print_status "INPUT" "🗑️  Are you sure? (y/N): ")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Check if container is running
            local status=$(get_container_status "$container_name")
            if [ "$status" = "RUNNING" ]; then
                print_status "WARN" "Container is running. Stopping it first..."
                lxc stop "$container_name"
                sleep 2
            fi
            
            print_status "PROGRESS" "🗑️  Deleting container '$container_name'..."
            if lxc delete "$container_name"; then
                print_status "SUCCESS" "Container deleted successfully"
            else
                print_status "ERROR" "Failed to delete container"
            fi
        else
            print_status "INFO" "Deletion cancelled"
        fi
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to open container shell
open_shell() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        local status=$(get_container_status "$container_name")
        
        if [ "$status" != "RUNNING" ]; then
            print_status "WARN" "Container is not running. Starting it first..."
            lxc start "$container_name"
            sleep 3
        fi
        
        print_status "INFO" "Opening shell on '$container_name'..."
        print_status "INFO" "Type 'exit' to return to the menu"
        echo
        lxc exec "$container_name" -- bash
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to show container info
show_container_info() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        display_header
        show_container_summary "$container_name"
        
        # Get detailed info
        print_status "INFO" "📊 Detailed Information:"
        echo
        lxc info "$container_name"
        echo
        lxc config show "$container_name"
        
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to edit container configuration
edit_container_config() {
    local container_name=$1
    
    if lxc info "$container_name" &>/dev/null; then
        show_submenu "EDIT CONTAINER: $container_name" \
            " 1) 🧠 Change Memory Limit" \
            " 2) ⚡ Change CPU Limit" \
            " 3) 💾 Change Disk Size" \
            " 4) 🔌 Add Port Forward" \
            " 5) 🗑️  Remove Port Forward" \
            " 6) 🔧 Edit Raw Config" \
            " 0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                read -p "$(print_status "INPUT" "Enter new memory limit (e.g., 4096MB): ")" new_memory
                if lxc config set "$container_name" limits.memory "$new_memory"; then
                    print_status "SUCCESS" "Memory limit updated"
                fi
                ;;
            2)
                read -p "$(print_status "INPUT" "Enter new CPU limit: ")" new_cpu
                if lxc config set "$container_name" limits.cpu "$new_cpu"; then
                    print_status "SUCCESS" "CPU limit updated"
                fi
                ;;
            3)
                read -p "$(print_status "INPUT" "Enter new disk size (e.g., 20GB): ")" new_disk
                # This requires stopping the container and resizing
                print_status "WARN" "Disk resizing requires container to be stopped"
                read -p "$(print_status "INPUT" "Stop container and resize? (y/N): ")" confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    lxc stop "$container_name"
                    lxc config device set "$container_name" root size="$new_disk"
                    lxc start "$container_name"
                    print_status "SUCCESS" "Disk size updated"
                fi
                ;;
            4)
                read -p "$(print_status "INPUT" "Enter port forward (e.g., 8080:80): ")" port_forward
                IFS=':' read -r host_port container_port <<< "$port_forward"
                lxc config device add "$container_name" "proxy-$host_port" proxy \
                    listen=tcp:0.0.0.0:$host_port \
                    connect=tcp:127.0.0.1:$container_port
                print_status "SUCCESS" "Port forward added"
                ;;
            5)
                lxc config device list "$container_name" | grep proxy
                read -p "$(print_status "INPUT" "Enter proxy device name to remove: ")" device_name
                lxc config device remove "$container_name" "$device_name"
                print_status "SUCCESS" "Port forward removed"
                ;;
            6)
                ${EDITOR:-nano} "/var/lib/lxc/$container_name/config"
                print_status "INFO" "Configuration saved. Restart container for changes to take effect."
                ;;
            0) return ;;
            *) print_status "ERROR" "Invalid choice" ;;
        esac
    else
        print_status "ERROR" "Container '$container_name' not found"
    fi
}

# Function to show system information
show_system_info() {
    display_header
    
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║           SYSTEM INFORMATION           ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ Hostname: $(hostname)"
    echo "║ Kernel: $(uname -r)"
    echo "║ LXC Version: $(lxc --version 2>/dev/null || echo "Not found")"
    echo "║ LXD Version: $(lxd --version 2>/dev/null || echo "Not found")"
    echo "╠════════════════════════════════════════╣"
    echo "║               RESOURCES                ║"
    echo "╠════════════════════════════════════════╣"
    echo -e "${NC}"
    
    # Memory
    echo -e "🧠 Memory Usage:"
    free -h
    
    echo -e "\n💾 Disk Usage:"
    df -h /
    
    echo -e "\n⚡ CPU Info:"
    lscpu | grep -E "(CPU\(s\):|Model name|MHz)"
    
    echo -e "\n${CYAN}╚════════════════════════════════════════╝${NC}"
    
    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
}

# Function to manage containers
manage_container() {
    local container_name=$1
    
    while true; do
        display_header
        show_container_summary "$container_name"
        
        local status=$(get_container_status "$container_name")
        local status_icon="💤"
        
        if [ "$status" = "RUNNING" ]; then
            status_icon="🚀"
        fi
        
        show_submenu "MANAGE: $container_name $status_icon" \
            " 1) 🚀 Start Container" \
            " 2) 🛑 Stop Container" \
            " 3) 🔄 Restart Container" \
            " 4) 📊 Show Info" \
            " 5) 🐚 Open Shell" \
            " 6) ⚙️  Edit Configuration" \
            " 7) 📝 View Logs" \
            " 8) 🏷️  Rename Container" \
            " 9) 📦 Create Snapshot" \
            "10) 🗑️  Delete Container" \
            " 0) ↩️  Back to Main Menu"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1) start_container "$container_name" ;;
            2) stop_container "$container_name" ;;
            3) restart_container "$container_name" ;;
            4) show_container_info "$container_name" ;;
            5) open_shell "$container_name" ;;
            6) edit_container_config "$container_name" ;;
            7) 
                lxc info "$container_name" --show-log
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                ;;
            8)
                read -p "$(print_status "INPUT" "Enter new name: ")" new_name
                if lxc move "$container_name" "$new_name"; then
                    print_status "SUCCESS" "Container renamed to $new_name"
                    container_name="$new_name"
                fi
                ;;
            9)
                read -p "$(print_status "INPUT" "Enter snapshot name: ")" snapshot_name
                if lxc snapshot "$container_name" "$snapshot_name"; then
                    print_status "SUCCESS" "Snapshot created: $snapshot_name"
                fi
                ;;
            10) 
                delete_container "$container_name"
                return 0
                ;;
            0) return 0 ;;
            *) print_status "ERROR" "Invalid choice" ;;
        esac
        
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    done
}

# Main menu
main_menu() {
    while true; do
        display_header
        
        local containers=($(get_container_list))
        local count=${#containers[@]}
        
        if [ $count -gt 0 ]; then
            print_status "INFO" "📁 Found $count container(s):"
            echo
            
            for i in "${!containers[@]}"; do
                local status=$(get_container_status "${containers[$i]}")
                local status_icon="💤"
                
                if [ "$status" = "RUNNING" ]; then
                    status_icon="🚀"
                fi
                
                printf "  %2d) %s %s\n" $((i+1)) "${containers[$i]}" "$status_icon"
            done
            echo
        fi
        
        show_submenu "MAIN MENU" \
            " 1) 🆕 Create new container" \
            " 2) 📋 List all containers" \
            " 3) ⚙️  Manage specific container" \
            " 4) 🛠️  System tools" \
            " 5) 📊 System information" \
            " 6) 🔧 Check/Install dependencies" \
            " 0) 👋 Exit"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_container
                ;;
            2)
                list_containers
                ;;
            3)
                if [ $count -gt 0 ]; then
                    echo
                    read -p "$(print_status "INPUT" "Enter container number to manage: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $count ]; then
                        manage_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                    fi
                else
                    print_status "INFO" "No containers available"
                    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                fi
                ;;
            4)
                show_submenu "SYSTEM TOOLS" \
                    " 1) 🔄 Restart LXD service" \
                    " 2) 🧹 Clean up unused images" \
                    " 3) 💾 Backup all containers" \
                    " 4) 🔍 Check LXC/LXD status" \
                    " 0) ↩️  Back"
                
                read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" tool_choice
                
                case $tool_choice in
                    1)
                        systemctl restart lxd
                        print_status "SUCCESS" "LXD service restarted"
                        ;;
                    2)
                        lxc image list
                        read -p "$(print_status "INPUT" "Delete unused images? (y/N): ")" confirm
                        if [[ $confirm =~ ^[Yy]$ ]]; then
                            lxc image prune
                            print_status "SUCCESS" "Unused images cleaned up"
                        fi
                        ;;
                    3)
                        print_status "INFO" "Backup feature coming soon!"
                        ;;
                    4)
                        systemctl status lxd --no-pager
                        lxc list
                        ;;
                    0) ;;
                    *) print_status "ERROR" "Invalid choice" ;;
                esac
                ;;
            5)
                show_system_info
                ;;
            6)
                check_dependencies
                initialize_lxc
                print_status "SUCCESS" "All dependencies are installed"
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                ;;
            0)
                print_status "INFO" "👋 Goodbye!"
                echo
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid option"
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                ;;
        esac
    done
}

# Main execution
check_root
check_dependencies
initialize_lxc
main_menu
