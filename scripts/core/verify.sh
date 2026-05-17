#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Post-Install Verification Script
# Checks all components after install to catch problems early
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

verify_install() {
    print_section "Post-Install Verification"
    local errors=0

    # 1. Xray binary
    if command -v xray &>/dev/null; then
        msg_ok "Xray binary found: $(xray version 2>/dev/null | head -1)"
    else
        msg_fail "Xray binary not found"
        errors=$((errors + 1))
    fi

    # 2. Xray config valid JSON
    if [[ -f "${XRAY_CONFIG}" ]]; then
        if jq empty "${XRAY_CONFIG}" 2>/dev/null; then
            msg_ok "Xray config: valid JSON"
        else
            msg_fail "Xray config: invalid JSON"
            errors=$((errors + 1))
        fi
    else
        msg_fail "Xray config not found at ${XRAY_CONFIG}"
        errors=$((errors + 1))
    fi

    # 3. Xray service
    if systemctl is-active xray &>/dev/null; then
        msg_ok "Xray service: running"
    else
        msg_fail "Xray service: not running"
        errors=$((errors + 1))
    fi

    # 4. Nginx service
    if systemctl is-active nginx &>/dev/null; then
        msg_ok "Nginx service: running"
    else
        msg_fail "Nginx service: not running"
        errors=$((errors + 1))
    fi

    # 5. Nginx config syntax
    if nginx -t 2>/dev/null; then
        msg_ok "Nginx config: syntax OK"
    else
        msg_fail "Nginx config: syntax error"
        errors=$((errors + 1))
    fi

    # 6. SSL certificate
    if [[ -f /etc/xray/xray.crt && -f /etc/xray/xray.key ]]; then
        local cert_expiry
        cert_expiry=$(openssl x509 -in /etc/xray/xray.crt -noout -enddate 2>/dev/null | cut -d= -f2)
        msg_ok "SSL certificate: ${cert_expiry}"
    else
        msg_fail "SSL certificate files missing"
        errors=$((errors + 1))
    fi

    # 7. Domain configured
    local domain
    domain=$(get_domain)
    if [[ -n "${domain}" ]]; then
        msg_ok "Domain: ${domain}"
    else
        msg_fail "Domain not configured"
        errors=$((errors + 1))
    fi

    # 8. Port checks
    echo ""
    msg_info "Checking ports..."
    for port in 80 443 8080 8443 8880 2083 2086 2087; do
        if ss -tlnp | grep -q ":${port} " 2>/dev/null; then
            msg_ok "Port ${port}: listening"
        else
            msg_warn "Port ${port}: not listening"
        fi
    done

    # 9. Xray Stats API
    if ss -tlnp | grep -q ":10085 " 2>/dev/null; then
        msg_ok "Xray Stats API (10085): listening"
    else
        msg_warn "Xray Stats API (10085): not listening"
    fi

    # 10. Config directory
    if [[ -d "${CONFIG_DIR}" ]]; then
        msg_ok "Config directory: ${CONFIG_DIR}"
    else
        msg_fail "Config directory missing"
        errors=$((errors + 1))
    fi

    # 11. Menu command
    if [[ -f /usr/local/bin/menu ]] || command -v menu &>/dev/null; then
        msg_ok "Menu command: available"
    else
        msg_warn "Menu command not found (type 'freeflow' instead)"
    fi

    echo ""
    print_line
    if [[ "${errors}" -eq 0 ]]; then
        msg_ok "All checks passed"
    else
        msg_fail "${errors} check(s) failed — review errors above"
    fi
    echo ""

    return "${errors}"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    verify_install
fi
