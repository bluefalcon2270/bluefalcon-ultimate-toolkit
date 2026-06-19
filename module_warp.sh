#!/usr/bin/env bash
# module_warp.sh
# Cloudflare WARP Routing Engine

export WGCF_conf="/etc/wireguard/wgcf.conf"
export Profile_conf="/etc/warp/wgcf-profile.conf"
export Wgcf_account="/etc/warp/wgcf-account.toml"
export CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

# ==============================================================================
# 1. Backend Logic
# ==============================================================================

backend_install() {
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a >> "${WARP_LOG}" 2>&1 || true
    apt-get update -y >> "${WARP_LOG}" 2>&1
    apt-get install -y curl gnupg lsb-release ca-certificates >> "${WARP_LOG}" 2>&1

    if ! command -v wgcf >/dev/null 2>&1; then
        curl -fsSL git.io/wgcf.sh -o /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
        bash /tmp/wgcf.sh >> "${WARP_LOG}" 2>&1
    fi

    if ! command -v warp-cli >/dev/null 2>&1; then
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg >> "${WARP_LOG}" 2>&1
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
        apt-get update -y >> "${WARP_LOG}" 2>&1
        local dns_pkg="resolvconf"
        if apt-cache show openresolv >/dev/null 2>&1; then dns_pkg="openresolv"; fi
        apt-get install cloudflare-warp iproute2 "${dns_pkg}" wireguard-tools -y >> "${WARP_LOG}" 2>&1
    fi

    mkdir -p /etc/warp
    cd /etc/warp || exit
    if [[ ! -f "$Wgcf_account" ]]; then
        wgcf register --accept-tos >> "${WARP_LOG}" 2>&1
    fi

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

    local IPv4_addr=$(hostname -I | awk '{print $1}')
    local IPv6_addr=$(hostname -I | awk '{ for(i=1;i<=NF;i++) if($i~/^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$/) {print $i; exit} }')

    # Defaulting to Dual-Stack Routing
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

    (crontab -l 2>/dev/null | grep -v "wg-quick@wgcf"; echo "0 4 * * * systemctl restart wg-quick@wgcf;systemctl restart warp-svc") | crontab -
    systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
}

backend_toggle() {
    if [ ! -f "/etc/wireguard/wgcf.conf" ]; then exit 1; fi
    if ip link show wgcf >/dev/null 2>&1; then
        systemctl disable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        wg-quick down wgcf >> "${WARP_LOG}" 2>&1
        ip link delete wgcf >/dev/null 2>&1
    else
        wg-quick down wgcf >/dev/null 2>&1
        systemctl enable --now wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        if ! ip link show wgcf >/dev/null 2>&1; then wg-quick up wgcf >> "${WARP_LOG}" 2>&1; fi
    fi
}

backend_uninstall() {
    if [ -f "/etc/wireguard/wgcf.conf" ] || command -v wgcf >/dev/null 2>&1; then
        systemctl stop wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        systemctl disable wg-quick@wgcf >> "${WARP_LOG}" 2>&1
        export DEBIAN_FRONTEND=noninteractive
        apt-get purge cloudflare-warp -y >> "${WARP_LOG}" 2>&1
        rm -rf /etc/warp /etc/wireguard/wgcf* /usr/local/bin/wgcf
        ip link delete wgcf >/dev/null 2>&1
    fi
}

# ==============================================================================
# 2. UI Switchboard (Interactive Menu)
# ==============================================================================

draw_warp_dashboard() {
    local VPS_IPv4_Int=$(hostname -I | awk '{print $1}')
    [ -z "$VPS_IPv4_Int" ] && VPS_IPv4_Int="N/A"
    
    local VPS_IPv6_Int=$(hostname -I | awk '{ for(i=1;i<=NF;i++) if($i~/^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$/) {print $i; exit} }')
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
    echo -e "${BOLD_BLUE}                   Cloudflare WARP                   ${NC}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
    echo -e " VPS  (IPv4) : ${v4_vps_out}"
    echo -e " WARP (IPv4) : ${v4_warp_out}\n"
    echo -e " VPS  (IPv6) : ${v6_vps_out}"
    echo -e " WARP (IPv6) : ${v6_warp_out}"
    echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
}

manage_warp_menu() {
    while true; do
        clear
        draw_warp_dashboard
        echo ""
        echo "1. Install WARP (Free Dual-Stack)"
        echo "2. Toggle WARP On/Off"
        echo "3. Uninstall WARP"
        echo "4. View WARP Debug Logs"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " choice
        case "$choice" in
            1)
                if [ -n "${run_with_spinner:-}" ]; then
                    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing Cloudflare WARP Engine" backend_install
                else
                    backend_install
                fi
                if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi
                ;;
            2)
                if [ -n "${run_with_spinner:-}" ]; then
                    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Toggling Cloudflare WARP Service" backend_toggle
                else
                    backend_toggle
                fi
                if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi
                ;;
            3) 
                if [ -n "${run_with_spinner:-}" ]; then
                    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Uninstalling Cloudflare WARP Engine" backend_uninstall
                else
                    backend_uninstall
                fi
                if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi
                ;;
            4) 
                clear
                echo -e "${BOLD_BLUE}                   WARP Debug Logs                   ${NC}"
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

action="${1:-menu}"
case "$action" in
    --install) backend_install ;;
    --toggle) backend_toggle ;;
    --uninstall) backend_uninstall ;;
    menu) manage_warp_menu ;;
esac