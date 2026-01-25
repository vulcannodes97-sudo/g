#!/bin/bash

# ================= COLORS =================
G="\e[32m"; R="\e[31m"; Y="\e[33m"
B="\e[34m"; C="\e[36m"; W="\e[0m"

pause(){ read -p "Press Enter to continue..." ; }

check_lxd() { command -v lxc >/dev/null 2>&1; }

install_lxd() {
    echo -e "${C}📦 Installing LXD...${W}"
    sudo apt update
    sudo apt install lxd lxd-client -y
    sudo lxd init --auto
    echo -e "${G}✅ LXD Installed${W}"
}

sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g'
}

# ================= LIST VMS =================
show_vms() {
    if ! check_lxd; then return; fi

    echo -e "${Y}📦 LXC Instances:${W}"

    list=$(lxc list --format=csv -c ns4 2>/dev/null)

    if [[ -z "$list" ]]; then
        echo -e "${R}No containers found${W}"
        return
    fi

    printf "${C}%-25s %-10s %-20s${W}\n" "NAME" "STATUS" "IP"
    echo "$list" | while IFS=',' read -r name state ip; do
        printf "${G}%-25s %-10s %-20s${W}\n" "$name" "$state" "$ip"
    done
}

# ================= CREATE LXC =================
create_lxc() {
    if ! check_lxd; then install_lxd; fi

    clear
    echo -e "${C}🆕 Create New LXC${W}"

    echo "1) Ubuntu"
    echo "2) Debian"
    echo "3) Kali"
    echo "4) Fedora"
    echo "5) Rocky Linux"

    read -p "Choose OS: " os_choice

    case $os_choice in
        1) os="ubuntu" ;;
        2) os="debian" ;;
        3) os="kali" ;;
        4) os="fedora" ;;
        5) os="rockylinux" ;;
        *) echo -e "${R}Invalid OS${W}"; return ;;
    esac

    if [[ "$os" == "ubuntu" ]]; then
        echo "Ubuntu Version: 22.04 / 24.04"
        read -p "Enter version: " release
        release=${release:-22.04}
    elif [[ "$os" == "debian" ]]; then
        echo "Debian Version: 11 / 12"
        read -p "Enter version: " release
        release=${release:-12}
    else
        release="stable"
    fi

    default_name="${os}-${release}"
    read -p "VM Name (default: $default_name): " cname
    cname=$(sanitize_name "${cname:-$default_name}")

    if lxc list -c n --format=csv | grep -qw "$cname"; then
        echo -e "${R}❌ Name already exists${W}"
        return
    fi

    read -p "RAM MB (default 2048): " memory
    memory=${memory:-2048}

    read -p "CPU cores (default 2): " cpu
    cpu=${cpu:-2}

    echo -e "${C}📥 Creating container...${W}"

    if sudo lxc launch images:$os/$release "$cname"; then
        sudo lxc config set "$cname" limits.memory "${memory}MB"
        sudo lxc config set "$cname" limits.cpu "$cpu"
        echo -e "${G}✅ Created: $cname${W}"
    else
        echo -e "${R}❌ Failed to create${W}"
    fi
}

# ================= VM ACTIONS =================
vm_action() {
    show_vms
    read -p "Enter VM Name: " vm

    if ! lxc list -c n --format=csv | grep -qw "$vm"; then
        echo -e "${R}VM not found${W}"
        return
    fi

    echo ""
    echo "1) Start"
    echo "2) Stop"
    echo "3) Restart"
    echo "4) Delete"
    echo "5) Rename"
    echo "6) Change RAM/CPU"

    read -p "Choose action: " act

    case $act in
        1) sudo lxc start "$vm" ;;
        2) sudo lxc stop "$vm" ;;
        3) sudo lxc restart "$vm" ;;
        4) sudo lxc delete "$vm" --force ;;
        5)
            read -p "New Name: " newname
            newname=$(sanitize_name "$newname")
            sudo lxc rename "$vm" "$newname"
            ;;
        6)
            read -p "New RAM MB: " ram
            read -p "New CPU cores: " cpu
            sudo lxc config set "$vm" limits.memory "${ram}MB"
            sudo lxc config set "$vm" limits.cpu "$cpu"
            ;;
        *) echo -e "${R}Invalid choice${W}" ;;
    esac
}

# ================= MAIN MENU =================
while true; do
    clear

    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${W}"
    echo -e "${C}🔥 ULTIMATE LXC CONTROL PANEL${W}"
    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${W}"

    if check_lxd; then
        echo -e "${G}Status: LXC Installed ✔${W}"
        show_vms
    else
        echo -e "${R}Status: LXC Not Installed ✖${W}"
    fi

    echo ""
    echo -e "${Y}📋 Main Menu:${W}"
    echo "  1) 🆕 Create LXC"
    echo "  2) ⚙ Manage VM"
    echo "  3) 📦 Install LXC"
    echo "  0) 👋 Exit"
    echo ""

    read -p "🎯 Choose option: " choice

    case $choice in
        1) create_lxc ;;
        2) vm_action ;;
        3) install_lxd ;;
        0) echo -e "${G}Bye 👋${W}"; exit ;;
        *) echo -e "${R}Invalid option${W}" ;;
    esac

    pause
done
