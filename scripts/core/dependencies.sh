#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Dependency Installation
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_base_packages() {
    print_section "Installing Base Packages"

    apt-get update -y
    apt-get install -y \
        wget curl openssl sudo coreutils gnupg bc \
        lsof socat unzip zip jq htop net-tools \
        cron vnstat python3 certbot \
        binutils screen

    if command -v apt-get &>/dev/null; then
        msg_ok "Base packages installed"
    else
        msg_fail "Package installation failed"
        return 1
    fi
}

install_optional_packages() {
    print_section "Installing Optional Packages"

    # Speedtest CLI
    if ! command -v speedtest &>/dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
        apt-get install -y speedtest 2>/dev/null
        if command -v speedtest &>/dev/null; then
            msg_ok "Speedtest CLI installed"
        else
            msg_warn "Speedtest CLI installation failed (non-critical)"
        fi
    else
        msg_ok "Speedtest CLI already installed"
    fi

    # vnstat for bandwidth monitoring
    if ! command -v vnstat &>/dev/null; then
        apt-get install -y vnstat
        systemctl enable vnstat
        systemctl start vnstat
        msg_ok "vnstat installed"
    else
        msg_ok "vnstat already installed"
    fi
}

setup_dns() {
    print_section "Configuring DNS"

    # Backup current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null

    # Add Google and Cloudflare DNS
    if ! grep -q "8.8.8.8" /etc/resolv.conf; then
        {
            echo "nameserver 8.8.8.8"
            echo "nameserver 1.1.1.1"
            cat /etc/resolv.conf
        } > /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
    fi

    msg_ok "DNS configured (8.8.8.8, 1.1.1.1)"
}

setup_timezone() {
    print_section "Setting Timezone"

    # Auto-set timezone — no prompt during install
    local tz="Asia/Kuala_Lumpur"

    if timedatectl set-timezone "${tz}" 2>/dev/null; then
        msg_ok "Timezone set to ${tz}"
    else
        msg_warn "Could not set timezone to ${tz}"
    fi
}

setup_swap() {
    print_section "Setting Up Swap"

    local total_ram
    total_ram=$(free -m | awk '/^Mem:/{print $2}')

    if [[ -f /swapfile ]]; then
        msg_info "Swap file already exists"
        return 0
    fi

    local swap_size
    if [[ "${total_ram}" -le 1024 ]]; then
        swap_size="2G"
    elif [[ "${total_ram}" -le 2048 ]]; then
        swap_size="4G"
    else
        swap_size="4G"
    fi

    msg_info "Creating ${swap_size} swap file..."
    fallocate -l "${swap_size}" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="${swap_size%G}000" 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi

    msg_ok "Swap ${swap_size} created and enabled"
}

setup_bbr() {
    print_section "Enabling BBR Congestion Control"

    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        msg_ok "BBR already enabled"
        return 0
    fi

    cat >> /etc/sysctl.conf <<EOF
# BBR Congestion Control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p &>/dev/null
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        msg_ok "BBR enabled"
    else
        msg_warn "BBR could not be enabled (kernel may not support it)"
    fi
}

install_all_dependencies() {
    setup_dns
    install_base_packages
    install_optional_packages
    setup_swap
    setup_bbr
    setup_timezone
    msg_ok "All dependencies installed"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    install_all_dependencies
fi
