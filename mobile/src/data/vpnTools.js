export const vpnCategories = [
  // ─────────────────────────────────────────────
  // VPN Autoscript Installers – community AIO bundles
  // (Ported from freeflowonelinerrebuildvps repo)
  // ─────────────────────────────────────────────
  {
    id: "autoscript",
    name: "VPN Autoscript Installers",
    icon: "🌐",
    color: "#8B5CF6",
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
      {
        id: "vpn-install-dotycat",
        name: "Dotycat Tunnel",
        icon: "🐱",
        description:
          "VLESS/VMess/Trojan WS/gRPC/xHTTP + SSH WS + OpenVPN. Active 2026, 28 stars.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. If you already have another autoscript installed, rebuild your VPS first.",
        script:
          "apt update && apt upgrade -y && apt install -y git wget curl unzip && wget -O /root/install.sh https://raw.githubusercontent.com/dotywrt/doty/main/install.sh && chmod +x /root/install.sh && /root/install.sh",
      },
      {
        id: "vpn-install-vinstech-lite",
        name: "Vinstech Lite",
        icon: "⚡",
        description:
          "VMess/VLess/Trojan WS & gRPC. Popular in MY. 30 stars.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. Requires domain pointed to VPS IP.",
        script:
          "sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl && wget https://raw.githubusercontent.com/vinstechmy/AutoscriptWebsocketLite/main/V1/setup-lite.sh && chmod +x setup-lite.sh && screen -S vinstech ./setup-lite.sh",
      },
      {
        id: "vpn-install-vinstech-minix",
        name: "Vinstech MiniXLite",
        icon: "⚡",
        description:
          "VLess/Trojan WS + TCP XTLS. Trial accounts, Telegram backup. 16 stars.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. Requires domain pointed to VPS IP.",
        script:
          "sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl && wget https://raw.githubusercontent.com/vinstechmy/MiniXLiteAutoscript/main/V1/setup.sh && chmod +x setup.sh && screen -S vinstech ./setup.sh",
      },
      {
        id: "vpn-install-vinstech-multi",
        name: "Vinstech Multiport",
        icon: "⚡",
        description:
          "SSH WS + VMess/VLess/Trojan WS multiport. 8 stars.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. Requires domain pointed to VPS IP.",
        script:
          "sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl && wget https://raw.githubusercontent.com/vinstechmy/SSH-XRAY-Websocket-Multiport/main/setup.sh && chmod +x setup.sh && screen -S vinstech ./setup.sh",
      },
      {
        id: "vpn-install-decode",
        name: "Decode Reality",
        icon: "🔍",
        description:
          "VLess-only (Reality). TLS/gRPC/HttpUpgrade/xHTTP. Clean & focused. New 2026.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. VLess protocol only.",
        script:
          "wget -q https://raw.githubusercontent.com/DecodeXOfficial/Reality/main/setup.sh -O setup.sh && chmod +x setup.sh && screen -S decode ./setup.sh",
      },
      {
        id: "vpn-install-rerechan",
        name: "FN Project (Rerechan)",
        icon: "🌍",
        description:
          "VMess/VLess/Trojan + NoobzVPN + SlowDNS + UDP Custom. ALL OS support. 23 stars.",
        supportedOS: "ALL Linux distros",
        notes:
          "Only run on a FRESH VPS. Supports ALL Linux distros.",
        script:
          "apt update && apt install wget curl screen gnupg openssl perl binutils -y && wget -O install.sh \"https://codeberg.org/Rerechan02/scvps-stable/raw/branch/main/install.sh\" && chmod +x install.sh && screen -S fn ./install.sh",
      },
      {
        id: "vpn-install-darqan",
        name: "DarQan Script",
        icon: "📜",
        description:
          "SSH WS + VLess WS only. IP limit, data limit, user recovery. Debian 11/12.",
        recommendedOS: "⭐ Debian 11 / 12",
        supportedOS: "Debian 11 / 12 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 11/12). Run `apt full-upgrade -y && reboot` first.",
        script:
          "apt update ; apt install wget curl openssl perl screen -y ; wget -q https://raw.githubusercontent.com/darul-itqan/Auto-Script-VPS-SSH-WS-VLESS-WS/main/install.sh ; chmod +x install.sh ; screen -S rere ./install.sh",
      },
      {
        id: "vpn-install-gegevps",
        name: "GegeVPS",
        icon: "🖥️",
        description:
          "SSH/OpenVPN/Xray/WireGuard + SlowDNS + UDP Custom. Cloudflare auto-DNS. 54 stars.",
        supportedOS: "Fresh VPS + Cloudflare domain",
        notes:
          "Only run on a FRESH VPS. Requires Cloudflare domain.",
        script:
          "apt update && apt install -y wget curl screen && wget https://raw.githubusercontent.com/GegeDevs/sshvpn-script/main/setup.sh && chmod +x setup.sh && screen -S gege ./setup.sh",
      },
      {
        id: "vpn-install-kingkong",
        name: "KingKongVPN",
        icon: "🦍",
        description:
          "SSH/OpenVPN/Stunnel/Xray Multiport/WireGuard. Webmin panel. 163 stars.",
        recommendedOS: "⭐ Debian 10 / Ubuntu 18-20",
        supportedOS: "Debian 10 / Ubuntu 18-20 (fresh)",
        notes: "Only run on a FRESH VPS (Debian 10/Ubuntu 18-20).",
        script:
          "wget https://raw.githubusercontent.com/xiihaiqal/AutoScriptVPS/master/AutoScript && bash AutoScript",
      },
      {
        id: "vpn-install-netzxray",
        name: "Netz-Xray (110 Contributors)",
        icon: "👥",
        description:
          "Xray only: VMess/VLess/Trojan/SS WS & gRPC. Dynamic path. 142 stars.",
        recommendedOS: "⭐ Debian 10 / Ubuntu 20",
        supportedOS: "Debian 10 / Ubuntu 20 (fresh)",
        notes: "Only run on a FRESH VPS (Debian 10/Ubuntu 20).",
        script:
          "wget -q https://raw.githubusercontent.com/adisubagja/AutoScriptXray/master/adi.sh && chmod +x adi.sh && screen -S netzinstall ./adi.sh",
      },
      {
        id: "vpn-install-givpn",
        name: "GIVPN",
        icon: "🔒",
        description:
          "VMess/VLess/Trojan/SS WS & gRPC + SSH WS + OpenVPN. 49 stars.",
        supportedOS: "Fresh VPS only",
        notes: "Only run on a FRESH VPS.",
        script:
          "apt update && apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/givpn/AutoScriptXray/master/setup.sh && chmod +x setup.sh && screen -S givpn ./setup.sh",
      },
      {
        id: "vpn-install-farelvpn",
        name: "FarellVPN (Modern)",
        icon: "💻",
        description:
          "VMess/VLess/Trojan + Web API + Telegram bot + Quota management. Python+Go.",
        supportedOS: "Fresh VPS only",
        notes:
          "Only run on a FRESH VPS. Has REST API for remote management.",
        script:
          "apt update && apt install -y wget curl screen && wget https://raw.githubusercontent.com/farelvpn/autoscript/main/setup.sh && chmod +x setup.sh && screen -S farel ./setup.sh",
      },
      {
        id: "vpn-install-mantap",
        name: "SL Mantap AIO",
        icon: "💪",
        description:
          "SSH/OHP/Stunnel5/OpenVPN/Xray/SS/SSR/WireGuard/Trojan-Go. 209 stars.",
        recommendedOS: "⭐ Debian 9-10 / Ubuntu 18-20",
        supportedOS: "Debian 9-10 / Ubuntu 18-20 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 9-10/Ubuntu 18-20).",
        script:
          "wget https://raw.githubusercontent.com/fisabiliyusri/Mantap/main/setup.sh && chmod +x setup.sh && ./setup.sh",
      },
      {
        id: "vpn-install-praiman",
        name: "PR Aiman AIO (13+ Protocols)",
        icon: "🏆",
        description:
          "SSH/OpenVPN/Xray/Trojan/SS/SSR/WireGuard/SSTP/L2TP/PPTP. Most protocols.",
        recommendedOS: "⭐ Debian 9-10",
        supportedOS: "Debian 9-10 (fresh)",
        notes: "Only run on a FRESH VPS (Debian 9-10).",
        script:
          "apt install -y bzip2 gzip coreutils curl && wget https://raw.githubusercontent.com/praiman99/AutoScriptVPN-AIO/Beginner/setup.sh && chmod +x setup.sh && ./setup.sh",
      },
      {
        id: "vpn-install-scvps",
        name: "SCVPS AIO",
        icon: "🖥️",
        description:
          "SSH/Xray/WireGuard/Trojan-Go/SSR/L2TP. Theme menu, admin panel. 92 stars.",
        recommendedOS: "⭐ Debian 10 / Ubuntu 18-20",
        supportedOS: "Debian 10 / Ubuntu 18-20 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 10/Ubuntu 18-20).",
        script:
          "apt update && apt upgrade -y && apt install -y wget screen && wget -q https://raw.githubusercontent.com/scvps/scriptvps/main/setup.sh && chmod +x setup.sh && screen -S setup ./setup.sh",
      },
      {
        id: "vpn-install-caliph",
        name: "Caliph Dev",
        icon: "🏰",
        description:
          "Xray (VMess/VLess/Trojan/SS) WS & gRPC + SSH WS. No IP registration. 7 stars.",
        recommendedOS: "⭐ Debian 11-12 / Ubuntu 20-22",
        supportedOS: "Debian 11-12 / Ubuntu 20-22 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 11-12/Ubuntu 20-22).",
        script:
          "apt update && apt install -y wget curl screen && wget https://raw.githubusercontent.com/cabrata/autoscript/master/setup.sh && chmod +x setup.sh && screen -S caliph ./setup.sh",
      },
      {
        id: "vpn-install-233boy",
        name: "233boy Xray (2.2K Stars)",
        icon: "⭐",
        description:
          "VLESS Reality/VMess/Trojan/SS2022. Best CLI manager. Chinese community.",
        supportedOS: "Works on existing VPS",
        notes:
          "Works on existing VPS. Manage via `xray` command after install.",
        script:
          "bash <(wget -qO- https://raw.githubusercontent.com/233boy/Xray/main/install.sh)",
      },
      {
        id: "vpn-install-jinwyp",
        name: "One Click Script (5.1K Stars)",
        icon: "🌟",
        description:
          "V2Ray/Xray/Trojan-Go/WireGuard/SS + BBR kernel. Most starred. Chinese community.",
        supportedOS: "Works on existing VPS",
        notes:
          "Interactive menu. Works on existing VPS but may conflict with other scripts.",
        script:
          "wget -O setup.sh https://raw.githubusercontent.com/jinwyp/one_click_script/master/install_v2ray.sh && bash setup.sh",
      },
      {
        id: "vpn-install-afandiazmi",
        name: "afandiazmi 8-in-1",
        icon: "📦",
        description:
          "VLESS/VMess/Trojan 8 combo (TCP/WS/gRPC + TLS/XTLS). Xray & V2Ray core. 39 stars.",
        supportedOS: "Fresh VPS only",
        notes: "Only run on a FRESH VPS.",
        script:
          "apt update && apt install -y wget curl screen && wget https://raw.githubusercontent.com/afandiazmi/v2RayVPN/main/setup.sh && chmod +x setup.sh && screen -S afandi ./setup.sh",
      },
      {
        id: "vpn-install-senovpn",
        name: "SenoVPN",
        icon: "🖥️",
        description:
          "SSH/OHP/OpenVPN/Stunnel5/Xray/SSR/WireGuard/Trojan-Go/SSTP/L2TP/PPTP. 61 stars.",
        recommendedOS: "⭐ Debian 10 / Ubuntu 18-20",
        supportedOS: "Debian 10 / Ubuntu 18-20 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 10/Ubuntu 18-20).",
        script:
          "rm -f setup.sh && sysctl -w net.ipv6.conf.all.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/senowahyu62/scriptvps/main/setup.sh && chmod +x setup.sh && ./setup.sh",
      },
      {
        id: "vpn-install-rascom",
        name: "RasCom AIO",
        icon: "📡",
        description:
          "SSH/OpenVPN/V2Ray/Trojan/Trojan-Go/SS/SSR/WireGuard/SSTP/L2TP/PPTP. Telegram bot. 13 stars.",
        recommendedOS: "⭐ Debian 9-10 / Ubuntu 18-20",
        supportedOS: "Debian 9-10 / Ubuntu 18-20 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 9-10/Ubuntu 18-20).",
        script:
          "apt update && apt install -y wget curl screen && wget https://raw.githubusercontent.com/myskynblack/aioscvps/main/setup.sh && chmod +x setup.sh && screen -S rascom ./setup.sh",
      },
      {
        id: "vpn-install-givps-tor",
        name: "GIVPS + Tor",
        icon: "🕵️",
        description:
          "Xray/SSH WS/Stunnel/OpenVPN + Tor integration for anonymity. 16 stars.",
        recommendedOS: "⭐ Debian 11-12 / Ubuntu 18-22",
        supportedOS: "Debian 11-12 / Ubuntu 18-22 (fresh)",
        notes:
          "Only run on a FRESH VPS (Debian 11-12/Ubuntu 18-22).",
        script:
          "apt update && apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/givps/AutoScriptXray/master/setup.sh && chmod +x setup.sh && screen -S setup ./setup.sh",
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
