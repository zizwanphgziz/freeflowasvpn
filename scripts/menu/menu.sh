#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Premium Menu System
# Styled after JinGGo VPN — compact, two-column, premium look
# ============================================================

if [[ -d "/usr/local/lib/freeflow/scripts" ]]; then
    SCRIPT_BASE="/usr/local/lib/freeflow/scripts"
else
    SCRIPT_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

source "${SCRIPT_BASE}/core/common.sh"

# --- Separator line ---
L="${CYAN}══════════════════════════════════════════════════════${NC}"

# --- Count users ---
count_users() {
    local count=0
    for f in "${USER_DB}/$1/active/"*; do
        [[ -f "${f}" ]] && count=$((count + 1))
    done
    echo "${count}"
}

# --- Service status helper ---
svc_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "${GREEN}ON${NC}"
    else
        echo -e "${RED}OFF${NC}"
    fi
}

# =============================================
#  MAIN MENU
# =============================================

main_menu() {
    while true; do
        clear
        local domain ip xray_ver kernel_ver cert_expiry
        domain=$(get_domain)
        ip=$(get_server_ip)
        xray_ver=$(xray version 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        kernel_ver=$(uname -r)
        detect_os

        local ssh_c xray_c
        ssh_c=$(count_users "ssh")
        xray_c=$(( $(count_users "vless") + $(count_users "vmess") + $(count_users "trojan") ))

        if [[ -f /etc/xray/xray.crt ]]; then
            cert_expiry=$(openssl x509 -enddate -noout -in /etc/xray/xray.crt 2>/dev/null | cut -d= -f2)
        else
            cert_expiry="No Certificate"
        fi

        echo -e "$L"
        echo -e "    ${BOLD}${WHITE}FreeFlow Auto Script VPN — Premium${NC}"
        echo -e "     ${PURPLE}github.com/zizwanphgziz/freeflowasvpn${NC}"
        echo -e "$L"
        echo -e " OS VERSION          : ${WHITE}${OS_PRETTY}${NC}"
        echo -e " KERNEL VERSION      : ${WHITE}${kernel_ver}${NC}"
        echo -e " XRAY CORE VERSION   : ${WHITE}${xray_ver}${NC}"
        echo -e " EXP DATE CERT XRAY  : ${WHITE}${cert_expiry}${NC}"
        echo -e "$L"
        echo -e "    TOTAL SSH : ${GREEN}[${ssh_c}]${NC}    TOTAL XRAY : ${GREEN}[${xray_c}]${NC}"
        echo -e "$L"
        echo -e "            ${BOLD}${YELLOW}↙ VPN MENU ↘${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} MENU SSH              ${GREEN}[ 02 ]${NC} MENU XRAY VLESS"
        echo -e " ${GREEN}[ 03 ]${NC} MENU XRAY VMESS       ${GREEN}[ 04 ]${NC} MENU XRAY TROJAN"
        echo -e "$L"
        echo -e "            ${BOLD}${YELLOW}↙ SYSTEM MENU ↘${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 05 ]${NC} ADD/CHANGE DOMAIN      ${GREEN}[ 11 ]${NC} SPEEDTEST VPS"
        echo -e " ${GREEN}[ 06 ]${NC} CHANGE DNS SERVER      ${GREEN}[ 12 ]${NC} STREAM GEO LOCATION"
        echo -e " ${GREEN}[ 07 ]${NC} RESTART ALL SERVICE    ${GREEN}[ 13 ]${NC} SERVICE/PORT INFO"
        echo -e " ${GREEN}[ 08 ]${NC} CHECK RAM USAGE        ${GREEN}[ 14 ]${NC} SERVICE STATUS"
        echo -e " ${GREEN}[ 09 ]${NC} REBOOT VPS             ${GREEN}[ 15 ]${NC} SOCKS WARP"
        echo -e " ${GREEN}[ 10 ]${NC} UPDATE SCRIPT          ${GREEN}[ 16 ]${NC} ADS BLOCKER"
        echo -e "                                ${GREEN}[ 17 ]${NC} DIAGNOSE CONNECTION"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT MENU"
        echo -e "$L"
        echo -e "$L"
        echo -e " SCRIPT VERSION : ${WHITE}FREEFLOW v$(get_installed_version)${NC}"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        case "${opt}" in
            01|1) menu_ssh ;;
            02|2) menu_vless ;;
            03|3) menu_vmess ;;
            04|4) menu_trojan ;;
            05|5) change_domain ;;
            06|6) source "${SCRIPT_BASE}/tools/dns_changer.sh"; change_dns ;;
            07|7) restart_all_services ;;
            08|8) source "${SCRIPT_BASE}/tools/ram_monitor.sh"; show_ram_usage ;;
            09|9) reboot_vps ;;
            10) source "${SCRIPT_BASE}/update/auto_update.sh"; check_update; [[ $? -eq 2 ]] && confirm "Update now?" && do_update ;;
            11) run_speedtest ;;
            12) source "${SCRIPT_BASE}/tools/netflix_checker.sh"; check_netflix_region ;;
            13) service_port_info ;;
            14) service_status ;;
            15) menu_warp ;;
            16) menu_ads ;;
            17) source "${SCRIPT_BASE}/core/diagnose.sh" ;;
            00|0) echo -e "\n ${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *) msg_warn "Invalid option" ;;
        esac

        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  SSH MENU
# =============================================

menu_ssh() {
    while true; do
        clear
        local ssh_st sshws_st user_c
        ssh_st=$(svc_status sshd)
        sshws_st=$(if [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]]; then svc_status ssh-ws; else echo -e "${RED}OFF${NC}"; fi)
        user_c=$(count_users "ssh")

        echo -e "$L"
        echo -e "              ${BOLD}${YELLOW}↙ MENU SSH ↘${NC}"
        echo -e "$L"
        echo -e " SSH : ${ssh_st}   SSHWS : ${sshws_st}   TOTAL USER : ${WHITE}${user_c}${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} CREATE NEW USER        ${GREEN}[ 06 ]${NC} LIST USER INFORMATION"
        echo -e " ${GREEN}[ 02 ]${NC} CREATE TRIAL USER      ${GREEN}[ 07 ]${NC} SET AUTO KILL LOGIN"
        echo -e " ${GREEN}[ 03 ]${NC} EXTEND ACCOUNT ACTIVE  ${GREEN}[ 08 ]${NC} DISPLAY USER MULTILOGIN"
        echo -e " ${GREEN}[ 04 ]${NC} DELETE ACTIVE USER     ${GREEN}[ 09 ]${NC} INSTALL SSHWS"
        echo -e " ${GREEN}[ 05 ]${NC} CHECK USER LOGIN"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT TO MENU"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        case "${opt}" in
            01|1) ssh_add_user ;;
            02|2) ssh_trial_user ;;
            03|3) ssh_renew_user ;;
            04|4) ssh_delete_user ;;
            05|5) ssh_check_login ;;
            06|6) ssh_list_users ;;
            07|7) ssh_auto_kill ;;
            08|8) ssh_multilogin ;;
            09|9) ssh_ws_toggle ;;
            00|0) return ;;
            *) msg_warn "Invalid option" ;;
        esac
        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  VLESS MENU
# =============================================

menu_vless() {
    while true; do
        clear
        local xray_st xray_none xray_xhttp user_c
        xray_st=$(svc_status xray)
        xray_none=$([[ -f /etc/xray/config.json ]] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
        xray_xhttp=$([[ -f /etc/xray/config.json ]] && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
        user_c=$(count_users "vless")

        echo -e "$L"
        echo -e "           ${BOLD}${YELLOW}↙ MENU XRAY VLESS ↘${NC}"
        echo -e "$L"
        echo -e " XRAY : ${xray_st}   XRAY NONE : ${xray_none}   XRAY XHTTP : ${xray_xhttp}   TOTAL USER : ${WHITE}${user_c}${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} CREATE NEW USER        ${GREEN}[ 05 ]${NC} CHECK USER LOGIN"
        echo -e " ${GREEN}[ 02 ]${NC} CREATE TRIAL USER      ${GREEN}[ 06 ]${NC} LIST USER"
        echo -e " ${GREEN}[ 03 ]${NC} EXTEND ACCOUNT ACTIVE  ${GREEN}[ 07 ]${NC} RENEW XRAY CERTIFICATION"
        echo -e " ${GREEN}[ 04 ]${NC} DELETE ACTIVE USER     ${GREEN}[ 08 ]${NC} CHANGE PORT XRAY"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT TO MENU"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        source "${SCRIPT_BASE}/user/manage_user.sh"
        case "${opt}" in
            01|1) add_vless_user ;;
            02|2) create_trial_account "vless" ;;
            03|3) renew_vless_user ;;
            04|4) delete_vless_user ;;
            05|5) check_login_users ;;
            06|6) list_protocol_active "vless" ;;
            07|7) renew_ssl ;;
            08|8) change_xray_port ;;
            00|0) return ;;
            *) msg_warn "Invalid option" ;;
        esac
        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  VMESS MENU
# =============================================

menu_vmess() {
    while true; do
        clear
        local xray_st user_c
        xray_st=$(svc_status xray)
        user_c=$(count_users "vmess")

        echo -e "$L"
        echo -e "           ${BOLD}${YELLOW}↙ MENU XRAY VMESS ↘${NC}"
        echo -e "$L"
        echo -e " XRAY : ${xray_st}   TOTAL USER : ${WHITE}${user_c}${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} CREATE NEW USER        ${GREEN}[ 05 ]${NC} CHECK USER LOGIN"
        echo -e " ${GREEN}[ 02 ]${NC} CREATE TRIAL USER      ${GREEN}[ 06 ]${NC} LIST USER"
        echo -e " ${GREEN}[ 03 ]${NC} EXTEND ACCOUNT ACTIVE  ${GREEN}[ 07 ]${NC} RENEW XRAY CERTIFICATION"
        echo -e " ${GREEN}[ 04 ]${NC} DELETE ACTIVE USER     ${GREEN}[ 08 ]${NC} USER DATA USAGE"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT TO MENU"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        source "${SCRIPT_BASE}/user/manage_user.sh"
        case "${opt}" in
            01|1) add_vmess_user ;;
            02|2) create_trial_account "vmess" ;;
            03|3) renew_vmess_user ;;
            04|4) delete_vmess_user ;;
            05|5) check_login_users ;;
            06|6) list_protocol_active "vmess" ;;
            07|7) renew_ssl ;;
            08|8) source "${SCRIPT_BASE}/user/usage_tracker.sh"; show_usage ;;
            00|0) return ;;
            *) msg_warn "Invalid option" ;;
        esac
        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  TROJAN MENU
# =============================================

menu_trojan() {
    while true; do
        clear
        local xray_st user_c
        xray_st=$(svc_status xray)
        user_c=$(count_users "trojan")

        echo -e "$L"
        echo -e "          ${BOLD}${YELLOW}↙ MENU XRAY TROJAN ↘${NC}"
        echo -e "$L"
        echo -e " XRAY : ${xray_st}   TOTAL USER : ${WHITE}${user_c}${NC}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} CREATE NEW USER        ${GREEN}[ 05 ]${NC} CHECK USER LOGIN"
        echo -e " ${GREEN}[ 02 ]${NC} CREATE TRIAL USER      ${GREEN}[ 06 ]${NC} LIST USER"
        echo -e " ${GREEN}[ 03 ]${NC} EXTEND ACCOUNT ACTIVE  ${GREEN}[ 07 ]${NC} RENEW XRAY CERTIFICATION"
        echo -e " ${GREEN}[ 04 ]${NC} DELETE ACTIVE USER     ${GREEN}[ 08 ]${NC} USER DATA USAGE"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT TO MENU"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        source "${SCRIPT_BASE}/user/manage_user.sh"
        case "${opt}" in
            01|1) add_trojan_user ;;
            02|2) create_trial_account "trojan" ;;
            03|3) renew_trojan_user ;;
            04|4) delete_trojan_user ;;
            05|5) check_login_users ;;
            06|6) list_protocol_active "trojan" ;;
            07|7) renew_ssl ;;
            08|8) source "${SCRIPT_BASE}/user/usage_tracker.sh"; show_usage ;;
            00|0) return ;;
            *) msg_warn "Invalid option" ;;
        esac
        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  WARP MENU
# =============================================

menu_warp() {
    while true; do
        clear
        local warp_st
        if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
            warp_st="${GREEN}ON${NC}"
        else
            warp_st="${RED}OFF${NC}"
        fi

        echo -e "$L"
        echo -e "           ${BOLD}${YELLOW}↙ SOCKS WARP MENU ↘${NC}"
        echo -e "$L"
        echo -e " WARP SOCKS STATUS : ${warp_st}"
        echo -e "$L"
        echo -e " ${GREEN}[ 01 ]${NC} INSTALL SOCKS WARP"
        echo -e " ${GREEN}[ 02 ]${NC} LIST DOMAIN"
        echo -e " ${GREEN}[ 03 ]${NC} ADD DOMAIN"
        echo -e " ${GREEN}[ 04 ]${NC} DELETE DOMAIN"
        echo -e " ${GREEN}[ 05 ]${NC} UNINSTALL SOCKS WARP"
        echo -e "$L"
        echo -e " ${RED}[  0 ]${NC} EXIT TO MENU"
        echo -e "$L"
        echo ""
        read -rp "    Please select an option : " opt

        source "${SCRIPT_BASE}/warp/install_warp.sh"
        case "${opt}" in
            01|1) install_warp ;;
            02|2) list_warp_routes ;;
            03|3) add_warp_route ;;
            04|4) delete_warp_route ;;
            05|5) uninstall_warp ;;
            00|0) return ;;
            *) msg_warn "Invalid option" ;;
        esac
        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  ADS BLOCKER MENU
# =============================================

menu_ads() {
    if [[ -f "${CONFIG_DIR}/modules/ads_blocker_installed" ]]; then
        echo -e "  Ads Blocker is ${GREEN}active${NC}"
        echo -e "  ${GREEN}1${NC}. Update blocklist"
        echo -e "  ${GREEN}2${NC}. Uninstall"
        echo -e "  ${GREEN}0${NC}. Back"
        echo ""
        read -rp " Choose: " choice
        case "${choice}" in
            1) source "${SCRIPT_BASE}/tools/ads_blocker.sh"; update_ads_blocker ;;
            2) source "${SCRIPT_BASE}/tools/ads_blocker.sh"; uninstall_ads_blocker ;;
            0) return ;;
        esac
    else
        echo -e "  Ads Blocker is ${RED}not installed${NC}"
        if confirm "Install Ads Blocker?"; then
            source "${SCRIPT_BASE}/tools/ads_blocker.sh"
            install_ads_blocker
        fi
    fi
}

# =============================================
#  SYSTEM HELPERS
# =============================================

ssh_add_user() {
    echo -e "$L"
    echo -e " ${BOLD}CREATE SSH USER${NC}"
    echo -e "$L"
    read -rp " Username: " username
    [[ -z "${username}" ]] && { msg_fail "Empty username"; return; }
    read -rp " Password: " password
    [[ -z "${password}" ]] && { msg_fail "Empty password"; return; }
    read -rp " Validity in days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")

    useradd -M -s /bin/false -e "${expiry}" "${username}" 2>/dev/null
    echo "${username}:${password}" | chpasswd

    cat > "${USER_DB}/ssh/active/${username}" <<EOF
USERNAME=${username}
CREATED=$(date +"%Y-%m-%d")
EXPIRY=${expiry}
STATUS=active
EOF

    msg_ok "SSH user '${username}' created (expires: ${expiry})"
}

ssh_trial_user() {
    echo -e "$L"
    echo -e " ${BOLD}CREATE TRIAL SSH USER${NC}"
    echo -e "$L"
    local username="trial-$(date +%s | tail -c 5)"
    local password="trial$(shuf -i 1000-9999 -n1)"
    local expiry
    expiry=$(get_expiry_date "1")
    useradd -M -s /bin/false -e "${expiry}" "${username}" 2>/dev/null
    echo "${username}:${password}" | chpasswd
    cat > "${USER_DB}/ssh/active/${username}" <<EOF
USERNAME=${username}
CREATED=$(date +"%Y-%m-%d")
EXPIRY=${expiry}
STATUS=active
EOF
    msg_ok "Trial SSH user created"
    echo -e " Username : ${GREEN}${username}${NC}"
    echo -e " Password : ${GREEN}${password}${NC}"
    echo -e " Expires  : ${YELLOW}${expiry}${NC}"
}

ssh_delete_user() {
    echo -e "$L"
    echo -e " ${BOLD}DELETE SSH USER${NC}"
    echo -e "$L"
    read -rp " Username: " username
    [[ -z "${username}" ]] && { msg_fail "Empty username"; return; }
    userdel -f "${username}" 2>/dev/null
    rm -f "${USER_DB}/ssh/active/${username}" "${USER_DB}/ssh/expired/${username}"
    msg_ok "SSH user '${username}' deleted"
}

ssh_list_users() {
    echo -e "$L"
    echo -e " ${BOLD}SSH USER LIST${NC}"
    echo -e "$L"
    local count=0
    for f in "${USER_DB}/ssh/active/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        echo -e " ${GREEN}${count}${NC}. ${uname} — expires: ${expiry}"
    done
    [[ "${count}" -eq 0 ]] && echo -e " ${YELLOW}No SSH users${NC}"
}

ssh_renew_user() {
    echo -e "$L"
    echo -e " ${BOLD}EXTEND SSH ACCOUNT${NC}"
    echo -e "$L"
    read -rp " Username: " username
    [[ -z "${username}" ]] && { msg_fail "Empty username"; return; }
    read -rp " Extend by days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")
    usermod -e "${expiry}" "${username}" 2>/dev/null
    [[ -f "${USER_DB}/ssh/active/${username}" ]] && sed -i "s/^EXPIRY=.*/EXPIRY=${expiry}/" "${USER_DB}/ssh/active/${username}"
    msg_ok "SSH user '${username}' extended to ${expiry}"
}

ssh_check_login() {
    echo -e "$L"
    echo -e " ${BOLD}SSH LOGGED IN USERS${NC}"
    echo -e "$L"
    who 2>/dev/null || echo -e " ${YELLOW}No users logged in${NC}"
}

ssh_auto_kill() {
    echo -e "$L"
    echo -e " ${BOLD}AUTO KILL MULTI-LOGIN${NC}"
    echo -e "$L"
    echo -e " ${GREEN}1${NC}. Enable (max 2 sessions per user)"
    echo -e " ${GREEN}2${NC}. Disable"
    echo ""
    read -rp " Choose: " c
    case "${c}" in
        1) msg_ok "Auto-kill enabled (feature placeholder)" ;;
        2) msg_ok "Auto-kill disabled" ;;
    esac
}

ssh_multilogin() {
    echo -e "$L"
    echo -e " ${BOLD}MULTI-LOGIN CHECK${NC}"
    echo -e "$L"
    who | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
}

ssh_ws_toggle() {
    if [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]]; then
        echo -e "  SSH WebSocket is ${GREEN}installed${NC}"
        if confirm "Uninstall SSH WebSocket?"; then
            source "${SCRIPT_BASE}/ssh/install_ssh_ws.sh"
            uninstall_ssh_ws
        fi
    else
        echo -e "  SSH WebSocket is ${RED}not installed${NC}"
        if confirm "Install SSH WebSocket?"; then
            source "${SCRIPT_BASE}/ssh/install_ssh_ws.sh"
            install_ssh_ws
        fi
    fi
}

change_xray_port() {
    echo -e "$L"
    echo -e " ${BOLD}CHANGE XRAY PORT${NC}"
    echo -e "$L"
    echo -e " Current ports:"
    echo -e "  443   : VLESS XTLS Reality"
    echo -e "  80    : Non-TLS"
    echo -e "  8443  : TLS"
    msg_info "Port changes require manual config edit for now"
}

restart_all_services() {
    echo -e "$L"
    echo -e " ${BOLD}RESTARTING ALL SERVICES${NC}"
    echo -e "$L"
    restart_service xray
    restart_service nginx
    [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]] && restart_service ssh-ws
    msg_ok "All services restarted"
}

run_speedtest() {
    echo -e "$L"
    echo -e " ${BOLD}SPEEDTEST VPS${NC}"
    echo -e "$L"
    if command -v speedtest &>/dev/null; then
        speedtest --accept-license
    elif command -v speedtest-cli &>/dev/null; then
        speedtest-cli
    else
        msg_info "Installing speedtest..."
        apt-get install -y speedtest-cli > /dev/null 2>&1
        speedtest-cli 2>/dev/null || msg_fail "Speedtest not available"
    fi
}

change_domain() {
    echo -e "$L"
    echo -e " ${BOLD}ADD/CHANGE DOMAIN VPS${NC}"
    echo -e "$L"
    local old_domain
    old_domain=$(get_domain)
    msg_info "Current domain: ${old_domain:-Not set}"
    read -rp " New domain: " new_domain
    [[ -z "${new_domain}" ]] && { msg_fail "Empty domain"; return; }
    echo "${new_domain}" > "${CONFIG_DIR}/domain"
    source "${SCRIPT_BASE}/nginx/install_nginx.sh"
    setup_ssl_certificate
    generate_nginx_config
    restart_service xray
    msg_ok "Domain changed to ${new_domain}"
}

renew_ssl() {
    echo -e "$L"
    echo -e " ${BOLD}RENEW XRAY CERTIFICATION${NC}"
    echo -e "$L"
    local domain
    domain=$(get_domain)
    certbot renew --quiet
    cp "/etc/letsencrypt/live/${domain}/fullchain.pem" /etc/xray/xray.crt 2>/dev/null
    cp "/etc/letsencrypt/live/${domain}/privkey.pem" /etc/xray/xray.key 2>/dev/null
    restart_service nginx
    msg_ok "SSL certificate renewed"
}

reboot_vps() {
    if confirm "Reboot VPS now?"; then
        msg_ok "Rebooting..."
        sleep 2
        reboot
    fi
}

service_status() {
    clear
    echo -e "$L"
    echo -e "           ${BOLD}${YELLOW}↙ SERVICE STATUS ↘${NC}"
    echo -e "$L"
    local services=("xray" "nginx" "sshd" "ssh-ws" "cron")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            echo -e "   ${GREEN}●${NC} ${svc} — ${GREEN}running${NC}"
        elif systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
            echo -e "   ${RED}●${NC} ${svc} — ${RED}stopped${NC}"
        else
            echo -e "   ${YELLOW}○${NC} ${svc} — not installed"
        fi
    done
    if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        echo -e "   ${GREEN}●${NC} warp — installed"
    fi
    if [[ -f "${CONFIG_DIR}/modules/ads_blocker_installed" ]]; then
        echo -e "   ${GREEN}●${NC} ads-blocker — active"
    fi
    echo -e "$L"
}

service_port_info() {
    clear
    echo -e "$L"
    echo -e "         ${BOLD}${YELLOW}↙ SERVICE/PORT INFORMATION ↘${NC}"
    echo -e "$L"
    echo -e " ${BOLD}Port    Protocol       Transport${NC}"
    echo -e "$L"
    echo -e " 443     VLESS Reality   TCP XTLS (direct)"
    echo -e " 80      All protocols   Non-TLS (Nginx)"
    echo -e " 8080    All protocols   Non-TLS (Nginx)"
    echo -e " 8880    All protocols   Non-TLS (Nginx)"
    echo -e " 2086    All protocols   Non-TLS (Nginx)"
    echo -e " 8443    All protocols   TLS (Nginx)"
    echo -e " 2083    All protocols   TLS (Nginx)"
    echo -e " 2087    All protocols   TLS (Nginx)"
    echo -e "$L"
    echo -e " ${BOLD}Internal Ports (Xray)${NC}"
    echo -e "$L"
    echo -e " 10001   VLESS WebSocket"
    echo -e " 10002   VLESS HttpUpgrade"
    echo -e " 10003   VLESS XHTTP"
    echo -e " 10004   VLESS gRPC"
    echo -e " 10005   VMESS WebSocket"
    echo -e " 10006   VMESS gRPC"
    echo -e " 10007   Trojan WebSocket"
    echo -e " 10008   Trojan gRPC"
    echo -e " 10010   Trojan TCP"
    echo -e " 10085   Stats API"
    echo -e "$L"
}

backup_restore_menu() {
    echo -e "$L"
    echo -e " ${BOLD}BACKUP & RESTORE${NC}"
    echo -e "$L"
    echo -e " ${GREEN}1${NC}. Backup user data"
    echo -e " ${GREEN}2${NC}. Restore user data"
    echo -e " ${GREEN}0${NC}. Back"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1)
            local backup_file="${DATA_DIR}/backup/freeflow_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            mkdir -p "${DATA_DIR}/backup"
            local tmp_dir
            tmp_dir=$(mktemp -d)
            cp -a "${DATA_DIR}/users" "${tmp_dir}/" 2>/dev/null
            cp -a "${DATA_DIR}/usage" "${tmp_dir}/" 2>/dev/null
            mkdir -p "${tmp_dir}/config"
            cp -f "${CONFIG_DIR}/domain" "${CONFIG_DIR}/paths.conf" "${CONFIG_DIR}/default_uuid" "${tmp_dir}/config/" 2>/dev/null
            [[ -f "${CONFIG_DIR}/cf_mode" ]] && cp -f "${CONFIG_DIR}/cf_mode" "${tmp_dir}/config/"
            tar czf "${backup_file}" -C "${tmp_dir}" . 2>/dev/null
            rm -rf "${tmp_dir}"
            msg_ok "Backup saved: ${backup_file}"
            ;;
        2)
            read -rp " Backup file path: " backup_file
            if [[ -f "${backup_file}" ]]; then
                tar xzf "${backup_file}" -C "${DATA_DIR}" 2>/dev/null
                msg_ok "Data restored from ${backup_file}"
                msg_info "Restart services to apply"
            else
                msg_fail "File not found: ${backup_file}"
            fi
            ;;
        0) return ;;
    esac
}

# --- Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    main_menu
fi
