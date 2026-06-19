#!/usr/bin/env bash
# module_essentials.sh
# Core Server Utilities, Updates, and SSH Management

# ==============================================================================
# 1. Backend Logic
# ==============================================================================

update_system() {
    clear
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                    Update System                    ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    
    # Self-updater mechanism
    if [ -d .git ]; then
        echo -e "\n[ ${YELLOW}⚙${NC} ] Checking for toolkit repository updates..."
        if git pull | grep -q "Already up to date."; then
            echo -e "[ ${GREEN}✔${NC} ] Toolkit repository is already up to date."
        else
            echo -e "[ ${GREEN}✔${NC} ] Toolkit updated successfully from GitHub!"
        fi
    fi

    echo -e "\n${BOLD_BLUE}--- Updating Repositories ---${NC}"
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a || true
    apt-get update -y
    
    echo -e "\n${BOLD_BLUE}--- Upgrading Packages ---${NC}"
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    echo -e "\n[ ${GREEN}✔${NC} ] System update and upgrade successfully finished!"
    pause_execution
}

install_docker_engine() {
    export DEBIAN_FRONTEND=noninteractive
    . /etc/os-release
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} jammy stable" | tee /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_utilities() {
    clear
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                   System Packages                   ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo ""
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a >> "${LOG_FILE}" 2>&1 || true
    
    local std_pkgs=(curl wget git htop unzip zip nano net-tools tmux screen socat cron ufw iptables nftables qrencode dnsutils)
    
    for pkg in "${std_pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            run_with_spinner "$pkg" apt-get install -yq "$pkg"
        else
            echo -e "[ ${GREEN}✔${NC} ] ${pkg}"
        fi
    done
    
    if ! command -v docker >/dev/null 2>&1 || ! dpkg-query -W -f='${Status}' "docker-compose-plugin" 2>/dev/null | grep -q "ok installed"; then
        run_with_spinner "Docker Engine & Compose" install_docker_engine
    else
        echo -e "[ ${GREEN}✔${NC} ] Docker Engine & Compose"
    fi

    echo -e "\nInstallation process finished."
    pause_execution
}

get_ssh_status() {
    local key="$1"
    local default_value="$2"
    local status
    status=$(sshd -T 2>/dev/null | grep -i "^${key} " | awk '{print $2}')
    echo "${status:-$default_value}"
}

format_ssh_status() {
    if [[ "${1,,}" == "yes" ]]; then echo -e "${GREEN}ON${NC}"
    elif [[ "${1,,}" == "no" ]]; then echo -e "${RED}OFF${NC}"
    else echo -e "${YELLOW}${1}${NC}"; fi
}

update_ssh_config() {
    local key="$1"
    local value="$2"
    cp "${SSH_CONFIG}" "${SSH_CONFIG}.bak"
    if grep -iqE "^#?${key}\s+" "${SSH_CONFIG}"; then
        sed -i -E "s/^#?${key}\s+.*/${key} ${value}/I" "${SSH_CONFIG}"
    else
        echo "${key} ${value}" >> "${SSH_CONFIG}"
    fi
    if sshd -t; then
        systemctl restart ssh sshd 2>/dev/null || true
        echo -e "[ ${GREEN}✔${NC} ] SSH configuration updated to: ${key} ${value}"
    else
        echo -e "[ ${RED}✖${NC} ] Invalid SSH configuration detected. Restoring backup..."
        mv "${SSH_CONFIG}.bak" "${SSH_CONFIG}"
    fi
}

manage_ssh_access() {
    while true; do
        clear
        local current_port pw_auth_raw key_auth_raw pw_auth key_auth
        current_port=$(get_ssh_status "port" "Unknown")
        pw_auth_raw=$(get_ssh_status "passwordauthentication" "Unknown")
        key_auth_raw=$(get_ssh_status "pubkeyauthentication" "Unknown")
        pw_auth=$(format_ssh_status "${pw_auth_raw}")
        key_auth=$(format_ssh_status "${key_auth_raw}")

        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                    SSH Settings                     ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e " Port:             ${current_port}"
        echo -e " Password Login:   ${pw_auth}"
        echo -e " Key Login:        ${key_auth}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Change Password"
        echo "2. Change Port"
        echo "3. Toggle Password Login"
        echo "4. Toggle Key Login"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " ssh_choice
        case "${ssh_choice}" in
            1)
                echo ""
                read -rp "Enter username to change password (leave empty for 'root'): " target_user
                passwd "${target_user:-root}"
                pause_execution ;;
            2)
                echo ""
                read -rp "Enter new SSH port (1024-65535): " new_port
                if [[ "${new_port}" =~ ^[0-9]+$ ]] && [ "${new_port}" -ge 1024 ] && [ "${new_port}" -le 65535 ]; then
                    update_ssh_config "Port" "${new_port}"
                else
                    echo -e "[ ${RED}✖${NC} ] Invalid port range."
                fi
                pause_execution ;;
            3)
                echo ""
                local new_pw_auth="yes"
                [[ "${pw_auth_raw,,}" == "yes" ]] && new_pw_auth="no"
                update_ssh_config "PasswordAuthentication" "${new_pw_auth}"
                pause_execution ;;
            4)
                echo ""
                local new_key_auth="yes"
                [[ "${key_auth_raw,,}" == "yes" ]] && new_key_auth="no"
                update_ssh_config "PubkeyAuthentication" "${new_key_auth}"
                pause_execution ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

# ==============================================================================
# 2. UI Switchboard (Interactive Menu)
# ==============================================================================
manage_essential_menu() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                   Essential Tools                   ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Update System OS & Toolkit"
        echo "2. Install Packages & Docker Engine"
        echo "3. SSH Configurations"
        echo "0. Return"
        echo ""
        read -rp "Select option: " ess_choice
        case "${ess_choice}" in
            1) update_system ;;
            2) install_utilities ;;
            3) manage_ssh_access ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

action="${1:-menu}"
case "$action" in
    --update) update_system ;;
    --packages) install_utilities ;;
    --ssh) manage_ssh_access ;;
    menu) manage_essential_menu ;;
esac