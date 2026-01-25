#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display headers
header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║        LXC CONTAINER MANAGER          ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Please run as root (sudo)"
        exit 1
    fi
}

# Function to install required packages
install_dependencies() {
    echo -e "${YELLOW}[INFO]${NC} Checking dependencies..."
    
    # Check for required commands
    for cmd in lxc grep awk tr curl; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${YELLOW}[INFO]${NC} Installing $cmd..."
            apt-get update && apt-get install -y $cmd
        fi
    done
    
    # Check if LXC is initialized
    if [ ! -f "/var/lib/lxc/default.conf" ]; then
        echo -e "${YELLOW}[INFO]${NC} Initializing LXC..."
        lxd init --auto
    fi
}

# Function to create Ubuntu container
create_ubuntu() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║           UBUNTU VERSIONS              ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1) Server 22.04 LTS (Jammy)           ║"
    echo "║ 2) Server 24.04 LTS (Noble)           ║"
    echo "║ 3) Desktop 22.04 LTS (Jammy)          ║"
    echo "║ 4) Desktop 24.04 LTS (Noble)          ║"
    echo "║ 0) Back to Main Menu                  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "🎯 [INPUT] Enter your choice (0-4): " ubuntu_choice
    
    case $ubuntu_choice in
        1) OS_TYPE="ubuntu:22.04"; OS_NAME="ubuntu-server-2204" ;;
        2) OS_TYPE="ubuntu:24.04"; OS_NAME="ubuntu-server-2404" ;;
        3) OS_TYPE="ubuntu:22.04"; OS_NAME="ubuntu-desktop-2204"; DESKTOP=true ;;
        4) OS_TYPE="ubuntu:24.04"; OS_NAME="ubuntu-desktop-2404"; DESKTOP=true ;;
        0) return ;;
        *) echo -e "${RED}[ERROR]${NC} Invalid choice"; return ;;
    esac
}

# Function to create Debian container
create_debian() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║            DEBIAN VERSIONS             ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1) Debian 11 (Bullseye) - Server      ║"
    echo "║ 2) Debian 12 (Bookworm) - Server      ║"
    echo "║ 3) Debian 11 (Bullseye) - Desktop     ║"
    echo "║ 4) Debian 12 (Bookworm) - Desktop     ║"
    echo "║ 0) Back to Main Menu                  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "🎯 [INPUT] Enter your choice (0-4): " debian_choice
    
    case $debian_choice in
        1) OS_TYPE="debian:11"; OS_NAME="debian-11" ;;
        2) OS_TYPE="debian:12"; OS_NAME="debian-12" ;;
        3) OS_TYPE="debian:11"; OS_NAME="debian-desktop-11"; DESKTOP=true ;;
        4) OS_TYPE="debian:12"; OS_NAME="debian-desktop-12"; DESKTOP=true ;;
        0) return ;;
        *) echo -e "${RED}[ERROR]${NC} Invalid choice"; return ;;
    esac
}

# Function to get user input with defaults
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "🎯 [INPUT] $prompt (default: $default): " input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Function to create LXC container
create_lxc() {
    header
    
    echo -e "${GREEN}[INFO]${NC} 🆕 Creating a new LXC"
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║         SELECT OPERATING SYSTEM        ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1) Ubuntu                              ║"
    echo "║ 2) Debian                              ║"
    echo "║ 3) AlmaLinux 9                         ║"
    echo "║ 4) CentOS Stream 9                     ║"
    echo "║ 5) Rocky Linux 9                       ║"
    echo "║ 6) Fedora 40                           ║"
    echo "║ 7) Kali Linux                          ║"
    echo "║ 0) Back to Main Menu                  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "🎯 [INPUT] Enter your choice (0-7): " os_choice
    
    case $os_choice in
        1) 
            create_ubuntu
            if [ $? -eq 1 ]; then return; fi
            ;;
        2) 
            create_debian
            if [ $? -eq 1 ]; then return; fi
            ;;
        3) OS_TYPE="almalinux:9"; OS_NAME="almalinux-9" ;;
        4) OS_TYPE="centos-stream:9"; OS_NAME="centos-stream-9" ;;
        5) OS_TYPE="rockylinux:9"; OS_NAME="rockylinux-9" ;;
        6) OS_TYPE="fedora:40"; OS_NAME="fedora-40" ;;
        7) OS_TYPE="images:kali/current"; OS_NAME="kali-linux" ;;
        0) return ;;
        *) echo -e "${RED}[ERROR]${NC} Invalid choice"; return ;;
    esac
    
    # Get container details
    get_input "🏷️  Enter container name" "${OS_NAME}-$(date +%s)" CONTAINER_NAME
    get_input "🏠 Enter hostname" "$CONTAINER_NAME" HOSTNAME
    get_input "👤 Enter username" "admin" USERNAME
    get_input "🔑 Enter password" "password123" PASSWORD
    get_input "💾 Disk size in GB" "10" DISK_SIZE
    get_input "🧠 Memory in MB" "2048" MEMORY
    get_input "⚡ Number of CPUs" "2" CPUS
    get_input "🔌 SSH Port" "2222" SSH_PORT
    
    read -p "🎯 [INPUT] 🌐 Additional port forwards (e.g., 8080:80, press Enter for none): " PORT_FORWARDS
    
    # Summary
    echo -e "${YELLOW}"
    echo "╔════════════════════════════════════════╗"
    echo "║         CONTAINER SUMMARY              ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ Container: $CONTAINER_NAME"
    echo "║ OS Type: $OS_TYPE"
    echo "║ Hostname: $HOSTNAME"
    echo "║ Username: $USERNAME"
    echo "║ Disk: ${DISK_SIZE}G"
    echo "║ Memory: ${MEMORY}MB"
    echo "║ CPUs: $CPUS"
    echo "║ SSH Port: $SSH_PORT"
    echo "║ Port Forwards: ${PORT_FORWARDS:-None}"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "🎯 [INPUT] Proceed with creation? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[INFO]${NC} Creation cancelled"
        return
    fi
    
    # Create container
    echo -e "${GREEN}[INFO]${NC} 📥 Downloading and preparing image..."
    
    # Launch container
    if lxc launch "$OS_TYPE" "$CONTAINER_NAME" \
        --config limits.cpu="$CPUS" \
        --config limits.memory="${MEMORY}MB" \
        --config limits.memory.swap=true \
        --config boot.autostart=true \
        --config security.nesting=true \
        --config raw.lxc="lxc.cgroup2.devices.allow = a\nlxc.cap.drop =" ; then
        
        echo -e "${GREEN}[INFO]${NC} Container created successfully!"
        
        # Wait for container to start
        echo -e "${YELLOW}[INFO]${NC} Waiting for container to initialize..."
        sleep 5
        
        # Set root password
        echo -e "${YELLOW}[INFO]${NC} Setting up user account..."
        if [ "$USERNAME" != "root" ]; then
            lxc exec "$CONTAINER_NAME" -- useradd -m -s /bin/bash "$USERNAME"
            lxc exec "$CONTAINER_NAME" -- usermod -aG sudo "$USERNAME"
        fi
        
        # Set password
        lxc exec "$CONTAINER_NAME" -- bash -c "echo -e '$PASSWORD\n$PASSWORD' | passwd $USERNAME"
        
        # Configure SSH (if not Kali - Kali has different SSH setup)
        if [ "$os_choice" != "7" ]; then
            echo -e "${YELLOW}[INFO]${NC} Configuring SSH..."
            lxc exec "$CONTAINER_NAME" -- apt-get update
            lxc exec "$CONTAINER_NAME" -- apt-get install -y openssh-server
            lxc exec "$CONTAINER_NAME" -- systemctl enable ssh
        fi
        
        # Configure port forwarding
        if [ ! -z "$SSH_PORT" ]; then
            echo -e "${YELLOW}[INFO]${NC} Configuring SSH port forward..."
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
                echo -e "${GREEN}[INFO]${NC} Port $local_port forwarded to container port $container_port"
            done
        fi
        
        # Start container
        lxc start "$CONTAINER_NAME"
        
        # Get container IP
        CONTAINER_IP=$(lxc list "$CONTAINER_NAME" --format=csv | cut -d, -f6 | tr -d ' ')
        
        echo -e "${GREEN}"
        echo "╔════════════════════════════════════════╗"
        echo "║     CONTAINER CREATED SUCCESSFULLY    ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ Name: $CONTAINER_NAME"
        echo "║ IP Address: $CONTAINER_IP"
        echo "║ SSH: ssh $USERNAME@localhost -p $SSH_PORT"
        echo "║ Password: $PASSWORD"
        if [ ! -z "$PORT_FORWARDS" ]; then
            echo "║ Port Forwards: $PORT_FORWARDS"
        fi
        echo "║"
        echo "║ Commands:"
        echo "║ - Connect: lxc exec $CONTAINER_NAME -- bash"
        echo "║ - Stop: lxc stop $CONTAINER_NAME"
        echo "║ - Start: lxc start $CONTAINER_NAME"
        echo "║ - Delete: lxc delete $CONTAINER_NAME"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        
    else
        echo -e "${RED}[ERROR]${NC} Failed to create container"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to list containers
list_containers() {
    header
    echo -e "${GREEN}[INFO]${NC} 📋 Listing all LXC containers..."
    echo ""
    lxc list
    echo ""
    read -p "Press Enter to continue..."
}

# Function to manage containers
manage_containers() {
    header
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║         MANAGE CONTAINERS              ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1) Start Container                     ║"
    echo "║ 2) Stop Container                      ║"
    echo "║ 3) Restart Container                   ║"
    echo "║ 4) Delete Container                    ║"
    echo "║ 5) Open Shell                          ║"
    echo "║ 6) View Logs                           ║"
    echo "║ 0) Back to Main Menu                  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "🎯 [INPUT] Enter your choice (0-6): " manage_choice
    
    case $manage_choice in
        1)
            read -p "Enter container name: " container
            lxc start "$container" && echo -e "${GREEN}[INFO]${NC} Container started"
            ;;
        2)
            read -p "Enter container name: " container
            lxc stop "$container" && echo -e "${YELLOW}[INFO]${NC} Container stopped"
            ;;
        3)
            read -p "Enter container name: " container
            lxc restart "$container" && echo -e "${GREEN}[INFO]${NC} Container restarted"
            ;;
        4)
            read -p "Enter container name: " container
            read -p "Are you sure? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                lxc delete "$container" && echo -e "${RED}[INFO]${NC} Container deleted"
            fi
            ;;
        5)
            read -p "Enter container name: " container
            lxc exec "$container" -- bash
            ;;
        6)
            read -p "Enter container name: " container
            lxc info "$container"
            ;;
        0) return ;;
        *) echo -e "${RED}[ERROR]${NC} Invalid choice" ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Function to show system info
show_info() {
    header
    echo -e "${GREEN}[INFO]${NC} 📊 System Information"
    echo ""
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "LXC Version: $(lxc --version 2>/dev/null || echo "Not found")"
    echo ""
    echo "Disk Usage:"
    df -h / | tail -1
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        header
        
        echo -e "${CYAN}"
        echo "╔════════════════════════════════════════╗"
        echo "║            MAIN MENU                   ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ 1) 🆕 Create new LXC container         ║"
        echo "║ 2) 📋 List all containers              ║"
        echo "║ 3) ⚙️  Manage containers                ║"
        echo "║ 4) 📊 System information               ║"
        echo "║ 5) 🔧 Install dependencies             ║"
        echo "║ 0) 👋 Exit                            ║"
        echo "╚════════════════════════════════════════╝"
        echo -e "${NC}"
        
        read -p "🎯 [INPUT] 🎯 Enter your choice: " choice
        
        case $choice in
            1) create_lxc ;;
            2) list_containers ;;
            3) manage_containers ;;
            4) show_info ;;
            5) install_dependencies ;;
            0) 
                echo -e "${GREEN}[INFO]${NC} Goodbye! 👋"
                exit 0
                ;;
            *) 
                echo -e "${RED}[ERROR]${NC} Invalid choice"
                sleep 2
                ;;
        esac
    done
}

# Main execution
check_root
install_dependencies
main_menu
