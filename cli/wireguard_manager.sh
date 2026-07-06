#!/usr/bin/env bash
# ==============================================================================
# --- MODULE: WireGuard Manager ---
# ==============================================================================

manage_wireguard() {
    local wg_status
    local wg_is_installed
    wg_is_installed=$(sqlite3 "${DB_FILE}" "SELECT is_installed FROM settings WHERE server_name='wireguard';" 2>/dev/null || echo "0")

    while true; do
        clear
        if [[ "${wg_is_installed}" == "1" ]]; then
            if systemctl is-active --quiet wg-quick@wg0; then
                wg_status="${GREEN}Active${NC}"
            else
                wg_status="${RED}Inactive${NC}"
            fi
        else
            wg_status="${RED}Not Installed${NC}"
        fi

        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                 WireGuard Manager                   ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e " Status: ${wg_status}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        
        if [[ "${wg_is_installed}" != "1" ]]; then
            echo "1. Install WireGuard"
        else
            echo "1. Reinstall WireGuard"
            echo "2. Add User"
            echo "3. Remove User"
            echo "4. List Users"
        fi
        echo "0. Return to Main Menu"
        echo ""
        
        read -rp "Select option: " wg_choice
        case "${wg_choice}" in
            1)
                echo ""
                read -rp "Enter port for WireGuard [Default: 51820]: " custom_port
                custom_port=${custom_port:-51820}
                bash "${SCRIPT_DIR}/core/wireguard/core_setup.sh" "$custom_port" "8.8.8.8" "8.8.4.4"
                wg_is_installed="1"
                pause_execution
                ;;
            2)
                if [[ "${wg_is_installed}" == "1" ]]; then
                    echo ""
                    read -rp "Enter Username: " new_user
                    read -rp "Enter Expiration (days) [Default: 30]: " exp_days
                    exp_days=${exp_days:-30}
                    bash "${SCRIPT_DIR}/core/wireguard/add_user.sh" "$new_user" "$exp_days"
                    pause_execution
                else
                    echo -e "\n[ ${RED}âœ–${NC} ] WireGuard is not installed."
                    sleep 1.5
                fi
                ;;
            3)
                if [[ "${wg_is_installed}" == "1" ]]; then
                    echo ""
                    read -rp "Enter Username to remove: " del_user
                    bash "${SCRIPT_DIR}/core/wireguard/del_user.sh" "$del_user"
                    pause_execution
                else
                    echo -e "\n[ ${RED}âœ–${NC} ] WireGuard is not installed."
                    sleep 1.5
                fi
                ;;
            4)
                if [[ "${wg_is_installed}" == "1" ]]; then
                    echo ""
                    echo -e "${BOLD_BLUE}--- WireGuard Users ---${NC}"
                    sqlite3 "${DB_FILE}" "SELECT system_name, ip_address, exp_days, status FROM wg_users;" | column -t -s '|'
                    pause_execution
                else
                    echo -e "\n[ ${RED}âœ–${NC} ] WireGuard is not installed."
                    sleep 1.5
                fi
                ;;
            0) break ;;
            *) echo -e "\n[ ${RED}âœ–${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}
