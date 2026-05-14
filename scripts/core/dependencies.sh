#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Dependency Installation
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_base_packages() {
    print_section "Installing Base Packages"

    export DEBIAN_FRONTEND=noninteractive
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

setup_firewall() {
    print_section "Configuring Firewall"

    # Pre-seed iptables-persistent to avoid interactive prompts
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections 2>/dev/null
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections 2>/dev/null

    # Install iptables if not present
    apt-get install -y iptables iptables-persistent > /dev/null 2>&1

    # Open required ports
    local ports=("22" "80" "443" "700" "8080" "8443" "8880" "2083" "2086" "2087" "10001" "10002" "10003" "10004" "10005" "10006" "10007" "10008" "10010" "10085")
    for port in "${ports[@]}"; do
        iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null
    done

    # Save iptables rules
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save 2>/dev/null
    elif [[ -f /etc/iptables/rules.v4 ]]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi

    # If ufw is installed, open ports via ufw too
    if command -v ufw &>/dev/null; then
        for port in "${ports[@]}"; do
            ufw allow "${port}/tcp" > /dev/null 2>&1
        done
        echo "y" | ufw enable 2>/dev/null
    fi

    msg_ok "Firewall configured (all VPN ports open)"
}

install_all_dependencies() {
    setup_dns
    install_base_packages
    install_optional_packages
    setup_firewall
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
