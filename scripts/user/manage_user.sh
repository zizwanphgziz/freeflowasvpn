#!/bin/bash
# ============================================================
# FreeFlow ASVPN - User Management System
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

# --- Add User ---
add_vless_user() {
    print_section "Add VLESS User"

    read -rp " Username: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

    # Check if user already exists (active or expired)
    if [[ -f "${USER_DB}/vless/active/${username}" ]] || [[ -f "${USER_DB}/vless/expired/${username}" ]]; then
        msg_fail "User '${username}' already exists"
        msg_info "Use reactivate to re-enable an expired user"
        return 1
    fi

    # UUID prompt
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

    # Expiry
    read -rp " Validity in days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")

    # IP limit
    read -rp " Max connections/IPs (default: 2, 0=unlimited): " max_ip
    max_ip="${max_ip:-2}"

    # Data limit
    read -rp " Data limit in GB (default: 0=unlimited): " data_limit
    data_limit="${data_limit:-0}"

    # Save user data
    cat > "${USER_DB}/vless/active/${username}" <<EOF
USERNAME=${username}
UUID=${uuid}
CREATED=$(date +"%Y-%m-%d")
EXPIRY=${expiry}
MAX_IP=${max_ip}
DATA_LIMIT_GB=${data_limit}
STATUS=active
EOF

    # Add user to Xray config
    local tmp_config
    tmp_config=$(mktemp)

    jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
        .inbounds |= map(
            if .tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" then
                .settings.clients += [{"id": $uuid, "email": $email}]
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
        msg_fail "Could not add user to Xray config"
        return 1
    fi

    # Initialize usage tracking
    echo "0" > "${DATA_DIR}/usage/${username}"

    # Display user info
    local domain
    domain=$(get_domain)
    local server_ip
    server_ip=$(get_server_ip)

    # Load paths
    local vless_ws_path="/"
    local vless_hu_path="/vless-hu"
    local vless_xhttp_path="/vless-xhttp"
    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    print_section "User Created Successfully"
    echo -e " ${GREEN}Username${NC}  : ${username}"
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
    echo -e " ${YELLOW}VLESS WS${NC}"
    echo -e "   Port (TLS)    : 443,8443,2083,2087"
    echo -e "   Port (nonTLS) : 80,8080,8880,2086"
    echo -e "   Path          : ${vless_ws_path}"
    echo ""
    echo -e " ${YELLOW}VLESS HttpUpgrade${NC}"
    echo -e "   Port (TLS)    : 443,8443,2083,2087"
    echo -e "   Port (nonTLS) : 80,8080,8880,2086"
    echo -e "   Path          : ${vless_hu_path}"
    echo ""
    echo -e " ${YELLOW}VLESS XHTTP${NC}"
    echo -e "   Port (TLS)    : 443,8443,2083,2087"
    echo -e "   Port (nonTLS) : 80,8080,8880,2086"
    echo -e "   Path          : ${vless_xhttp_path}"
    print_line
}

# --- Delete User ---
delete_vless_user() {
    print_section "Delete VLESS User"

    read -rp " Username to delete: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

    local user_file=""
    if [[ -f "${USER_DB}/vless/active/${username}" ]]; then
        user_file="${USER_DB}/vless/active/${username}"
    elif [[ -f "${USER_DB}/vless/expired/${username}" ]]; then
        user_file="${USER_DB}/vless/expired/${username}"
    else
        msg_fail "User '${username}' not found"
        return 1
    fi

    if ! confirm "Permanently delete user '${username}'?"; then
        return 1
    fi

    # Get UUID before deleting
    local uuid
    uuid=$(grep "^UUID=" "${user_file}" | cut -d= -f2)

    # Remove from Xray config
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

    # Remove user files
    rm -f "${user_file}"
    rm -f "${DATA_DIR}/usage/${username}"

    msg_ok "User '${username}' permanently deleted"
}

# --- Expire User (block but don't delete) ---
expire_vless_user() {
    local username="$1"

    if [[ -z "${username}" ]]; then
        read -rp " Username to expire: " username
    fi

    if [[ ! -f "${USER_DB}/vless/active/${username}" ]]; then
        msg_warn "User '${username}' not found in active users"
        return 1
    fi

    # Get UUID
    local uuid
    uuid=$(grep "^UUID=" "${USER_DB}/vless/active/${username}" | cut -d= -f2)

    # Remove from Xray config (block connection)
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

    # Move to expired (keep the data!)
    sed -i 's/^STATUS=active/STATUS=expired/' "${USER_DB}/vless/active/${username}"
    mv "${USER_DB}/vless/active/${username}" "${USER_DB}/vless/expired/${username}"

    msg_ok "User '${username}' expired (data preserved, connection blocked)"
}

# --- Reactivate Expired User ---
reactivate_vless_user() {
    print_section "Reactivate Expired User"

    read -rp " Username to reactivate: " username
    if [[ ! -f "${USER_DB}/vless/expired/${username}" ]]; then
        msg_fail "User '${username}' not found in expired users"
        return 1
    fi

    read -rp " New validity in days (default: 30): " days
    days="${days:-30}"
    local expiry
    expiry=$(get_expiry_date "${days}")

    # Get UUID from saved data
    local uuid
    uuid=$(grep "^UUID=" "${USER_DB}/vless/expired/${username}" | cut -d= -f2)

    # Update expiry and status
    sed -i "s/^EXPIRY=.*/EXPIRY=${expiry}/" "${USER_DB}/vless/expired/${username}"
    sed -i 's/^STATUS=expired/STATUS=active/' "${USER_DB}/vless/expired/${username}"

    # Move back to active
    mv "${USER_DB}/vless/expired/${username}" "${USER_DB}/vless/active/${username}"

    # Re-add to Xray config with same UUID
    local tmp_config
    tmp_config=$(mktemp)
    jq --arg uuid "${uuid}" --arg email "${username}@freeflow" '
        .inbounds |= map(
            if .tag == "vless-ws" or .tag == "vless-httpupgrade" or .tag == "vless-xhttp" then
                .settings.clients += [{"id": $uuid, "email": $email}]
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

    msg_ok "User '${username}' reactivated until ${expiry} (same UUID: ${uuid})"
}

# --- Renew User ---
renew_vless_user() {
    print_section "Renew VLESS User"

    read -rp " Username to renew: " username
    if [[ ! -f "${USER_DB}/vless/active/${username}" ]]; then
        msg_fail "User '${username}' not found in active users"
        msg_info "Use reactivate for expired users"
        return 1
    fi

    read -rp " Extend by days (default: 30): " days
    days="${days:-30}"

    local current_expiry
    current_expiry=$(grep "^EXPIRY=" "${USER_DB}/vless/active/${username}" | cut -d= -f2)

    local new_expiry
    new_expiry=$(date -d "${current_expiry} + ${days} days" +"%Y-%m-%d")

    sed -i "s/^EXPIRY=.*/EXPIRY=${new_expiry}/" "${USER_DB}/vless/active/${username}"

    msg_ok "User '${username}' renewed until ${new_expiry}"
}

# --- List Users ---
list_active_users() {
    print_section "Active VLESS Users"

    local count=0
    echo -e " ${BOLD}No  Username         UUID                                  Expiry      IPs${NC}"
    print_line

    for f in "${USER_DB}/vless/active/"*; do
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
        echo -e " ${YELLOW}No active users${NC}"
    fi
    echo ""
    echo -e " Total active: ${GREEN}${count}${NC}"
}

list_expired_users() {
    print_section "Expired VLESS Users"

    local count=0
    echo -e " ${BOLD}No  Username         UUID                                  Expired${NC}"
    print_line

    for f in "${USER_DB}/vless/expired/"*; do
        [[ -f "${f}" ]] || continue
        count=$((count + 1))
        local uname uuid expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        uuid=$(grep "^UUID=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        printf " %-3s %-16s %-37s %s\n" "${count}" "${uname}" "${uuid}" "${expiry}"
    done

    if [[ "${count}" -eq 0 ]]; then
        echo -e " ${YELLOW}No expired users${NC}"
    fi
    echo ""
    echo -e " Total expired: ${RED}${count}${NC}"
}

list_all_users() {
    list_active_users
    list_expired_users
}

# --- Auto Expire Check (run via cron) ---
check_expired_users() {
    for f in "${USER_DB}/vless/active/"*; do
        [[ -f "${f}" ]] || continue
        local uname expiry
        uname=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
        expiry=$(grep "^EXPIRY=" "${f}" | cut -d= -f2)
        if is_expired "${expiry}"; then
            expire_vless_user "${uname}"
            echo "[$(date)] User '${uname}' auto-expired" >> "${LOG_DIR}/expiry.log"
        fi
    done
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        add) add_vless_user ;;
        delete) delete_vless_user ;;
        renew) renew_vless_user ;;
        reactivate) reactivate_vless_user ;;
        list) list_all_users ;;
        list-active) list_active_users ;;
        list-expired) list_expired_users ;;
        check-expiry) check_expired_users ;;
        *) echo "Usage: $0 {add|delete|renew|reactivate|list|list-active|list-expired|check-expiry}" ;;
    esac
fi
