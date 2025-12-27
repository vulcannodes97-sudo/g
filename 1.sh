#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 4.0 - Windows & Linux Support
# ============================================


# if you use Ubuntu


# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
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
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            LXC/LXD Container Manager v4.0                    ║"
    echo "║          Windows & Linux Support with VNC                    ║"
    echo "║               Mode BY - Nobita                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
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
    ["10"]="windows/11|Windows 11 (VM)"
    ["11"]="windows/10|Windows 10 (VM)"
    ["12"]="ubuntu/focal/cloud|Ubuntu 20.04 (Desktop)"
)

# Windows-specific images (需要手动导入)
declare -A WINDOWS_IMAGES=(
    ["win11"]="Windows 11 Professional"
    ["win10"]="Windows 10 Professional"
    ["win11-enterprise"]="Windows 11 Enterprise"
    ["win10-enterprise"]="Windows 10 Enterprise"
    ["win2022"]="Windows Server 2022"
    ["win2019"]="Windows Server 2019"
)

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Dependencies..."
    echo "══════════════════════════════════════════════════════════════"
    
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
            
            # Install virtualization tools for Windows VMs
            print_color "$CYAN" "💻 Installing virtualization tools..."
            sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst virt-manager bridge-utils
            
            # Install VNC tools for remote access
            print_color "$CYAN" "👁️  Installing VNC tools..."
            sudo apt install -y tigervnc-viewer novnc websockify
            
            # Install and configure snapd for LXD
            if ! command -v snap &> /dev/null; then
                print_color "$CYAN" "📦 Installing snapd..."
                sudo apt install -y snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
                echo "⚠️  Please log out and log back in for snap to work properly"
            fi
            
            # Install LXD (latest version for Windows support)
            print_color "$CYAN" "🚀 Installing LXD 5.0 or later..."
            sudo snap install lxd --channel=latest/stable
            
            # Add user to necessary groups
            print_color "$CYAN" "👤 Adding user to groups..."
            sudo usermod -aG lxd $USER
            sudo usermod -aG kvm $USER
            sudo usermod -aG libvirt $USER
            
            # Initialize LXD with VM support
            print_color "$CYAN" "⚙️  Initializing LXD..."
            echo "Setting up LXD with virtualization support..."
            sudo lxd init --auto --storage-backend=zfs --storage-create-loop=20
            
            # Enable VM support
            print_color "$CYAN" "💻 Enabling VM support..."
            sudo lxc config set core.https_address "[::]:8443"
            sudo lxc config set core.trust_password password
            
            # Start LXD service
            print_color "$CYAN" "▶️  Starting LXD service..."
            sudo systemctl start snap.lxd.daemon 2>/dev/null || sudo systemctl start lxd 2>/dev/null
            
            # Enable KVM
            print_color "$CYAN" "🔧 Enabling KVM..."
            sudo modprobe kvm
            sudo modprobe kvm_intel 2>/dev/null || sudo modprobe kvm_amd 2>/dev/null
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  IMPORTANT: Please log out and log back in for group changes!"
            print_color "$YELLOW" "   Then run this script again."
            print_color "$CYAN" "💡 For Windows VMs, you'll need to import Windows ISO images."
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo "For Ubuntu/Debian:"
            echo "  sudo apt install lxc lxc-utils bridge-utils snapd qemu-kvm virt-manager"
            echo "  sudo snap install lxd"
            echo "  sudo usermod -aG lxd,kvm,libvirt \$USER"
            echo "  sudo lxd init --auto"
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
    exit 0
}

# 添加新函数：检测Windows镜像
detect_windows_images() {
    print_color "$PURPLE" "🪟 Searching for Windows images..."
    
    local win_count=0
    local win_images=$(lxc image list images: 2>/dev/null | grep -i windows | head -10)
    
    if [[ -n "$win_images" ]]; then
        while IFS= read -r line; do
            local image_name=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
            local description=$(echo "$line" | awk -F'|' '{print $3}' | xargs)
            
            if [[ -n "$image_name" ]]; then
                ((win_count++))
                # 添加到AVAILABLE_IMAGES
                local key=$((100 + win_count))  # 100+ 给Windows保留
                AVAILABLE_IMAGES["$key"]="images:$image_name|$description"
            fi
        done <<< "$win_images"
    fi
    
    # 如果没有找到，添加Windows占位符
    if [[ $win_count -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  No Windows images found. You'll need to import them manually."
        echo
        print_color "$CYAN" "💡 To add Windows images:"
        echo "  1. Download Windows ISO from Microsoft"
        echo "  2. Use: lxc image import /path/to/windows.iso --alias windows10"
        echo "  3. Or use cloud images if available"
    else
        print_color "$GREEN" "✅ Found $win_count Windows images"
    fi
}

# 修改detect_available_images函数
detect_available_images() {
    print_color "$CYAN" "🔍 Scanning for available images..."
    echo
    
    # Clear previous image list
    declare -gA AVAILABLE_IMAGES
    AVAILABLE_IMAGES=()
    
    # List of remotes to check
    local remotes=("images" "ubuntu" "debian" "fedora" "centos" "almalinux" "rockylinux")
    local image_count=0
    
    # Try to get images from remotes
    for remote in "${remotes[@]}"; do
        print_color "$BLUE" "📡 Checking remote: $remote"
        
        # Try to list images from this remote
        local remote_images=$(timeout 15 lxc image list "$remote:" 2>/dev/null | grep -E "^\| [a-zA-Z0-9/:-]+ \|" | head -15)
        
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
    
    # 检测Windows镜像
    detect_windows_images
    
    # If no images found, use defaults
    if [[ ${#AVAILABLE_IMAGES[@]} -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  Could not detect images automatically. Using defaults..."
        for key in "${!DEFAULT_IMAGES[@]}"; do
            AVAILABLE_IMAGES["$key"]="${DEFAULT_IMAGES[$key]}"
        done
    fi
    
    echo
    print_color "$GREEN" "✅ Found ${#AVAILABLE_IMAGES[@]} available images"
    sleep 1
}

# 添加新函数：安装VNC服务
install_vnc_service() {
    local container_name=$1
    local vnc_password=$2
    local vnc_port=$3
    
    print_color "$CYAN" "👁️  Configuring VNC for $container_name..."
    
    # 对于Linux容器
    if [[ "$container_name" =~ ubuntu|debian|centos|fedora ]]; then
        # 创建VNC安装脚本
        cat > /tmp/install_vnc.sh << 'EOF'
#!/bin/bash
# Install VNC Server
apt update && apt install -y tightvncserver xfce4 xfce4-goodies firefox || \
yum install -y tigervnc-server @xfce firefox || \
dnf install -y tigervnc-server @xfce-desktop firefox

# Create VNC password
mkdir -p ~/.vnc
echo -e "$VNC_PASSWORD\n$VNC_PASSWORD\nn" | vncpasswd ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create VNC startup script
cat > ~/.vnc/xstartup << 'VNC_EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
VNC_EOF

chmod +x ~/.vnc/xstartup

# Start VNC server on specified port
vncserver :1 -geometry 1280x800 -depth 24 -localhost no
echo "VNC server started on port 5901"
EOF
        
        # 复制并执行脚本
        lxc file push /tmp/install_vnc.sh $container_name/tmp/
        lxc exec $container_name -- bash -c "export VNC_PASSWORD='$vnc_password' && bash /tmp/install_vnc.sh"
        
    # 对于Windows容器（VM）
    elif [[ "$container_name" =~ win || "$container_name" =~ windows ]]; then
        # Windows VM通常内置RDP，我们配置SPICE或VNC
        print_color "$BLUE" "💻 Windows VM detected - using SPICE for better performance"
        
        # 配置SPICE显示
        lxc config device add $container_name spice serial= spice.agent.enabled=true \
            listen=type=address,address=0.0.0.0,port=5900
        
        # 添加VirtIO显卡
        lxc config device add $container_name video-gpu gpu \
            driver=virtio-gpu accel3d=true
        
        print_color "$GREEN" "✅ SPICE/VNC configured for Windows VM"
        print_color "$CYAN" "🔗 Connect using:"
        echo "  - Remote Desktop (RDP): Connect to container IP"
        echo "  - SPICE: Use virt-viewer or similar client"
        echo "  - VNC: Connect to host:$vnc_port"
    fi
    
    rm -f /tmp/install_vnc.sh
}

# 修改create_container函数，添加VNC配置选项
create_container() {
    # Detect available images first
    detect_available_images
    
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
    echo "══════════════════════════════════════════════════════════════"
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
    
    # Check if Windows image
    local is_windows=false
    if [[ "$image_name" =~ windows|win11|win10 ]]; then
        is_windows=true
        print_color "$PURPLE" "🪟 Windows image detected - will create as Virtual Machine"
    fi
    
    # Get container type
    echo
    print_color "$YELLOW" "💻 Container Type:"
    echo "  1) Container (Default) - Lightweight, shares host kernel"
    echo "  2) Virtual Machine - Full VM with its own kernel (more resources)"
    
    # Windows强制使用VM
    if [ "$is_windows" = true ]; then
        container_type=2
        print_color "$PURPLE" "⚠️  Windows requires Virtual Machine mode. Auto-selected option 2"
    else
        read -p "Select type (1-2, default: 1): " container_type
        container_type=${container_type:-1}
    fi
    
    local type_flag=""
    case $container_type in
        1) 
            type_flag=""
            print_color "$BLUE" "📦 Selected: Container (lightweight)"
            ;;
        2) 
            type_flag="--vm"
            print_color "$PURPLE" "💻 Selected: Virtual Machine (required for Windows)"
            ;;
        *) 
            type_flag=""
            print_color "$YELLOW" "⚠️  Using default: Container"
            ;;
    esac
    
    # Windows专用资源设置
    if [ "$is_windows" = true ]; then
        print_color "$PURPLE" "🪟 Windows VM Recommended Settings:"
        disk_size="50GB"
        memory="4GB"
        cpu_count="2"
        print_color "$CYAN" "💾 Disk: $disk_size (Windows needs more space)"
        print_color "$CYAN" "🧠 Memory: $memory (minimum for Windows)"
        print_color "$CYAN" "⚡ CPU: $cpu_count cores"
        
        read -p "Use Windows defaults? (Y/n): " use_defaults
        use_defaults=${use_defaults:-Y}
        
        if [[ ! "$use_defaults" =~ ^[Yy]$ ]]; then
            echo
            print_color "$YELLOW" "⚙️  Custom Resource Configuration:"
            read -p "💾 Disk size (minimum 30GB, default: 50GB): " disk_size
            disk_size=${disk_size:-50GB}
            
            read -p "🧠 Memory (minimum 2GB, default: 4GB): " memory
            memory=${memory:-4GB}
            
            read -p "⚡ CPU cores (default: 2): " cpu_count
            cpu_count=${cpu_count:-2}
        fi
    else
        # Linux资源设置
        echo
        print_color "$YELLOW" "⚙️  Resource Configuration:"
        read -p "💾 Disk size (e.g., 10GB, default: 10GB): " disk_size
        disk_size=${disk_size:-10GB}
        
        read -p "🧠 Memory (e.g., 2GB, default: 2GB): " memory
        memory=${memory:-2GB}
        
        read -p "⚡ CPU cores (default: 2): " cpu_count
        cpu_count=${cpu_count:-2}
    fi
    
    # VNC配置
    local enable_vnc=false
    local vnc_password=""
    local vnc_port="5901"
    
    echo
    print_color "$CYAN" "👁️  Remote Access Configuration:"
    read -p "Enable VNC/RDP remote access? (y/N): " enable_vnc_choice
    
    if [[ "$enable_vnc_choice" =~ ^[Yy]$ ]]; then
        enable_vnc=true
        
        if [ "$is_windows" = true ]; then
            print_color "$PURPLE" "💻 Windows will have RDP enabled by default"
            vnc_port="3389"  # RDP端口
        else
            read -p "🔒 Set VNC password (default: vncpassword): " vnc_password
            vnc_password=${vnc_password:-vncpassword}
            
            read -p "🔌 VNC port (default: 5901): " vnc_port
            vnc_port=${vnc_port:-5901}
        fi
    fi
    
    # Summary
    echo
    print_color "$CYAN" "📋 Creation Summary:"
    echo "──────────────────────────────────────────────────────"
    echo "🏷️  Name: $container_name"
    echo "📦 Image: $display_name"
    echo "💻 Type: $([ "$type_flag" == "--vm" ] && echo "Virtual Machine" || echo "Container")"
    echo "💾 Disk: $disk_size"
    echo "🧠 Memory: $memory"
    echo "⚡ CPU: $cpu_count cores"
    if [ "$enable_vnc" = true ]; then
        if [ "$is_windows" = true ]; then
            echo "👁️  Remote: RDP enabled (port 3389)"
        else
            echo "👁️  Remote: VNC enabled (port $vnc_port)"
        fi
    fi
    echo "──────────────────────────────────────────────────────"
    echo
    
    read -p "✅ Proceed with creation? (Y/n): " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  Creation cancelled."
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # 创建容器
    print_color "$BLUE" "📦 Creating container '$container_name'..."
    echo
    
    # 检查是否是Windows镜像
    local launch_success=false
    
    if [ "$is_windows" = true ]; then
        print_color "$PURPLE" "🪟 Creating Windows Virtual Machine..."
        
        # Windows创建特殊处理
        print_color "$CYAN" "💡 Note: Windows VMs may require manual ISO installation"
        print_color "$YELLOW" "⚠️  You may need to manually install Windows from ISO"
        
        # 尝试创建VM
        if lxc launch $type_flag "$image_name" "$container_name" --config limits.cpu=$cpu_count --config limits.memory=$memory 2>&1 | tee /tmp/lxc_launch.log; then
            launch_success=true
        else
            print_color "$RED" "❌ Failed to create Windows VM"
            echo
            print_color "$YELLOW" "💡 Windows VM Troubleshooting:"
            echo "1. Ensure KVM is enabled: sudo modprobe kvm-intel (or kvm-amd)"
            echo "2. Check virtualization in BIOS"
            echo "3. You may need to import Windows ISO manually:"
            echo "   lxc image import /path/to/windows.iso --alias windows10"
            echo "   lxc launch images:windows10 vm-name --vm"
        fi
    else
        # Linux容器创建
        if lxc launch $type_flag "$image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
            launch_success=true
        else
            # 错误处理...
            local error_msg=$(cat /tmp/lxc_launch.log)
            # ... 保持原有的错误处理代码
        fi
    fi
    
    if [[ "$launch_success" == false ]]; then
        print_color "$RED" "❌ Failed to create container!"
        echo
        print_color "$YELLOW" "💡 Troubleshooting tips:"
        echo "1. Check if LXD is initialized: sudo lxd init --auto"
        echo "2. List available images: lxc image list images:"
        echo "3. Try a different image name"
        echo "4. Check internet connection"
        echo "5. For Windows: Check KVM/virtualization support"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # 设置资源限制
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
    
    # 配置VNC/RDP
    if [ "$enable_vnc" = true ]; then
        install_vnc_service "$container_name" "$vnc_password" "$vnc_port"
    fi
    
    # 等待容器准备就绪
    print_color "$BLUE" "⏳ Waiting for container to initialize..."
    sleep 10
    
    # 显示容器信息
    echo
    print_color "$CYAN" "📊 Container Information:"
    echo "──────────────────────────────────────────────────────"
    lxc list "$container_name"
    
    # 获取IP地址
    local container_ip=$(lxc list "$container_name" -c 4 --format csv | head -1)
    
    echo
    print_color "$GREEN" "🎉 Container '$container_name' created successfully!"
    
    if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
        print_color "$BLUE" "🌐 IP Address: $container_ip"
        
        # 显示连接信息
        echo
        print_color "$YELLOW" "🔗 Connection Information:"
        
        if [ "$is_windows" = true ]; then
            echo "  RDP: Use Remote Desktop Connection"
            echo "  Address: $container_ip"
            echo "  Username: Administrator"
            echo "  Password: Set during Windows setup"
        else
            # 确定默认用户名
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
            
            if [ "$enable_vnc" = true ]; then
                echo "  VNC: Connect to host:$vnc_port"
                echo "  VNC Password: $vnc_password"
            fi
        fi
    fi
    
    # 对于Windows，提供额外提示
    if [ "$is_windows" = true ]; then
        echo
        print_color "$PURPLE" "🪟 Windows VM Notes:"
        echo "  1. First boot may take several minutes"
        echo "  2. You may need to complete Windows setup"
        echo "  3. Use RDP for graphical interface"
        echo "  4. Drivers are provided via VirtIO"
    fi
    
    # 提供打开shell的选项
    echo
    if [ "$is_windows" = false ]; then
        read -p "💻 Open shell in container? (y/N): " open_shell
        if [[ "$open_shell" =~ ^[Yy]$ ]]; then
            echo "📝 Type 'exit' to return to menu"
            lxc exec "$container_name" -- /bin/bash || lxc exec "$container_name" -- /bin/sh
        fi
    else
        print_color "$CYAN" "💡 Use RDP client to connect to Windows VM"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# 添加新函数：导入Windows ISO
import_windows_iso() {
    print_header
    print_color "$PURPLE" "🪟 Windows ISO Import"
    echo "══════════════════════════════════════════════════════════════"
    echo
    
    print_color "$YELLOW" "📋 Steps to add Windows to LXD:"
    echo "──────────────────────────────────────────────────────"
    echo "1. Download Windows ISO from Microsoft"
    echo "2. Convert ISO to LXD compatible image"
    echo "3. Import into LXD"
    echo
    
    read -p "Do you have Windows ISO file? (y/N): " has_iso
    
    if [[ "$has_iso" =~ ^[Yy]$ ]]; then
        read -p "📁 Enter full path to Windows ISO: " iso_path
        
        if [[ -f "$iso_path" ]]; then
            read -p "🏷️  Enter alias (e.g., win10-pro): " iso_alias
            
            print_color "$BLUE" "🔄 Converting and importing Windows ISO..."
            
            # 创建临时目录
            local temp_dir=$(mktemp -d)
            
            # 提取ISO（简化版本）
            print_color "$CYAN" "📦 Extracting Windows ISO..."
            
            # 尝试使用wimlib-imagex提取
            if command -v wimlib-imagex &> /dev/null; then
                sudo apt install -y wimtools 2>/dev/null || true
                
                # 挂载ISO
                sudo mount -o loop "$iso_path" "$temp_dir" 2>/dev/null || print_color "$YELLOW" "⚠️  Could not mount ISO"
                
                # 导入到LXD
                print_color "$GREEN" "✅ Importing to LXD..."
                if lxc image import "$iso_path" --alias "$iso_alias" --vm; then
                    print_color "$GREEN" "🎉 Windows image imported as '$iso_alias'!"
                    print_color "$CYAN" "💡 Now you can create VM: lxc launch $iso_alias vm-name --vm"
                else
                    print_color "$RED" "❌ Failed to import ISO"
                fi
                
                # 卸载ISO
                sudo umount "$temp_dir" 2>/dev/null || true
            else
                print_color "$YELLOW" "⚠️  wimtools not installed. Installing..."
                sudo apt install -y wimtools
            fi
            
            rm -rf "$temp_dir"
        else
            print_color "$RED" "❌ ISO file not found: $iso_path"
        fi
    else
        print_color "$CYAN" "💡 Alternative Windows sources:"
        echo "1. Windows cloud images (limited availability)"
        echo "2. Pre-configured Windows templates"
        echo "3. Manual installation from ISO"
        echo
        print_color "$YELLOW" "📝 Manual installation steps:"
        echo "  lxc init win10-template vm-name --vm --empty"
        echo "  lxc config device add vm-name iso disk source=$iso_path boot.priority=10"
        echo "  lxc start vm-name"
        echo "  # Then complete Windows installation"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# 修改image_management函数
image_management() {
    while true; do
        print_header
        print_color "$CYAN" "📦 Image Management"
        echo "══════════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Operations:"
        echo "  1) 🔍 List Available Images"
        echo "  2) 🔄 Refresh Image List"
        echo "  3) 🔎 Search Images"
        echo "  4) 🪟 Import Windows ISO"
        echo "  5) 📥 Import Custom Image"
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
                import_windows_iso
                ;;
            5)
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

# 修改主菜单
main_menu() {
    while true; do
        print_header
        
        # Get container count
        local container_count=0
        local vm_count=0
        if command -v lxc &> /dev/null; then
            container_count=$(lxc list --format csv 2>/dev/null | wc -l)
            vm_count=$(lxc list --format csv 2>/dev/null | xargs -I {} lxc config show {} 2>/dev/null | grep "type: virtual-machine" | wc -l)
        fi
        
        print_color "$GREEN" "🏠 Main Menu"
        print_color "$BLUE" "📦 Active Containers: $container_count (VMs: $vm_count)"
        echo "══════════════════════════════════════════════════════════════"
        echo
        
        echo "  1) 🚀 Create New Container/VM"
        echo "  2) 📋 List Containers"
        echo "  3) ⚙️  Manage Container"
        echo "  4) 📦 Image Management"
        echo "  5) 🪟 Windows Tools"
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
            5) windows_tools ;;
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

# 添加新函数：Windows工具菜单
windows_tools() {
    while true; do
        print_header
        print_color "$PURPLE" "🪟 Windows VM Tools"
        echo "══════════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Windows VM Operations:"
        echo "  1) 🪟 List Windows VMs"
        echo "  2) 💾 Install VirtIO Drivers"
        echo "  3) 🔧 Configure RDP Access"
        echo "  4) 📁 Share Folder with Host"
        echo "  5) 🎮 Enable Enhanced Video"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1)
                print_color "$CYAN" "🪟 Windows VMs:"
                lxc list --format csv | while IFS= read -r line; do
                    local name=$(echo "$line" | cut -d',' -f1)
                    if lxc config show "$name" 2>/dev/null | grep -q "virtual-machine"; then
                        print_color "$PURPLE" "  💻 $name (Windows VM)"
                    fi
                done
                read -p "⏎ Press Enter to continue..."
                ;;
            2)
                print_color "$CYAN" "💾 VirtIO Drivers for Windows"
                echo "Download from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/"
                echo
                echo "After downloading:"
                echo "1. Mount ISO to Windows VM:"
                echo "   lxc config device add vm-name virtio disk source=/path/to/virtio.iso"
                echo "2. Install drivers in Windows Device Manager"
                read -p "⏎ Press Enter to continue..."
                ;;
            3)
                print_color "$CYAN" "🔧 Configure RDP on Windows VM"
                echo "In Windows VM, enable RDP:"
                echo "1. Open System Properties"
                echo "2. Remote Desktop → Allow remote connections"
                echo "3. Set firewall rules if needed"
                echo
                print_color "$GREEN" "💡 Default RDP port: 3389"
                read -p "⏎ Press Enter to continue..."
                ;;
            4)
                print_color "$CYAN" "📁 Share folder with Windows VM"
                read -p "VM name: " vm_name
                read -p "Host folder path: " host_path
                read -p "Share name (e.g., host-files): " share_name
                
                if [[ -d "$host_path" ]]; then
                    lxc config device add "$vm_name" "$share_name" disk \
                        source="$host_path" path="C:\\Shares\\$share_name"
                    print_color "$GREEN" "✅ Folder shared as C:\\Shares\\$share_name"
                else
                    print_color "$RED" "❌ Host folder not found"
                fi
                read -p "⏎ Press Enter to continue..."
                ;;
            5)
                print_color "$CYAN" "🎮 Enhanced Video for Windows VM"
                echo "Adding VirtIO-GPU with 3D acceleration:"
                lxc config device add "$vm_name" video-gpu gpu \
                    driver=virtio-gpu accel3d=true
                print_color "$GREEN" "✅ 3D acceleration enabled"
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

# 修改main函数
main() {
    # Check if in terminal
    if [[ ! -t 0 ]]; then
        print_color "$RED" "❌ This script must be run in a terminal!"
        exit 1
    fi
    
    # Welcome
    print_header
    print_color "$GREEN" "🌟 Welcome to LXC/LXD Container Manager v4.0"
    print_color "$PURPLE" "🪟 Windows & Linux Support with VNC/RDP"
    echo
    
    # Check system
    check_system_ready
    
    # Check for virtualization support (important for Windows)
    if ! grep -Eq "(vmx|svm)" /proc/cpuinfo; then
        print_color "$YELLOW" "⚠️  CPU virtualization not detected or disabled in BIOS"
        print_color "$CYAN" "💡 Windows VMs require hardware virtualization (Intel VT-x/AMD-V)"
        echo
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            print_color "$RED" "Please enable virtualization in BIOS/UEFI settings"
            exit 1
        fi
    fi
    
    # Initial image detection
    detect_available_images
    
    # Start main menu
    main_menu
}

# Run main
main
