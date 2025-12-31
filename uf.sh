#!/bin/bash

# ============================================
# Windows VM Installer with NoVNC/RDP Support
# Version: 1.0 - Windows 10/11 VM Manager
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
    echo "║         Windows VM Installer with NoVNC/RDP             ║"
    echo "║               Mode BY - Nobita                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
}

# Function to check system requirements
check_system_requirements() {
    print_header
    print_color "$CYAN" "🔍 Checking System Requirements..."
    echo "══════════════════════════════════════════════════════════"
    echo
    
    local total_checks=0
    local passed_checks=0
    
    # Check CPU virtualization support
    ((total_checks++))
    if grep -E -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        print_color "$GREEN" "✅ CPU virtualization support (VT-x/AMD-V)"
        ((passed_checks++))
    else
        print_color "$RED" "❌ CPU virtualization not enabled"
        print_color "$YELLOW" "   Enable VT-x/AMD-V in BIOS"
    fi
    
    # Check KVM module
    ((total_checks++))
    if lsmod | grep -q kvm; then
        print_color "$GREEN" "✅ KVM kernel module loaded"
        ((passed_checks++))
    else
        print_color "$YELLOW" "⚠️  KVM module not loaded"
    fi
    
    # Check disk space (minimum 50GB free)
    ((total_checks++))
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -ge 50 ]]; then
        print_color "$GREEN" "✅ Disk space: ${free_space}GB free"
        ((passed_checks++))
    else
        print_color "$RED" "❌ Low disk space: ${free_space}GB free (need 50GB+)"
    fi
    
    # Check RAM (minimum 4GB)
    ((total_checks++))
    local total_ram=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ $total_ram -ge 4 ]]; then
        print_color "$GREEN" "✅ System RAM: ${total_ram}GB"
        ((passed_checks++))
    else
        print_color "$RED" "❌ Low RAM: ${total_ram}GB (need 4GB+)"
    fi
    
    # Check if user is in kvm group
    ((total_checks++))
    if groups $USER | grep -q '\bkvm\b'; then
        print_color "$GREEN" "✅ User in kvm group"
        ((passed_checks++))
    else
        print_color "$YELLOW" "⚠️  User not in kvm group"
    fi
    
    echo
    print_color "$BLUE" "📊 System Check: $passed_checks/$total_checks passed"
    
    if [[ $passed_checks -eq $total_checks ]]; then
        print_color "$GREEN" "🎉 System ready for Windows VMs!"
        return 0
    elif [[ $passed_checks -ge 3 ]]; then
        print_color "$YELLOW" "⚠️  Some issues detected but can proceed"
        return 1
    else
        print_color "$RED" "❌ System not suitable for Windows VMs"
        return 2
    fi
}

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "📦 Installing Required Dependencies..."
    echo "══════════════════════════════════════════════════════════"
    echo
    
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
            
            # Install KVM/QEMU
            print_color "$CYAN" "📥 Installing KVM/QEMU..."
            sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
                                bridge-utils virt-manager virt-viewer
            
            # Install NoVNC
            print_color "$CYAN" "🌐 Installing NoVNC..."
            sudo apt install -y novnc websockify python3-websockify
            
            # Install RDP clients
            print_color "$CYAN" "📥 Installing RDP clients..."
            sudo apt install -y freerdp2-x11 remmina remmina-plugin-rdp
            
            # Install VNC server
            print_color "$CYAN" "🖥️  Installing TigerVNC..."
            sudo apt install -y tigervnc-standalone-server tigervnc-viewer
            
            # Add user to groups
            print_color "$CYAN" "👤 Adding user to virtualization groups..."
            sudo usermod -aG kvm $USER
            sudo usermod -aG libvirt $USER
            sudo usermod -aG libvirt-qemu $USER
            
            # Enable services
            print_color "$CYAN" "⚙️  Enabling services..."
            sudo systemctl enable --now libvirtd
            sudo systemctl enable --now virtlogd.socket
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  IMPORTANT: Please log out and log back in for group changes!"
            ;;
        
        fedora|centos|rhel)
            print_color "$GREEN" "📦 Installing for Fedora/CentOS/RHEL..."
            echo
            
            # Update package lists
            print_color "$CYAN" "🔄 Updating package lists..."
            sudo dnf update -y
            
            # Install KVM/QEMU
            print_color "$CYAN" "📥 Installing KVM/QEMU..."
            sudo dnf install -y qemu-kvm libvirt virt-install virt-manager \
                                virt-viewer bridge-utils
            
            # Install NoVNC
            print_color "$CYAN" "🌐 Installing NoVNC..."
            sudo dnf install -y novnc websockify
            
            # Install RDP clients
            print_color "$CYAN" "📥 Installing RDP clients..."
            sudo dnf install -y freerdp remmina remmina-plugins-rdp
            
            # Install VNC server
            print_color "$CYAN" "🖥️  Installing TigerVNC..."
            sudo dnf install -y tigervnc-server tigervnc
            
            # Add user to groups
            print_color "$CYAN" "👤 Adding user to virtualization groups..."
            sudo usermod -aG kvm $USER
            sudo usermod -aG libvirt $USER
            
            # Enable services
            print_color "$CYAN" "⚙️  Enabling services..."
            sudo systemctl enable --now libvirtd
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  IMPORTANT: Please log out and log back in for group changes!"
            ;;
            
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo
            echo "Required packages:"
            echo "  • qemu-kvm"
            echo "  • libvirt"
            echo "  • virt-manager"
            echo "  • novnc"
            echo "  • freerdp or remmina"
            echo "  • tigervnc-server"
            echo
            echo "Required groups: kvm, libvirt"
            exit 1
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
}

# Function to setup NoVNC
setup_novnc() {
    local vm_name=$1
    local vnc_port=$2
    
    print_color "$CYAN" "🌐 Setting up NoVNC for $vm_name..."
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Create NoVNC directory
    NOVNC_DIR="$HOME/novnc-$vm_name"
    mkdir -p "$NOVNC_DIR"
    
    # Create simple NoVNC HTML page
    cat > "$NOVNC_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Windows VM: $vm_name</title>
    <meta charset="utf-8">
    <style>
        body { margin: 0; padding: 20px; background: #2c3e50; color: white; font-family: Arial, sans-serif; }
        h1 { color: #3498db; }
        .container { max-width: 1200px; margin: 0 auto; }
        .vnc-container { background: #1a252f; padding: 20px; border-radius: 10px; margin-top: 20px; }
        .info-box { background: #34495e; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .btn { 
            display: inline-block; 
            background: #3498db; 
            color: white; 
            padding: 10px 20px; 
            text-decoration: none; 
            border-radius: 5px; 
            margin: 5px;
        }
        .btn:hover { background: #2980b9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Windows VM: $vm_name</h1>
        
        <div class="info-box">
            <h3>📋 Connection Information</h3>
            <p><strong>VM Name:</strong> $vm_name</p>
            <p><strong>VNC Port:</strong> $vnc_port</p>
            <p><strong>NoVNC URL:</strong> http://$(hostname -I | awk '{print $1}'):6080/vnc.html?host=$(hostname -I | awk '{print $1}')&port=$vnc_port</p>
            <p><strong>Password:</strong> (Set in VNC server)</p>
        </div>
        
        <div class="vnc-container">
            <h3>🖥️ NoVNC Console</h3>
            <iframe src="/vnc.html?host=$(hostname -I | awk '{print $1}')&port=$vnc_port" 
                    width="100%" 
                    height="600" 
                    style="border: none; border-radius: 5px;">
            </iframe>
        </div>
        
        <div style="margin-top: 20px;">
            <h3>🔗 Quick Links</h3>
            <a href="/vnc.html?host=$(hostname -I | awk '{print $1}')&port=$vnc_port" class="btn" target="_blank">Open Full NoVNC</a>
            <a href="/vnc_lite.html?host=$(hostname -I | awk '{print $1}')&port=$vnc_port" class="btn" target="_blank">Open Lite NoVNC</a>
            <a href="rdp://$(hostname -I | awk '{print $1}')" class="btn">Connect via RDP</a>
        </div>
    </div>
</body>
</html>
EOF
    
    # Copy NoVNC files
    print_color "$BLUE" "📁 Setting up NoVNC files..."
    if [[ -d /usr/share/novnc ]]; then
        cp -r /usr/share/novnc/* "$NOVNC_DIR/"
    else
        print_color "$YELLOW" "⚠️  NoVNC not found in /usr/share/novnc"
        print_color "$CYAN" "📥 Downloading NoVNC..."
        wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz -O /tmp/novnc.tar.gz
        tar -xzf /tmp/novnc.tar.gz -C "$NOVNC_DIR" --strip-components=1
    fi
    
    # Create startup script for NoVNC proxy
    cat > "$NOVNC_DIR/start-novnc.sh" << EOF
#!/bin/bash
# NoVNC Proxy for $vm_name
VM_NAME="$vm_name"
VNC_PORT="$vnc_port"
NOVNC_PORT="6080"
NOVNC_DIR="\$(dirname "\$0")"

echo "Starting NoVNC proxy for \$VM_NAME..."
echo "VNC Server: localhost:\$VNC_PORT"
echo "NoVNC Web: http://\$(hostname -I | awk '{print \$1}'):\$NOVNC_PORT"

cd "\$NOVNC_DIR"
./utils/novnc_proxy --vnc localhost:\$VNC_PORT --listen \$NOVNC_PORT
EOF
    
    chmod +x "$NOVNC_DIR/start-novnc.sh"
    
    # Create systemd service for NoVNC
    cat > "/tmp/novnc-$vm_name.service" << EOF
[Unit]
Description=NoVNC Web Console for $vm_name
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$NOVNC_DIR
ExecStart=$NOVNC_DIR/start-novnc.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp "/tmp/novnc-$vm_name.service" "/etc/systemd/system/"
    sudo systemctl daemon-reload
    sudo systemctl enable "novnc-$vm_name.service"
    
    print_color "$GREEN" "✅ NoVNC setup completed!"
    echo
    print_color "$CYAN" "📋 NoVNC Details:"
    echo "  • Directory: $NOVNC_DIR"
    echo "  • Web Interface: http://$(hostname -I | awk '{print $1}'):6080"
    echo "  • Service: novnc-$vm_name.service"
    echo
    print_color "$YELLOW" "💡 To start NoVNC: sudo systemctl start novnc-$vm_name.service"
    
    return 0
}

# Function to create Windows VM
create_windows_vm() {
    print_header
    print_color "$CYAN" "🚀 Creating Windows Virtual Machine"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Legal disclaimer
    print_color "$RED" "⚠️  IMPORTANT LEGAL NOTICE:"
    print_color "$YELLOW" "========================================"
    echo "Windows requires a valid license for use."
    echo "This setup is for TESTING and EVALUATION only."
    echo "You must provide your own Windows ISO and license."
    echo "========================================"
    echo
    
    read -p "📋 Do you have a valid Windows license? (y/N): " has_license
    if [[ ! "$has_license" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  Windows VM creation cancelled."
        read -p "⏎ Press Enter to continue..."
        return 1
    fi
    
    # Get VM name
    while true; do
        read -p "🏷️  Enter VM name (e.g., win10-vm): " vm_name
        
        if [[ -z "$vm_name" ]]; then
            print_color "$RED" "❌ VM name cannot be empty!"
            continue
        fi
        
        if [[ ! "$vm_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]{1,}$ ]]; then
            print_color "$RED" "❌ Invalid name! Use letters, numbers, hyphens, underscores"
            continue
        fi
        
        # Check if VM already exists
        if virsh list --all --name | grep -q "^$vm_name$"; then
            print_color "$RED" "❌ VM '$vm_name' already exists!"
            read -p "🔄 Use different name? (y/N): " rename_choice
            if [[ ! "$rename_choice" =~ ^[Yy]$ ]]; then
                return
            fi
            continue
        fi
        
        break
    done
    
    # Windows version selection
    echo
    print_color "$YELLOW" "🪟 Select Windows Version:"
    echo "  1) Windows 10"
    echo "  2) Windows 11"
    echo "  3) Custom Windows ISO"
    echo
    
    read -p "🎯 Select version (1-3): " win_version
    
    local iso_path=""
    case $win_version in
        1)
            print_color "$BLUE" "📀 Windows 10 selected"
            read -p "Enter path to Windows 10 ISO: " iso_path
            ;;
        2)
            print_color "$BLUE" "📀 Windows 11 selected"
            read -p "Enter path to Windows 11 ISO: " iso_path
            ;;
        3)
            print_color "$BLUE" "📀 Custom Windows ISO"
            read -p "Enter full path to Windows ISO: " iso_path
            ;;
        *)
            print_color "$RED" "❌ Invalid selection!"
            return 1
            ;;
    esac
    
    # Verify ISO exists
    if [[ ! -f "$iso_path" ]]; then
        print_color "$RED" "❌ ISO file not found: $iso_path"
        print_color "$YELLOW" "💡 Download Windows ISO from:"
        echo "  Windows 10: https://www.microsoft.com/software-download/windows10"
        echo "  Windows 11: https://www.microsoft.com/software-download/windows11"
        read -p "⏎ Press Enter to continue..."
        return 1
    fi
    
    # Resource configuration
    echo
    print_color "$YELLOW" "⚙️  Resource Configuration:"
    
    read -p "💾 Disk size (default: 50GB): " disk_size
    disk_size=${disk_size:-50}
    
    read -p "🧠 Memory in GB (default: 4GB): " memory
    memory=${memory:-4}
    
    read -p "⚡ CPU cores (default: 2): " cpu_count
    cpu_count=${cpu_count:-2}
    
    # VNC configuration
    echo
    print_color "$CYAN" "🖥️  VNC/NoVNC Configuration:"
    
    # Find available VNC port
    local vnc_port=5900
    while netstat -tln | grep -q ":$vnc_port "; do
        ((vnc_port++))
    done
    
    print_color "$BLUE" "🔌 Auto-selected VNC port: $vnc_port"
    read -p "Use this VNC port? (Y/n): " use_vnc_port
    use_vnc_port=${use_vnc_port:-Y}
    
    if [[ ! "$use_vnc_port" =~ ^[Yy]$ ]]; then
        read -p "Enter custom VNC port (5900-5999): " vnc_port
    fi
    
    read -p "Set VNC password? (Y/n): " set_vnc_password
    set_vnc_password=${set_vnc_password:-Y}
    
    local vnc_password=""
    if [[ "$set_vnc_password" =~ ^[Yy]$ ]]; then
        read -sp "Enter VNC password: " vnc_password
        echo
        read -sp "Confirm VNC password: " vnc_password_confirm
        echo
        
        if [[ "$vnc_password" != "$vnc_password_confirm" ]]; then
            print_color "$RED" "❌ Passwords don't match!"
            return 1
        fi
    fi
    
    # Network configuration
    echo
    print_color "$YELLOW" "🌐 Network Configuration:"
    echo "  1) NAT (Default) - VM shares host's IP"
    echo "  2) Bridge - VM gets own IP on network"
    
    read -p "Select network type (1-2, default: 1): " network_type
    network_type=${network_type:-1}
    
    # Summary
    echo
    print_color "$CYAN" "📋 Creation Summary:"
    echo "──────────────────────────────────────"
    echo "🏷️  VM Name: $vm_name"
    echo "🪟 Windows: $iso_path"
    echo "💾 Disk: ${disk_size}GB"
    echo "🧠 Memory: ${memory}GB"
    echo "⚡ CPU: $cpu_count cores"
    echo "🖥️  VNC Port: $vnc_port"
    echo "🌐 Network: $([ "$network_type" == "1" ] && echo "NAT" || echo "Bridge")"
    echo "🌐 NoVNC: Enabled"
    echo "──────────────────────────────────────"
    echo
    
    read -p "✅ Proceed with VM creation? (Y/n): " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  VM creation cancelled."
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Create VM disk
    print_color "$BLUE" "💾 Creating virtual disk..."
    local disk_path="$HOME/virt-images/$vm_name.qcow2"
    mkdir -p "$HOME/virt-images"
    
    qemu-img create -f qcow2 "$disk_path" "${disk_size}G"
    
    # Determine OS variant
    local os_variant="win10"
    if [[ "$iso_path" =~ [Ww]indows.*11 ]] || [[ $win_version -eq 2 ]]; then
        os_variant="win11"
    fi
    
    # Create VM using virt-install
    print_color "$GREEN" "🚀 Creating Windows VM..."
    echo "This may take several minutes. Please wait..."
    
    local network_arg="network=default"
    if [[ "$network_type" == "2" ]]; then
        network_arg="bridge=virbr0"
    fi
    
    # Create VM with VNC
    if [[ -n "$vnc_password" ]]; then
        virt-install \
            --name "$vm_name" \
            --memory $((memory * 1024)) \
            --vcpus "$cpu_count" \
            --disk "$disk_path,format=qcow2,size=$disk_size" \
            --os-variant "$os_variant" \
            --network "$network_arg" \
            --graphics "vnc,port=$vnc_port,password=$vnc_password" \
            --video qxl \
            --cdrom "$iso_path" \
            --boot uefi \
            --noautoconsole
    else
        virt-install \
            --name "$vm_name" \
            --memory $((memory * 1024)) \
            --vcpus "$cpu_count" \
            --disk "$disk_path,format=qcow2,size=$disk_size" \
            --os-variant "$os_variant" \
            --network "$network_arg" \
            --graphics "vnc,port=$vnc_port" \
            --video qxl \
            --cdrom "$iso_path" \
            --boot uefi \
            --noautoconsole
    fi
    
    if [[ $? -eq 0 ]]; then
        print_color "$GREEN" "✅ Windows VM created successfully!"
        
        # Setup NoVNC
        setup_novnc "$vm_name" "$vnc_port"
        
        # Start NoVNC service
        sudo systemctl start "novnc-$vm_name.service"
        
        # Show connection info
        echo
        print_color "$CYAN" "🔗 Connection Information:"
        echo "──────────────────────────────────────"
        echo "🏷️  VM Name: $vm_name"
        echo "🖥️  VNC Port: $vnc_port"
        echo "🌐 NoVNC URL: http://$(hostname -I | awk '{print $1}'):6080"
        echo "💻 Console: virsh console $vm_name"
        echo "🔄 Status: virsh domstate $vm_name"
        echo
        
        print_color "$YELLOW" "📝 Windows Installation Steps:"
        echo "  1. Connect via NoVNC URL above"
        echo "  2. Follow Windows installation wizard"
        echo "  3. Enter your Windows license key"
        echo "  4. Create user account"
        echo "  5. Install VirtIO drivers (if needed)"
        echo "  6. Enable RDP in Windows Settings"
        
        echo
        print_color "$GREEN" "🎉 Windows VM is ready! Connect via NoVNC to begin installation."
        
    else
        print_color "$RED" "❌ Failed to create VM!"
        print_color "$YELLOW" "💡 Check error messages above."
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to manage Windows VMs
manage_windows_vms() {
    print_header
    print_color "$CYAN" "⚙️  Windows VM Management"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    # Get list of VMs
    local vms=$(virsh list --all --name)
    
    if [[ -z "$vms" ]]; then
        print_color "$YELLOW" "📭 No VMs found!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Display VMs
    print_color "$BLUE" "📋 Available Windows VMs:"
    echo
    
    local i=1
    declare -A vm_map
    for vm in $vms; do
        vm_map[$i]=$vm
        local state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
        local status_icon="❓"
        [[ "$state" == "running" ]] && status_icon="🟢"
        [[ "$state" == "shut off" ]] && status_icon="🔴"
        [[ "$state" == "paused" ]] && status_icon="⏸️"
        
        # Get VNC port
        local vnc_port=$(virsh vncdisplay "$vm" 2>/dev/null | cut -d: -f2)
        [[ -z "$vnc_port" ]] && vnc_port="N/A"
        
        echo "  $i) $status_icon $vm ($state)"
        echo "     VNC: $vnc_port | NoVNC: http://$(hostname -I | awk '{print $1}'):6080"
        echo
        ((i++))
    done
    
    echo
    read -p "🎯 Select VM number (or 0 to go back): " vm_num
    
    if [[ "$vm_num" == "0" ]]; then
        return
    fi
    
    if [[ -z "${vm_map[$vm_num]}" ]]; then
        print_color "$RED" "❌ Invalid selection!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    local vm_name=${vm_map[$vm_num]}
    vm_management_menu "$vm_name"
}

# VM management sub-menu
vm_management_menu() {
    local vm_name=$1
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  Managing: $vm_name"
        
        # Get VM status
        local vm_state=$(virsh domstate "$vm_name" 2>/dev/null || echo "unknown")
        local vnc_port=$(virsh vncdisplay "$vm_name" 2>/dev/null | cut -d: -f2)
        
        print_color "$BLUE" "📊 Status: $vm_state"
        if [[ -n "$vnc_port" ]]; then
            print_color "$GREEN" "🖥️  VNC Port: $vnc_port"
            print_color "$CYAN" "🌐 NoVNC: http://$(hostname -I | awk '{print $1}'):6080"
        fi
        echo "══════════════════════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Operations:"
        echo "  1) ▶️  Start VM"
        echo "  2) ⏹️  Shutdown VM (graceful)"
        echo "  3) 🔌 Force Stop VM"
        echo "  4) 🔄 Reboot VM"
        echo "  5) ⏸️  Pause VM"
        echo "  6) ⏯️  Resume VM"
        echo "  7) 💻 Open Console (virsh)"
        echo "  8) 🌐 Open NoVNC Web Console"
        echo "  9) 📊 Show VM Info"
        echo "  10) ⚙️  Configure VNC/NoVNC"
        echo "  11) 🗑️  Delete VM"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select operation: " operation
        
        case $operation in
            1)
                print_color "$GREEN" "▶️  Starting VM..."
                if virsh start "$vm_name"; then
                    print_color "$GREEN" "✅ VM started!"
                else
                    print_color "$RED" "❌ Failed to start VM"
                fi
                sleep 2
                ;;
            2)
                print_color "$YELLOW" "⏹️  Shutting down VM..."
                if virsh shutdown "$vm_name"; then
                    print_color "$GREEN" "✅ VM shutdown initiated!"
                else
                    print_color "$RED" "❌ Failed to shutdown VM"
                fi
                sleep 2
                ;;
            3)
                print_color "$RED" "🔌 Force stopping VM..."
                if virsh destroy "$vm_name"; then
                    print_color "$GREEN" "✅ VM force stopped!"
                else
                    print_color "$RED" "❌ Failed to force stop VM"
                fi
                sleep 2
                ;;
            4)
                print_color "$BLUE" "🔄 Rebooting VM..."
                if virsh reboot "$vm_name"; then
                    print_color "$GREEN" "✅ VM reboot initiated!"
                else
                    print_color "$RED" "❌ Failed to reboot VM"
                fi
                sleep 2
                ;;
            5)
                print_color "$PURPLE" "⏸️  Pausing VM..."
                if virsh suspend "$vm_name"; then
                    print_color "$GREEN" "✅ VM paused!"
                else
                    print_color "$RED" "❌ Failed to pause VM"
                fi
                sleep 2
                ;;
            6)
                print_color "$PURPLE" "⏯️  Resuming VM..."
                if virsh resume "$vm_name"; then
                    print_color "$GREEN" "✅ VM resumed!"
                else
                    print_color "$RED" "❌ Failed to resume VM"
                fi
                sleep 2
                ;;
            7)
                print_color "$CYAN" "💻 Opening virsh console..."
                echo "📝 Press 'Ctrl+]' to exit console"
                virsh console "$vm_name"
                ;;
            8)
                print_color "$CYAN" "🌐 Opening NoVNC console..."
                local novnc_url="http://$(hostname -I | awk '{print $1}'):6080"
                print_color "$GREEN" "🔗 NoVNC URL: $novnc_url"
                echo "💡 Opening in default browser..."
                
                # Try to open in browser
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$novnc_url" 2>/dev/null &
                elif command -v gnome-open &> /dev/null; then
                    gnome-open "$novnc_url" 2>/dev/null &
                fi
                
                read -p "⏎ Press Enter to continue..."
                ;;
            9)
                print_color "$BLUE" "📊 VM Information:"
                virsh dominfo "$vm_name" || echo "Could not get VM info"
                
                echo
                print_color "$CYAN" "📈 Resource Usage:"
                virsh domstats "$vm_name" --cpu --memory --disk --network 2>/dev/null || echo "Stats not available"
                
                read -p "⏎ Press Enter to continue..."
                ;;
            10)
                configure_vnc_novnc "$vm_name"
                ;;
            11)
                print_color "$RED" "⚠️  ⚠️  ⚠️  WARNING: This will permanently delete '$vm_name'!"
                read -p "🗑️  Are you sure? (type 'DELETE' to confirm): " confirm
                if [[ "$confirm" == "DELETE" ]]; then
                    print_color "$RED" "🗑️  Deleting VM..."
                    
                    # Stop VM first
                    virsh destroy "$vm_name" 2>/dev/null
                    
                    # Undefine VM
                    if virsh undefine "$vm_name"; then
                        print_color "$GREEN" "✅ VM deleted!"
                        
                        # Remove disk if exists
                        local disk_path="$HOME/virt-images/$vm_name.qcow2"
                        if [[ -f "$disk_path" ]]; then
                            read -p "🗑️  Delete disk file too? (y/N): " delete_disk
                            if [[ "$delete_disk" =~ ^[Yy]$ ]]; then
                                rm -f "$disk_path"
                                print_color "$GREEN" "✅ Disk file deleted!"
                            fi
                        fi
                        
                        # Stop NoVNC service
                        sudo systemctl stop "novnc-$vm_name.service" 2>/dev/null
                        sudo systemctl disable "novnc-$vm_name.service" 2>/dev/null
                        sudo rm -f "/etc/systemd/system/novnc-$vm_name.service"
                        
                        read -p "⏎ Press Enter to continue..."
                        return
                    else
                        print_color "$RED" "❌ Failed to delete VM"
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

# Function to configure VNC/NoVNC
configure_vnc_novnc() {
    local vm_name=$1
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  VNC/NoVNC Configuration: $vm_name"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        local current_vnc=$(virsh vncdisplay "$vm_name" 2>/dev/null | cut -d: -f2)
        local novnc_status=$(systemctl is-active "novnc-$vm_name.service" 2>/dev/null || echo "inactive")
        
        print_color "$BLUE" "📊 Current Status:"
        echo "  VNC Port: ${current_vnc:-Not set}"
        echo "  NoVNC Service: $novnc_status"
        echo
        
        print_color "$YELLOW" "📋 Configuration Options:"
        echo "  1) 🔄 Change VNC Port"
        echo "  2) 🔑 Set/Change VNC Password"
        echo "  3) 🌐 Restart NoVNC Service"
        echo "  4) 📊 View NoVNC Logs"
        echo "  5) 🔧 Reconfigure NoVNC"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select option: " config_opt
        
        case $config_opt in
            1)
                read -p "Enter new VNC port (5900-5999): " new_port
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 5900 ]] && [[ $new_port -le 5999 ]]; then
                    # Edit VM XML to change VNC port
                    print_color "$BLUE" "🔄 Changing VNC port to $new_port..."
                    
                    # Get current XML
                    local xml_file="/tmp/$vm_name.xml"
                    virsh dumpxml "$vm_name" > "$xml_file"
                    
                    # Update VNC port in XML
                    sed -i "s/port='[0-9]*'/port='$new_port'/" "$xml_file"
                    
                    # Redefine VM
                    if virsh define "$xml_file"; then
                        print_color "$GREEN" "✅ VNC port changed to $new_port"
                        
                        # Restart NoVNC with new port
                        sudo systemctl stop "novnc-$vm_name.service" 2>/dev/null
                        
                        # Update NoVNC config
                        local novnc_dir="$HOME/novnc-$vm_name"
                        sed -i "s/VNC_PORT=\"[0-9]*\"/VNC_PORT=\"$new_port\"/" "$novnc_dir/start-novnc.sh"
                        
                        sudo systemctl start "novnc-$vm_name.service"
                        print_color "$GREEN" "✅ NoVNC updated with new port"
                    else
                        print_color "$RED" "❌ Failed to change VNC port"
                    fi
                    
                    rm -f "$xml_file"
                else
                    print_color "$RED" "❌ Invalid port number!"
                fi
                ;;
            2)
                read -sp "Enter new VNC password: " vnc_pass
                echo
                read -sp "Confirm VNC password: " vnc_pass_confirm
                echo
                
                if [[ "$vnc_pass" == "$vnc_pass_confirm" ]]; then
                    print_color "$BLUE" "🔑 Setting VNC password..."
                    
                    # Edit VM XML to add/change password
                    local xml_file="/tmp/$vm_name.xml"
                    virsh dumpxml "$vm_name" > "$xml_file"
                    
                    if grep -q "graphics.*vnc" "$xml_file"; then
                        if grep -q "passwd=" "$xml_file"; then
                            # Update existing password
                            sed -i "s/passwd='[^']*'/passwd='$vnc_pass'/" "$xml_file"
                        else
                            # Add password attribute
                            sed -i "s/<graphics type='vnc'/& passwd='$vnc_pass'/" "$xml_file"
                        fi
                    fi
                    
                    if virsh define "$xml_file"; then
                        print_color "$GREEN" "✅ VNC password updated!"
                    else
                        print_color "$RED" "❌ Failed to update VNC password"
                    fi
                    
                    rm -f "$xml_file"
                else
                    print_color "$RED" "❌ Passwords don't match!"
                fi
                ;;
            3)
                print_color "$BLUE" "🔄 Restarting NoVNC service..."
                sudo systemctl restart "novnc-$vm_name.service"
                print_color "$GREEN" "✅ NoVNC service restarted!"
                ;;
            4)
                print_color "$BLUE" "📊 NoVNC Service Logs:"
                sudo journalctl -u "novnc-$vm_name.service" -n 20 --no-pager
                read -p "⏎ Press Enter to continue..."
                ;;
            5)
                print_color "$BLUE" "🔧 Reconfiguring NoVNC..."
                local current_vnc=$(virsh vncdisplay "$vm_name" 2>/dev/null | cut -d: -f2)
                if [[ -n "$current_vnc" ]]; then
                    sudo systemctl stop "novnc-$vm_name.service" 2>/dev/null
                    sudo systemctl disable "novnc-$vm_name.service" 2>/dev/null
                    setup_novnc "$vm_name" "$current_vnc"
                    sudo systemctl start "novnc-$vm_name.service"
                else
                    print_color "$RED" "❌ No VNC port configured for this VM"
                fi
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
    
    # Virtualization Info
    print_color "$YELLOW" "🚀 Virtualization Information:"
    echo "──────────────────────────────────────"
    
    # KVM Status
    if systemctl is-active --quiet libvirtd; then
        print_color "$GREEN" "✅ libvirtd service is running"
    else
        print_color "$RED" "❌ libvirtd service is NOT running"
    fi
    
    # List VMs
    local vm_count=$(virsh list --all --name | wc -l)
    echo "📦 Virtual Machines: $vm_count"
    
    if [[ $vm_count -gt 0 ]]; then
        echo "📋 VM List:"
        virsh list --all --name | head -5
        if [[ $vm_count -gt 5 ]]; then
            echo "  ... and $((vm_count - 5)) more"
        fi
    fi
    
    # NoVNC Status
    echo
    print_color "$YELLOW" "🌐 NoVNC Services:"
    echo "──────────────────────────────────────"
    local novnc_services=$(systemctl list-units --type=service --all | grep novnc | awk '{print $1}')
    if [[ -n "$novnc_services" ]]; then
        for service in $novnc_services; do
            local status=$(systemctl is-active "$service")
            if [[ "$status" == "active" ]]; then
                echo "✅ $service: $status"
            else
                echo "❌ $service: $status"
            fi
        done
    else
        echo "📭 No NoVNC services found"
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
    if grep -q -E '(vmx|svm)' /proc/cpuinfo; then
        echo "🔧 Virtualization: Enabled"
    else
        echo "🔧 Virtualization: Disabled"
    fi
    
    # Memory
    echo "💾 Memory: $(free -h | awk '/^Mem:/ {print $2}') total"
    echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"
    
    echo
    print_color "$CYAN" "🔧 Quick Commands:"
    echo "  virsh list --all          # List all VMs"
    echo "  virt-manager              # GUI VM manager"
    echo "  systemctl status libvirtd # Check libvirt status"
    echo "  sudo systemctl start novnc-<vmname>  # Start NoVNC"
    
    read -p "⏎ Press Enter to continue..."
}

# Function to install Windows VirtIO drivers
install_virtio_drivers() {
    print_header
    print_color "$CYAN" "📦 Windows VirtIO Drivers Installation"
    echo "══════════════════════════════════════════════════════════"
    echo
    
    print_color "$YELLOW" "📝 About VirtIO Drivers:"
    echo "VirtIO drivers improve performance for Windows VMs on KVM."
    echo "They provide better disk, network, and graphics performance."
    echo
    
    # Download VirtIO ISO
    print_color "$BLUE" "📥 Downloading latest VirtIO drivers..."
    
    local virtio_url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    local iso_path="$HOME/virtio-win.iso"
    
    wget -q --show-progress -O "$iso_path" "$virtio_url"
    
    if [[ $? -eq 0 ]]; then
        print_color "$GREEN" "✅ VirtIO drivers downloaded: $iso_path"
        echo
        print_color "$YELLOW" "📋 Installation Instructions:"
        echo "1. Attach the VirtIO ISO to your Windows VM:"
        echo "   virsh attach-disk $vm_name $iso_path hdc --type cdrom"
        echo
        echo "2. In Windows VM:"
        echo "   • Open File Explorer"
        echo "   • Navigate to the VirtIO CD-ROM"
        echo "   • Run the appropriate installer:"
        echo "     - For Windows 10/11: virtio-win-gt-x64.msi"
        echo "     - For network drivers: NetKVM directory"
        echo "     - For storage drivers: viostor directory"
        echo
        echo "3. Restart Windows after installation"
    else
        print_color "$RED" "❌ Failed to download VirtIO drivers"
        print_color "$YELLOW" "💡 Manual download: https://github.com/virtio-win/virtio-win-pkg-scripts"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        print_header
        
        # Get VM count
        local vm_count=0
        if command -v virsh &> /dev/null; then
            vm_count=$(virsh list --all --name | wc -l)
        fi
        
        print_color "$GREEN" "🏠 Windows VM Manager with NoVNC"
        print_color "$BLUE" "📦 Active VMs: $vm_count"
        echo "══════════════════════════════════════════════════════════"
        echo
        
        echo "  1) 🚀 Create New Windows VM"
        echo "  2) 📋 List & Manage VMs"
        echo "  3) 🔧 Check System Requirements"
        echo "  4) 📦 Install Dependencies"
        echo "  5) 📥 Install VirtIO Drivers"
        echo "  6) 📊 System Information"
        echo "  0) 👋 Exit"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1) create_windows_vm ;;
            2) manage_windows_vms ;;
            3) check_system_requirements ;;
            4) install_dependencies ;;
            5) install_virtio_drivers ;;
            6) show_system_info ;;
            0)
                print_header
                print_color "$GREEN" "👋 Goodbye! Happy Windows VM management! 🪟"
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
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_color "$RED" "❌ Do not run this script as root!"
        print_color "$YELLOW" "💡 Run as normal user with sudo privileges."
        exit 1
    fi
    
    # Check if in terminal
    if [[ ! -t 0 ]]; then
        print_color "$RED" "❌ This script must be run in a terminal!"
        exit 1
    fi
    
    # Welcome
    print_header
    print_color "$GREEN" "🌟 Welcome to Windows VM Installer"
    print_color "$CYAN" "🪟 Windows 10/11 | NoVNC Web Console | RDP Support"
    echo
    
    # Check if libvirtd is running
    if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
        print_color "$YELLOW" "⚠️  libvirtd service is not running"
        print_color "$CYAN" "Would you like to start it now?"
        echo
        
        read -p "🔧 Start libvirtd? (Y/n): " start_libvirt
        start_libvirt=${start_libvirt:-Y}
        
        if [[ "$start_libvirt" =~ ^[Yy]$ ]]; then
            sudo systemctl start libvirtd
            sudo systemctl enable libvirtd
            print_color "$GREEN" "✅ libvirtd started and enabled!"
            sleep 2
        fi
    fi
    
    # Start main menu
    main_menu
}


