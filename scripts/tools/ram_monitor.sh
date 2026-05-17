#!/bin/bash
# ============================================================
# FreeFlow ASVPN - RAM Monitor
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

show_ram_usage() {
    print_section "RAM Usage Monitor"

    echo -e " ${BOLD}Memory Overview${NC}"
    print_line
    free -h
    echo ""

    print_line
    echo -e " ${BOLD}Top Processes by Memory${NC}"
    print_line
    ps aux --sort=-%mem | head -11 | awk 'NR==1{printf " %-8s %-6s %-6s %s\n", "USER", "%MEM", "RSS", "COMMAND"} NR>1{printf " %-8s %-6s %-6s %s\n", $1, $4, $6, $11}'
    echo ""

    # Service-specific usage
    print_line
    echo -e " ${BOLD}FreeFlow Service Memory${NC}"
    print_line
    for svc in xray nginx ssh-ws freeflow-bot; do
        local pid mem_kb
        pid=$(systemctl show --property=MainPID --value "${svc}" 2>/dev/null)
        if [[ -n "${pid}" ]] && [[ "${pid}" != "0" ]]; then
            mem_kb=$(ps --no-headers -o rss -p "${pid}" 2>/dev/null | tr -d ' ')
            if [[ -n "${mem_kb}" ]]; then
                local mem_mb
                mem_mb=$(echo "scale=1; ${mem_kb}/1024" | bc)
                echo -e "   ${GREEN}●${NC} ${svc}: ${mem_mb} MB"
            fi
        else
            echo -e "   ${YELLOW}○${NC} ${svc}: not running"
        fi
    done
    print_line
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    show_ram_usage
fi
