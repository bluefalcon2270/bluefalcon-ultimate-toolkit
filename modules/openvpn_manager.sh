#!/bin/bash
# ==============================================================================
# --- MODULE 3: OpenVPN Core Management ---
# ==============================================================================

APP_DIR="/opt/bluefalcon-ultimate-toolkit/panel"
DB_PATH="${APP_DIR}/panel.db"

update_users_db_file() {
    if [ -f "$DB_PATH" ]; then
        > /etc/openvpn/server/auth/users.db
        sqlite3 "$DB_PATH" "SELECT system_name, password, exp_days, status FROM users;" | while IFS='|' read -r sys pass exp stat; do
            echo "${sys}:${pass}:${exp}:${stat}" >> /etc/openvpn/server/auth/users.db
        done
    fi
}

ovpn_add_user() {
    clear
    echo -e "${BOLD_BLUE}--- Create New VPN User ---${NC}\n"
    read -rp "Display Name: " disp_name
    read -rp "Password: " password
    read -rp "Expiry (Days, 0 for unlimited): " exp_days

    # Sanitize name
    sys_name=$(echo "$disp_name" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')

    # Calculate Epoch Timestamp
    if [ "$exp_days" -eq 0 ]; then
        ts=0
    else
        ts=$(($(date +%s) + (exp_days * 86400)))
    fi

    # Inject into Web Panel DB
    sqlite3 "$DB_PATH" "INSERT INTO users (display_name, system_name, password, exp_days, status, rx, tx) VALUES ('$disp_name', '$sys_name', '$password', $ts, 'active', 0, 0);"
    update_users_db_file

    # Run OpenVPN Script
    bash "${APP_DIR}/scripts/add_user.sh" "$sys_name" "$password" >/dev/null 2>&1
    
    echo -e "\n[ ${GREEN}✔${NC} ] User '$disp_name' created successfully!"
    pause_execution
}

ovpn_revoke_user() {
    clear
    echo -e "${BOLD_BLUE}--- Revoke VPN User ---${NC}\n"
    read -rp "Enter System Name to revoke: " sys_name
    
    if ! sqlite3 "$DB_PATH" "SELECT 1 FROM users WHERE system_name='$sys_name';" | grep -q 1; then
        echo -e "\n[ ${RED}✖${NC} ] User '$sys_name' not found in database."
        pause_execution
        return
    fi

    # Remove from Web DB
    sqlite3 "$DB_PATH" "DELETE FROM users WHERE system_name='$sys_name';"
    sed -i "/^${sys_name}:/d" /etc/openvpn/server/auth/users.db

    # Kill active connection
    echo -e "kill ${sys_name}\nquit" | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &

    # Revoke Certificates via Easy-RSA
    cd "${APP_DIR}/easy-rsa" || return
    ./easyrsa --batch revoke "$sys_name" >/dev/null 2>&1
    ./easyrsa gen-crl >/dev/null 2>&1
    cp "${APP_DIR}/easy-rsa/pki/crl.pem" /etc/openvpn/server/
    chmod 644 /etc/openvpn/server/crl.pem

    # Delete config files
    rm -f "${APP_DIR}/configs/${sys_name}.ovpn"
    rm -f "${APP_DIR}/configs/${sys_name}_manual.ovpn"

    echo -e "\n[ ${GREEN}✔${NC} ] User '$sys_name' revoked and deleted."
    pause_execution
}

ovpn_toggle_user() {
    clear
    echo -e "${BOLD_BLUE}--- Toggle VPN User (Pause/Resume) ---${NC}\n"
    read -rp "Enter System Name to toggle: " sys_name

    current_stat=$(sqlite3 "$DB_PATH" "SELECT status FROM users WHERE system_name='$sys_name';")
    
    if [ -z "$current_stat" ]; then
        echo -e "\n[ ${RED}✖${NC} ] User '$sys_name' not found."
        pause_execution
        return
    fi

    if [ "$current_stat" == "active" ]; then
        new_stat="paused"
        echo -e "kill ${sys_name}\nquit" | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &
    else
        new_stat="active"
    fi

    sqlite3 "$DB_PATH" "UPDATE users SET status='$new_stat' WHERE system_name='$sys_name';"
    update_users_db_file

    echo -e "\n[ ${GREEN}✔${NC} ] User '$sys_name' is now $new_stat."
    pause_execution
}

ovpn_list_users() {
    clear
    echo -e "${BOLD_BLUE}--- Active VPN Users ---${NC}\n"
    printf "%-20s %-20s %-15s %-10s\n" "Display Name" "System Name" "Expiry" "Status"
    echo "------------------------------------------------------------------------"
    
    current_time=$(date +%s)
    
    sqlite3 "$DB_PATH" "SELECT display_name, system_name, exp_days, status FROM users;" | while IFS='|' read -r disp sys exp stat; do
        if [ "$exp" -eq 0 ]; then
            exp_text="Unlimited"
        elif [ "$exp" -lt "$current_time" ]; then
            exp_text="Expired"
        else
            days_left=$(( (exp - current_time) / 86400 ))
            exp_text="${days_left} Days"
        fi
        printf "%-20s %-20s %-15s %-10s\n" "$disp" "$sys" "$exp_text" "$stat"
    done
    echo ""
    pause_execution
}

manage_openvpn() {
    if [ ! -f "$DB_PATH" ]; then
        clear
        echo -e "\n[ ${RED}✖${NC} ] Database missing. Please install the Web Panel first to configure OpenVPN."
        pause_execution
        return
    fi

    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}           OpenVPN Management (${BF_VERSION})              ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        if systemctl is-active --quiet openvpn-server@server; then echo -e " OpenVPN Core:        [ ${GREEN}✔${NC} ] Active"; else echo -e " OpenVPN Core:        [ ${RED}✖${NC} ] Offline"; fi
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Create New User"
        echo "2. Revoke/Delete User"
        echo "3. Pause/Resume User"
        echo "4. List All Users"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " o_choice
        case "$o_choice" in
            1) ovpn_add_user ;;
            2) ovpn_revoke_user ;;
            3) ovpn_toggle_user ;;
            4) ovpn_list_users ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}