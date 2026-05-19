#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Auto Clear Log
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

LOG_CRON_MARKER="${CONFIG_DIR}/modules/auto_clear_log"

clear_logs_now() {
    print_section "Clearing Logs"

    local total_freed=0

    # Xray logs
    for logf in /var/log/xray/access.log /var/log/xray/error.log; do
        if [[ -f "${logf}" ]]; then
            local size
            size=$(stat -c%s "${logf}" 2>/dev/null || echo 0)
            total_freed=$((total_freed + size))
            : > "${logf}"
        fi
    done

    # Nginx logs
    for logf in /var/log/nginx/access.log /var/log/nginx/error.log; do
        if [[ -f "${logf}" ]]; then
            local size
            size=$(stat -c%s "${logf}" 2>/dev/null || echo 0)
            total_freed=$((total_freed + size))
            : > "${logf}"
        fi
    done

    # FreeFlow logs (keep recent entries)
    for logf in "${LOG_DIR}/"*.log; do
        if [[ -f "${logf}" ]]; then
            local size
            size=$(stat -c%s "${logf}" 2>/dev/null || echo 0)
            # Keep last 100 lines
            tail -100 "${logf}" > "${logf}.tmp"
            mv "${logf}.tmp" "${logf}"
            local new_size
            new_size=$(stat -c%s "${logf}" 2>/dev/null || echo 0)
            total_freed=$((total_freed + size - new_size))
        fi
    done

    # Journal logs
    journalctl --vacuum-size=50M 2>/dev/null

    local freed_mb
    freed_mb=$(echo "scale=2; ${total_freed}/1048576" | bc 2>/dev/null || echo "0")
    msg_ok "Logs cleared — freed ~${freed_mb} MB"
}

setup_auto_clear() {
    print_section "Auto Clear Log Settings"

    echo -e "  ${GREEN}1${NC}. Enable auto clear (daily at 3 AM)"
    echo -e "  ${GREEN}2${NC}. Custom schedule"
    echo -e "  ${GREEN}3${NC}. Disable auto clear"
    echo -e "  ${GREEN}4${NC}. Clear logs now"
    echo -e "  ${GREEN}5${NC}. Back"
    echo ""
    read -rp " Choose: " choice

    case "${choice}" in
        1)
            local cron_cmd="0 3 * * * /bin/bash ${SCRIPT_DIR}/auto_clear_log.sh clear >> /var/log/freeflow/autoclear.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "auto_clear_log.sh"; echo "${cron_cmd}") | crontab -
            mkdir -p "${CONFIG_DIR}/modules"
            touch "${LOG_CRON_MARKER}"
            msg_ok "Auto clear log enabled (daily at 3 AM)"
            ;;
        2)
            read -rp " Hour (0-23): " hour
            read -rp " Minute (0-59): " minute
            local cron_cmd="${minute} ${hour} * * * /bin/bash ${SCRIPT_DIR}/auto_clear_log.sh clear >> /var/log/freeflow/autoclear.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "auto_clear_log.sh"; echo "${cron_cmd}") | crontab -
            mkdir -p "${CONFIG_DIR}/modules"
            touch "${LOG_CRON_MARKER}"
            msg_ok "Auto clear log set to ${hour}:${minute} daily"
            ;;
        3)
            crontab -l 2>/dev/null | grep -v "auto_clear_log.sh" | crontab -
            rm -f "${LOG_CRON_MARKER}"
            msg_ok "Auto clear log disabled"
            ;;
        4)
            clear_logs_now
            ;;
        5) return ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        clear) clear_logs_now ;;
        setup) setup_auto_clear ;;
        *) echo "Usage: $0 {clear|setup}" ;;
    esac
fi
