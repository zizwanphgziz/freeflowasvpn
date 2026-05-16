#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Per-User Data Usage Tracker
# Supports: VLESS, VMESS, Trojan protocols
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

USAGE_DIR="${DATA_DIR}/usage"
USAGE_LOG="${LOG_DIR}/usage.log"

# --- Query Xray Stats API for a user ---
query_user_stats() {
    local email="$1"
    local direction="$2" # uplink or downlink

    local result
    result=$(xray api statsquery --server=127.0.0.1:10085 \
        -pattern "user>>>${email}>>>traffic>>>${direction}" 2>/dev/null | \
        jq -r '.stat[0].value // "0"' 2>/dev/null)

    echo "${result:-0}"
}

# --- Format bytes to human-readable ---
format_bytes() {
    local bytes="$1"
    if [[ "${bytes}" -ge 1073741824 ]]; then
        echo "$(echo "scale=2; ${bytes}/1073741824" | bc) GB"
    elif [[ "${bytes}" -ge 1048576 ]]; then
        echo "$(echo "scale=2; ${bytes}/1048576" | bc) MB"
    elif [[ "${bytes}" -ge 1024 ]]; then
        echo "$(echo "scale=2; ${bytes}/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# --- Record usage for all users (all protocols) ---
# Uses delta tracking: stores last-seen raw Xray counters to avoid double-counting
record_usage() {
    mkdir -p "${USAGE_DIR}" "${USAGE_DIR}/.last_raw"

    for proto in vless vmess trojan; do
        for f in "${USER_DB}/${proto}/active/"*; do
            [[ -f "${f}" ]] || continue

            local username
            username=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            local email="${username}@freeflow"

            local raw_up raw_down
            raw_up=$(query_user_stats "${email}" "uplink")
            raw_down=$(query_user_stats "${email}" "downlink")

            # Read last-seen raw values
            local last_up last_down
            last_up=$(cat "${USAGE_DIR}/.last_raw/${username}_up" 2>/dev/null || echo "0")
            last_down=$(cat "${USAGE_DIR}/.last_raw/${username}_down" 2>/dev/null || echo "0")

            # Compute delta (handle counter reset: if raw < last, Xray was restarted)
            local delta_up delta_down
            if [[ "${raw_up}" -ge "${last_up}" ]]; then
                delta_up=$((raw_up - last_up))
            else
                delta_up="${raw_up}"
            fi
            if [[ "${raw_down}" -ge "${last_down}" ]]; then
                delta_down=$((raw_down - last_down))
            else
                delta_down="${raw_down}"
            fi
            local delta_total=$((delta_up + delta_down))

            # Save current raw values for next delta calculation
            echo "${raw_up}" > "${USAGE_DIR}/.last_raw/${username}_up"
            echo "${raw_down}" > "${USAGE_DIR}/.last_raw/${username}_down"

            # Accumulate delta to stored usage
            local stored
            stored=$(cat "${USAGE_DIR}/${username}" 2>/dev/null || echo "0")
            local new_total=$((stored + delta_total))
            echo "${new_total}" > "${USAGE_DIR}/${username}"

            # Log entry
            echo "[$(date +%Y-%m-%d\ %H:%M)] ${proto}:${username}: delta_up=$(format_bytes "${delta_up}") delta_down=$(format_bytes "${delta_down}") delta=$(format_bytes "${delta_total}") cumulative=$(format_bytes "${new_total}")" >> "${USAGE_LOG}"

            # Check data limit
            local data_limit
            data_limit=$(grep "^DATA_LIMIT_GB=" "${f}" | cut -d= -f2)
            if [[ "${data_limit}" -gt 0 ]] 2>/dev/null; then
                local limit_bytes=$((data_limit * 1073741824))
                if [[ "${new_total}" -ge "${limit_bytes}" ]]; then
                    echo "[$(date)] User '${username}' (${proto}) exceeded data limit (${data_limit}GB)" >> "${LOG_DIR}/expiry.log"
                    source "${SCRIPT_DIR}/manage_user.sh"
                    expire_protocol_user "${proto}" "${username}"
                fi
            fi
        done
    done
}

# --- Display usage for all users ---
show_usage() {
    print_section "User Data Usage (All Protocols)"

    echo -e " ${BOLD}No  Protocol  Username         Upload        Download      Total         Limit${NC}"
    print_line

    local count=0

    for proto in vless vmess trojan; do
        # Active users
        for f in "${USER_DB}/${proto}/active/"*; do
            [[ -f "${f}" ]] || continue
            count=$((count + 1))

            local username email up down total_stored data_limit
            username=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            email="${username}@freeflow"

            up=$(query_user_stats "${email}" "uplink")
            down=$(query_user_stats "${email}" "downlink")
            total_stored=$(cat "${USAGE_DIR}/${username}" 2>/dev/null || echo "0")
            local cumulative=$((total_stored + up + down))

            data_limit=$(grep "^DATA_LIMIT_GB=" "${f}" | cut -d= -f2)
            local limit_display
            if [[ "${data_limit}" -eq 0 ]] 2>/dev/null; then
                limit_display="Unlimited"
            else
                limit_display="${data_limit} GB"
            fi

            printf " %-3s %-9s %-16s %-13s %-13s %-13s %s\n" \
                "${count}" "${proto}" "${username}" \
                "$(format_bytes "${up}")" \
                "$(format_bytes "${down}")" \
                "$(format_bytes "${cumulative}")" \
                "${limit_display}"
        done

        # Expired users
        for f in "${USER_DB}/${proto}/expired/"*; do
            [[ -f "${f}" ]] || continue
            count=$((count + 1))

            local username total_stored data_limit
            username=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            total_stored=$(cat "${USAGE_DIR}/${username}" 2>/dev/null || echo "0")

            data_limit=$(grep "^DATA_LIMIT_GB=" "${f}" | cut -d= -f2)
            local limit_display
            if [[ "${data_limit}" -eq 0 ]] 2>/dev/null; then
                limit_display="Unlimited"
            else
                limit_display="${data_limit} GB"
            fi

            printf " %-3s %-9s ${RED}%-16s${NC} %-13s %-13s %-13s %s\n" \
                "${count}" "${proto}" "${username} [EXP]" \
                "-" "-" \
                "$(format_bytes "${total_stored}")" \
                "${limit_display}"
        done
    done

    if [[ "${count}" -eq 0 ]]; then
        echo -e " ${YELLOW}No users found${NC}"
    fi
    print_line
}

# --- Show single user usage ---
show_user_usage() {
    local username="$1"
    if [[ -z "${username}" ]]; then
        read -rp " Username: " username
    fi

    local user_file="" user_proto=""
    for proto in vless vmess trojan; do
        if [[ -f "${USER_DB}/${proto}/active/${username}" ]]; then
            user_file="${USER_DB}/${proto}/active/${username}"
            user_proto="${proto}"
            break
        elif [[ -f "${USER_DB}/${proto}/expired/${username}" ]]; then
            user_file="${USER_DB}/${proto}/expired/${username}"
            user_proto="${proto}"
            break
        fi
    done

    if [[ -z "${user_file}" ]]; then
        msg_fail "User '${username}' not found"
        return 1
    fi

    local uuid expiry status data_limit
    uuid=$(grep "^UUID=" "${user_file}" | cut -d= -f2)
    expiry=$(grep "^EXPIRY=" "${user_file}" | cut -d= -f2)
    status=$(grep "^STATUS=" "${user_file}" | cut -d= -f2)
    data_limit=$(grep "^DATA_LIMIT_GB=" "${user_file}" | cut -d= -f2)

    local email="${username}@freeflow"
    local up down total_stored
    up=$(query_user_stats "${email}" "uplink")
    down=$(query_user_stats "${email}" "downlink")
    total_stored=$(cat "${USAGE_DIR}/${username}" 2>/dev/null || echo "0")
    local cumulative=$((total_stored + up + down))

    print_section "Usage: ${username}"
    echo -e " ${GREEN}Username${NC}    : ${username}"
    echo -e " ${GREEN}Protocol${NC}    : ${user_proto^^}"
    echo -e " ${GREEN}UUID${NC}        : ${uuid}"
    echo -e " ${GREEN}Status${NC}      : ${status}"
    echo -e " ${GREEN}Expiry${NC}      : ${expiry}"
    echo ""
    echo -e " ${CYAN}Upload${NC}      : $(format_bytes "${up}") (current session)"
    echo -e " ${CYAN}Download${NC}    : $(format_bytes "${down}") (current session)"
    echo -e " ${CYAN}Total Used${NC}  : $(format_bytes "${cumulative}")"
    if [[ "${data_limit}" -gt 0 ]] 2>/dev/null; then
        local limit_bytes=$((data_limit * 1073741824))
        local remaining=$((limit_bytes - cumulative))
        if [[ "${remaining}" -lt 0 ]]; then remaining=0; fi
        echo -e " ${CYAN}Data Limit${NC}  : ${data_limit} GB"
        echo -e " ${CYAN}Remaining${NC}   : $(format_bytes "${remaining}")"
    else
        echo -e " ${CYAN}Data Limit${NC}  : Unlimited"
    fi
    print_line
}

# --- Setup cron for periodic recording ---
setup_usage_cron() {
    local cron_cmd="*/5 * * * * /bin/bash ${SCRIPT_DIR}/usage_tracker.sh record"
    if ! crontab -l 2>/dev/null | grep -q "usage_tracker.sh record"; then
        (crontab -l 2>/dev/null; echo "${cron_cmd}") | crontab -
        msg_ok "Usage tracking cron set (every 5 minutes)"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        record) record_usage ;;
        show) show_usage ;;
        user) show_user_usage "$2" ;;
        setup-cron) setup_usage_cron ;;
        *) echo "Usage: $0 {record|show|user <username>|setup-cron}" ;;
    esac
fi
