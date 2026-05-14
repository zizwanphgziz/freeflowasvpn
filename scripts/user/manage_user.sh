#!/bin/bash
# ============================================================
# FreeFlow ASVPN - User Management System
# Supports: VLESS, VMESS, Trojan protocols
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

# All VLESS inbound tags
VLESS_TAGS=("vless-ws" "vless-httpupgrade" "vless-xhttp" "vless-grpc" "vless-reality")
# All VMESS inbound tags
VMESS_TAGS=("vmess-ws" "vmess-grpc")
# All Trojan inbound tags
TROJAN_TAGS=("trojan-ws" "trojan-grpc" "trojan-tcp")

# --- Generic add user for a protocol ---
add_protocol_user() {
    local protocol="$1" # vless, vmess, trojan
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
        msg_info "Use reactivate to re-enable an expired user"
        return 1
    fi

    echo ""
    echo -e " ${BOLD}UUID Configuration${NC}"
    read -rp " Custom UUID/name? (leave empty for random): " custom_name
    local uuid
    if [[ -n "${custom_name}" ]]; then
        uuid=$(custom_uuid_from_name "${custom_name}")
        msg_info "UUID from '${custom_name}': ${uuid}"
    else
        uuid=$(generate_uuid)
        msg_info "Random UUID: ${uuid}"
    fi

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

    # Determine which inbound tags to add user to
    local -a tags
    local jq_filter
    case "${protocol}" in
        vless)
            tags=("${VLESS_TAGS[@]}")
            # VLESS Reality needs "flow" field
            local tmp_config
            tmp_config=$(mktemp)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if (.tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" or .tag == "vless-grpc") then
                        .settings.clients += [{"id": $uuid, "email": $email}]
                    elif .tag == "vless-reality" then
                        .settings.clients += [{"id": $uuid, "flow": "xtls-rprx-vision", "email": $email}]
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            if [[ -s "${tmp_config}" ]]; then
                mv "${tmp_config}" "${XRAY_CONFIG}"
            else
                rm -f "${tmp_config}"
                msg_fail "Could not add user to Xray config"
                return 1
            fi
            ;;
        vmess)
            tags=("${VMESS_TAGS[@]}")
            local tmp_config
            tmp_config=$(mktemp)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "vmess-ws" or .tag == "vmess-grpc" then
                        .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            if [[ -s "${tmp_config}" ]]; then
                mv "${tmp_config}" "${XRAY_CONFIG}"
            else
                rm -f "${tmp_config}"
                msg_fail "Could not add user to Xray config"
                return 1
            fi
            ;;
        trojan)
            tags=("${TROJAN_TAGS[@]}")
            local tmp_config
            tmp_config=$(mktemp)
            jq --arg password "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "trojan-ws" or .tag == "trojan-grpc" or .tag == "trojan-tcp" then
                        .settings.clients += [{"password": $password, "email": $email}]
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            if [[ -s "${tmp_config}" ]]; then
                mv "${tmp_config}" "${XRAY_CONFIG}"
            else
                rm -f "${tmp_config}"
                msg_fail "Could not add user to Xray config"
                return 1
            fi
            ;;
    esac

    restart_service xray

    echo "0" > "${DATA_DIR}/usage/${username}"

    local domain server_ip
    domain=$(get_domain)
    server_ip=$(get_server_ip)

    # Load paths
    local vless_ws_path="/" vless_hu_path="/vless-hu" vless_xhttp_path="/vless-xhttp"
    local vless_grpc_sn="vless-grpc" vmess_ws_path="/vmess-ws" vmess_grpc_sn="vmess-grpc"
    local trojan_ws_path="/trojan-ws" trojan_grpc_sn="trojan-grpc"
    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    print_section "User Created Successfully"
    echo -e " ${GREEN}Username${NC}  : ${username}"
    echo -e " ${GREEN}Protocol${NC}  : ${display_name}"
    echo -e " ${GREEN}UUID${NC}      : ${uuid}"
    echo -e " ${GREEN}Expiry${NC}    : ${expiry} (${days} days)"
    echo -e " ${GREEN}Max IPs${NC}   : ${max_ip}"
    echo -e " ${GREEN}Data Limit${NC}: ${data_limit} GB"
    echo ""
    print_line
    echo -e " ${BOLD}Connection Details${NC}"
    print_line
    echo -e " ${CYAN}Domain${NC}    : ${domain}"
    echo -e " ${CYAN}IP${NC}        : ${server_ip}"
    echo ""

    case "${protocol}" in
        vless)
            echo -e " ${YELLOW}VLESS WS${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | path=${vless_ws_path}"
            echo -e " ${YELLOW}VLESS HU${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | path=${vless_hu_path}"
            echo -e " ${YELLOW}VLESS XHTTP${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | path=${vless_xhttp_path}"
            echo -e " ${YELLOW}VLESS gRPC${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | sn=${vless_grpc_sn}"
            echo -e " ${YELLOW}VLESS Reality${NC}: port=443 | sni=www.google.com"
            ;;
        vmess)
            echo -e " ${YELLOW}VMESS WS${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | path=${vmess_ws_path}"
            echo -e " ${YELLOW}VMESS gRPC${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | sn=${vmess_grpc_sn}"
            ;;
        trojan)
            echo -e " ${YELLOW}Trojan WS${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | path=${trojan_ws_path}"
            echo -e " ${YELLOW}Trojan gRPC${NC}: TLS=443,8443,2083,2087 | nonTLS=80,8080,8880,2086 | sn=${trojan_grpc_sn}"
            echo -e " ${YELLOW}Trojan TCP${NC}: port=443 (via Reality fallback)"
            ;;
    esac
    print_line
}

# Convenience wrappers
add_vless_user() { add_protocol_user "vless"; }
add_vmess_user() { add_protocol_user "vmess"; }
add_trojan_user() { add_protocol_user "trojan"; }

# --- Delete User ---
delete_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Delete ${display_name} User"

    read -rp " Username to delete: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

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
            else
                .
            end
        )
    ' "${XRAY_CONFIG}" > "${tmp_config}"

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    rm -f "${user_file}"
    rm -f "${DATA_DIR}/usage/${username}"

    msg_ok "User '${username}' permanently deleted"
}

delete_vless_user() { delete_protocol_user "vless"; }
delete_vmess_user() { delete_protocol_user "vmess"; }
delete_trojan_user() { delete_protocol_user "trojan"; }

# --- Expire User (block but don't delete) ---
expire_protocol_user() {
    local protocol="$1"
    local username="$2"

    if [[ -z "${username}" ]]; then
        read -rp " Username to expire: " username
    fi

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
            else
                .
            end
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

expire_vless_user() { expire_protocol_user "vless" "$1"; }
expire_vmess_user() { expire_protocol_user "vmess" "$1"; }
expire_trojan_user() { expire_protocol_user "trojan" "$1"; }

# --- Reactivate Expired User ---
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
    uuid=$(grep "^UUID=" "${USER_DB}/${protocol}/expired/${username}" | cut -d= -f2)

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
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            ;;
        vmess)
            jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "vmess-ws" or .tag == "vmess-grpc" then
                        .settings.clients += [{"id": $uuid, "alterId": 0, "email": $email}]
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            ;;
        trojan)
            jq --arg password "${uuid}" --arg email "${username}@freeflow" '
                .inbounds |= map(
                    if .tag == "trojan-ws" or .tag == "trojan-grpc" or .tag == "trojan-tcp" then
                        .settings.clients += [{"password": $password, "email": $email}]
                    else
                        .
                    end
                )
            ' "${XRAY_CONFIG}" > "${tmp_config}"
            ;;
    esac

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    msg_ok "User '${username}' reactivated until ${expiry} (same UUID: ${uuid})"
}

reactivate_vless_user() { reactivate_protocol_user "vless"; }
reactivate_vmess_user() { reactivate_protocol_user "vmess"; }
reactivate_trojan_user() { reactivate_protocol_user "trojan"; }

# --- Renew User ---
renew_protocol_user() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Renew ${display_name} User"

    read -rp " Username to renew: " username
    if [[ ! -f "${USER_DB}/${protocol}/active/${username}" ]]; then
        msg_fail "User '${username}' not found in active ${protocol} users"
        msg_info "Use reactivate for expired users"
        return 1
    fi

    read -rp " Extend by days (default: 30): " days
    days="${days:-30}"

    local current_expiry
    current_expiry=$(grep "^EXPIRY=" "${USER_DB}/${protocol}/active/${username}" | cut -d= -f2)

    local new_expiry
    new_expiry=$(date -d "${current_expiry} + ${days} days" +"%Y-%m-%d")

    sed -i "s/^EXPIRY=.*/EXPIRY=${new_expiry}/" "${USER_DB}/${protocol}/active/${username}"

    msg_ok "User '${username}' renewed until ${new_expiry}"
}

renew_vless_user() { renew_protocol_user "vless"; }
renew_vmess_user() { renew_protocol_user "vmess"; }
renew_trojan_user() { renew_protocol_user "trojan"; }

# --- List Users ---
list_protocol_active() {
    local protocol="$1"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Active ${display_name} Users"

    local count=0
    echo -e " ${BOLD}No  Username         UUID                                  Expiry      IPs${NC}"
    print_line

    for f in "${USER_DB}/${protocol}/active/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname uuid expiry max_ip
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        uuid=$(grep "^UUID=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        max_ip=$(grep "^MAX_IP=" "${f}" | cut -d= -f2)
        printf " %-3s %-16s %-37s %-11s %s\n" "${count}" "${uname}" "${uuid}" "${expiry}" "${max_ip}"
    done

    if [[ "${count}" -eq 0 ]]; then
        echo -e " ${YELLOW}No active ${protocol} users${NC}"
    fi
    echo ""
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

    if [[ "${count}" -eq 0 ]]; then
        echo -e " ${YELLOW}No expired ${protocol} users${NC}"
    fi
    echo ""
    echo -e " Total expired: ${RED}${count}${NC}"
}

# Legacy convenience wrappers
list_active_users() { list_protocol_active "vless"; }
list_expired_users() { list_protocol_expired "vless"; }

list_all_users() {
    for proto in vless vmess trojan; do
        list_protocol_active "${proto}"
        list_protocol_expired "${proto}"
    done
}

# --- Trial Account Generator ---
create_trial_account() {
    local protocol="$1"
    protocol="${protocol:-vless}"
    local display_name
    display_name=$(echo "${protocol}" | tr '[:lower:]' '[:upper:]')

    print_section "Create ${display_name} Trial Account"

    read -rp " Trial duration in hours (default: 1): " hours
    hours="${hours:-1}"

    local trial_name="trial_$(date +%s | tail -c 7)"
    local uuid
    uuid=$(generate_uuid)

    # Compute expiry: use minutes for short trials
    local expiry
    local minutes=$((hours * 60))
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

    # Add to xray config
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

    local domain
    domain=$(get_domain)

    print_section "Trial Account Created"
    echo -e " ${GREEN}Username${NC}  : ${trial_name}"
    echo -e " ${GREEN}Protocol${NC}  : ${display_name}"
    echo -e " ${GREEN}UUID${NC}      : ${uuid}"
    echo -e " ${GREEN}Duration${NC}  : ${hours} hour(s)"
    echo -e " ${GREEN}Data Limit${NC}: 1 GB"
    echo -e " ${GREEN}Domain${NC}    : ${domain}"
    print_line
}

# --- Check Online/Login Users ---
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
    local cutoff
    cutoff=$(date -d "5 minutes ago" +"%Y/%m/%d %H:%M" 2>/dev/null)

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

    if [[ "${count}" -eq 0 ]]; then
        echo -e " ${YELLOW}No users currently connected${NC}"
    fi
    echo ""
    echo -e " Total online: ${GREEN}${count}${NC}"
    print_line
}

# --- Auto Expire Check (run via cron) ---
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

# Run if called directly
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
        *) echo "Usage: $0 {add|add-vmess|add-trojan|delete|renew|reactivate|list|list-active|list-expired|check-expiry|trial|online}" ;;
    esac
fi
