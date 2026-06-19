#!/usr/bin/env bash

# ==============================================================================
# BlueFalcon Ultimate Toolkit (God Script)
# Version: v1.9
# Architecture: Optimized for Debian & Ubuntu (Bash/Python/SQLite Stack)
# ==============================================================================

set -uo pipefail

# --- Load Core Dependencies ---
source "$(dirname "$0")/core/ui_utils.sh"
source "$(dirname "$0")/core/preflight.sh"

# --- Load Modules ---
source "$(dirname "$0")/modules/essential_tools.sh"
source "$(dirname "$0")/modules/warp_manager.sh"
source "$(dirname "$0")/modules/panel_manager.sh"

# ==============================================================================
# --- God Script Main Execution ---
# ==============================================================================
show_main_menu() {
    clear
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo -e "${BOLD_BLUE}                    🧰 BlueFalcon Ultimate Toolkit (v1.9) 🧰             ${NC}"
    echo -e "${BOLD_BLUE}=====================================================${NC}"
    echo ""
    echo "1. Essential Tools"
    echo "2. OpenVPN & Web Panel"
    echo "3. Cloudflare WARP"
    echo "0. Exit"
    echo ""
}

main() {
    check_preflight
    while true; do
        show_main_menu
        read -rp "Select option: " choice

        case "${choice}" in
            1) manage_essential ;;
            2) manage_panel ;;
            3) manage_warp ;;
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