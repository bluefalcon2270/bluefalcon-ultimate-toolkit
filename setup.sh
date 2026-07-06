#!/usr/bin/env bash

# ==============================================================================
# BlueFalcon Ultimate Toolkit (God Script)
# Version: v7.6
# Architecture: Optimized for Debian & Ubuntu (Bash/Python/SQLite Stack)
# ==============================================================================

set -uo pipefail

# Resolve true directory even when executed from a symlink (/usr/local/bin/bfu)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# --- Load Core Dependencies ---
source "${SCRIPT_DIR}/core/ui_utils.sh"
source "${SCRIPT_DIR}/core/preflight.sh"

# --- Load Modules ---
source "${SCRIPT_DIR}/cli/essential_tools.sh"
source "${SCRIPT_DIR}/cli/panel_manager.sh"
source "${SCRIPT_DIR}/cli/openvpn_manager.sh"
source "${SCRIPT_DIR}/cli/wireguard_manager.sh"
source "${SCRIPT_DIR}/cli/warp_manager.sh"
source "${SCRIPT_DIR}/cli/backup_manager.sh"
source "${SCRIPT_DIR}/cli/logs_manager.sh"

# ==============================================================================
# --- God Script Main Execution ---
# ==============================================================================
show_main_menu() {
    clear
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo -e "${BOLD_BLUE}       🧰 BlueFalcon Ultimate Toolkit (${BF_VERSION}) 🧰       ${NC}"
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo ""
    echo "1. Web Panel"
    echo "2. OpenVPN"
    echo "3. WireGuard"
    echo "4. WARP"
    echo "5. Essentials"
    echo "6. Backup/Restore"
    echo "7. Logs"
    echo "0. Exit"
    echo ""
}

main() {
    check_preflight
    
    while true; do
        show_main_menu
        read -rp "Select option: " choice

        case "${choice}" in
            1) manage_panel ;;
            2) manage_openvpn ;;
            3) manage_wireguard ;;
            4) manage_warp ;;
            5) manage_essential ;;
            6) manage_backup ;;
            7) manage_logs ;;
            0) 
                echo -e "\n[ ${GREEN}✔${NC} ] Exiting toolkit. Session terminated cleanly.\n"
                tput cnorm
                exit 0 
                ;;
            *) 
                echo -e "\n[ ${RED}✖${NC} ] Invalid option."
                sleep 1.5 
                ;;
        esac
    done
}

main "$@"