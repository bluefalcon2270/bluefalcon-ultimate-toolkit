# ==============================================================================
# --- MODULE 2: WARP Routing Utility ---
# ==============================================================================
WGCF_conf="/etc/wireguard/wgcf.conf"
Profile_conf="/etc/warp/wgcf-profile.conf"
Wgcf_account="/etc/warp/wgcf-account.toml"
CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

install_warp() {
    local target=$1
    local license=${2:-free}
    echo ""
    
    export TARGET="$target"
    export LICENSE="$license"
    source "${SCRIPT_DIR}/core/warp/action.sh"
    
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing Prerequisites" install_warp_prereqs
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Installing WGCF Binary" install_wgcf
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Registering Profile" register_account
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Building Configuration" build_config
    
    if ip link show wgcf >/dev/null 2>&1; then
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
    
    source "${SCRIPT_DIR}/core/warp/action.sh"
    CURRENT_LOG="${WARP_LOG}" run_with_spinner "Toggling WARP" toggle_warp    
    if ip link show wgcf >/dev/null 2>&1; then
        echo -e "[ ${GREEN}✔${NC} ] WARP Service Started."
    else
        echo -e "[ ${RED}✖${NC} ] WARP Service Stopped."
    fi
    sleep 2
}

uninstall_warp() {
    echo ""
    if [ -f "/etc/wireguard/wgcf.conf" ] || command -v wgcf >/dev/null 2>&1; then
        source "${SCRIPT_DIR}/core/warp/action.sh"
        CURRENT_LOG="${WARP_LOG}" run_with_spinner "Uninstalling WARP" uninstall_warp
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
    echo -e "${BOLD_BLUE}              Cloudflare WARP (${BF_VERSION})              ${NC}"
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
                if [[ "$t" =~ ^[1-3]$ ]]; then install_warp "$t" "free"; fi ;;
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
                        install_warp "$t" "$k"
                    fi
                fi ;;
            3) toggle_warp_service ;;
            4) uninstall_warp ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}