# FreeFlow ASVPN - Development Chat Log

## Session 1 — 2026-05-14

### Ahmad (Initial Request)
- Build the most perfect all-in-one autoscript VPN
- Combine all available autoscript VPN features into one
- Must support all OS (especially Debian and Ubuntu)
- Key features requested:
  1. VLESS protocol (WS, XHTTP, HttpUpgrade) — multiport + multipath, install/uninstall option
  2. SSH WS functions — optional install/uninstall
  3. WARP Cloudflare — install/uninstall for domain bypass
  4. Custom UUID — option to set short name like 'Ahmad' or use random UUID
  5. User management — expired users blocked but not deleted, can reactivate, active/expired lists
  6. Per-user data usage tracking (vnstat-style)
  7. Auto-update from GitHub repo (online push or manual update option)
  8. Chat & Progress files in repo (hidden deeper since public repo)
  9. Telegram bot integration — full menu control via bot
  10. Standard VPN script options (refer to reference scripts)

### Reference Scripts Provided
- Decode (multiport): https://github.com/DecodeXOfficial/Reality
- Darul Itqan: https://github.com/darul-itqan/Auto-Script-VPS-SSH-WS-VLESS-WS
- Rerechan: https://github.com/Rerechan02
- JinGGo (WARP): wget script with password LUQMAN

### Architecture Decision
- Ahmad asked: Xray direct (JinGGo style) vs Nginx+Xray (Decode style)?
- Analysis done comparing both approaches
- **Decision: Nginx + Xray** — solves port clash issues Ahmad experienced with JinGGo
- Nginx as reverse proxy on public ports → Xray on internal localhost ports
- Ahmad confirmed: proceed with Nginx + Xray architecture

### Architecture Overview
```
Internet → Nginx (80, 443, 8080, 8443, 8880, 2083, 2086, 2087)
              ├── /vless-ws     → Xray (localhost:10001)
              ├── /vless-hu     → Xray (localhost:10002) [HttpUpgrade]
              ├── /vless-xhttp  → Xray (localhost:10003) [XHTTP]
              ├── /ssh          → SSH-WS (localhost:700)
              ├── /telegram     → Telegram Bot webhook
              └── /             → Decoy website / panel
```
