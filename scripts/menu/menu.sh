#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Main Menu (JinGGo-Style)
# ============================================================

if [[ -d "/usr/local/lib/freeflow/scripts" ]]; then
    SCRIPT_BASE="/usr/local/lib/freeflow/scripts"
else
    SCRIPT_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

source "${SCRIPT_BASE}/core/common.sh"

# --- Count users ---
count_protocol_users() {
    local proto="$1"
    local count=0
    for f in "${USER_DB}/${proto}/active/"*; do
        [[ -f "${f}" ]] && count=$((count + 1))
    done
    echo "${count}"
}

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        local domain ip xray_ver kernel_ver cert_expiry
        domain=$(get_domain)
        ip=$(get_server_ip)
        xray_ver=$(xray version 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
        kernel_ver=$(uname -r)
        detect_os

        local ssh_count vless_count vmess_count trojan_count xray_total
        ssh_count=$(count_protocol_users "ssh")
        vless_count=$(count_protocol_users "vless")
        vmess_count=$(count_protocol_users "vmess")
        trojan_count=$(count_protocol_users "trojan")
        xray_total=$((vless_count + vmess_count + trojan_count))

        # Cert expiry
        if [[ -f /etc/xray/xray.crt ]]; then
            cert_expiry=$(openssl x509 -enddate -noout -in /etc/xray/xray.crt 2>/dev/null | cut -d= -f2)
        else
            cert_expiry="No Certificate"
        fi

        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo -e "  IP VPS              : ${WHITE}${ip}${NC}"
        echo -e "  DOMAIN              : ${WHITE}${domain:-Not Set}${NC}"
        echo -e "  OS VERSION          : ${WHITE}${OS_PRETTY}${NC}"
        echo -e "  KERNEL VERSION      : ${WHITE}${kernel_ver}${NC}"
        echo -e "  XRAY CORE VERSION   : ${WHITE}${xray_ver}${NC}"
        echo -e "  EXP DATE CERT       : ${WHITE}${cert_expiry}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo -e "  TOTAL SSH : ${GREEN}[${ssh_count}]${NC}  TOTAL XRAY : ${GREEN}[${xray_total}]${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo -e "          ${YELLOW}↗ VPN MENU ↘${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        printf "  ${GREEN}[ 01 ]${NC}  %-20s ${GREEN}[ 02 ]${NC}  %s\n" "MENU SSH" "MENU XRAY VLESS"
        printf "  ${GREEN}[ 03 ]${NC}  %-20s ${GREEN}[ 04 ]${NC}  %s\n" "MENU XRAY VMESS" "MENU XRAY TROJAN"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo -e "          ${YELLOW}↗ SYSTEM MENU ↘${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        printf "  ${GREEN}[ 05 ]${NC}  %-20s ${GREEN}[ 13 ]${NC}  %s\n" "ADD/CHANGE DOMAIN" "SPEEDTEST VPS"
        printf "  ${GREEN}[ 06 ]${NC}  %-20s ${GREEN}[ 14 ]${NC}  %s\n" "CHANGE DNS SERVER" "STREAM GEO CHECK"
        printf "  ${GREEN}[ 07 ]${NC}  %-20s ${GREEN}[ 15 ]${NC}  %s\n" "RESTART ALL SERVICE" "SERVICE STATUS"
        printf "  ${GREEN}[ 08 ]${NC}  %-20s ${GREEN}[ 16 ]${NC}  %s\n" "CHECK RAM USAGE" "SSH WEBSOCKET"
        printf "  ${GREEN}[ 09 ]${NC}  %-20s ${GREEN}[ 17 ]${NC}  %s\n" "REBOOT VPS" "WARP MANAGER"
        printf "  ${GREEN}[ 10 ]${NC}  %-20s ${GREEN}[ 18 ]${NC}  %s\n" "UPDATE SCRIPT" "ADS BLOCKER"
        printf "  ${GREEN}[ 11 ]${NC}  %-20s ${GREEN}[ 19 ]${NC}  %s\n" "BACKUP / RESTORE" "TELEGRAM BOT"
        printf "  ${GREEN}[ 12 ]${NC}  %-20s ${GREEN}[ 20 ]${NC}  %s\n" "RENEW SSL CERT" "AUTO SETTINGS"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo -e "  ${RED}[  0 ]${NC}  EXIT MENU"
        echo -e "${CYAN}════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}════════════════════════════════════${NC}"
        echo -e "  SCRIPT VERSION  : ${WHITE}$(get_installed_version)${NC}"
        echo -e "  BY              : ${WHITE}FREEFLOW${NC}"
        echo -e "${CYAN}════════════════════════════════════${NC}"
        echo ""
        read -rp "  Select menu [0-20]: " opt

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
            11) backup_restore_menu ;;
            12) renew_ssl ;;
            13) run_speedtest ;;
            14) source "${SCRIPT_BASE}/tools/netflix_checker.sh"; check_netflix_region ;;
            15) service_status ;;
            16) ssh_ws_menu ;;
            17) warp_menu ;;
            18) ads_menu ;;
            19) source "${SCRIPT_BASE}/telegram/setup_bot.sh"; setup_telegram_bot ;;
            20) auto_settings_menu ;;
            00|0) echo -e "\n ${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *) msg_warn "Invalid option" ;;
        esac

        echo ""
        read -rp " Press Enter to continue..."
    done
}

# =============================================
#  VPN SUB-MENUS
# =============================================

menu_ssh() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}SSH MENU${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[ 01 ]${NC}  ADD SSH USER"
    echo -e "  ${GREEN}[ 02 ]${NC}  DELETE SSH USER"
    echo -e "  ${GREEN}[ 03 ]${NC}  LIST SSH USERS"
    echo -e "  ${GREEN}[ 04 ]${NC}  RENEW SSH USER"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[  0 ]${NC}  BACK TO MAIN MENU"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    read -rp "  Select: " opt
    case "${opt}" in
        01|1) ssh_add_user ;;
        02|2) ssh_delete_user ;;
        03|3) ssh_list_users ;;
        04|4) ssh_renew_user ;;
        00|0) return ;;
        *) msg_warn "Invalid option" ;;
    esac
}

menu_vless() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}XRAY VLESS MENU${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[ 01 ]${NC}  ADD VLESS USER"
    echo -e "  ${GREEN}[ 02 ]${NC}  DELETE VLESS USER"
    echo -e "  ${GREEN}[ 03 ]${NC}  RENEW VLESS USER"
    echo -e "  ${GREEN}[ 04 ]${NC}  REACTIVATE EXPIRED VLESS"
    echo -e "  ${GREEN}[ 05 ]${NC}  LIST ACTIVE VLESS USERS"
    echo -e "  ${GREEN}[ 06 ]${NC}  LIST EXPIRED VLESS USERS"
    echo -e "  ${GREEN}[ 07 ]${NC}  CHECK ONLINE USERS"
    echo -e "  ${GREEN}[ 08 ]${NC}  TRIAL VLESS ACCOUNT"
    echo -e "  ${GREEN}[ 09 ]${NC}  USER DATA USAGE"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[  0 ]${NC}  BACK TO MAIN MENU"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    read -rp "  Select: " opt
    source "${SCRIPT_BASE}/user/manage_user.sh"
    case "${opt}" in
        01|1) add_vless_user ;;
        02|2) delete_vless_user ;;
        03|3) renew_vless_user ;;
        04|4) reactivate_vless_user ;;
        05|5) list_protocol_active "vless" ;;
        06|6) list_protocol_expired "vless" ;;
        07|7) check_login_users ;;
        08|8) create_trial_account "vless" ;;
        09|9) source "${SCRIPT_BASE}/user/usage_tracker.sh"; show_usage ;;
        00|0) return ;;
        *) msg_warn "Invalid option" ;;
    esac
}

menu_vmess() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}XRAY VMESS MENU${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[ 01 ]${NC}  ADD VMESS USER"
    echo -e "  ${GREEN}[ 02 ]${NC}  DELETE VMESS USER"
    echo -e "  ${GREEN}[ 03 ]${NC}  RENEW VMESS USER"
    echo -e "  ${GREEN}[ 04 ]${NC}  REACTIVATE EXPIRED VMESS"
    echo -e "  ${GREEN}[ 05 ]${NC}  LIST ACTIVE VMESS USERS"
    echo -e "  ${GREEN}[ 06 ]${NC}  LIST EXPIRED VMESS USERS"
    echo -e "  ${GREEN}[ 07 ]${NC}  CHECK ONLINE USERS"
    echo -e "  ${GREEN}[ 08 ]${NC}  TRIAL VMESS ACCOUNT"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[  0 ]${NC}  BACK TO MAIN MENU"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    read -rp "  Select: " opt
    source "${SCRIPT_BASE}/user/manage_user.sh"
    case "${opt}" in
        01|1) add_vmess_user ;;
        02|2) delete_vmess_user ;;
        03|3) renew_vmess_user ;;
        04|4) reactivate_vmess_user ;;
        05|5) list_protocol_active "vmess" ;;
        06|6) list_protocol_expired "vmess" ;;
        07|7) check_login_users ;;
        08|8) create_trial_account "vmess" ;;
        00|0) return ;;
        *) msg_warn "Invalid option" ;;
    esac
}

menu_trojan() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}XRAY TROJAN MENU${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[ 01 ]${NC}  ADD TROJAN USER"
    echo -e "  ${GREEN}[ 02 ]${NC}  DELETE TROJAN USER"
    echo -e "  ${GREEN}[ 03 ]${NC}  RENEW TROJAN USER"
    echo -e "  ${GREEN}[ 04 ]${NC}  REACTIVATE EXPIRED TROJAN"
    echo -e "  ${GREEN}[ 05 ]${NC}  LIST ACTIVE TROJAN USERS"
    echo -e "  ${GREEN}[ 06 ]${NC}  LIST EXPIRED TROJAN USERS"
    echo -e "  ${GREEN}[ 07 ]${NC}  CHECK ONLINE USERS"
    echo -e "  ${GREEN}[ 08 ]${NC}  TRIAL TROJAN ACCOUNT"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[  0 ]${NC}  BACK TO MAIN MENU"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    read -rp "  Select: " opt
    source "${SCRIPT_BASE}/user/manage_user.sh"
    case "${opt}" in
        01|1) add_trojan_user ;;
        02|2) delete_trojan_user ;;
        03|3) renew_trojan_user ;;
        04|4) reactivate_trojan_user ;;
        05|5) list_protocol_active "trojan" ;;
        06|6) list_protocol_expired "trojan" ;;
        07|7) check_login_users ;;
        08|8) create_trial_account "trojan" ;;
        00|0) return ;;
        *) msg_warn "Invalid option" ;;
    esac
}

# =============================================
#  SYSTEM SUB-MENUS & HELPERS
# =============================================

auto_settings_menu() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}AUTO SETTINGS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[ 01 ]${NC}  AUTO UPDATE SETTINGS"
    echo -e "  ${GREEN}[ 02 ]${NC}  AUTO REBOOT SETTINGS"
    echo -e "  ${GREEN}[ 03 ]${NC}  AUTO CLEAR LOG"
    echo -e "  ${GREEN}[ 04 ]${NC}  TELEGRAM AUTO BACKUP"
    echo -e "  ${GREEN}[ 05 ]${NC}  SYSTEM INFO"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[  0 ]${NC}  BACK TO MAIN MENU"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
    read -rp "  Select: " opt
    case "${opt}" in
        01|1) source "${SCRIPT_BASE}/update/auto_update.sh"; setup_auto_update_cron ;;
        02|2) setup_auto_reboot ;;
        03|3) source "${SCRIPT_BASE}/tools/auto_clear_log.sh"; setup_auto_clear ;;
        04|4) source "${SCRIPT_BASE}/tools/tg_auto_backup.sh"; setup_auto_backup ;;
        05|5) system_info ;;
        00|0) return ;;
        *) msg_warn "Invalid option" ;;
    esac
}

service_status() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}SERVICE STATUS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"

    local services=("xray" "nginx" "ssh-ws" "cron")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            echo -e "   ${GREEN}●${NC} ${svc} — running"
        elif systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
            echo -e "   ${RED}●${NC} ${svc} — stopped"
        else
            echo -e "   ${YELLOW}○${NC} ${svc} — not installed"
        fi
    done

    if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        if warp-cli status 2>/dev/null | grep -q "Connected"; then
            echo -e "   ${GREEN}●${NC} warp — connected"
        else
            echo -e "   ${YELLOW}●${NC} warp — disconnected"
        fi
    fi

    if [[ -f "${CONFIG_DIR}/modules/ads_blocker_installed" ]]; then
        echo -e "   ${GREEN}●${NC} ads-blocker — active"
    fi

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Port Information${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "  443   : VLESS XTLS Reality (Xray direct)"
    echo -e "  80    : Non-TLS (Nginx)"
    echo -e "  8080  : Non-TLS (Nginx)"
    echo -e "  8880  : Non-TLS (Nginx)"
    echo -e "  2086  : Non-TLS (Nginx)"
    echo -e "  8443  : TLS (Nginx)"
    echo -e "  2083  : TLS (Nginx)"
    echo -e "  2087  : TLS (Nginx)"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
}

ssh_ws_menu() {
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

warp_menu() {
    if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        echo -e "  WARP is ${GREEN}installed${NC}"
        echo -e "  ${GREEN}1${NC}. View WARP routed domains"
        echo -e "  ${GREEN}2${NC}. Add domains to WARP"
        echo -e "  ${GREEN}3${NC}. Uninstall WARP"
        echo -e "  ${GREEN}0${NC}. Back"
        echo ""
        read -rp " Choose: " choice
        case "${choice}" in
            1) source "${SCRIPT_BASE}/warp/install_warp.sh"; list_warp_routes ;;
            2) source "${SCRIPT_BASE}/warp/install_warp.sh"; add_warp_route ;;
            3) source "${SCRIPT_BASE}/warp/install_warp.sh"; uninstall_warp ;;
            0) return ;;
        esac
    else
        echo -e "  WARP is ${RED}not installed${NC}"
        if confirm "Install WARP?"; then
            source "${SCRIPT_BASE}/warp/install_warp.sh"
            install_warp
        fi
    fi
}

ads_menu() {
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

ssh_add_user() {
    print_section "Add SSH User"
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

ssh_delete_user() {
    print_section "Delete SSH User"
    read -rp " Username: " username
    [[ -z "${username}" ]] && { msg_fail "Empty username"; return; }
    userdel -f "${username}" 2>/dev/null
    rm -f "${USER_DB}/ssh/active/${username}" "${USER_DB}/ssh/expired/${username}"
    msg_ok "SSH user '${username}' deleted"
}

ssh_list_users() {
    print_section "SSH Users"
    local count=0
    echo -e " ${BOLD}No  Username         Expiry${NC}"
    print_line
    for f in "${USER_DB}/ssh/active/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        printf " %-3s %-16s %s\n" "${count}" "${uname}" "${expiry}"
    done
    [[ "${count}" -eq 0 ]] && echo -e " ${YELLOW}No SSH users${NC}"
    echo -e " Total: ${count}"
}

ssh_renew_user() {
    print_section "Renew SSH User"
    read -rp " Username: " username
    [[ -z "${username}" ]] && { msg_fail "Empty username"; return; }
    read -rp " Extend by days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")
    usermod -e "${expiry}" "${username}" 2>/dev/null
    if [[ -f "${USER_DB}/ssh/active/${username}" ]]; then
        sed -i "s/^EXPIRY=.*/EXPIRY=${expiry}/" "${USER_DB}/ssh/active/${username}"
    fi
    msg_ok "SSH user '${username}' renewed until ${expiry}"
}

restart_all_services() {
    print_section "Restarting All Services"
    restart_service xray
    restart_service nginx
    [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]] && restart_service ssh-ws
    msg_ok "All services restarted"
}

run_speedtest() {
    print_section "Server Speedtest"
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
    print_section "Change Domain"
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
    print_section "Renew SSL Certificate"
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

setup_auto_reboot() {
    print_section "Auto Reboot Settings"
    echo -e "  ${GREEN}1${NC}. Enable (5:00 AM daily)"
    echo -e "  ${GREEN}2${NC}. Custom time"
    echo -e "  ${GREEN}3${NC}. Disable"
    echo -e "  ${GREEN}0${NC}. Back"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1)
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            echo "0 5 * * * root /sbin/reboot" >> /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot: 5:00 AM daily"
            ;;
        2)
            read -rp " Hour (0-23): " hour
            read -rp " Minute (0-59): " minute
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            echo "${minute} ${hour} * * * root /sbin/reboot" >> /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot: ${hour}:${minute} daily"
            ;;
        3)
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot disabled"
            ;;
        0) return ;;
    esac
}

system_info() {
    print_section "System Information"
    echo -e " ${CYAN}Hostname${NC}  : $(hostname)"
    echo -e " ${CYAN}OS${NC}        : $(detect_os; echo "${OS_PRETTY}")"
    echo -e " ${CYAN}Kernel${NC}    : $(uname -r)"
    echo -e " ${CYAN}Arch${NC}      : $(uname -m)"
    echo -e " ${CYAN}CPU${NC}       : $(nproc) core(s)"
    echo -e " ${CYAN}RAM${NC}       : $(free -h | awk '/^Mem:/{print $3 " / " $2}')"
    echo -e " ${CYAN}Swap${NC}      : $(free -h | awk '/^Swap:/{print $2}')"
    echo -e " ${CYAN}Disk${NC}      : $(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 " used)"}')"
    echo -e " ${CYAN}IP${NC}        : $(get_server_ip)"
    echo -e " ${CYAN}Uptime${NC}    : $(uptime -p 2>/dev/null || uptime)"
}

backup_restore_menu() {
    print_section "Backup & Restore"
    echo -e "  ${GREEN}1${NC}. Backup user data"
    echo -e "  ${GREEN}2${NC}. Restore user data"
    echo -e "  ${GREEN}0${NC}. Back"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1)
            local backup_file="${DATA_DIR}/backup/freeflow_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            mkdir -p "${DATA_DIR}/backup"
            tar czf "${backup_file}" -C "${DATA_DIR}" users/ usage/ 2>/dev/null
            tar rzf "${backup_file}" -C "${CONFIG_DIR}" domain paths.conf default_uuid 2>/dev/null
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
