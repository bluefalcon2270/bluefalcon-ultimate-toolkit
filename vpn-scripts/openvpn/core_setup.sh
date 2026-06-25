#!/bin/bash
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
echo "[INFO] Commencing OpenVPN Core Installation..."
sleep 1
if ! command -v openvpn >/dev/null 2>&1; then
    apt-get install -y openvpn openssl iptables iptables-persistent iproute2 > /dev/null 2>&1
fi
echo " - Network and core packages installed [OK]"
echo "[INFO] Initializing Easy-RSA PKI Cryptography..."
mkdir -p "${APP_DIR}/easy-rsa"
if [ ! -f "${APP_DIR}/easy-rsa/easyrsa" ]; then
    wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.6/EasyRSA-3.2.6.tgz | tar xz -C "${APP_DIR}/easy-rsa" --strip-components 1 > /dev/null 2>&1
    cd "${APP_DIR}/easy-rsa"
    ./easyrsa --batch init-pki > /dev/null 2>&1
    ./easyrsa --batch build-ca nopass > /dev/null 2>&1
    ./easyrsa --batch build-server-full server nopass > /dev/null 2>&1
    ./easyrsa gen-crl > /dev/null 2>&1
else
    cd "${APP_DIR}/easy-rsa"
fi
echo " - Authority Certificates built [OK]"

echo "[INFO] Generating Diffie-Hellman Parameters (Fast Method)..."
if [ ! -f "/etc/openvpn/server/dh.pem" ]; then openssl dhparam -dsaparam -out /etc/openvpn/server/dh.pem 2048 > /dev/null 2>&1; fi

mkdir -p /etc/openvpn/server/auth
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server/
if [ ! -f "/etc/openvpn/server/tc.key" ]; then openvpn --genkey secret /etc/openvpn/server/tc.key; fi
chmod 644 /etc/openvpn/server/crl.pem
echo " - Key generation complete [OK]"
echo "[INFO] Setting up Pause/Resume Authentication Engine..."
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
echo " - Live DB verification logic attached [OK]"
echo "[INFO] Engineering Data Persistence Hook..."
cat > /etc/openvpn/server/disconnect.sh << 'EOF_D'
#!/bin/bash
/usr/bin/sqlite3 -cmd ".timeout 5000" /opt/bluefalcon-ultimate-toolkit/panel.db "UPDATE users SET rx = rx + ${bytes_received:-0}, tx = tx + ${bytes_sent:-0} WHERE system_name = '${common_name}';"
EOF_D
chmod +x /etc/openvpn/server/disconnect.sh
echo " - Disconnect database injector deployed [OK]"
echo "[INFO] Writing Server Configuration & NAT Firewalls..."
PROTOCOL=$(sqlite3 "${APP_DIR}/panel.db" "SELECT protocol FROM settings LIMIT 1;")
PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT port FROM settings LIMIT 1;")
DNS=$(sqlite3 "${APP_DIR}/panel.db" "SELECT dns FROM settings LIMIT 1;")
DNS2=$(sqlite3 "${APP_DIR}/panel.db" "SELECT dns2 FROM settings LIMIT 1;")
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
if [ -n "$DNS2" ] && [ "$DNS2" != "None" ] && [ "$DNS2" != "" ]; then echo "push \"dhcp-option DNS $DNS2\"" >> /etc/openvpn/server/server.conf; fi
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
LIMIT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT conn_limit FROM settings LIMIT 1;")
if [ "$LIMIT" == "unlimited" ]; then echo "duplicate-cn" >> /etc/openvpn/server/server.conf; fi
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf > /dev/null 2>&1

# --- Bulletproof Firewall & NAT Routing ---
sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

if command -v ufw >/dev/null 2>&1; then
    sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    ufw reload >/dev/null 2>&1
fi

ETH=$(ip -4 route ls | grep default | awk '{print $5}' | head -1)

# Allow traffic in and out of the VPN tunnel
iptables -I FORWARD 1 -i tun+ -j ACCEPT
iptables -I FORWARD 1 -o tun+ -j ACCEPT
iptables -I FORWARD 1 -s 10.8.0.0/24 -j ACCEPT

# Masquerade (hide) the VPN traffic globally (allows WARP bridging)
if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null; then
    iptables -t nat -I POSTROUTING 1 -s 10.8.0.0/24 -j MASQUERADE
fi

netfilter-persistent save > /dev/null 2>&1
systemctl restart openvpn-server@server
systemctl enable openvpn-server@server > /dev/null 2>&1
echo -e "\n[OK] OPENVPN CORE DEPLOYED SUCCESSFULLY."