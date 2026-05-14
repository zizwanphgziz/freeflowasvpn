#!/bin/bash
# ============================================================
# FreeFlow ASVPN - User Management System
# Supports: VLESS, VMESS, Trojan protocols
# Outputs JinGGo-style config with share links
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

VLESS_TAGS=("vless-ws" "vless-httpupgrade" "vless-xhttp" "vless-grpc" "vless-reality")
VMESS_TAGS=("vmess-ws" "vmess-grpc")
TROJAN_TAGS=("trojan-ws" "trojan-grpc" "trojan-tcp")

# ============================================================
#  SHARE LINK GENERATORS
# ============================================================

show_vless_config() {
    local username="$1" uuid="$2" expiry="$3"
    local domain server_ip
    domain=$(get_domain)
    server_ip=$(get_server_ip)

    local vless_ws_path="/vless-ws" vless_hu_path="/vless-hup"
    local vless_xhttp_path="/vless-xhttp" vless_grpc_sn="vless-grpc"
    [[ -f "${CONFIG_DIR}/paths.conf" ]] && source "${CONFIG_DIR}/paths.conf"

    local reality_public reality_short_id
    reality_public=$(cat "${CONFIG_DIR}/reality_public_key" 2>/dev/null)
    reality_short_id=$(cat "${CONFIG_DIR}/reality_short_id" 2>/dev/null)

    echo ""
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e "       ${BOLD}XRAY VLESS CONFIG${NC}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " Remarks             : ${GREEN}${username}${NC}"
    echo -e " Expired On          : ${YELLOW}${expiry}${NC}"
    echo -e " Domain              : ${domain}"
    echo -e " IP/Host             : ${server_ip}"
    echo -e " Port TLS            : 8443, 2083, 2087"
    echo -e " Port None TLS       : 80, 8080, 8880, 2086"
    echo -e " Port Reality        : 443"
    echo -e " ID                  : ${uuid}"
    echo -e " Encryption          : none"
    echo -e " Network             : ws/httpupgrade/xhttp/grpc"
    echo -e " Path WS             : ${vless_ws_path}"
    echo -e " Path HttpUpgrade    : ${vless_hu_path}"
    echo -e " Path XHTTP          : ${vless_xhttp_path}"
    echo -e " gRPC ServiceName    : ${vless_grpc_sn}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS WS TLS :${NC}"
    echo -e " vless://${uuid}@${domain}:8443?path=${vless_ws_path}&security=tls&encryption=none&type=ws&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS WS NTLS :${NC}"
    echo -e " vless://${uuid}@${domain}:80?path=${vless_ws_path}&encryption=none&type=ws&host=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS HTTPUPGRADE TLS :${NC}"
    echo -e " vless://${uuid}@${domain}:8443?path=${vless_hu_path}&security=tls&encryption=none&type=httpupgrade&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS HTTPUPGRADE NTLS :${NC}"
    echo -e " vless://${uuid}@${domain}:80?path=${vless_hu_path}&encryption=none&type=httpupgrade&host=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS XHTTP NTLS :${NC}"
    echo -e " vless://${uuid}@${domain}:8080?mode=auto&path=${vless_xhttp_path}&encryption=none&type=xhttp&host=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS XHTTP TLS :${NC}"
    echo -e " vless://${uuid}@${domain}:8443?mode=auto&path=${vless_xhttp_path}&security=tls&encryption=none&type=xhttp&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS GRPC :${NC}"
    echo -e " vless://${uuid}@${domain}:8443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=${vless_grpc_sn}&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VLESS XTLS REALITY :${NC}"
    echo -e " vless://${uuid}@${server_ip}:443?security=reality&encryption=none&headerType=none&type=tcp&flow=xtls-rprx-vision&sni=www.google.com&fp=chrome&pbk=${reality_public}&sid=${reality_short_id}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
}

show_vmess_config() {
    local username="$1" uuid="$2" expiry="$3"
    local domain server_ip
    domain=$(get_domain)
    server_ip=$(get_server_ip)

    local vmess_ws_path="/vmess-ws" vmess_grpc_sn="vmess-grpc"
    [[ -f "${CONFIG_DIR}/paths.conf" ]] && source "${CONFIG_DIR}/paths.conf"

    # VMESS share link uses base64-encoded JSON
    local vmess_ws_tls vmess_ws_ntls vmess_grpc

    vmess_ws_tls=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"8443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${vmess_ws_path}\",\"tls\":\"tls\",\"sni\":\"${domain}\"}" | base64 -w 0)
    vmess_ws_ntls=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${vmess_ws_path}\",\"tls\":\"\"}" | base64 -w 0)
    vmess_grpc=$(echo -n "{\"v\":\"2\",\"ps\":\"${username}\",\"add\":\"${domain}\",\"port\":\"8443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"${vmess_grpc_sn}\",\"tls\":\"tls\",\"sni\":\"${domain}\"}" | base64 -w 0)

    echo ""
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e "       ${BOLD}XRAY VMESS CONFIG${NC}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " Remarks             : ${GREEN}${username}${NC}"
    echo -e " Expired On          : ${YELLOW}${expiry}${NC}"
    echo -e " Domain              : ${domain}"
    echo -e " IP/Host             : ${server_ip}"
    echo -e " Port TLS            : 8443, 2083, 2087"
    echo -e " Port None TLS       : 80, 8080, 8880, 2086"
    echo -e " ID                  : ${uuid}"
    echo -e " Security            : auto"
    echo -e " Network             : ws/grpc"
    echo -e " Path WS             : ${vmess_ws_path}"
    echo -e " gRPC ServiceName    : ${vmess_grpc_sn}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VMESS WS TLS :${NC}"
    echo -e " vmess://${vmess_ws_tls}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VMESS WS NTLS :${NC}"
    echo -e " vmess://${vmess_ws_ntls}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK VMESS GRPC :${NC}"
    echo -e " vmess://${vmess_grpc}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
}

show_trojan_config() {
    local username="$1" uuid="$2" expiry="$3"
    local domain server_ip
    domain=$(get_domain)
    server_ip=$(get_server_ip)

    local trojan_ws_path="/trojan-ws" trojan_grpc_sn="trojan-grpc"
    [[ -f "${CONFIG_DIR}/paths.conf" ]] && source "${CONFIG_DIR}/paths.conf"

    echo ""
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e "       ${BOLD}XRAY TROJAN CONFIG${NC}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " Remarks             : ${GREEN}${username}${NC}"
    echo -e " Expired On          : ${YELLOW}${expiry}${NC}"
    echo -e " Domain              : ${domain}"
    echo -e " IP/Host             : ${server_ip}"
    echo -e " Port TLS            : 8443, 2083, 2087"
    echo -e " Port None TLS       : 80, 8080, 8880, 2086"
    echo -e " Password            : ${uuid}"
    echo -e " Network             : ws/grpc/tcp"
    echo -e " Path WS             : ${trojan_ws_path}"
    echo -e " gRPC ServiceName    : ${trojan_grpc_sn}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK TROJAN WS TLS :${NC}"
    echo -e " trojan://${uuid}@${domain}:8443?path=${trojan_ws_path}&security=tls&type=ws&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK TROJAN WS NTLS :${NC}"
    echo -e " trojan://${uuid}@${domain}:80?path=${trojan_ws_path}&type=ws&host=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK TROJAN GRPC :${NC}"
    echo -e " trojan://${uuid}@${domain}:8443?mode=gun&security=tls&type=grpc&serviceName=${trojan_grpc_sn}&sni=${domain}#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
    echo -e " ${BOLD}LINK TROJAN TCP (via Reality fallback) :${NC}"
    echo -e " trojan://${uuid}@${server_ip}:443?security=reality&type=tcp&sni=www.google.com&fp=chrome#${username}"
    echo -e "${CYAN}═════════════════════════════════════════${NC}"
}

# ============================================================
#  ADD USER
# ============================================================

add_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Add ${display_name} User"

    read -rp " Username: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

    if [[ -f "${USER_DB}/${protocol}/active/${username}" ]] || [[ -f "${USER_DB}/${protocol}/expired/${username}" ]]; then
        msg_fail "User '${username}' already exists"
        return 1
    fi

    echo ""
    read -rp " Custom UUID/name? (leave empty for random): " custom_name
    local uuid
    if [[ -n "${custom_name}" ]]; then
        uuid=$(custom_uuid_from_name "${custom_name}" | tr -d '[:cntrl:]')
        msg_info "UUID from '${custom_name}': ${uuid}"
    else
        uuid=$(generate_uuid | tr -d '[:cntrl:]')
    fi
    # Sanitize — strip any control chars that break JSON
    uuid=$(echo -n "${uuid}" | tr -d '[:cntrl:]' | tr -d '[:space:]')
    username=$(echo -n "${username}" | tr -d '[:cntrl:]')

    read -rp " Validity in days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")

    read -rp " Max connections/IPs (default: 2, 0=unlimited): " max_ip
    max_ip="${max_ip:-2}"

    read -rp " Data limit in GB (default: 0=unlimited): " data_limit
    data_limit="${data_limit:-0}"

    cat > "${USER_DB}/${protocol}/active/${username}" <<EOF
USERNAME=${username}
UUID=${uuid}
PROTOCOL=${protocol}
CREATED=$(date +"%Y-%m-%d")
EXPIRY=${expiry}
MAX_IP=${max_ip}
DATA_LIMIT_GB=${data_limit}
STATUS=active
EOF

    # Clean the xray config before modifying — strip control chars
    if [[ -f "${XRAY_CONFIG}" ]]; then
        local clean_json
        clean_json=$(sed 's/[[:cntrl:]]//g' "${XRAY_CONFIG}" | jq '.' 2>/dev/null)
        if [[ -n "${clean_json}" ]]; then
            echo "${clean_json}" > "${XRAY_CONFIG}"
        fi
    fi

    # Add user to Xray config
    local tmp_config
    tmp_config=$(mktemp)
    case "${protocol}" in
        vless)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if (.tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" or .tag == "vless-grpc") then
                        .settings.clients += [{"id": $uuid, "email": $email}]
                    elif .tag == "vless-reality" then
                        .settings.clients += [{"id": $uuid, "flow": "xtls-rprx-vision", "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null
            ;;
        vmess)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "vmess-ws" or .tag == "vmess-grpc" then
                        .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null
            ;;
        trojan)
            jq --arg password "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "trojan-ws" or .tag == "trojan-grpc" or .tag == "trojan-tcp" then
                        .settings.clients += [{"password": $password, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null
            ;;
    esac

    if [[ -s "${tmp_config}" ]] && jq empty "${tmp_config}" 2>/dev/null; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
    else
        rm -f "${tmp_config}"
        msg_fail "Could not add user to Xray config (JSON error)"
        msg_info "Try restarting xray and running the command again"
        return 1
    fi

    restart_service xray
    echo "0" > "${DATA_DIR}/usage/${username}"

    # Show config with share links
    case "${protocol}" in
        vless)  show_vless_config "${username}" "${uuid}" "${expiry}" ;;
        vmess)  show_vmess_config "${username}" "${uuid}" "${expiry}" ;;
        trojan) show_trojan_config "${username}" "${uuid}" "${expiry}" ;;
    esac
}

add_vless_user() { add_protocol_user "vless"; }
add_vmess_user() { add_protocol_user "vmess"; }
add_trojan_user() { add_protocol_user "trojan"; }

# ============================================================
#  DELETE USER
# ============================================================

delete_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Delete ${display_name} User"

    read -rp " Username to delete: " username
    [[ -z "${username}" ]] && { msg_fail "Username cannot be empty"; return 1; }

    local user_file=""
    if [[ -f "${USER_DB}/${protocol}/active/${username}" ]]; then
        user_file="${USER_DB}/${protocol}/active/${username}"
    elif [[ -f "${USER_DB}/${protocol}/expired/${username}" ]]; then
        user_file="${USER_DB}/${protocol}/expired/${username}"
    else
        msg_fail "User '${username}' not found"
        return 1
    fi

    if ! confirm "Permanently delete user '${username}'?"; then
        return 1
    fi

    local tmp_config
    tmp_config=$(mktemp)
    jq --arg email "${username}@freeflow" '
        .inbounds |= map(
            if .settings.clients then
                .settings.clients = [.settings.clients[] | select(.email != $email)]
            else . end
        )
    ' "${XRAY_CONFIG}" > "${tmp_config}"

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    rm -f "${user_file}" "${DATA_DIR}/usage/${username}"
    msg_ok "User '${username}' permanently deleted"
}

delete_vless_user() { delete_protocol_user "vless"; }
delete_vmess_user() { delete_protocol_user "vmess"; }
delete_trojan_user() { delete_protocol_user "trojan"; }

# ============================================================
#  EXPIRE USER (block but don't delete)
# ============================================================

expire_protocol_user() {
    local protocol="$1"
    local username="$2"
    [[ -z "${username}" ]] && read -rp " Username to expire: " username

    if [[ ! -f "${USER_DB}/${protocol}/active/${username}" ]]; then
        msg_warn "User '${username}' not found in active ${protocol} users"
        return 1
    fi

    local tmp_config
    tmp_config=$(mktemp)
    jq --arg email "${username}@freeflow" '
        .inbounds |= map(
            if .settings.clients then
                .settings.clients = [.settings.clients[] | select(.email != $email)]
            else . end
        )
    ' "${XRAY_CONFIG}" > "${tmp_config}"

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    sed -i 's/^STATUS=active/STATUS=expired/' "${USER_DB}/${protocol}/active/${username}"
    mv "${USER_DB}/${protocol}/active/${username}" "${USER_DB}/${protocol}/expired/${username}"
    msg_ok "User '${username}' expired (data preserved, connection blocked)"
}

# ============================================================
#  REACTIVATE EXPIRED USER
# ============================================================

reactivate_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Reactivate Expired ${display_name} User"

    read -rp " Username to reactivate: " username
    if [[ ! -f "${USER_DB}/${protocol}/expired/${username}" ]]; then
        msg_fail "User '${username}' not found in expired ${protocol} users"
        return 1
    fi

    read -rp " New validity in days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")

    local uuid
    uuid=$(grep "^UUID=" "${USER_DB}/${protocol}/expired/${username}" | cut -d= -f2 | tr -d '[:cntrl:]' | tr -d '[:space:]')

    # Clean xray config before modifying
    if [[ -f "${XRAY_CONFIG}" ]]; then
        local clean_json
        clean_json=$(sed 's/[[:cntrl:]]//g' "${XRAY_CONFIG}" | jq '.' 2>/dev/null)
        if [[ -n "${clean_json}" ]]; then
            echo "${clean_json}" > "${XRAY_CONFIG}"
        fi
    fi

    sed -i "s/^EXPIRY=.*/EXPIRY=${expiry}/" "${USER_DB}/${protocol}/expired/${username}"
    sed -i 's/^STATUS=expired/STATUS=active/' "${USER_DB}/${protocol}/expired/${username}"
    mv "${USER_DB}/${protocol}/expired/${username}" "${USER_DB}/${protocol}/active/${username}"

    local tmp_config
    tmp_config=$(mktemp)
    case "${protocol}" in
        vless)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if (.tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" or .tag == "vless-grpc") then
                        .settings.clients += [{"id": $uuid, "email": $email}]
                    elif .tag == "vless-reality" then
                        .settings.clients += [{"id": $uuid, "flow": "xtls-rprx-vision", "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
        vmess)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "vmess-ws" or .tag == "vmess-grpc" then
                        .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
        trojan)
            jq --arg password "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "trojan-ws" or .tag == "trojan-grpc" or .tag == "trojan-tcp" then
                        .settings.clients += [{"password": $password, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
    esac

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    msg_ok "User '${username}' reactivated until ${expiry} (same UUID: ${uuid})"

    case "${protocol}" in
        vless)  show_vless_config "${username}" "${uuid}" "${expiry}" ;;
        vmess)  show_vmess_config "${username}" "${uuid}" "${expiry}" ;;
        trojan) show_trojan_config "${username}" "${uuid}" "${expiry}" ;;
    esac
}

reactivate_vless_user() { reactivate_protocol_user "vless"; }
reactivate_vmess_user() { reactivate_protocol_user "vmess"; }
reactivate_trojan_user() { reactivate_protocol_user "trojan"; }

# ============================================================
#  RENEW USER
# ============================================================

renew_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Renew ${display_name} User"

    read -rp " Username to renew: " username
    if [[ ! -f "${USER_DB}/${protocol}/active/${username}" ]]; then
        msg_fail "User '${username}' not found in active ${protocol} users"
        return 1
    fi

    read -rp " Extend by days (default: 30): " days
    days="${days:-30}"

    local current_expiry new_expiry
    current_expiry=$(grep "^EXPIRY=" "${USER_DB}/${protocol}/active/${username}" | cut -d= -f2)
    new_expiry=$(date -d "${current_expiry} + ${days} days" +"%Y-%m-%d")
    sed -i "s/^EXPIRY=.*/EXPIRY=${new_expiry}/" "${USER_DB}/${protocol}/active/${username}"

    msg_ok "User '${username}' renewed until ${new_expiry}"
}

renew_vless_user() { renew_protocol_user "vless"; }
renew_vmess_user() { renew_protocol_user "vmess"; }
renew_trojan_user() { renew_protocol_user "trojan"; }

# ============================================================
#  LIST USERS
# ============================================================

list_protocol_active() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Active ${display_name} Users"

    local count=0
    echo -e " ${BOLD}No  Username         UUID                                  Expiry${NC}"
    print_line

    for f in "${USER_DB}/${protocol}/active/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname uuid expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        uuid=$(grep "^UUID=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        printf " %-3s %-16s %-37s %s\n" "${count}" "${uname}" "${uuid}" "${expiry}"
    done

    [[ "${count}" -eq 0 ]] && echo -e " ${YELLOW}No active ${protocol} users${NC}"
    echo -e " Total active: ${GREEN}${count}${NC}"
}

list_protocol_expired() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Expired ${display_name} Users"

    local count=0
    echo -e " ${BOLD}No  Username         UUID                                  Expired${NC}"
    print_line

    for f in "${USER_DB}/${protocol}/expired/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname uuid expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        uuid=$(grep "^UUID=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        printf " %-3s %-16s %-37s %s\n" "${count}" "${uname}" "${uuid}" "${expiry}"
    done

    [[ "${count}" -eq 0 ]] && echo -e " ${YELLOW}No expired ${protocol} users${NC}"
    echo -e " Total expired: ${RED}${count}${NC}"
}

list_all_users() {
    for proto in vless vmess trojan; do
        list_protocol_active "${proto}"
        list_protocol_expired "${proto}"
    done
}

# ============================================================
#  TRIAL ACCOUNT GENERATOR
# ============================================================

create_trial_account() {
    local protocol="${1:-vless}"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Create ${display_name} Trial Account"

    read -rp " Trial duration in hours (default: 1): " hours
    hours="${hours:-1}"

    local trial_name="trial_$(date +%s | tail -c 7)"
    local uuid
    uuid=$(generate_uuid | tr -d '[:cntrl:]' | tr -d '[:space:]')
    local minutes=$((hours * 60))
    local expiry
    expiry=$(date -d "+${minutes} minutes" +"%Y-%m-%d")

    cat > "${USER_DB}/${protocol}/active/${trial_name}" <<EOF
USERNAME=${trial_name}
UUID=${uuid}
PROTOCOL=${protocol}
CREATED=$(date +"%Y-%m-%d %H:%M")
EXPIRY=${expiry}
MAX_IP=1
DATA_LIMIT_GB=1
STATUS=active
TRIAL=true
TRIAL_HOURS=${hours}
EOF

    local tmp_config
    tmp_config=$(mktemp)
    case "${protocol}" in
        vless)
            jq --arg uuid "${uuid}" --arg email "${trial_name}@freeflow" '
                .inbounds |= map(
                    if (.tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" or .tag == "vless-grpc") then
                        .settings.clients += [{"id": $uuid, "email": $email}]
                    elif .tag == "vless-reality" then
                        .settings.clients += [{"id": $uuid, "flow": "xtls-rprx-vision", "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
        vmess)
            jq --arg uuid "${uuid}" --arg email "${trial_name}@freeflow" '
                .inbounds |= map(
                    if .tag == "vmess-ws" or .tag == "vmess-grpc" then
                        .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
        trojan)
            jq --arg password "${uuid}" --arg email "${trial_name}@freeflow" '
                .inbounds |= map(
                    if .tag == "trojan-ws" or .tag == "trojan-grpc" or .tag == "trojan-tcp" then
                        .settings.clients += [{"password": $password, "email": $email}]
                    else . end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}" ;;
    esac

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    echo "0" > "${DATA_DIR}/usage/${trial_name}"

    case "${protocol}" in
        vless)  show_vless_config "${trial_name}" "${uuid}" "${expiry}" ;;
        vmess)  show_vmess_config "${trial_name}" "${uuid}" "${expiry}" ;;
        trojan) show_trojan_config "${trial_name}" "${uuid}" "${expiry}" ;;
    esac

    echo -e " ${YELLOW}Trial: ${hours} hour(s) | Data limit: 1 GB${NC}"
}

# ============================================================
#  CHECK ONLINE USERS
# ============================================================

check_login_users() {
    print_section "Online/Connected Users"

    local access_log="/var/log/xray/access.log"
    if [[ ! -f "${access_log}" ]]; then
        msg_warn "No access log found"
        return
    fi

    echo -e " ${BOLD}Currently connected users (last 5 min):${NC}"
    print_line

    local count=0
    for proto in vless vmess trojan; do
        for f in "${USER_DB}/${proto}/active/"*; do
            [[ -f "${f}" ]] || continue
            local uname
            uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            local email="${uname}@freeflow"

            if grep -q "${email}" "${access_log}" 2>/dev/null; then
                local last_seen
                last_seen=$(grep "${email}" "${access_log}" | tail -1 | awk '{print $1, $2}')
                count=$((count + 1))
                echo -e "   ${GREEN}●${NC} ${uname} (${proto}) — last: ${last_seen}"
            fi
        done
    done

    [[ "${count}" -eq 0 ]] && echo -e " ${YELLOW}No users currently connected${NC}"
    echo -e " Total online: ${GREEN}${count}${NC}"
}

# ============================================================
#  AUTO EXPIRE CHECK (cron)
# ============================================================

check_expired_users() {
    for proto in vless vmess trojan; do
        for f in "${USER_DB}/${proto}/active/"*; do
            [[ -f "${f}" ]] || continue
            local uname expiry
            uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
            if is_expired "${expiry}"; then
                expire_protocol_user "${proto}" "${uname}"
                echo "[$(date)] User '${uname}' (${proto}) auto-expired" >> "${LOG_DIR}/expiry.log"
            fi
        done
    done
}

# ============================================================
#  CLI ENTRY POINT
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        add) add_vless_user ;;
        add-vmess) add_vmess_user ;;
        add-trojan) add_trojan_user ;;
        delete) delete_vless_user ;;
        delete-vmess) delete_vmess_user ;;
        delete-trojan) delete_trojan_user ;;
        renew) renew_vless_user ;;
        reactivate) reactivate_vless_user ;;
        list) list_all_users ;;
        list-active) list_protocol_active "${2:-vless}" ;;
        list-expired) list_protocol_expired "${2:-vless}" ;;
        check-expiry) check_expired_users ;;
        trial) create_trial_account "${2:-vless}" ;;
        online) check_login_users ;;
        *) echo "Usage: $0 {add|add-vmess|add-trojan|delete|renew|reactivate|list|check-expiry|trial|online}" ;;
    esac
fi
