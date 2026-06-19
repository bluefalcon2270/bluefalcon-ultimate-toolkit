#!/usr/bin/env bash
# module_openvpn.sh
# OpenVPN Backend Engine

# ==============================================================================
# 1. Backend Logic
# ==============================================================================

backend_install() {
    echo "[INFO] Commencing OpenVPN Core Installation..."
    if ! command -v openvpn >/dev/null 2>&1; then 
        apt-get install -y openvpn openssl iptables iptables-persistent iproute2 > /dev/null 2>&1
    fi
    
    echo "[INFO] Initializing Easy-RSA PKI..."
    mkdir -p "${APP_DIR}/easy-rsa"
    if [ ! -f "${APP_DIR}/easy-rsa/easyrsa" ]; then
        wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.6/EasyRSA-3.2.6.tgz | tar xz -C "${APP_DIR}/easy-rsa" --strip-components 1 > /dev/null 2>&1
        cd "${APP_DIR}/easy-rsa" || exit
        ./easyrsa --batch init-pki > /dev/null 2>&1
        ./easyrsa --batch build-ca nopass > /dev/null 2>&1
        ./easyrsa --batch build-server-full server nopass > /dev/null 2>&1
        ./easyrsa gen-crl > /dev/null 2>&1
    fi
    
    echo "[INFO] Generating Parameters..."
    if [ ! -f "/etc/openvpn/server/dh.pem" ]; then openssl dhparam -out /etc/openvpn/server/dh.pem 2048 > /dev/null 2>&1; fi
    mkdir -p /etc/openvpn/server/auth
    cp "${APP_DIR}/easy-rsa/pki/ca.crt" "${APP_DIR}/easy-rsa/pki/issued/server.crt" "${APP_DIR}/easy-rsa/pki/private/server.key" "${APP_DIR}/easy-rsa/pki/crl.pem" /etc/openvpn/server/
    if [ ! -f "/etc/openvpn/server/tc.key" ]; then openvpn --genkey secret /etc/openvpn/server/tc.key; fi
    chmod 644 /etc/openvpn/server/crl.pem
    
    echo "[INFO] Configuring Auth Engine..."
    cat > /etc/openvpn/server/auth/verify.sh << 'EOF_V'
#!/bin/bash
user=$(head -n 1 "$1"); pass=$(tail -n 1 "$1")
line=$(grep "^${user}:${pass}:" /etc/openvpn/server/auth/users.db)
if [ -n "$line" ]; then
    status=$(echo "$line" | cut -d':' -f4)
    if [ "$status" == "active" ]; then exit 0; fi
fi
exit 1
EOF_V
    chmod +x /etc/openvpn/server/auth/verify.sh
    touch /etc/openvpn/server/auth/users.db
    chmod 666 /etc/openvpn/server/auth/users.db
    
    cat > /etc/openvpn/server/disconnect.sh << 'EOF_D'
#!/bin/bash
/usr/bin/sqlite3 -cmd ".timeout 5000" /opt/bluefalcon-ultimate-toolkit/panel/panel.db "UPDATE users SET rx = rx + ${bytes_received:-0}, tx = tx + ${bytes_sent:-0} WHERE system_name = '${common_name}';"
EOF_D
    chmod +x /etc/openvpn/server/disconnect.sh
    
    echo "[INFO] Writing Server Configuration..."
    PROTOCOL=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT protocol FROM settings LIMIT 1;" 2>/dev/null || echo "udp")
    PORT=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT port FROM settings LIMIT 1;" 2>/dev/null || echo "1194")
    DNS=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT dns FROM settings LIMIT 1;" 2>/dev/null || echo "8.8.8.8")
    DNS2=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT dns2 FROM settings LIMIT 1;" 2>/dev/null || echo "")
    
    cat > /etc/openvpn/server/server.conf << EOCONF
port $PORT
proto $PROTOCOL
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt tc.key
crl-verify crl.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS"
EOCONF

    if [ -n "$DNS2" ] && [ "$DNS2" != "None" ] && [ "$DNS2" != "" ]; then 
        echo "push \"dhcp-option DNS $DNS2\"" >> /etc/openvpn/server/server.conf
    fi

    cat >> /etc/openvpn/server/server.conf << EOCONF
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
script-security 2
auth-user-pass-verify /etc/openvpn/server/auth/verify.sh via-file
client-disconnect /etc/openvpn/server/disconnect.sh
management 127.0.0.1 7505
status /var/log/openvpn/status.log 5
status-version 2
verb 3
EOCONF

    LIMIT=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT conn_limit FROM settings LIMIT 1;" 2>/dev/null || echo "1")
    if [ "$LIMIT" == "unlimited" ]; then echo "duplicate-cn" >> /etc/openvpn/server/server.conf; fi
    
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
    sysctl -p /etc/sysctl.d/99-openvpn.conf > /dev/null 2>&1
    sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw 2>/dev/null || true
    ufw reload >/dev/null 2>&1 || true
    if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
        netfilter-persistent save > /dev/null 2>&1
    fi
    
    systemctl restart openvpn-server@server
    systemctl enable openvpn-server@server > /dev/null 2>&1
    echo -e "\n[OK] OPENVPN CORE DEPLOYED SUCCESSFULLY."
}

add_user() {
    local u=$1; local p=$2
    local IPV4=$(curl -s -4 ifconfig.me)
    local PROTOCOL=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT protocol FROM settings LIMIT 1;" 2>/dev/null || echo "udp")
    local PORT=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT port FROM settings LIMIT 1;" 2>/dev/null || echo "1194")
    
    cd "${APP_DIR}/easy-rsa" || exit
    ./easyrsa --batch build-client-full "$u" nopass > /dev/null 2>&1
    mkdir -p "${APP_DIR}/configs"
    
    # Generate _auto configuration
    cat > "${APP_DIR}/configs/${u}.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<auth-user-pass>
$u
$p
</auth-user-pass>
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF

    # Generate _manual configuration
    cat > "${APP_DIR}/configs/${u}_manual.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF
}

# ==============================================================================
# 2. UI Switchboard (Interactive Menu)
# ==============================================================================

manage_openvpn_menu() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}                   OpenVPN Engine                    ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        
        if systemctl is-active --quiet openvpn-server@server; then echo -e " Core Status: [ ${GREEN}✔${NC} ] Active"; else echo -e " Core Status: [ ${RED}✖${NC} ] Offline"; fi
        
        echo ""
        echo "1. Run Headless OpenVPN Install"
        echo "2. View OpenVPN Core Logs"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " p_choice
        case "$p_choice" in
            1) 
                if [ -n "${run_with_spinner:-}" ]; then
                    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Installing OpenVPN Engine" backend_install
                else
                    backend_install
                fi
                if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi
                ;;
            2) 
                clear
                echo -e "${BOLD_BLUE}--- OpenVPN Core Logs ---${NC}\nStreaming real-time service logs. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                journalctl -u openvpn-server@server -f -n 50
                trap cleanup SIGINT SIGTERM
                ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

action="${1:-menu}"
case "$action" in
    --install) backend_install ;;
    --add-user) add_user "$2" "$3" ;;
    menu) manage_openvpn_menu ;;
esac