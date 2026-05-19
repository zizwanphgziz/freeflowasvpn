# FreeFlow Auto Script VPN — All In One

The most complete all-in-one autoscript VPN combining the best features from all major VPN scripts.

## Supported OS

| OS | Versions |
|---|---|
| Ubuntu | 18.04, 20.04, 22.04, 24.04, 26.04 |
| Debian | 9, 10, 11, 12, 13 |

## Architecture

```
Internet → Nginx (reverse proxy, multiport)
              ├── VLESS WebSocket     → Xray (internal)
              ├── VLESS HttpUpgrade   → Xray (internal)
              ├── VLESS XHTTP         → Xray (internal)
              ├── VLESS gRPC          → Xray (internal)
              ├── VMESS WebSocket     → Xray (internal)
              ├── VMESS gRPC          → Xray (internal)
              ├── Trojan WebSocket    → Xray (internal)
              ├── Trojan gRPC         → Xray (internal)
              ├── SSH WebSocket       → SSH-WS Proxy (internal)
              └── Decoy Page          → Static HTML

         VLESS Reality (XTLS)     → Xray (direct, port 443)
         Trojan TCP               → Xray (via Reality fallback)
```

Nginx handles all public ports and SSL termination. Xray runs on internal localhost ports only. No port conflicts with other services. VLESS Reality uses direct XTLS connection bypassing Nginx for maximum performance.

## Features

### Protocols
- **VLESS**: WebSocket, HttpUpgrade, XHTTP, gRPC, XTLS Reality — all with multiport and multipath support
- **VMESS**: WebSocket, gRPC — multiport and multipath
- **Trojan**: WebSocket, gRPC, TCP TLS — multiport and multipath

### Modules
- **SSH WebSocket**: Optional install/uninstall
- **WARP Cloudflare**: Domain bypass via Xray native WireGuard (wgcf) — no external daemon needed
- **Ads Blocker**: DNS-level ad blocking — install/uninstall

### User Management
- **Custom UUID**: Use a custom name (e.g., 'Ahmad') or random UUID
- **User Lifecycle**: Create, renew, expire (block without delete), reactivate, delete
- **Trial Accounts**: Auto-generate temporary trial accounts (VLESS/VMESS/Trojan)
- **Data Usage Tracking**: Per-user upload/download/total tracking with data limits
- **Check Online Users**: See who is currently connected
- **YAML Config Generator**: Generate ready-made Clash/Mihomo YAML configs
- **Share Link / WSS Converter**: Generate vless://, vmess://, trojan:// share links

### System Tools
- **Auto Update**: Online auto-update from this GitHub repo, or manual update option
- **Telegram Bot**: Full menu control via Telegram bot (all 46 options)
- **Telegram Auto Backup**: Scheduled automatic backup sent to Telegram
- **Auto Reboot**: Configurable daily auto reboot
- **Auto Clear Log**: Scheduled log cleanup
- **DNS Changer**: Change VPS DNS on-the-fly (Google, Cloudflare, OpenDNS, Quad9, custom)
- **Netflix Region Checker**: Detect which Netflix region your VPS IP unlocks
- **RAM Monitor**: Real-time RAM usage and per-service memory breakdown
- **Backup/Restore**: User data backup and restore
- **BBR**: TCP congestion control optimization
- **Speedtest**: Built-in server speed test

## Port Info

```
Service              TLS Ports            Non-TLS Ports
─────────────────────────────────────────────────────────
VLESS WebSocket      443,8443,2083,2087   80,8080,8880,2086
VLESS HttpUpgrade    443,8443,2083,2087   80,8080,8880,2086
VLESS XHTTP          443,8443,2083,2087   80,8080,8880,2086
VLESS gRPC           443,8443,2083,2087   80,8080,8880,2086
VLESS Reality        443 (direct XTLS)
VMESS WebSocket      443,8443,2083,2087   80,8080,8880,2086
VMESS gRPC           443,8443,2083,2087   80,8080,8880,2086
Trojan WebSocket     443,8443,2083,2087   80,8080,8880,2086
Trojan gRPC          443,8443,2083,2087   80,8080,8880,2086
Trojan TCP           443 (via Reality)
SSH WebSocket        Via Nginx path /ssh
```

## Cloudflare Settings

```
SSL/TLS            : FULL
WebSocket          : ON
Always Use HTTPS   : OFF
```

## Installation

```bash
apt update && apt install wget -y
wget -qO setup.sh https://raw.githubusercontent.com/zizwanphgziz/freeflowasvpn/init-branch/setup.sh
chmod +x setup.sh
./setup.sh
```

## After Installation

Type `freeflow` or `menu` to open the main menu (46 options).

## Menu Options

**VLESS** — Add/Delete/Renew/Reactivate users, list active/expired
**VMESS** — Add/Delete/Renew/Reactivate users, list active/expired
**Trojan** — Add/Delete/Renew/Reactivate users, list active/expired
**User Tools** — Data usage, online users, trial accounts, YAML generator, share links
**SSH** — Add/Delete/List SSH users, install/uninstall SSH WebSocket
**Modules** — WARP install/uninstall + domain routing, Ads Blocker
**Server** — Restart services, Xray config check, logs, speedtest, bandwidth, RAM monitor, domain change, SSL renewal, DNS changer, Netflix checker
**System** — Update script, auto-update, auto-reboot, auto-clear log, Telegram bot, Telegram auto backup, system info, backup/restore

## Credits

Built by FreeFlow. Inspired by the best VPN scripts in the community.
