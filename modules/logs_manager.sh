#!/bin/bash
# ==============================================================================
# --- MODULE 6: Logs Manager ---
# ==============================================================================

view_logs() {
    local log_type="$1"
    
    clear
    echo -e "${BOLD_BLUE}--- ${log_type} ---${NC}\nStreaming real-time logs. Press Ctrl+C to exit.\n"
    trap 'true' SIGINT
    
    case "$log_type" in
        "Unified Master Stream")
            journalctl -u bluefalcon-panel -u openvpn-server@server -u wg-quick@wgcf -f -n 50
            ;;
        "Web Panel Core")
            journalctl -u bluefalcon-panel -f -n 50
            ;;
        "OpenVPN Service")
            journalctl -u openvpn-server@server -f -n 50
            ;;
        "WARP Shield")
            journalctl -u wg-quick@wgcf -f -n 50
            ;;
        "Security & Auth")
            if [ -f /var/log/auth.log ]; then tail -f -n 50 /var/log/auth.log; else echo "No auth.log found."; fi
            ;;
        "Firewall Drops (UFW)")
            journalctl -k -f | grep --line-buffered UFW
            ;;
        "Kernel & Network")
            journalctl -k -f -n 50
            ;;
        "Package Manager (APT)")
            if [ -f /var/log/dpkg.log ]; then tail -f -n 50 /var/log/dpkg.log; else echo "No dpkg.log found."; fi
            ;;
        "Cron Tasks")
            journalctl -u cron -f -n 50
            ;;
    esac

    trap cleanup SIGINT SIGTERM
}

manage_logs() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}              Log Center (${BF_VERSION})                   ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Unified Master Stream (Panel + OpenVPN + WARP)"
        echo "2. Web Panel Core"
        echo "3. OpenVPN Service"
        echo "4. WARP Shield"
        echo "5. Security & Auth (auth.log)"
        echo "6. Firewall Drops (UFW)"
        echo "7. Kernel & Network (dmesg)"
        echo "8. Package Manager (APT/dpkg)"
        echo "9. Cron Tasks"
        echo "0. Return to Main Menu"
        echo ""
        
        read -rp "Select option: " o_choice
        case "$o_choice" in
            1) view_logs "Unified Master Stream" ;;
            2) view_logs "Web Panel Core" ;;
            3) view_logs "OpenVPN Service" ;;
            4) view_logs "WARP Shield" ;;
            5) view_logs "Security & Auth" ;;
            6) view_logs "Firewall Drops (UFW)" ;;
            7) view_logs "Kernel & Network" ;;
            8) view_logs "Package Manager (APT)" ;;
            9) view_logs "Cron Tasks" ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}
