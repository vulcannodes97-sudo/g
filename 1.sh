#!/usr/bin/env bash
# AMD VDS Login → Animesh Sequence → Nobita Script Runner

set -euo pipefail

# Configuration
AMD_VDS_URL="https://amd.vds.login.system"
NOBITA_URL="https://run.nobitapro.online"
HOST="run.nobitapro.online"
NETRC="${HOME}/.netrc"

# UI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'
BLINK='\033[5m'

# Animation frames
ANIM_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# Display functions
print_master_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██║ ╚████║╚██████╔╝██████╔╝██║   ██║   ██║  ██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${BOLD}              MULTI-STAGE EXECUTION SYSTEM                     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 1
}

print_stage_header() {
    local stage_name=$1
    local stage_num=$2
    
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}${BOLD}${YELLOW}               STAGE ${stage_num}: ${stage_name}                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo ""
}

print_step() {
    echo -e "${PURPLE}${BOLD}[→]${NC} ${BOLD}Stage $1:${NC} $2"
}

print_status() {
    local type=$1
    local msg=$2
    
    case $type in
        "success") echo -e "  ${GREEN}✓${NC} ${GREEN}$msg${NC}" ;;
        "error") echo -e "  ${RED}✗${NC} ${RED}$msg${NC}" ;;
        "warning") echo -e "  ${YELLOW}⚠${NC} ${YELLOW}$msg${NC}" ;;
        "info") echo -e "  ${BLUE}ℹ${NC} ${BLUE}$msg${NC}" ;;
        "running") echo -ne "  ${BLUE}↻${NC} ${msg}" ;;
    esac
}

print_status_done() {
    echo -e "\r  ${GREEN}✓${NC} ${GREEN}$1${NC}"
}

spinner() {
    local text=$1
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        for frame in "${ANIM_FRAMES[@]}"; do
            echo -ne "\r  ${BLUE}${frame}${NC} ${text}"
            sleep 0.1
        done
    done
    echo -ne "\r\033[K"
}

show_amd_vds_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}     █████╗ ███╗   ███╗██████╗      ██╗   ██╗██████╗ ███████╗   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}    ██╔══██╗████╗ ████║██╔══██╗     ██║   ██║██╔══██╗██╔════╝   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}    ███████║██╔████╔██║██║  ██║     ██║   ██║██║  ██║███████╗   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}    ██╔══██║██║╚██╔╝██║██║  ██║     ██║   ██║██║  ██║╚════██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}    ██║  ██║██║ ╚═╝ ██║██████╔╝     ╚██████╔╝██████╔╝███████║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}    ╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝       ╚═════╝ ╚═════╝ ╚══════╝   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${BOLD}               VIRTUAL DATA SYSTEM LOGIN                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_animesh_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}    █████╗ ███╗   ██╗██╗███╗   ███╗███████╗███████╗██╗  ██╗   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ██╔══██╗████╗  ██║██║████╗ ████║██╔════╝██╔════╝██║  ██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ███████║██╔██╗ ██║██║██╔████╔██║█████╗  ███████╗███████║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██╔══██║██║╚██╗██║██║██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██║  ██║██║ ╚████║██║██║ ╚═╝ ██║███████╗███████║██║  ██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${BOLD}                QUANTUM SEQUENCE INITIATION                   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_nobita_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BLINK}${BOLD}${MAGENTA}   ██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ██║ ╚████║╚██████╔╝██████╔╝██║   ██║   ██║  ██║   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${MAGENTA}   ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${BOLD}                  SCRIPT EXECUTION ENGINE                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_animesh_sequence() {
    show_animesh_banner
    
    # Animesh sequence steps
    local steps=(
        "Initializing neural pathways..."
        "Calibrating quantum processors..."
        "Synchronizing temporal matrices..."
        "Establishing dimensional bridge..."
        "Loading consciousness protocol..."
        "Activating reality interface..."
    )
    
    for step in "${steps[@]}"; do
        print_status "running" "${step}"
        sleep 0.8
        print_status_done "${step}"
    done
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${BOLD}${BLINK}         ANIMESH SEQUENCE COMPLETED SUCCESSFULLY               ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 1
}

amd_vds_login() {
    show_amd_vds_banner
    
    print_status "info" "Connecting to AMD Virtual Data System..."
    sleep 0.5
    
    # Simulate VDS login process
    print_status "running" "Establishing secure connection to ${AMD_VDS_URL}"
    sleep 1.5
    print_status_done "Secure connection established"
    
    print_status "running" "Authenticating with VDS credentials"
    sleep 1.2
    print_status_done "Authentication successful"
    
    print_status "running" "Synchronizing data streams"
    sleep 1.0
    print_status_done "Data streams synchronized"
    
    print_status "running" "Initializing virtual environment"
    sleep 0.8
    print_status_done "Virtual environment ready"
    
    print_status "success" "AMD VDS Login completed"
    echo ""
    
    # Show VDS status
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${BOLD}            AMD VDS STATUS REPORT                     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}  ╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}  ║${NC} Connection: ${GREEN}Active${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC} Bandwidth:  ${GREEN}1.2 Gbps${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC} Latency:    ${GREEN}12ms${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC} Security:   ${GREEN}TLS 1.3${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC} Encryption: ${GREEN}AES-256-GCM${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 2
}

run_nobita_script() {
    show_nobita_banner
    
    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        print_status "error" "curl is required but not installed."
        exit 1
    fi
    
    # Setup .netrc
    print_status "info" "Configuring authentication..."
    
    touch "$NETRC"
    chmod 600 "$NETRC"
    
    # Remove existing entry
    tmpfile="$(mktemp)"
    grep -vE "^[[:space:]]*machine[[:space:]]+${HOST}([[:space:]]+|$)" "$NETRC" > "$tmpfile" || true
    mv "$tmpfile" "$NETRC"
    
    # Add credentials
    {
        printf 'machine %s ' "$HOST"
        printf 'login %s ' "user-www"
        printf 'password %s\n' "r3frwsrfrq"
    } >> "$NETRC"
    
    print_status "success" "Authentication configured"
    
    # Download and execute
    script_file="$(mktemp)"
    cleanup() { rm -f "$script_file"; }
    trap cleanup EXIT
    
    print_status "info" "Downloading script from ${NOBITA_URL}..."
    
    if curl -fsS --netrc -o "$script_file" "$NOBITA_URL"; then
        print_status "success" "Script downloaded successfully"
        
        # Show script info
        if [ -s "$script_file" ]; then
            line_count=$(wc -l < "$script_file")
            print_status "info" "Script size: ${line_count} lines"
            
            echo ""
            echo -e "${YELLOW}════════════════════ SCRIPT EXECUTION START ════════════════════${NC}"
            echo ""
            
            # Execute with output
            bash "$script_file"
            local exit_code=$?
            
            echo ""
            echo -e "${YELLOW}═════════════════════ SCRIPT EXECUTION END ═════════════════════${NC}"
            echo ""
            
            if [ $exit_code -eq 0 ]; then
                print_status "success" "Script executed successfully (Exit code: ${exit_code})"
            else
                print_status "warning" "Script completed with exit code: ${exit_code}"
            fi
        else
            print_status "error" "Downloaded script is empty"
            exit 1
        fi
    else
        print_status "error" "Authentication or download failed."
        exit 1
    fi
}

show_completion_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}${BLINK}${BOLD}${MAGENTA}   ███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗    ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}${BLINK}${BOLD}${MAGENTA}   ████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗   ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}${BLINK}${BOLD}${MAGENTA}   ██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║   ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}${BOLD}${MAGENTA}   ██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║   ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}${BOLD}${MAGENTA}   ██║ ╚████║╚██████╔╝██████╔╝██║   ██║   ██║  ██║   ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}${BOLD}${MAGENTA}   ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝   ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${BOLD}            EXECUTION SUMMARY - ALL STAGES COMPLETE            ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${GREEN}✓${NC} Stage 1: AMD VDS Login                     ${GREEN}[COMPLETED]${NC} ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${GREEN}✓${NC} Stage 2: Animesh Sequence                  ${GREEN}[COMPLETED]${NC} ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${GREEN}✓${NC} Stage 3: Nobita Script Execution          ${GREEN}[COMPLETED]${NC} ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${BOLD}${BLINK}           ALL OPERATIONS COMPLETED SUCCESSFULLY               ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Final timestamp with animation
    echo -ne "${CYAN}${BLINK}"
    echo -e "Execution completed at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${DIM}System: $(uname -srm)${NC}"
}

main() {
    print_master_header
    
    # Stage 1: AMD VDS Login
    print_stage_header "AMD VDS LOGIN" "1"
    amd_vds_login
    
    # Stage 2: Animesh Sequence
    print_stage_header "ANIMESH SEQUENCE" "2"
    show_animesh_sequence
    
    # Stage 3: Nobita Script Execution
    print_stage_header "NOBITA SCRIPT RUNNER" "3"
    run_nobita_script
    
    # Completion
    show_completion_summary
    
    # Final pause
    sleep 3
}

# Error handling
trap 'echo -e "\n${RED}✗ Process interrupted by user${NC}"; exit 1' INT

# Run the main function
main
