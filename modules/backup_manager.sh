#!/bin/bash
# ==============================================================================
# --- MODULE 5: Backup & Restore Manager ---
# ==============================================================================

APP_DIR="/opt/bluefalcon-ultimate-toolkit"
BACKUP_DIR="/var/backups/bluefalcon"

mkdir -p "$BACKUP_DIR"

create_backup() {
    clear
    echo -e "${BOLD_BLUE}--- Create System Backup ---${NC}\n"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/bf_backup_${timestamp}.tar.gz"
    
    echo "Creating backup archive..."
    
    # Paths to backup
    local paths_to_backup=""
    
    if [ -d "/etc/openvpn/server" ]; then
        paths_to_backup+=" /etc/openvpn/server"
    fi
    
    if [ -f "${APP_DIR}/panel/panel.db" ]; then
        paths_to_backup+=" ${APP_DIR}/panel/panel.db"
    fi
    
    if [ -d "/etc/wireguard" ]; then
        paths_to_backup+=" /etc/wireguard"
    fi

    if [ -z "$paths_to_backup" ]; then
        echo -e "\n[ ${RED}✖${NC} ] No configurations found to backup."
        pause_execution
        return
    fi
    
    tar -czf "$backup_file" $paths_to_backup >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "\n[ ${GREEN}✔${NC} ] Backup created successfully: $backup_file"
    else
        echo -e "\n[ ${RED}✖${NC} ] Backup failed."
    fi
    
    pause_execution
}

restore_backup() {
    clear
    echo -e "${BOLD_BLUE}--- Restore System Backup ---${NC}\n"
    
    local backups=($(ls -1t "${BACKUP_DIR}"/bf_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "[ ${YELLOW}!${NC} ] No backups found in ${BACKUP_DIR}"
        pause_execution
        return
    fi
    
    echo "Available Backups:"
    for i in "${!backups[@]}"; do
        echo "$((i+1)). $(basename "${backups[$i]}")"
    done
    echo "0. Cancel"
    echo ""
    
    read -rp "Select backup to restore: " b_choice
    
    if [[ "$b_choice" -eq 0 ]]; then
        return
    elif [[ "$b_choice" -gt 0 && "$b_choice" -le "${#backups[@]}" ]]; selected_backup="${backups[$((b_choice-1))]}"; then
        echo -e "\nRestoring from $selected_backup..."
        tar -xzf "$selected_backup" -C / >/dev/null 2>&1
        
        # Restart services if necessary
        systemctl restart openvpn-server@server 2>/dev/null
        systemctl restart bluefalcon-panel 2>/dev/null
        
        echo -e "\n[ ${GREEN}✔${NC} ] Restore completed successfully."
    else
        echo -e "\n[ ${RED}✖${NC} ] Invalid selection."
    fi
    
    pause_execution
}

manage_backup() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}        Backup & Restore Management (${BF_VERSION})         ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Create Backup"
        echo "2. Restore Backup"
        echo "0. Return to Main Menu"
        echo ""
        
        read -rp "Select option: " o_choice
        case "$o_choice" in
            1) create_backup ;;
            2) restore_backup ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}
