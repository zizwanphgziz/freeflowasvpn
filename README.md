# FreeFlow Auto Script VPN — All In One

The most complete all-in-one autoscript VPN combining the best features from all major VPN scripts.

## Supported OS

| OS | Versions |
|---|---|
| Ubuntu | 18.04, 20.04, 22.04, 24.04 |
| Debian | 9, 10, 11, 12 |

## Architecture

```
Internet → Nginx (reverse proxy, multiport)
              ├── VLESS WebSocket     → Xray (internal)
              ├── VLESS HttpUpgrade   → Xray (internal)
              ├── VLESS XHTTP         → Xray (internal)
              ├── SSH WebSocket       → SSH-WS Proxy (internal)
              └── Decoy Page          → Static HTML
```

Nginx handles all public ports and SSL termination. Xray runs on internal localhost ports only. No port conflicts with other services.

## Features

- **VLESS Protocol**: WebSocket, HttpUpgrade, XHTTP — all with multiport and multipath support
- **SSH WebSocket**: Optional install/uninstall
- **WARP Cloudflare**: Bypass domains via Cloudflare's network — install/uninstall
- **Custom UUID**: Use a custom name (e.g., 'Ahmad') or random UUID
- **User Management**: Create, renew, expire (block without delete), reactivate, delete
- **Data Usage Tracking**: Per-user upload/download/total tracking with data limits
- **Auto Update**: Online auto-update from this GitHub repo, or manual update option
- **Telegram Bot**: Full menu control via Telegram bot
- **Auto Reboot**: Configurable daily auto reboot
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

Type `freeflow` or `menu` to open the main menu.

## Menu Options

1. Add/Delete/Renew/Reactivate VLESS users
2. List active and expired users
3. Per-user data usage tracking
4. SSH user management
5. Install/Uninstall SSH WebSocket
6. Install/Uninstall WARP + domain routing
7. Restart all services
8. Speedtest, bandwidth monitoring
9. Domain management, SSL renewal
10. Auto-update, auto-reboot settings
11. Telegram bot setup
12. Backup and restore
13. System information

## Credits

Built by FreeFlow. Inspired by the best VPN scripts in the community.
