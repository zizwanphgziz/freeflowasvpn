export const vpnCategories = [
  // ─────────────────────────────────────────────
  // SkyNode – added first as a featured installer
  // ─────────────────────────────────────────────
  {
    id: "skynode",
    name: "SkyNode (NevermoreSSH)",
    icon: "🌐",
    color: "#00C8FF",
    tools: [
      {
        id: "skynode-autoscript",
        name: "SkyNode AutoScript",
        icon: "🌐",
        description:
          "AutoScript VPN Xray SSH Websocket Multiport. Includes SSH, Dropbear, Stunnel4, BadVPN, VMESS/VLESS WS+TLS, HTTPUpgrade. Timezone GMT+8, auto-reboot & auto-backup included.",
        recommendedOS: "⭐ Debian 11 / 12 / 13 (Recommended)",
        supportedOS: "Debian 10+ / Ubuntu 20+",
        minRam: "1 GB",
        notes:
          "License key: MNVR7X-M1M3AF-WWV7DT-RJKFQ7-R5V7XE-JWYPO7\nPorts: SSH 22/2222, Dropbear 143/109, WS-HTTP 80/8880, WS-HTTPS 443, VMESS/VLESS 443.\nTested on: AWS, DigitalOcean, Vultr, GBcloud.",
        script:
          "apt update -y && apt upgrade -y && apt dist-upgrade -y && apt install -y screen wget curl && wget https://raw.githubusercontent.com/NevermoreSSH/SkyNode/main/install/setup.sh && chmod +x setup.sh && sed -i -e 's/\\r$//' setup.sh && screen -S setup ./setup.sh",
      },
    ],
  },

  // ─────────────────
  // Xray / V2Ray
  // ─────────────────
  {
    id: "xray",
    name: "Xray / V2Ray",
    icon: "⚡",
    color: "#00D4FF",
    tools: [
      {
        id: "xray-reality",
        name: "Xray VLESS+XTLS-Reality",
        icon: "🔷",
        description: "Most modern & undetectable. XTLS-Reality with Xray-core.",
        recommendedOS: "⭐ Debian 12 / Ubuntu 22.04+",
        supportedOS:
          "CentOS 7+, Debian 8+, Ubuntu 16.04+, openSUSE (systemd required)",
        notes: "Requires systemd. Not compatible with OpenVZ/LXC containers.",
        script:
          'bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install',
      },
      {
        id: "xray-vmess-ws",
        name: "Xray VMess+WS+TLS",
        icon: "🌐",
        description: "WebSocket + TLS tunnel. Works behind CDN (Cloudflare).",
        recommendedOS: "⭐ Debian 12 / Ubuntu 22.04+",
        supportedOS:
          "CentOS 7+, Debian 8+, Ubuntu 16.04+, openSUSE (systemd required)",
        notes: "CDN-friendly. Requires a domain name with a TLS certificate.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)",
      },
      {
        id: "xray-vless-ws",
        name: "Xray VLESS+WS+TLS",
        icon: "🔗",
        description: "VLESS over WebSocket + TLS. CDN-friendly.",
        recommendedOS: "⭐ Debian 12 / Ubuntu 22.04+",
        supportedOS:
          "CentOS 7+, Debian 8+, Ubuntu 16.04+, openSUSE (systemd required)",
        notes:
          "VLESS has no MD5 auth overhead — better performance than VMess.",
        script:
          'bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install',
      },
      {
        id: "3xui",
        name: "3X-UI Panel",
        icon: "🖥️",
        description:
          "Full web panel for Xray. Multi-protocol, multi-user management.",
        recommendedOS: "⭐ Ubuntu 20.04 / 22.04 / Debian 11 / 12",
        supportedOS:
          "Ubuntu 20.04+, Debian 11+, CentOS 8+, Fedora 36+ (x86_64 / arm64)",
        minRam: "512 MB",
        notes:
          "Web panel on port 2053 after install. Supports traffic limits, expiry dates, and Telegram bot.",
        script:
          "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)",
      },
      {
        id: "xui",
        name: "X-UI Panel",
        icon: "📊",
        description: "Classic X-UI panel with Xray-core backend.",
        recommendedOS: "⭐ CentOS 7 / Debian 9 / Ubuntu 18.04",
        supportedOS:
          "CentOS 6-8, Debian 8-10, Ubuntu 16.04-20.04 (x86_64 only)",
        notes:
          "Original panel by vaxilu. For modern systems, use 3X-UI instead.",
        script:
          "bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)",
      },
      {
        id: "marzban",
        name: "Marzban Panel",
        icon: "🎛️",
        description: "Modern Xray panel with REST API & Telegram bot support.",
        recommendedOS: "⭐ Ubuntu 22.04 / Debian 11 or 12",
        supportedOS: "Ubuntu 20.04+, Debian 10+, any systemd Linux",
        minRam: "512 MB",
        notes:
          "Requires Docker for production. REST API + Telegram bot + subscription link generation.",
        script:
          'sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install',
      },
    ],
  },

  // ─────────────────────
  // Trojan / Hysteria
  // ─────────────────────
  {
    id: "trojan",
    name: "Trojan / Hysteria",
    icon: "🐴",
    color: "#A855F7",
    tools: [
      {
        id: "trojan-gfw",
        name: "Trojan-GFW",
        icon: "🛡️",
        description: "Original Trojan, mimics HTTPS to bypass censorship.",
        recommendedOS: "⭐ Debian 10 / Ubuntu 20.04",
        supportedOS: "Debian 8+, Ubuntu 16.04+, CentOS 7+",
        notes:
          "Requires a valid TLS certificate (Let's Encrypt) and a domain name.",
        script:
          'bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"',
      },
      {
        id: "trojan-go",
        name: "Trojan-Go",
        icon: "🚀",
        description: "Trojan-Go with mux & WebSocket support. Written in Go.",
        recommendedOS: "⭐ Debian 11 / Ubuntu 20.04+",
        supportedOS: "Any Linux with systemd (Debian 9+, Ubuntu 18.04+)",
        notes:
          "Supports WebSocket transport — CDN-compatible. More features than original Trojan.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/p4gefau1t/trojan-go/master/install.sh)",
      },
      {
        id: "hysteria2",
        name: "Hysteria2",
        icon: "💨",
        description: "UDP-based protocol. Extreme speed over lossy networks.",
        recommendedOS: "⭐ Debian 12 / Ubuntu 22.04+",
        supportedOS:
          "Any Linux (Debian 10+, Ubuntu 20.04+, CentOS 8+, Alpine 3.15+)",
        notes:
          "QUIC/UDP-based. Firewall must allow UDP. Best for high-latency or lossy connections.",
        script: "bash <(curl -fsSL https://get.hy2.sh/)",
      },
      {
        id: "tuic",
        name: "TUIC v5",
        icon: "🌊",
        description: "QUIC-based proxy protocol. Low-latency & multiplexed.",
        recommendedOS: "⭐ Debian 11+ / Ubuntu 20.04+",
        supportedOS: "Any Linux with kernel 5.x+ (for full QUIC support)",
        notes:
          "Requires UDP open. Best performance on low base-latency networks.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/daeuniverse/dae-installer/main/installer.sh)",
      },
    ],
  },

  // ──────────────
  // WireGuard
  // ──────────────
  {
    id: "wireguard",
    name: "WireGuard",
    icon: "🔒",
    color: "#10B981",
    tools: [
      {
        id: "wireguard-install",
        name: "WireGuard",
        icon: "🔑",
        description:
          "Modern, fast VPN. Minimal codebase, state-of-the-art cryptography.",
        recommendedOS: "⭐ Ubuntu 20.04+ / Debian 11+",
        supportedOS:
          "Ubuntu 16.04+, Debian 9+, CentOS 7+, Fedora 32+, AlmaLinux/Rocky 8+",
        minRam: "256 MB",
        notes:
          "Kernel 5.6+ recommended (or wireguard-dkms). Not compatible with OpenVZ containers.",
        script: "apt install wireguard -y",
      },
      {
        id: "wireguard-easy",
        name: "WireGuard Easy (wg-easy)",
        icon: "🖱️",
        description: "WireGuard + Web UI. Easiest way to run WireGuard.",
        recommendedOS: "⭐ Ubuntu 22.04 / Debian 12 (with Docker)",
        supportedOS:
          "Any Linux that supports Docker (Ubuntu 18.04+, Debian 10+, CentOS 7+)",
        minRam: "512 MB",
        notes:
          "Requires Docker & Docker Compose. Web admin UI runs on port 51821.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/wg-easy/wg-easy/master/install.sh)",
      },
      {
        id: "warp",
        name: "Cloudflare WARP",
        icon: "🧡",
        description: "Add Cloudflare's WARP as outbound for residential IP.",
        recommendedOS: "⭐ Debian 11 / Ubuntu 20.04+",
        supportedOS: "Debian 9+, Ubuntu 18.04+, CentOS 7+",
        notes:
          "Masks VPS IP behind Cloudflare's residential-like IP pool. Great for unlocking geo-blocked content.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/P3TERX/warp.sh/main/warp.sh) warp-go",
      },
    ],
  },

  // ──────────────────
  // Shadowsocks
  // ──────────────────
  {
    id: "shadowsocks",
    name: "Shadowsocks",
    icon: "🌑",
    color: "#F59E0B",
    tools: [
      {
        id: "ss-libev",
        name: "Shadowsocks-libev",
        icon: "🔮",
        description: "Lightweight C implementation. Low memory, fast.",
        recommendedOS: "⭐ Debian 9 / Ubuntu 18.04+",
        supportedOS: "CentOS 7, Debian 7-10, Ubuntu 14.04-20.04",
        minRam: "128 MB",
        notes:
          "Extremely low resource usage. Best for low-end VPS. AEAD encryption only.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev.sh)",
      },
      {
        id: "ss-rust",
        name: "Shadowsocks-rust",
        icon: "⚙️",
        description: "Rust implementation with AEAD encryption support.",
        recommendedOS: "⭐ Debian 11 / Ubuntu 20.04+",
        supportedOS: "Any Linux (Debian 9+, Ubuntu 18.04+, CentOS 7+)",
        minRam: "256 MB",
        notes:
          "Best performance and security. Supports AEAD-2022 ciphers. Actively maintained.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-rust.sh)",
      },
      {
        id: "outline",
        name: "Outline Server (Shadowbox)",
        icon: "🖊️",
        description: "Google-backed Shadowsocks server with management API.",
        recommendedOS: "⭐ Ubuntu 20.04 / Debian 11",
        supportedOS: "Ubuntu 18.04+, Debian 9+, CentOS 7+ (requires Docker)",
        minRam: "512 MB",
        notes:
          "Requires Docker. Managed via Outline Manager desktop app. Easy key sharing.",
        script:
          "bash <(curl -sSL https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)",
      },
    ],
  },

  // ──────────────
  // OpenVPN
  // ──────────────
  {
    id: "openvpn",
    name: "OpenVPN",
    icon: "🌍",
    color: "#EF4444",
    tools: [
      {
        id: "openvpn-install",
        name: "OpenVPN",
        icon: "🔐",
        description: "Classic, widely-compatible VPN. TCP/UDP support.",
        recommendedOS: "⭐ Ubuntu 22.04 / Debian 12",
        supportedOS:
          "Ubuntu 18.04+, Debian 10+, AlmaLinux 8+, Rocky Linux 8+, CentOS 7-8, Fedora 35+",
        minRam: "512 MB",
        notes:
          "Interactive setup wizard. Supports both UDP and TCP modes. Compatible with all major VPN clients.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh)",
      },
      {
        id: "softether",
        name: "SoftEther VPN",
        icon: "🏗️",
        description: "Multi-protocol VPN server. L2TP, OpenVPN, SSTP support.",
        recommendedOS: "⭐ Ubuntu 20.04 / Debian 11",
        supportedOS: "Debian 8+, Ubuntu 16.04+, CentOS 7+",
        minRam: "512 MB",
        notes:
          "Supports L2TP/IPsec, OpenVPN, SSTP, and SoftEther native protocol. Great for client compatibility.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/SoftEtherVPN/SoftEtherVPN/master/install.sh)",
      },
    ],
  },

  // ────────────────────
  // Panels & Tools
  // ────────────────────
  {
    id: "panel-tools",
    name: "Panels & Tools",
    icon: "🛠️",
    color: "#6366F1",
    tools: [
      {
        id: "naive",
        name: "NaiveProxy",
        icon: "🎭",
        description: "Uses Chrome network stack to mimic browser traffic.",
        recommendedOS: "⭐ Debian 11 / Ubuntu 20.04+",
        supportedOS: "Any Linux with systemd (Debian 9+, Ubuntu 18.04+)",
        notes:
          "Hardest to detect — mimics real Chrome TLS fingerprint. Requires Caddy server.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/klzgrad/naiveproxy/master/src/net/tools/naive/naive.go)",
      },
      {
        id: "bbr",
        name: "BBR / BBRv3 Acceleration",
        icon: "🏎️",
        description: "Enable Google's BBR congestion control for faster TCP.",
        recommendedOS: "⭐ Any Linux (kernel 4.9+)",
        supportedOS:
          "Debian 9+, Ubuntu 18.04+, CentOS 7+ (requires kernel 4.9+)",
        notes:
          "Dramatically improves TCP throughput. Safe on any production server. Highly recommended.",
        script:
          "bash <(curl -fsSL https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)",
      },
      {
        id: "haproxy",
        name: "HAProxy Load Balancer",
        icon: "⚖️",
        description: "Reverse proxy and load balancer for multi-server setups.",
        recommendedOS: "⭐ Debian 11 / Ubuntu 20.04+",
        supportedOS: "Debian 9+, Ubuntu 18.04+, CentOS 7+, AlmaLinux 8+",
        notes:
          "Installs via apt. Great for distributing traffic across multiple VPS nodes.",
        script: "apt update && apt install haproxy -y",
      },
      {
        id: "nezha",
        name: "Nezha Monitoring",
        icon: "📡",
        description: "Lightweight VPS monitoring agent with web dashboard.",
        recommendedOS: "⭐ Any Linux (Debian 10+ / Ubuntu 20.04+)",
        supportedOS:
          "Any Linux (Debian, Ubuntu, CentOS, Alpine, Arch) + FreeBSD, macOS",
        notes:
          "Agent is minimal (~10 MB). Sends stats to central Nezha dashboard. Supports Telegram alerts.",
        script:
          "curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh",
      },
      {
        id: "certbot",
        name: "Certbot SSL (Let's Encrypt)",
        icon: "🔏",
        description: "Free SSL certificates from Let's Encrypt via Certbot.",
        recommendedOS: "⭐ Ubuntu 20.04+ / Debian 11+",
        supportedOS: "Ubuntu 18.04+, Debian 9+, CentOS 7+, Fedora, Alpine",
        notes:
          "Run standalone mode (port 80 must be free). Auto-renew supported via cron.",
        script: "apt install certbot -y && certbot certonly --standalone",
      },
    ],
  },
];
