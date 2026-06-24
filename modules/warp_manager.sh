# ==============================================================================
# --- MODULE 2: WARP Routing Utility ---
# ==============================================================================
WGCF_conf="/etc/wireguard/wgcf.conf"
Profile_conf="/etc/warp/wgcf-profile.conf"
Wgcf_account="/etc/warp/wgcf-account.toml"
CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

install_warp_prereqs() {
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a >> "${WARP_LOG}" 2>&1 || true
    apt-get update -y >> "${WARP_LOG}" 2>&1
    apt-get install -y curl gnupg lsb-release ca-certificates >> "${WARP_LOG}" 2>&1
}

install_wgcf() {
    if command -v wgcf >/dev/null 2>&1; then return 0; fi
    curl -fsSL git.io/wgcf.sh -o /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing WGCF Binary" bash /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
}

install_cloudflare_packages() {
    if command -v warp-cli >/dev/null 2>&1; then return 0; fi
    export DEBIAN_FRONTEND=noninteractive
    . /etc/os-release
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg >> "${WARP_LOG}" 2>&1
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
    apt-get update -y >> "${WARP_LOG}" 2>&1
    
    # Bulletproof check: Simulate installation to see if openresolv actually exists
    local dns_pkg="resolvconf"
    if apt-get install -s openresolv >/dev/null 2>&1; then 
        dns_pkg="openresolv"
    fi
    
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing Cloudflare Packages" apt-get install cloudflare-warp iproute2 "${dns_pkg}" wireguard-tools -y >> "${WARP_LOG}" 2>&1
}

register_account() {
    mkdir -p /etc/warp
    cd /etc/warp || exit
    if [[ -f "$Wgcf_account" ]]; then return 0; fi
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Registering Free Account" wgcf register --accept-tos >> "${WARP_LOG}" 2>&1
}

build_config() {
    cd /etc/warp || exit
    wgcf generate >> "${WARP_LOG}" 2>&1
    [ -d "/etc/wireguard" ] || mkdir -p "/etc/wireguard"
    
    local PrivateKey=$(grep ^PrivateKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local Address=$(grep ^Address "${Profile_conf}" | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    local PublicKey=$(grep ^PublicKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local MTU=1280
    
    cat <<EOF >${WGCF_conf}
[Interface]
PrivateKey = ${PrivateKey}
Address = ${Address}
DNS = 8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844
MTU = ${MTU}
EOF

    local DEFAULT_IF=$(ip route | awk '/default/ {print $5}' | head -1)
    local IPv4_addr=$(ip -4 addr show "$DEFAULT_IF" | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
    local IPv6_addr=$(ip -6 addr show "$DEFAULT_IF" | awk '/inet6 / {print $2}' | cut -d/ -f1 | grep -v '^fe80' | head -1)

    case $1 in
        1)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = 0.0.0.0/0
Endpoint = 162.159.192.1:2408
EOF
            ;;
        2)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = ::/0
Endpoint = [2606:4700:d0::a29f:c001]:2408
EOF
            ;;
        3)
            cat <<EOF >>${WGCF_conf}
PreUp = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PreUp = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = 0.0.0.0/0,::/0
Endpoint = engage.cloudflareclient.com:2408
EOF
            ;;
    esac
}

execute_warp_install() {
    local target=$1
    echo ""
    install_warp_prereqs
    install_wgcf
    if ! install_cloudflare_packages; then
        echo -e "\n[ ${RED}✖${NC} ] Critical failure during package installation. Aborting."
        sleep 3
        return
    fi
    register_account
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Building wgcf.conf" build_config "$target"
    (crontab -l 2>/dev/null | grep -v "wg-quick@wgcf"; echo "0 4 * * * systemctl restart wg-quick@wgcf;systemctl restart warp-svc") | crontab -
    
    if CURRENT_LOG="${WARP_LOG}" run_with_spinner "Enabling WireGuard Service" systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1; then
        echo -e "\n[ ${GREEN}✔${NC} ] WARP Installation Completed Successfully!"
    else
        echo -e "\n[ ${RED}✖${NC} ] Failed to start WireGuard. Check 'View WARP Logs'."
    fi
    sleep 3
}

toggle_warp_service() {
    echo ""
    if [ ! -f "/etc/wireguard/wgcf.conf" ]; then 
        echo -e "[ ${RED}✖${NC} ] WARP is not installed."
        sleep 2; return
    fi
    
    if ip link show wgcf >/dev/null 2>&1; then
        systemctl disable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        wg-quick down wgcf >> "${WARP_LOG}" 2>&1
        ip link delete wgcf >/dev/null 2>&1
        echo -e "[ ${RED}✖${NC} ] WARP Service Stopped."
    else
        wg-quick down wgcf >/dev/null 2>&1
        systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        if ! ip link show wgcf >/dev/null 2>&1; then wg-quick up wgcf >> "${WARP_LOG}" 2>&1; fi
        echo -e "[ ${GREEN}✔${NC} ] WARP Service Started."
    fi
    sleep 2
}

uninstall_warp() {
    echo ""
    if [ -f "/etc/wireguard/wgcf.conf" ] || command -v wgcf >/dev/null 2>&1; then
        systemctl stop wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        systemctl disable wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        export DEBIAN_FRONTEND=noninteractive
        CURRENT_LOG="${WARP_LOG}" run_with_spinner "Purging Packages" apt-get purge cloudflare-warp -y >> "${WARP_LOG}" 2>&1
        rm -rf /etc/warp /etc/wireguard/wgcf* /usr/local/bin/wgcf
        ip link delete wgcf >/dev/null 2>&1
        echo -e "\n[ ${GREEN}✔${NC} ] WARP Uninstalled."
    else
        echo -e "[ ${RED}✖${NC} ] WARP is not installed."
    fi
    pause_execution
}

draw_warp_dashboard() {
    local DEFAULT_IF=$(ip route | awk '/default/ {print $5}' | head -1)
    local VPS_IPv4_Int=$(ip -4 addr show "$DEFAULT_IF" | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
    [ -z "$VPS_IPv4_Int" ] && VPS_IPv4_Int="N/A"
    
    local VPS_IPv6_Int=$(ip -6 addr show "$DEFAULT_IF" | awk '/inet6 / {print $2}' | cut -d/ -f1 | grep -v '^fe80' | head -1)
    [ -z "$VPS_IPv6_Int" ] && VPS_IPv6_Int="N/A"

    local WARP_IPv4_Status=$(curl -s4 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2 || echo "off")
    local WARP_IPv4_IP=$(curl -s4 ${CF_Trace_URL} --connect-timeout 2 | grep ip | cut -d= -f2 || echo "------------")
    local WARP_IPv6_Status=$(curl -s6 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2 || echo "off")
    local WARP_IPv6_IP=$(curl -s6 ${CF_Trace_URL} --connect-timeout 2 | grep ip | cut -d= -f2 || echo "------------")

    local active_tag="  ${GREEN}(🟢 Active)${NC}"
    local v4_vps_out v4_warp_out v6_vps_out v6_warp_out

    if [[ ${WARP_IPv4_Status} == "on" || ${WARP_IPv4_Status} == "plus" ]]; then
        v4_vps_out="${YELLOW}${VPS_IPv4_Int}${NC}"
        v4_warp_out="${GREEN}${WARP_IPv4_IP}${NC}${active_tag}"
    else
        v4_vps_out="${GREEN}${VPS_IPv4_Int}${NC}${active_tag}"
        v4_warp_out="${RED}------------${NC}"
    fi

    if [[ ${WARP_IPv6_Status} == "on" || ${WARP_IPv6_Status} == "plus" ]]; then
        v6_vps_out="${YELLOW}${VPS_IPv6_Int}${NC}"
        v6_warp_out="${GREEN}${WARP_IPv6_IP}${NC}${active_tag}"
    else
        v6_vps_out="${GREEN}${VPS_IPv6_Int}${NC}${active_tag}"
        v6_warp_out="${RED}------------${NC}"
    fi

    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e "${BOLD_BLUE}                    Cloudflare WARP                  ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e " VPS  (IPv4) : ${v4_vps_out}"
    echo -e " WARP (IPv4) : ${v4_warp_out}\n"
    echo -e " VPS  (IPv6) : ${v6_vps_out}"
    echo -e " WARP (IPv6) : ${v6_warp_out}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
}

manage_warp() {
    while true; do
        clear
        draw_warp_dashboard
        echo ""
        echo "1. Install WARP (Free)"
        echo "2. Install WARP+ (Key)"
        echo "3. Toggle WARP On/Off"
        echo "4. Uninstall WARP"
        echo "5. View WARP Logs"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " choice
        case "$choice" in
            1)
                echo -e "\nTarget: "
                echo -e "1- IPv4 "
                echo -e "2- IPv6"
                echo -e "3- IPv4 & IPv6 (Both)\n"
                read -rp "Select option: " t
                if [[ "$t" =~ ^[1-3]$ ]]; then execute_warp_install "$t"; fi ;;
            2)
                echo ""
                read -rp "Enter WARP+ Key: " k
                if [ -n "$k" ]; then
                    echo -e "\nTarget: "
                    echo -e "1- IPv4 "
                    echo -e "2- IPv6"
                    echo -e "3- IPv4 & IPv6 (Both)\n"
                    read -rp "Select option: " t
                    if [[ "$t" =~ ^[1-3]$ ]]; then
                        install_warp_prereqs
                        install_wgcf
                        if install_cloudflare_packages; then
                            register_account
                            sed -i "s/\(license_key = \).*/\1'${k}'/" "/etc/warp/wgcf-account.toml"
                            CURRENT_LOG="${WARP_LOG}" run_with_spinner "Applying WARP+ License" wgcf update --config /etc/warp/wgcf-account.toml
                            execute_warp_install "$t"
                        fi
                    fi
                fi ;;
            3) toggle_warp_service ;;
            4) uninstall_warp ;;
            5) 
                clear
                echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
                echo -e "${BOLD_BLUE}                    WARP Debug Logs                  ${NC}"
                echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
                echo -e "Streaming last 50 lines. Press Ctrl+C to exit.\n"
                trap 'true' SIGINT
                tail -n 50 -f "${WARP_LOG}"
                trap cleanup SIGINT SIGTERM
                ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}