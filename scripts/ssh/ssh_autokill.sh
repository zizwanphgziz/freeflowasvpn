#!/bin/bash
# ============================================================
# FreeFlow ASVPN - SSH Multi-Login Auto Kill
# Kills excess SSH sessions when user exceeds MAX_IP
# Runs via cron every minute
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh" 2>/dev/null

USER_DB="${DATA_DIR}/users"

check_ssh_logins() {
    for proto in vless vmess trojan; do
        for f in "${USER_DB}/${proto}/active/"*; do
            [[ -f "${f}" ]] || continue

            local username max_ip
            username=$(grep "^USERNAME=" "${f}" | cut -d= -f2)
            max_ip=$(grep "^MAX_IP=" "${f}" | cut -d= -f2)
            [[ -z "${max_ip}" || "${max_ip}" -eq 0 ]] && continue

            # Count current SSH sessions for this user (by matching the username in 'who' output)
            local current_sessions
            current_sessions=$(who | grep -c "^${username} " 2>/dev/null || echo "0")

            if [[ "${current_sessions}" -gt "${max_ip}" ]]; then
                local excess=$((current_sessions - max_ip))
                # Kill the oldest excess sessions
                local pids
                pids=$(ps -u "${username}" -o pid= 2>/dev/null | head -"${excess}")
                for pid in ${pids}; do
                    kill -9 "${pid}" 2>/dev/null
                done
                echo "[$(date)] Killed ${excess} excess SSH session(s) for '${username}' (max: ${max_ip})" >> "${LOG_DIR}/ssh_autokill.log"
            fi
        done
    done
}

# Run check
check_ssh_logins
