#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Connection Diagnostic Script
# Run this on VPS when VLESS/VMESS/Trojan connections fail
# Usage: bash /usr/local/lib/freeflow/scripts/core/diagnose.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG_DIR="/etc/freeflow"
XRAY_CONFIG="/etc/xray/config.json"
NGINX_CONF="/etc/nginx/conf.d/freeflow.conf"

ok()   { echo -e " ${GREEN}[OK]${NC}   $1"; }
fail() { echo -e " ${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e " ${YELLOW}[WARN]${NC} $1"; }
info() { echo -e " ${BLUE}[INFO]${NC} $1"; }

ERRORS=0

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     FreeFlow ASVPN — Connection Diagnostic          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. System Info ──
echo -e "${BOLD}[1] System Info${NC}"
info "Hostname: $(hostname)"
info "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
info "Kernel: $(uname -r)"
info "Date: $(date)"
echo ""

# ── 2. Domain & DNS ──
echo -e "${BOLD}[2] Domain & DNS${NC}"
domain=""
if [[ -f "${CONFIG_DIR}/domain" ]]; then
    domain=$(cat "${CONFIG_DIR}/domain")
    ok "Domain configured: ${domain}"
else
    fail "No domain file at ${CONFIG_DIR}/domain"
fi

server_ip=$(curl -s4 --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s4 --connect-timeout 5 ip.sb 2>/dev/null)
if [[ -n "${server_ip}" ]]; then
    ok "Server IP: ${server_ip}"
else
    warn "Could not detect server IP"
fi

if [[ -n "${domain}" ]]; then
    # Try dig first, then host, then getent as fallbacks
    dns_ip=""
    if command -v dig &>/dev/null; then
        dns_ip=$(dig +short "${domain}" A 2>/dev/null | head -1)
    elif command -v host &>/dev/null; then
        dns_ip=$(host -t A "${domain}" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}')
    elif command -v nslookup &>/dev/null; then
        dns_ip=$(nslookup "${domain}" 2>/dev/null | awk '/^Address: / {print $2}' | head -1)
    else
        dns_ip=$(getent ahosts "${domain}" 2>/dev/null | awk '{print $1}' | head -1)
    fi

    if [[ -n "${dns_ip}" ]]; then
        info "DNS resolves to: ${dns_ip}"
        if [[ "${dns_ip}" == "${server_ip}" ]]; then
            ok "DNS points directly to this server (no CDN)"
        else
            warn "DNS points to ${dns_ip} (not this server ${server_ip})"
            info "This is normal if using Cloudflare CDN"
        fi
    else
        fail "DNS resolution failed for ${domain}"
        info "Install dnsutils: apt-get install -y dnsutils"
    fi
fi

cf_mode=""
[[ -f "${CONFIG_DIR}/cf_mode" ]] && cf_mode="yes"
if [[ -n "${cf_mode}" ]]; then
    info "Cloudflare CDN mode: ENABLED"
else
    info "Cloudflare CDN mode: disabled"
fi
echo ""

# ── 3. Xray Service ──
echo -e "${BOLD}[3] Xray Service${NC}"
if command -v xray &>/dev/null; then
    ok "Xray binary: $(xray version 2>/dev/null | head -1)"
else
    fail "Xray binary not found"
fi

if systemctl is-active --quiet xray 2>/dev/null; then
    ok "Xray service: running"
else
    fail "Xray service: NOT running"
    warn "Xray status: $(systemctl is-active xray 2>/dev/null)"
    info "Last 5 lines of xray journal:"
    journalctl -u xray --no-pager -n 5 2>/dev/null | while read -r line; do
        info "  ${line}"
    done
fi

if [[ -f "${XRAY_CONFIG}" ]]; then
    if jq empty "${XRAY_CONFIG}" 2>/dev/null; then
        ok "Xray config: valid JSON"
    else
        fail "Xray config: INVALID JSON"
        info "Error: $(jq empty "${XRAY_CONFIG}" 2>&1)"
    fi
else
    fail "Xray config not found at ${XRAY_CONFIG}"
fi

# Check Xray config test
if command -v xray &>/dev/null && [[ -f "${XRAY_CONFIG}" ]]; then
    if xray run -test -config "${XRAY_CONFIG}" &>/dev/null; then
        ok "Xray config test: passed"
    else
        fail "Xray config test: FAILED"
        xray run -test -config "${XRAY_CONFIG}" 2>&1 | tail -3 | while read -r line; do
            info "  ${line}"
        done
    fi
fi
echo ""

# ── 4. Xray Config Details ──
echo -e "${BOLD}[4] Xray Config Details${NC}"
if [[ -f "${XRAY_CONFIG}" ]] && jq empty "${XRAY_CONFIG}" 2>/dev/null; then
    inbound_count=$(jq '.inbounds | length' "${XRAY_CONFIG}" 2>/dev/null)
    info "Total inbounds: ${inbound_count}"

    # Check each key inbound
    for tag in vless-ws vless-httpupgrade vless-xhttp vless-grpc vmess-ws trojan-ws vless-reality; do
        port=$(jq -r ".inbounds[] | select(.tag==\"${tag}\") | .port" "${XRAY_CONFIG}" 2>/dev/null)
        proto=$(jq -r ".inbounds[] | select(.tag==\"${tag}\") | .protocol" "${XRAY_CONFIG}" 2>/dev/null)
        clients=$(jq ".inbounds[] | select(.tag==\"${tag}\") | .settings.clients | length" "${XRAY_CONFIG}" 2>/dev/null)
        if [[ -n "${port}" && "${port}" != "null" ]]; then
            ok "${tag}: port=${port} proto=${proto} clients=${clients}"
        else
            warn "${tag}: not found in config"
        fi
    done

    # Check VLESS WS path specifically
    ws_path=$(jq -r '.inbounds[] | select(.tag=="vless-ws") | .streamSettings.wsSettings.path' "${XRAY_CONFIG}" 2>/dev/null)
    info "VLESS WS path in Xray: ${ws_path}"

    # Check default UUID
    default_uuid=$(jq -r '.inbounds[] | select(.tag=="vless-ws") | .settings.clients[0].id' "${XRAY_CONFIG}" 2>/dev/null)
    info "Default UUID: ${default_uuid:0:8}...${default_uuid: -4}"
fi
echo ""

# ── 5. Nginx Service ──
echo -e "${BOLD}[5] Nginx Service${NC}"
if command -v nginx &>/dev/null; then
    ok "Nginx binary: $(nginx -v 2>&1)"
else
    fail "Nginx not found"
fi

if systemctl is-active --quiet nginx 2>/dev/null; then
    ok "Nginx service: running"
else
    fail "Nginx service: NOT running"
fi

if nginx -t 2>/dev/null; then
    ok "Nginx config: syntax OK"
else
    fail "Nginx config: syntax ERROR"
    nginx -t 2>&1 | while read -r line; do
        info "  ${line}"
    done
fi

if [[ -f "${NGINX_CONF}" ]]; then
    ok "FreeFlow nginx config exists: ${NGINX_CONF}"
    # Check for vless-ws location
    if grep -q "vless-ws\|10001" "${NGINX_CONF}"; then
        ok "Nginx has vless-ws routing"
    else
        fail "Nginx missing vless-ws location block"
    fi
else
    fail "Nginx config not found: ${NGINX_CONF}"
fi

# Check for conflicting default site
if [[ -f /etc/nginx/sites-enabled/default ]]; then
    warn "Default nginx site still enabled (may conflict)"
fi
echo ""

# ── 6. SSL Certificate ──
echo -e "${BOLD}[6] SSL Certificate${NC}"
if [[ -f /etc/xray/xray.crt && -f /etc/xray/xray.key ]]; then
    ok "SSL cert files exist"
    cert_cn=$(openssl x509 -in /etc/xray/xray.crt -noout -subject 2>/dev/null | sed 's/.*CN = //')
    cert_expiry=$(openssl x509 -in /etc/xray/xray.crt -noout -enddate 2>/dev/null | cut -d= -f2)
    cert_issuer=$(openssl x509 -in /etc/xray/xray.crt -noout -issuer 2>/dev/null | sed 's/.*O = //' | cut -d, -f1)
    info "CN: ${cert_cn}"
    info "Issuer: ${cert_issuer}"
    info "Expires: ${cert_expiry}"
    if echo "${cert_issuer}" | grep -qi "Let's Encrypt\|R3\|R11\|E1\|ISRG"; then
        ok "Certificate: Let's Encrypt (trusted)"
    else
        warn "Certificate: ${cert_issuer} (may be self-signed)"
    fi
else
    fail "SSL certificate files missing"
fi
echo ""

# ── 7. Port Listening ──
echo -e "${BOLD}[7] Port Listening${NC}"
for port in 80 443 8080 8443 8880 2083 2086 2087 700 10001 10002 10003 10004 10005 10006 10007 10008 10010 10085; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        proc=$(ss -tlnp 2>/dev/null | grep ":${port} " | sed 's/.*users:(("//' | cut -d'"' -f1 | head -1)
        ok "Port ${port}: listening (${proc})"
    else
        if [[ "${port}" -le 8880 || "${port}" == "700" ]]; then
            fail "Port ${port}: NOT listening"
        else
            warn "Port ${port}: not listening (internal)"
        fi
    fi
done
echo ""

# ── 8. Firewall ──
echo -e "${BOLD}[8] Firewall Rules${NC}"
for port in 80 443 8080 8443 8880 2083 2086 2087 700; do
    if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:${port}"; then
        ok "iptables: port ${port} ACCEPT"
    else
        warn "iptables: port ${port} not explicitly allowed (may still be open)"
    fi
done
echo ""

# ── 9. WebSocket Test ──
echo -e "${BOLD}[9] WebSocket Connection Test (local)${NC}"
ws_path=$(jq -r '.inbounds[] | select(.tag=="vless-ws") | .streamSettings.wsSettings.path' "${XRAY_CONFIG}" 2>/dev/null)
ws_path="${ws_path:-/vless-ws}"

# Test non-TLS WS on port 80
if [[ -n "${domain}" ]]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Host: ${domain}" \
        "http://127.0.0.1:80${ws_path}" 2>/dev/null)
    if [[ "${http_code}" == "101" ]]; then
        ok "WS upgrade on port 80 ${ws_path}: HTTP ${http_code} (switching protocols)"
    elif [[ "${http_code}" == "400" ]]; then
        warn "WS upgrade on port 80 ${ws_path}: HTTP ${http_code} (bad request — may need full WS handshake)"
    else
        fail "WS upgrade on port 80 ${ws_path}: HTTP ${http_code} (expected 101)"
    fi

    # Test TLS WS on port 8443
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Host: ${domain}" \
        "https://127.0.0.1:8443${ws_path}" 2>/dev/null)
    if [[ "${http_code}" == "101" ]]; then
        ok "WS upgrade on port 8443 ${ws_path}: HTTP ${http_code} (switching protocols)"
    elif [[ "${http_code}" == "400" ]]; then
        warn "WS upgrade on port 8443 ${ws_path}: HTTP ${http_code} (bad request — may need full WS handshake)"
    else
        fail "WS upgrade on port 8443 ${ws_path}: HTTP ${http_code} (expected 101)"
    fi

    # Test decoy page
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:80/" 2>/dev/null)
    info "Decoy page on port 80 /: HTTP ${http_code}"

    # Test direct to Xray port 10001
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        "http://127.0.0.1:10001${ws_path}" 2>/dev/null)
    info "Direct Xray 10001 ${ws_path}: HTTP ${http_code}"
fi
echo ""

# ── 10. Paths Config ──
echo -e "${BOLD}[10] Paths Configuration${NC}"
if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
    ok "paths.conf exists"
    while IFS= read -r line; do
        info "  ${line}"
    done < "${CONFIG_DIR}/paths.conf"
else
    warn "paths.conf not found — using defaults"
fi
echo ""

# ── 11. Xray Access Log ──
echo -e "${BOLD}[11] Recent Xray Access Log${NC}"
if [[ -f /var/log/xray/access.log ]]; then
    log_lines=$(wc -l < /var/log/xray/access.log)
    info "Access log: ${log_lines} lines"
    if [[ "${log_lines}" -gt 0 ]]; then
        info "Last 5 entries:"
        tail -5 /var/log/xray/access.log | while read -r line; do
            info "  ${line}"
        done
    else
        warn "Access log is empty (no connections recorded)"
    fi
else
    warn "Access log not found"
fi

if [[ -f /var/log/xray/error.log ]]; then
    err_lines=$(wc -l < /var/log/xray/error.log)
    if [[ "${err_lines}" -gt 0 ]]; then
        warn "Error log: ${err_lines} lines"
        tail -5 /var/log/xray/error.log | while read -r line; do
            info "  ${line}"
        done
    fi
fi
echo ""

# ── 12. WARP Status ──
echo -e "${BOLD}[12] WARP Status${NC}"
if [[ -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
    warp_method=$(cat "${CONFIG_DIR}/warp/method" 2>/dev/null || echo "unknown")
    info "WARP method: ${warp_method}"
    if [[ "${warp_method}" == "warp-cli" ]]; then
        warp_status=$(warp-cli status 2>/dev/null || echo "warp-cli not available")
        if echo "${warp_status}" | grep -qi "connected"; then
            ok "WARP: connected (warp-cli)"
        else
            warn "WARP: not connected — ${warp_status}"
            info "Try: warp-cli connect"
        fi
        if ss -tlnp 2>/dev/null | grep -q ":40000 "; then
            ok "WARP SOCKS5 proxy: listening on port 40000"
        else
            warn "WARP SOCKS5 proxy: NOT listening on port 40000"
        fi
    elif [[ "${warp_method}" == "wireguard" ]]; then
        if ip link show warp &>/dev/null; then
            ok "WARP WireGuard interface: UP"
        else
            warn "WARP WireGuard interface: DOWN"
            info "Try: wg-quick up warp"
        fi
    fi
    # Check Xray WARP outbound
    if [[ -f "${XRAY_CONFIG}" ]] && jq -e '.outbounds[] | select(.tag=="warp")' "${XRAY_CONFIG}" &>/dev/null; then
        ok "Xray WARP outbound: configured"
    else
        warn "Xray WARP outbound: NOT configured"
    fi
    # Check WARP routed domains
    if [[ -f "${CONFIG_DIR}/warp/domains" && -s "${CONFIG_DIR}/warp/domains" ]]; then
        warp_domains=$(wc -l < "${CONFIG_DIR}/warp/domains")
        info "WARP routed domains: ${warp_domains}"
    else
        info "WARP routed domains: none"
    fi
else
    info "WARP: not installed"
fi
echo ""

# ── 13. Sample Share Link ──
echo -e "${BOLD}[13] Sample Share Link (for testing)${NC}"
if [[ -f "${XRAY_CONFIG}" ]] && jq empty "${XRAY_CONFIG}" 2>/dev/null; then
    uuid=$(jq -r '.inbounds[] | select(.tag=="vless-ws") | .settings.clients[0].id' "${XRAY_CONFIG}" 2>/dev/null)
    if [[ -n "${uuid}" && "${uuid}" != "null" && -n "${domain}" ]]; then
        info "Test with this VLESS WS non-TLS link (port 80):"
        echo -e " ${GREEN}vless://${uuid}@${domain}:80?path=%2Fvless-ws&encryption=none&type=ws&host=${domain}#diag-test${NC}"
        echo ""
        if [[ -n "${server_ip}" ]]; then
            info "Or direct (bypass CDN) — use server IP:"
            echo -e " ${GREEN}vless://${uuid}@${server_ip}:80?path=%2Fvless-ws&encryption=none&type=ws&host=${domain}#diag-direct${NC}"
        fi
    fi
fi
echo ""

# ── Summary ──
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
if [[ "${ERRORS}" -eq 0 ]]; then
    echo -e " ${GREEN}${BOLD}All checks passed — no errors found${NC}"
    echo -e " If connection still fails, try the sample share link above."
    echo -e " If using Cloudflare CDN, ensure:"
    echo -e "   - DNS record is ${YELLOW}Proxied (orange cloud)${NC}"
    echo -e "   - SSL mode: ${YELLOW}Flexible${NC}"
    echo -e "   - Network → WebSockets: ${YELLOW}ON${NC}"
else
    echo -e " ${RED}${BOLD}${ERRORS} error(s) found — see above${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""
