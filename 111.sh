#!/bin/bash
# ===========================================================
# CODING HUB Terminal Control Panel (v2.1 - New Banner)
# Mode By - Nobita
# ===========================================================

# --- COLORS & STYLES ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color
GRAY='\033[38;5;240m'
ORANGE='\033[38;5;208m'

# --- UI ELEMENTS (Adjusted Width for New Banner) ---
# Width set to match the large banner (approx 98 chars)
T_LINE="${GRAY}──────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
T_TOP="${GRAY}┌──────────────────────────────────────────────────────────────────────────────────────────────────┐${NC}"
T_BOT="${GRAY}└──────────────────────────────────────────────────────────────────────────────────────────────────┘${NC}"
T_SIDE="${GRAY}│${NC}"

# ===================== HELPER FUNCTIONS =====================

pause(){ 
    echo -e "\n${GRAY}  Press [ENTER] to continue...${NC}"
    read -r
}

loading_bar() {
    echo -ne "${CYAN}  Loading: ${NC}[ "
    for i in {1..20}; do
        echo -ne "${GREEN}▓${NC}"
        sleep 0.02
    done
    echo -e " ] ${GREEN}Done!${NC}"
    sleep 0.3
}

# ===================== HEADER & BANNER =====================
header(){
    clear
    # Dynamic Random Color for Logo
    COLORS=($RED $GREEN $YELLOW $BLUE $PURPLE $CYAN)
    RC=${COLORS[$RANDOM % ${#COLORS[@]}]}
    
    echo -e "${RC}"
    echo "   █████████                █████  ███                          █████                 █████    "
    echo "  ███░░░░░███              ░░███  ░░░                          ░░███                 ░░███     "
    echo " ███     ░░░   ██████    ███████   ████  ████████    ███████    ░███████    █████ ████ ░███████ "
    echo "░███          ███░░███  ███░░███  ░░███ ░░███░░███  ███░░███    ░███░░███  ░░███ ░███  ░███░░███"
    echo "░███         ░███ ░███ ░███ ░███   ░███  ░███ ░███ ░███ ░███    ░███ ░███   ░███ ░███  ░███ ░███"
    echo "░░███     ███░███ ░███ ░███ ░███   ░███  ░███ ░███ ░███ ░███    ░███ ░███   ░███ ░███  ░███ ░███"
    echo " ░░█████████ ░░██████  ░░████████  █████ ████ █████░░███████    ████ █████  ░░████████ ████████ "
    echo "  ░░░░░░░░░   ░░░░░░    ░░░░░░░░  ░░░░░  ░░░░ ░░░░░  ░░░░░███   ░░░░ ░░░░░   ░░░░░░░░ ░░░░░░░░  "
    echo "                                                     ███ ░███                                   "
    echo "                                                    ░░██████                                    "
    echo "                                                     ░░░░░░                                     "
    echo -e "${NC}"
    
    echo -e "                               ${BOLD}>> DEVELOPED BY NOBITA (2026) <<${NC}"
    echo -e ""
    # System Status Bar
    USER_INFO=$(whoami)
    HOST_INFO=$(hostname)
    DATE_INFO=$(date +'%H:%M')
    echo -e "  ${GRAY}User:${NC} $USER_INFO ${GRAY}|${NC} ${GRAY}Host:${NC} $HOST_INFO ${GRAY}|${NC} ${GRAY}Time:${NC} $DATE_INFO"
    echo -e "${T_LINE}"
}

# ===================== PANEL MENU =====================
panel_menu(){
    while true; do 
        header
        echo -e "  ${ORANGE}:: PANEL MANAGEMENT ::${NC}"
        echo -e "${T_TOP}"
        # Used printf for alignment in the wider box
        printf "${T_SIDE}  ${YELLOW}[01]${NC} %-40s ${YELLOW}[07]${NC} %-40s ${T_SIDE}\n" "FeatherPanel" "Payment Gateway"
        printf "${T_SIDE}  ${YELLOW}[02]${NC} %-40s ${YELLOW}[08]${NC} %-40s ${T_SIDE}\n" "Pterodactyl" "CtrlPanel"
        printf "${T_SIDE}  ${YELLOW}[03]${NC} %-40s ${YELLOW}[09]${NC} %-40s ${T_SIDE}\n" "Jexactyl v3" "Reviactyl"
        printf "${T_SIDE}  ${YELLOW}[04]${NC} %-40s ${YELLOW}[10]${NC} %-40s ${T_SIDE}\n" "Jexpanel v4" "Tools (External)"
        printf "${T_SIDE}  ${YELLOW}[05]${NC} %-40s ${RED}[11] Back to Main${NC}                     ${T_SIDE}\n" "Dashboard v3"
        printf "${T_SIDE}  ${YELLOW}[06]${NC} %-40s                                          ${T_SIDE}\n" "Dashboard v4"
        echo -e "${T_BOT}"
        
        echo -ne "  ${BOLD}${CYAN}➜ Select Option:${NC} "
        read -p "" p

        case $p in
            1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unFEATHERPANEL.sh) ;;
            2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unPterodactyl.sh) ;;
            3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/panel/Jexactyl.sh) ;;
            4) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unJexactyl.sh) ;;
            5) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/undash-3.sh) ;;
            6) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/dash-v4.sh) ;;
            7) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unPaymenter.sh) ;;
            8) bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/Uninstall/unCtrlPanel.sh) ;;
            9) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unReviactyl.sh) ;;
            10) bash <(curl -s https://raw.githubusercontent.com/yourlink/t-panel.sh) ;;
            11) loading_bar; break ;;
            *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
        esac
    done
}

# ===================== TOOLS MENU =====================
tools_menu(){
    while true; do 
        header
        echo -e "  ${BLUE}:: SYSTEM TOOLS ::${NC}"
        echo -e "${T_TOP}"
        printf "${T_SIDE}  ${CYAN}[01]${NC} %-88s ${T_SIDE}\n" "Root Access Setup"
        printf "${T_SIDE}  ${CYAN}[02]${NC} %-88s ${T_SIDE}\n" "Tailscale Setup"
        printf "${T_SIDE}  ${CYAN}[03]${NC} %-88s ${T_SIDE}\n" "Cloudflare DNS"
        printf "${T_SIDE}  ${CYAN}[04]${NC} %-88s ${T_SIDE}\n" "System Info"
        printf "${T_SIDE}  ${CYAN}[05]${NC} %-88s ${T_SIDE}\n" "VPS Run"
        printf "${T_SIDE}  ${CYAN}[06]${NC} %-88s ${T_SIDE}\n" "Terminal Utility"
        printf "${T_SIDE}  ${CYAN}[07]${NC} %-88s ${T_SIDE}\n" "RDP Installer"
        printf "${T_SIDE}  ${RED}[08] Back to Main${NC}                                                                         ${T_SIDE}\n"
        echo -e "${T_BOT}"

        echo -ne "  ${BOLD}${CYAN}➜ Select Option:${NC} "
        read -p "" t

        case $t in
            1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/root.sh) ;;
            2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/Tailscale.sh) ;;
            3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/cloudflare.sh) ;;
            4) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/SYSTEM.sh) ;;
            5) bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/tools/vps.sh) ;;
            6) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/terminal.sh) ;;
            7) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/rdp.sh) ;;
            8) loading_bar; break ;;
            *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
        esac
    done
}

# ===================== THEME MENU =====================
theme_menu(){
    while true; do 
        header
        echo -e "  ${PURPLE}:: THEME CONFIGURATION ::${NC}"
        echo -e "${T_TOP}"
        printf "${T_SIDE}  ${PURPLE}[01]${NC} %-88s ${T_SIDE}\n" "Blueprint Theme"
        printf "${T_SIDE}  ${PURPLE}[02]${NC} %-88s ${T_SIDE}\n" "Change Theme"
        printf "${T_SIDE}  ${PURPLE}[03]${NC} %-88s ${T_SIDE}\n" "Uninstall Theme"
        printf "${T_SIDE}  ${RED}[04] Back to Main${NC}                                                                         ${T_SIDE}\n"
        echo -e "${T_BOT}"

        echo -ne "  ${BOLD}${CYAN}➜ Select Option:${NC} "
        read -p "" th

        case $th in
            1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/thame/ch.sh) ;;
            2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/thame/chang.sh) ;;
            3) bash <(curl -s https://raw.githubusercontent.com/yourlink/theme_uninstall.sh) ;;
            4) loading_bar; break ;;
            *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
        esac
    done
}

# ===================== MAIN MENU =====================
main_menu(){
    # Initial Loading Effect
    clear
    echo -e "${CYAN}Starting Coding Hub Panel...${NC}"
    sleep 1
    loading_bar

    while true; do 
        header
        echo -e "  ${GREEN}:: MAIN MENU ::${NC}"
        echo -e "${T_TOP}"
        # Adjusted alignment to fit new width
        printf "${T_SIDE}  ${WHITE}[01]${NC} %-40s ${WHITE}[05]${NC} %-40s ${T_SIDE}\n" "VPS Run Setup" "Theme Manager"
        printf "${T_SIDE}  ${WHITE}[02]${NC} %-40s ${WHITE}[06]${NC} %-40s ${T_SIDE}\n" "Panel Manager" "System Options"
        printf "${T_SIDE}  ${WHITE}[03]${NC} %-40s ${WHITE}[07]${NC} %-40s ${T_SIDE}\n" "Wings Installation" "External Infra"
        printf "${T_SIDE}  ${WHITE}[04]${NC} %-40s ${RED}[08]${NC} %-40s ${T_SIDE}\n" "Tools Utility" "Exit Panel"
        echo -e "${T_BOT}"
        
        echo -e "${GRAY}  Enter the number corresponding to your choice:${NC}"
        echo -ne "  ${BOLD}${GREEN}root@codinghub:~#${NC} "
        read -p "" c

        case $c in
            1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/vps.sh) ;;
            2) loading_bar; panel_menu ;;
            3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/wings/www.sh) ;;
            4) loading_bar; tools_menu ;;
            5) loading_bar; theme_menu ;;
            6) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/menu/System1.sh) ;;
            7) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/External/INFRA.sh) ;;
            8) 
                echo -e ""
                echo -e "  ${GREEN}Thank you for using CODING HUB!${NC}"
                echo -e "  ${GRAY}See you soon, Nobita.${NC}"
                echo -e ""
                exit 
                ;;
            *) echo -e "  ${RED}Invalid Selection. Try again.${NC}"; sleep 1 ;;
        esac
    done
}

# Start the script
main_menu
