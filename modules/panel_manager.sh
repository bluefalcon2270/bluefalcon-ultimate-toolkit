#!/bin/bash
# ==============================================================================
# --- MODULE 2: Web Panel Management ---
# ==============================================================================

APP_DIR="/opt/bluefalcon-ultimate-toolkit/panel"

install_panel() {
    clear
    echo ""
    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Updating repositories" apt-get update -y
    echo "iptables-persistent iptables-persistent/ensure-ipv4-rules boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/ensure-ipv6-rules boolean true" | debconf-set-selections
    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Installing dependencies" apt-get install -y python3 python3-flask python3-gunicorn python3-psutil sqlite3 curl cron gunicorn iptables iptables-persistent iproute2 netcat-openbsd

    deploy_panel_files() {
        mkdir -p "${APP_DIR}/configs" /var/log/bluefalcon-panel "${APP_DIR}/scripts"
        local REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        
        cp -r "${REPO_DIR}/panel/"* "${APP_DIR}/"
        cp -r "${REPO_DIR}/vpn-scripts/openvpn/"* "${APP_DIR}/scripts/"
        cp -r "${REPO_DIR}/vpn-scripts/warp/"* "${APP_DIR}/scripts/"
        chmod +x "${APP_DIR}/scripts/"*.sh
    }
    
    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Deploying Material Design Application" deploy_panel_files

    if ! grep -q "/swapfile" /etc/fstab; then
        CURRENT_LOG="${LOG_FILE}" run_with_spinner "Creating Swapfile" bash -c "fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab"
    fi

    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Securing Web Panel Port" bash -c "iptables -I INPUT -p tcp --dport 2020 -j ACCEPT && netfilter-persistent save"

    cat > /etc/cron.daily/bluefalcon-panel-expiry << EOF
#!/bin/bash
python3 ${APP_DIR}/scripts/expiry.py
EOF
    chmod +x /etc/cron.daily/bluefalcon-panel-expiry

    GUNICORN_CMD=$(command -v gunicorn)
    if [ -z "$GUNICORN_CMD" ]; then GUNICORN_CMD="/usr/local/bin/gunicorn"; fi

    cat > /etc/systemd/system/bluefalcon-panel.service << EOF
[Unit]
Description=BlueFalcon Universal Web Panel
After=network.target

[Service]
User=root
WorkingDirectory=${APP_DIR}
ExecStart=$GUNICORN_CMD -w 2 -b 0.0.0.0:2020 --timeout 600 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Starting Web Panel Engine" bash -c "systemctl daemon-reload && systemctl enable bluefalcon-panel && systemctl restart bluefalcon-panel"

    IPV4=$(ip -4 addr show $(ip route | awk '/default/ {print $5}' | head -1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "\n[ ${GREEN}✔${NC} ] WEB PANEL DEPLOYED SUCCESSFULLY!"
    echo -e "Open your browser to the Initialization Wizard: ${YELLOW}http://$IPV4:2020${NC}\n"
    pause_execution
}

uninstall_panel() {
    clear
    echo ""
    read -rp "Uninstall Web Panel ONLY? (OpenVPN & WARP will remain intact) (y/N): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        echo ""
        CURRENT_LOG="${LOG_FILE}" run_with_spinner "Removing Web Panel service" bash -c "systemctl stop bluefalcon-panel 2>/dev/null; systemctl disable bluefalcon-panel 2>/dev/null; rm -f /etc/systemd/system/bluefalcon-panel.service /etc/cron.daily/bluefalcon-panel-expiry; systemctl daemon-reload"
        echo -e "\n[ ${GREEN}✔${NC} ] Web Panel safely disabled and removed. Your VPN engines are still running."
    else
        echo -e "\n[ ${YELLOW}✖${NC} ] Uninstallation canceled."
    fi
    pause_execution
}

manage_panel() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}           Web Panel Management (${BF_VERSION})              ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        
        IPV4=$(ip -4 addr show $(ip route | awk '/default/ {print $5}' | head -1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        PANEL_PORT="2020"
        ADMIN_USER="Not Set"
        ADMIN_PASS="Not Set"
        
        if [ -f "${APP_DIR}/panel.db" ]; then
            PANEL_PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT panel_port FROM settings LIMIT 1;" 2>/dev/null)
            PANEL_PORT=${PANEL_PORT:-2020}
            ADMIN_USER=$(sqlite3 "${APP_DIR}/panel.db" "SELECT username FROM admin LIMIT 1;" 2>/dev/null)
            ADMIN_USER=${ADMIN_USER:-"Not Set"}
            ADMIN_PASS=$(sqlite3 "${APP_DIR}/panel.db" "SELECT password FROM admin LIMIT 1;" 2>/dev/null)
            ADMIN_PASS=${ADMIN_PASS:-"Not Set"}
        fi
        
        echo -e " Panel Link:          ${YELLOW}http://$IPV4:$PANEL_PORT${NC}"
        echo -e " Admin Username:      ${CYAN}${ADMIN_USER}${NC}"
        echo -e " Admin Password:      ${CYAN}${ADMIN_PASS}${NC}"
        
        if systemctl is-active --quiet bluefalcon-panel; then echo -e " Web Panel:           [ ${GREEN}✔${NC} ] Active"; else echo -e " Web Panel:           [ ${RED}✖${NC} ] Offline"; fi
        
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Install Web Panel"
        echo "2. Uninstall Web Panel"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " p_choice
        case "$p_choice" in
            1) install_panel ;;
            2) uninstall_panel ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}