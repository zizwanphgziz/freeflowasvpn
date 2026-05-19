#!/bin/bash
# ============================================================
# FreeFlow ASVPN - DNS Changer
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

change_dns() {
    print_section "DNS Changer"

    echo -e " Current DNS servers:"
    grep "^nameserver" /etc/resolv.conf | while read -r line; do
        echo -e "   ${CYAN}${line}${NC}"
    done
    echo ""

    echo -e " ${BOLD}Select DNS Provider:${NC}"
    echo -e "  ${GREEN}1${NC}. Google DNS (8.8.8.8, 8.8.4.4)"
    echo -e "  ${GREEN}2${NC}. Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    echo -e "  ${GREEN}3${NC}. Cloudflare Malware (1.1.1.2, 1.0.0.2)"
    echo -e "  ${GREEN}4${NC}. Cloudflare Family (1.1.1.3, 1.0.0.3)"
    echo -e "  ${GREEN}5${NC}. OpenDNS (208.67.222.222, 208.67.220.220)"
    echo -e "  ${GREEN}6${NC}. Quad9 (9.9.9.9, 149.112.112.112)"
    echo -e "  ${GREEN}7${NC}. Custom DNS"
    echo -e "  ${GREEN}8${NC}. Back"
    echo ""
    read -rp " Choose: " choice

    local dns1="" dns2=""
    case "${choice}" in
        1) dns1="8.8.8.8"; dns2="8.8.4.4" ;;
        2) dns1="1.1.1.1"; dns2="1.0.0.1" ;;
        3) dns1="1.1.1.2"; dns2="1.0.0.2" ;;
        4) dns1="1.1.1.3"; dns2="1.0.0.3" ;;
        5) dns1="208.67.222.222"; dns2="208.67.220.220" ;;
        6) dns1="9.9.9.9"; dns2="149.112.112.112" ;;
        7)
            read -rp " Primary DNS: " dns1
            read -rp " Secondary DNS: " dns2
            ;;
        8) return ;;
        *) msg_warn "Invalid option"; return ;;
    esac

    if [[ -z "${dns1}" ]]; then
        msg_fail "DNS address cannot be empty"
        return 1
    fi

    # Backup
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null

    # Write new resolv.conf
    {
        echo "nameserver ${dns1}"
        [[ -n "${dns2}" ]] && echo "nameserver ${dns2}"
    } > /etc/resolv.conf

    # Also update resolvconf if available
    if [[ -d /etc/resolvconf/resolv.conf.d ]]; then
        {
            echo "nameserver ${dns1}"
            [[ -n "${dns2}" ]] && echo "nameserver ${dns2}"
        } > /etc/resolvconf/resolv.conf.d/head
        systemctl restart resolvconf 2>/dev/null
    fi

    msg_ok "DNS changed to ${dns1} / ${dns2}"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    change_dns
fi
