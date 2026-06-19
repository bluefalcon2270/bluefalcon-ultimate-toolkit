#!/usr/bin/env bash
# ==============================================================================
# BlueFalcon Ultimate Toolkit - Modular Setup
# ==============================================================================
set -uo pipefail

export SCRIPT_VERSION="v2.0-Modular"
export APP_DIR="/opt/bluefalcon-ultimate-toolkit"
export LOG_FILE="/var/log/bluefalcon_toolkit.log"
export WARP_LOG="/var/log/bluefalcon_warp.log"
export SSH_CONFIG="/etc/ssh/sshd_config"
export GITHUB_RAW_BASE="https://raw.githubusercontent.com/bluefalcon2270/bluefalcon-ultimate-toolkit/main"

export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export BOLD_BLUE='\033[1;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

touch "${LOG_FILE}" "${WARP_LOG}" 2>/dev/null || true

cleanup() {
    echo -e "${NC}\n[!] Process interrupted. Cleaning up..."
    local jobs=$(jobs -p)
    [ -n "$jobs" ] && kill $jobs 2>/dev/null
    tput cnorm
    rm -f /tmp/wgcf.sh
    exit 1
}
trap cleanup SIGINT SIGTERM

pause_execution() {
    tput cnorm; echo ""; read -n 1 -s -r -p "Press any key to continue..."; echo ""
}

run_with_spinner() {
    local msg="$1"; shift
    local log_tgt="${CURRENT_LOG:-$LOG_FILE}"
    "$@" >> "$log_tgt" 2>&1 &
    local pid=$!
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r[ ${CYAN}%s${NC} ] %s" "$frame" "$msg"
            sleep $delay
        done
    done
    wait "$pid"
    local exit_status=$?
    if [ $exit_status -eq 0 ]; then printf "\r[ ${GREEN}✔${NC} ] %s\n" "$msg"
    else printf "\r[ ${RED}✖${NC} ] %s\n" "$msg"; tput cnorm; return 1; fi
    tput cnorm
}
export -f run_with_spinner pause_execution cleanup

check_preflight() {
    if [[ "${EUID}" -ne 0 ]]; then echo -e "[ ${RED}✖${NC} ] Error: This script requires root privileges. Execute with sudo or as root."; exit 1; fi
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then echo -e "[ ${RED}✖${NC} ] Error: No active internet connection detected."; exit 1; fi
    if lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || lsof /var/lib/apt/lists/lock >/dev/null 2>&1; then echo -e "[ ${RED}✖${NC} ] Error: Package manager is currently locked by another process."; exit 1; fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "${ID}" == "ubuntu" && ("${VERSION_ID}" == "22.04" || "${VERSION_ID}" == "24.04") ]] || \
           [[ "${ID}" == "debian" && ("${VERSION_ID}" == "11" || "${VERSION_ID}" == "12" || "${VERSION_ID}" == "13") ]]; then
            :
        else
            echo -e "[ ${RED}✖${NC} ] Error: Toolkit strictly supports Ubuntu 22.04/24.04 or Debian 11/12/13."
            exit 1
        fi
    else
        echo -e "[ ${RED}✖${NC} ] Error: Cannot detect OS. /etc/os-release missing."
        exit 1
    fi
}

ensure_modules() {
    local modules=("module_essentials.sh" "module_openvpn.sh" "module_warp.sh" "module_panel.sh")
    for mod in "${modules[@]}"; do
        if [ ! -f "$mod" ]; then
            echo -e "[ ${YELLOW}⬇${NC} ] Fetching missing module: $mod..."
            curl -fsSL "${GITHUB_RAW_BASE}/${mod}" -o "$mod"
            chmod +x "$mod"
        fi
    done
}

main() {
    cd "$(dirname "$0")" || exit 1
    check_preflight
    ensure_modules
    while true; do
        clear
        echo -e "${BOLD_BLUE}=====================================================${NC}"
        echo -e "${BOLD_BLUE}       🧰 BlueFalcon Ultimate Toolkit (${SCRIPT_VERSION}) 🧰       ${NC}"
        echo -e "${BOLD_BLUE}=====================================================${NC}"
        echo ""
        echo "1. Essential Tools"
        echo "2. OpenVPN & Web Panel"
        echo "3. Cloudflare WARP"
        echo "0. Exit"
        echo ""
        read -rp "Select option: " choice
        case "${choice}" in
            1) bash module_essentials.sh ;;
            2) bash module_panel.sh ;;
            3) bash module_warp.sh ;;
            0) echo -e "\n[ ${GREEN}✔${NC} ] Exiting toolkit. Session terminated cleanly.\n"; tput cnorm; exit 0 ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid option."; sleep 1.5 ;;
        esac
    done
}
main "$@"