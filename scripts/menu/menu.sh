#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Main Menu
# ============================================================

# Determine install location
if [[ -d "/usr/local/lib/freeflow/scripts" ]]; then
    SCRIPT_BASE="/usr/local/lib/freeflow/scripts"
else
    SCRIPT_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

source "${SCRIPT_BASE}/core/common.sh"

show_service_status() {
    local services=("xray" "nginx" "ssh-ws")
    echo -e " ${BOLD}Service Status${NC}"
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            echo -e "   ${GREEN}●${NC} ${svc}"
        elif systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
            echo -e "   ${RED}●${NC} ${svc} (stopped)"
        else
            echo -e "   ${YELLOW}○${NC} ${svc} (not installed)"
        fi
    done

    # WARP status
    if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        if warp-cli status 2>/dev/null | grep -q "Connected"; then
            echo -e "   ${GREEN}●${NC} warp"
        elif systemctl is-active --quiet wg-quick@warp 2>/dev/null; then
            echo -e "   ${GREEN}●${NC} warp (wireguard)"
        else
            echo -e "   ${YELLOW}●${NC} warp (disconnected)"
        fi
    else
        echo -e "   ${YELLOW}○${NC} warp (not installed)"
    fi
}

show_server_info() {
    local domain ip version uptime_info
    domain=$(get_domain)
    ip=$(get_server_ip)
    version=$(get_installed_version)
    uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'( |,)' '{print $5,$6}')

    echo -e " ${CYAN}Domain${NC}  : ${domain:-Not set}"
    echo -e " ${CYAN}IP${NC}      : ${ip}"
    echo -e " ${CYAN}Version${NC} : ${version}"
    echo -e " ${CYAN}Uptime${NC}  : ${uptime_info}"
    echo -e " ${CYAN}OS${NC}      : $(detect_os; echo "${OS_PRETTY}")"
}

main_menu() {
    while true; do
        print_header
        show_server_info
        echo ""
        show_service_status
        echo ""
        print_line
        echo -e " ${BOLD}${WHITE}VLESS USER MANAGEMENT${NC}"
        print_line
        echo -e "  ${GREEN}1${NC}.  Add VLESS User"
        echo -e "  ${GREEN}2${NC}.  Delete VLESS User"
        echo -e "  ${GREEN}3${NC}.  Renew VLESS User"
        echo -e "  ${GREEN}4${NC}.  Reactivate Expired User"
        echo -e "  ${GREEN}5${NC}.  List Active Users"
        echo -e "  ${GREEN}6${NC}.  List Expired Users"
        echo -e "  ${GREEN}7${NC}.  User Data Usage"
        echo ""
        print_line
        echo -e " ${BOLD}${WHITE}SSH WEBSOCKET${NC}"
        print_line
        echo -e "  ${GREEN}8${NC}.  Add SSH User"
        echo -e "  ${GREEN}9${NC}.  Delete SSH User"
        echo -e "  ${GREEN}10${NC}. List SSH Users"
        echo ""
        print_line
        echo -e " ${BOLD}${WHITE}MODULES${NC}"
        print_line
        echo -e "  ${GREEN}11${NC}. Install/Uninstall SSH WebSocket"
        echo -e "  ${GREEN}12${NC}. Install/Uninstall WARP"
        echo -e "  ${GREEN}13${NC}. WARP Domain Routing"
        echo ""
        print_line
        echo -e " ${BOLD}${WHITE}SERVER MANAGEMENT${NC}"
        print_line
        echo -e "  ${GREEN}14${NC}. Restart All Services"
        echo -e "  ${GREEN}15${NC}. Check Xray Config"
        echo -e "  ${GREEN}16${NC}. View Xray Logs"
        echo -e "  ${GREEN}17${NC}. Speedtest"
        echo -e "  ${GREEN}18${NC}. Server Bandwidth (vnstat)"
        echo -e "  ${GREEN}19${NC}. Change Domain"
        echo -e "  ${GREEN}20${NC}. Renew SSL Certificate"
        echo ""
        print_line
        echo -e " ${BOLD}${WHITE}SYSTEM${NC}"
        print_line
        echo -e "  ${GREEN}21${NC}. Update Script"
        echo -e "  ${GREEN}22${NC}. Auto Update Settings"
        echo -e "  ${GREEN}23${NC}. Set Auto Reboot"
        echo -e "  ${GREEN}24${NC}. Telegram Bot Setup"
        echo -e "  ${GREEN}25${NC}. System Info"
        echo -e "  ${GREEN}26${NC}. Backup/Restore"
        echo ""
        print_line
        echo -e "  ${RED}0${NC}.  Exit"
        print_line
        echo ""
        read -rp " Select menu [0-26]: " menu_choice

        case "${menu_choice}" in
            1)  source "${SCRIPT_BASE}/user/manage_user.sh"; add_vless_user ;;
            2)  source "${SCRIPT_BASE}/user/manage_user.sh"; delete_vless_user ;;
            3)  source "${SCRIPT_BASE}/user/manage_user.sh"; renew_vless_user ;;
            4)  source "${SCRIPT_BASE}/user/manage_user.sh"; reactivate_vless_user ;;
            5)  source "${SCRIPT_BASE}/user/manage_user.sh"; list_active_users ;;
            6)  source "${SCRIPT_BASE}/user/manage_user.sh"; list_expired_users ;;
            7)  usage_menu ;;
            8)  ssh_add_user ;;
            9)  ssh_delete_user ;;
            10) ssh_list_users ;;
            11) ssh_ws_menu ;;
            12) warp_menu ;;
            13) source "${SCRIPT_BASE}/warp/install_warp.sh"; add_warp_route ;;
            14) restart_all_services ;;
            15) check_xray_config ;;
            16) view_xray_logs ;;
            17) run_speedtest ;;
            18) show_bandwidth ;;
            19) change_domain ;;
            20) renew_ssl ;;
            21) source "${SCRIPT_BASE}/update/auto_update.sh"; check_update; [[ $? -eq 2 ]] && confirm "Update now?" && do_update ;;
            22) source "${SCRIPT_BASE}/update/auto_update.sh"; setup_auto_update_cron ;;
            23) setup_auto_reboot ;;
            24) source "${SCRIPT_BASE}/telegram/setup_bot.sh"; setup_telegram_bot ;;
            25) system_info ;;
            26) backup_restore_menu ;;
            0)  echo -e "\n ${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *)  msg_warn "Invalid option" ;;
        esac

        echo ""
        read -rp " Press Enter to continue..."
    done
}

# --- Sub-menus and helper functions ---

usage_menu() {
    print_section "User Data Usage"
    echo -e "  ${GREEN}1${NC}. Show all users usage"
    echo -e "  ${GREEN}2${NC}. Show specific user usage"
    echo -e "  ${GREEN}3${NC}. Back"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1) source "${SCRIPT_BASE}/user/usage_tracker.sh"; show_usage ;;
        2)
            read -rp " Username: " uname
            source "${SCRIPT_BASE}/user/usage_tracker.sh"; show_user_usage "${uname}"
            ;;
        3) return ;;
    esac
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
        echo -e "  ${GREEN}4${NC}. Back"
        echo ""
        read -rp " Choose: " choice
        case "${choice}" in
            1) source "${SCRIPT_BASE}/warp/install_warp.sh"; list_warp_routes ;;
            2) source "${SCRIPT_BASE}/warp/install_warp.sh"; add_warp_route ;;
            3) source "${SCRIPT_BASE}/warp/install_warp.sh"; uninstall_warp ;;
            4) return ;;
        esac
    else
        echo -e "  WARP is ${RED}not installed${NC}"
        if confirm "Install WARP?"; then
            source "${SCRIPT_BASE}/warp/install_warp.sh"
            install_warp
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

    # Save SSH user data
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
    echo ""
    echo -e " Total: ${count}"
}

restart_all_services() {
    print_section "Restarting All Services"
    restart_service xray
    restart_service nginx
    [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]] && restart_service ssh-ws
    msg_ok "All services restarted"
}

check_xray_config() {
    print_section "Xray Configuration Check"
    if xray run -test -config "${XRAY_CONFIG}" 2>&1; then
        msg_ok "Xray configuration is valid"
    else
        msg_fail "Xray configuration has errors"
    fi
}

view_xray_logs() {
    print_section "Xray Logs (last 50 lines)"
    tail -50 /var/log/xray/access.log 2>/dev/null || msg_warn "No logs found"
}

run_speedtest() {
    print_section "Server Speedtest"
    if command -v speedtest &>/dev/null; then
        speedtest --accept-license
    else
        msg_fail "Speedtest not installed"
    fi
}

show_bandwidth() {
    print_section "Server Bandwidth"
    if command -v vnstat &>/dev/null; then
        vnstat
    else
        msg_fail "vnstat not installed"
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

    # Re-setup SSL
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

setup_auto_reboot() {
    print_section "Auto Reboot Settings"
    echo -e "  ${GREEN}1${NC}. Enable auto reboot (5:00 AM daily)"
    echo -e "  ${GREEN}2${NC}. Custom time"
    echo -e "  ${GREEN}3${NC}. Disable auto reboot"
    echo -e "  ${GREEN}4${NC}. Back"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1)
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            echo "0 5 * * * root /sbin/reboot" >> /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot set to 5:00 AM daily"
            ;;
        2)
            read -rp " Hour (0-23): " hour
            read -rp " Minute (0-59): " minute
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            echo "${minute} ${hour} * * * root /sbin/reboot" >> /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot set to ${hour}:${minute} daily"
            ;;
        3)
            sed -i '/\/sbin\/reboot/d' /etc/crontab
            systemctl restart cron
            msg_ok "Auto reboot disabled"
            ;;
        4) return ;;
    esac
}

system_info() {
    print_section "System Information"
    echo -e " ${CYAN}Hostname${NC}  : $(hostname)"
    echo -e " ${CYAN}OS${NC}        : $(detect_os; echo "${OS_PRETTY}")"
    echo -e " ${CYAN}Kernel${NC}    : $(uname -r)"
    echo -e " ${CYAN}Arch${NC}      : $(uname -m)"
    echo -e " ${CYAN}CPU${NC}       : $(nproc) core(s)"
    echo -e " ${CYAN}RAM${NC}       : $(free -h | awk '/^Mem:/{print $2}')"
    echo -e " ${CYAN}Swap${NC}      : $(free -h | awk '/^Swap:/{print $2}')"
    echo -e " ${CYAN}Disk${NC}      : $(df -h / | awk 'NR==2{print $2 " (" $5 " used)"}')"
    echo -e " ${CYAN}IP${NC}        : $(get_server_ip)"
    echo -e " ${CYAN}Uptime${NC}    : $(uptime -p 2>/dev/null || uptime)"
}

backup_restore_menu() {
    print_section "Backup & Restore"
    echo -e "  ${GREEN}1${NC}. Backup user data"
    echo -e "  ${GREEN}2${NC}. Restore user data"
    echo -e "  ${GREEN}3${NC}. Back"
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
                msg_info "Restart services to apply changes"
            else
                msg_fail "File not found: ${backup_file}"
            fi
            ;;
        3) return ;;
    esac
}

# --- Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    main_menu
fi
