#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Telegram Auto Backup
# Scheduled automatic backup sent to Telegram
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

BACKUP_CRON_MARKER="${CONFIG_DIR}/modules/tg_auto_backup"

send_backup_to_telegram() {
    local bot_token chat_id

    if [[ ! -f "${CONFIG_DIR}/telegram/token" ]] || [[ ! -f "${CONFIG_DIR}/telegram/chat_id" ]]; then
        msg_fail "Telegram bot not configured. Set it up first."
        return 1
    fi

    bot_token=$(cat "${CONFIG_DIR}/telegram/token")
    chat_id=$(cat "${CONFIG_DIR}/telegram/chat_id")

    # Create backup
    local backup_file="/tmp/freeflow_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar czf "${backup_file}" \
        -C "${DATA_DIR}" users/ usage/ \
        -C "${CONFIG_DIR}" domain paths.conf default_uuid 2>/dev/null

    if [[ ! -f "${backup_file}" ]]; then
        msg_fail "Backup creation failed"
        return 1
    fi

    local file_size
    file_size=$(du -h "${backup_file}" | cut -f1)

    # Send to Telegram
    local caption="FreeFlow ASVPN Backup
Date: $(date '+%Y-%m-%d %H:%M')
Server: $(hostname)
IP: $(curl -s4 ifconfig.me 2>/dev/null)
Size: ${file_size}"

    local response
    response=$(curl -s -F "chat_id=${chat_id}" \
        -F "document=@${backup_file}" \
        -F "caption=${caption}" \
        "https://api.telegram.org/bot${bot_token}/sendDocument" 2>/dev/null)

    rm -f "${backup_file}"

    if echo "${response}" | jq -e '.ok' 2>/dev/null | grep -q true; then
        msg_ok "Backup sent to Telegram (${file_size})"
    else
        msg_fail "Failed to send backup to Telegram"
        echo "${response}" | jq '.description' 2>/dev/null
        return 1
    fi
}

setup_auto_backup() {
    print_section "Telegram Auto Backup"

    if [[ ! -f "${CONFIG_DIR}/telegram/token" ]]; then
        msg_fail "Telegram bot not configured. Set it up first."
        return 1
    fi

    echo -e "  ${GREEN}1${NC}. Enable auto backup (daily at 2 AM)"
    echo -e "  ${GREEN}2${NC}. Custom schedule"
    echo -e "  ${GREEN}3${NC}. Disable auto backup"
    echo -e "  ${GREEN}4${NC}. Backup now"
    echo -e "  ${GREEN}5${NC}. Back"
    echo ""
    read -rp " Choose: " choice

    case "${choice}" in
        1)
            local cron_cmd="0 2 * * * /bin/bash ${SCRIPT_DIR}/tg_auto_backup.sh send >> /var/log/freeflow/backup.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "tg_auto_backup.sh"; echo "${cron_cmd}") | crontab -
            mkdir -p "${CONFIG_DIR}/modules"
            touch "${BACKUP_CRON_MARKER}"
            msg_ok "Auto backup enabled (daily at 2 AM → Telegram)"
            ;;
        2)
            read -rp " Hour (0-23): " hour
            read -rp " Minute (0-59): " minute
            local cron_cmd="${minute} ${hour} * * * /bin/bash ${SCRIPT_DIR}/tg_auto_backup.sh send >> /var/log/freeflow/backup.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "tg_auto_backup.sh"; echo "${cron_cmd}") | crontab -
            mkdir -p "${CONFIG_DIR}/modules"
            touch "${BACKUP_CRON_MARKER}"
            msg_ok "Auto backup set to ${hour}:${minute} daily → Telegram"
            ;;
        3)
            crontab -l 2>/dev/null | grep -v "tg_auto_backup.sh" | crontab -
            rm -f "${BACKUP_CRON_MARKER}"
            msg_ok "Auto backup disabled"
            ;;
        4)
            send_backup_to_telegram
            ;;
        5) return ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        send) send_backup_to_telegram ;;
        setup) setup_auto_backup ;;
        *) echo "Usage: $0 {send|setup}" ;;
    esac
fi
