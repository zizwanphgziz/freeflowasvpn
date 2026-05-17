#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Netflix Region Checker
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

check_netflix_region() {
    print_section "Netflix Region Checker"

    msg_info "Checking Netflix region for this VPS IP..."

    local result
    result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "https://www.netflix.com/title/81280792" 2>/dev/null)

    local ip_info
    ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/" 2>/dev/null)

    local country city isp ip_addr
    country=$(echo "${ip_info}" | jq -r '.country // "Unknown"' 2>/dev/null)
    city=$(echo "${ip_info}" | jq -r '.city // "Unknown"' 2>/dev/null)
    isp=$(echo "${ip_info}" | jq -r '.isp // "Unknown"' 2>/dev/null)
    ip_addr=$(echo "${ip_info}" | jq -r '.query // "Unknown"' 2>/dev/null)

    echo -e " ${CYAN}IP Address${NC} : ${ip_addr}"
    echo -e " ${CYAN}Country${NC}    : ${country}"
    echo -e " ${CYAN}City${NC}       : ${city}"
    echo -e " ${CYAN}ISP${NC}        : ${isp}"
    echo ""

    case "${result}" in
        200)
            msg_ok "Netflix: ${GREEN}Available${NC} — Full library access (${country})"
            ;;
        301|302|307)
            msg_ok "Netflix: ${YELLOW}Available${NC} — Region-locked content (${country})"
            ;;
        403)
            msg_fail "Netflix: ${RED}Blocked${NC} — This IP is blocked by Netflix"
            ;;
        404)
            msg_warn "Netflix: ${YELLOW}Partial${NC} — Self-produced content only"
            ;;
        *)
            msg_warn "Netflix: ${YELLOW}Unknown${NC} — HTTP ${result}"
            ;;
    esac

    # Check additional streaming services
    echo ""
    msg_info "Checking other streaming services..."

    local disney_result
    disney_result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        "https://www.disneyplus.com/" 2>/dev/null)
    if [[ "${disney_result}" == "200" ]] || [[ "${disney_result}" == "301" ]]; then
        echo -e "   ${GREEN}●${NC} Disney+: Available"
    else
        echo -e "   ${RED}●${NC} Disney+: Unavailable (HTTP ${disney_result})"
    fi

    local youtube_result
    youtube_result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        "https://www.youtube.com/premium" 2>/dev/null)
    if [[ "${youtube_result}" == "200" ]] || [[ "${youtube_result}" == "303" ]]; then
        echo -e "   ${GREEN}●${NC} YouTube Premium: Available"
    else
        echo -e "   ${RED}●${NC} YouTube Premium: Unavailable"
    fi

    print_line
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_netflix_region
fi
