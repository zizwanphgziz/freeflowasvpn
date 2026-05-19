# FreeFlow ASVPN - Development Progress

## Phase 1: Foundation — DONE
- [x] Repository created
- [x] Architecture decision: Nginx + Xray (confirmed by Ahmad)
- [x] Reference scripts analyzed (Decode, Darul Itqan, Rerechan, JinGGo)
- [x] Project structure designed
- [x] Core installer (setup.sh) with OS detection
- [x] Common functions library (colors, helpers, UUID, networking)
- [x] Dependency installation module (base packages, BBR, swap, DNS, timezone)

## Phase 2: Core VPN Engine — DONE
- [x] Xray installation module (official installer + geodata)
- [x] Xray config generator (VLESS WS, XHTTP, HttpUpgrade)
- [x] Multiport support (80, 8080, 8880, 2086 non-TLS / 443, 8443, 2083, 2087 TLS)
- [x] Multipath support (custom paths — user can set '/' or any path)
- [x] Nginx reverse proxy config generator (multiport + multipath)
- [x] SSL/TLS certificate setup (certbot + auto-renewal cron)
- [x] Stats API enabled in Xray config for usage tracking

## Phase 3: Optional Modules — DONE
- [x] SSH WebSocket (install/uninstall) — Python-based WS proxy
- [x] WARP Cloudflare (install/uninstall) — warp-cli or WireGuard fallback
- [x] WARP domain routing (add/list domains to bypass via WARP)
- [x] Xray routing integration for WARP outbound

## Phase 4: User Management — DONE
- [x] Create user (custom UUID from name or random UUID)
- [x] User expiry system (block connection but preserve data — don't delete)
- [x] Reactivate expired user (same UUID, new expiry)
- [x] Active/Expired user lists (separate views)
- [x] Delete user (permanent removal — manual only)
- [x] Renew active user (extend expiry)
- [x] Per-user data usage tracking (upload/download/total via Xray Stats API)
- [x] Data limit enforcement (auto-expire when limit reached)
- [x] Auto expiry check via cron (every 30 minutes)

## Phase 5: Menu System — DONE
- [x] Main menu with 26 options + sub-menus
- [x] Color-coded UI with service status display
- [x] Server info display (domain, IP, version, uptime, OS)
- [x] SSH user management (add/delete/list)
- [x] Backup/Restore functionality
- [x] Speedtest, bandwidth monitoring (vnstat)
- [x] System info, auto-reboot settings
- [x] Domain change, SSL renewal

## Phase 6: Auto-Update — DONE
- [x] GitHub-based auto-update (download latest from repo)
- [x] Manual update option with confirmation
- [x] Version tracking (VERSION file)
- [x] Auto-update cron (daily at 4 AM)
- [x] Backup before update

## Phase 7: Telegram Bot — DONE
- [x] Bot setup (prompts for bot token + chat ID)
- [x] Token validation via Telegram API
- [x] Full menu mirror via Telegram (inline keyboard buttons)
- [x] Add/Delete/Renew/Reactivate users via bot
- [x] Service status, restart, system info via bot
- [x] Speedtest, bandwidth, Xray logs via bot
- [x] WARP status via bot
- [x] Conversation handler for multi-step commands
- [x] Authorized access (restricted to configured chat ID)

## Phase 8: v2.0 — Multi-Protocol & Tools — DONE
- [x] OS support updated: Ubuntu 18.04-26.04, Debian 9-13
- [x] Vinstechmy repos analyzed (25 repos)
- [x] VMESS protocol (WebSocket + gRPC) — full user management
- [x] Trojan protocol (WebSocket + gRPC + TCP TLS) — full user management
- [x] gRPC transport for VLESS, VMESS, Trojan
- [x] VLESS XTLS Reality (TCP direct on port 443, xtls-rprx-vision flow)
- [x] Trojan TCP TLS (via Reality fallback)
- [x] User management extended for all 3 protocols
- [x] Trial Account Generator (auto-expire temporary accounts for each protocol)
- [x] Check Online Users (access.log analysis)
- [x] Ads Blocker (DNS-level, StevenBlack hosts list)
- [x] Netflix Region Checker (+ Disney+, YouTube Premium)
- [x] YAML Config Generator (Clash/Mihomo format for all protocols)
- [x] WSS Converter / Share Link Generator (vless://, vmess://, trojan://)
- [x] DNS Changer (Google, Cloudflare, OpenDNS, Quad9, custom)
- [x] RAM Monitor (free/used + per-service breakdown)
- [x] Auto Clear Log (scheduled log cleanup, cron)
- [x] Telegram Auto Backup (tar.gz backup sent to Telegram, cron)
- [x] Menu expanded from 26 to 46 options
- [x] Xray config: 11 inbounds (4 VLESS + 2 VMESS + 3 Trojan + Reality + API)
- [x] Nginx config updated for all protocol routing
- [x] Telegram bot updated for all protocols + tools
- [x] Usage tracker updated for multi-protocol
- [x] Version bumped to 2.0.0
- [x] All scripts pass shellcheck (0 errors)

## Xray Inbound Port Mapping
| Port | Protocol | Transport |
|------|----------|-----------|
| 10001 | VLESS | WebSocket |
| 10002 | VLESS | HttpUpgrade |
| 10003 | VLESS | XHTTP |
| 10004 | VLESS | gRPC |
| 10005 | VMESS | WebSocket |
| 10006 | VMESS | gRPC |
| 10007 | Trojan | WebSocket |
| 10008 | Trojan | gRPC |
| 443   | VLESS Reality | TCP XTLS (direct, port 443, NOT via Nginx) |
| 10010 | Trojan TCP | TLS (via Reality fallback) |
| 10085 | API | Stats query |

## Phase 9: v2.1 — Critical UX Fix (JinGGo Model) — DONE
- [x] **setup.sh rewrite** — ONLY asks for domain, everything else auto-installs
- [x] **install_xray.sh rewrite** — No prompts, auto UUID + paths + Reality keys, config validation
- [x] **install_nginx.sh fix** — Port 443 removed (reserved for Xray Reality), TLS on 8443/2083/2087
- [x] **menu.sh redesign** — JinGGo-style with server info header, VPN MENU + SYSTEM MENU, sub-menus
- [x] **manage_user.sh rewrite** — Config output shows JinGGo-style blocks with share links
- [x] Chat.md and Progress.md updated

## Phase 10: MoClaw VPS Audit — Findings Recorded
- [x] MoClaw AI accessed live VPS and did complete 12-script audit
- [x] 5 bugs fixed directly on VPS (F1-F5)
- [x] 11 additional bugs identified in source code (A-K)
- [x] Nginx config redesigned: separate WS (8443) and gRPC (2083/2087) blocks
- [x] VLESS confirmed working via Netmod + Nekobox
- [x] Cloudflare settings documented (Flexible SSL, WS ON, gRPC ON)

## Phase 11: v2.3 — MoClaw Audit Fixes — DONE (all 17 bugs fixed)

### Priority 1 — RED (Must Fix) — ALL DONE
- [x] Nginx config rewrite: 3 server blocks (non-TLS, TLS-WS, TLS-gRPC)
- [x] SSL: certbot → acme.sh (ECC ec-256, auto-renewal cron)
- [x] Ads blocker: /etc/hosts → dnsmasq (O(1) DNS, BUG A)
- [x] Xray loglevel "warning" → "none" for access.log (BUG C)
- [x] CF-aware setup + share links (BUG RC-4)
- [x] Firewall rules during installation (iptables + persistent)
- [x] setup.sh ordering: SSH WS before Nginx config (BUG #2)
- [x] REPO_BRANCH to stable branch (BUG RC-2)

### Priority 2 — ORANGE (Should Fix) — ALL DONE
- [x] Usage stats delta tracking (BUG B)
- [x] Trial expiry hour precision (BUG D)
- [x] delete_warp_route() function added (BUG E)
- [x] Telegram bot reactivate re-adds UUID to Xray (BUG F)
- [x] Post-install verify script (verify.sh)

### Priority 3 — YELLOW (Nice to Fix) — ALL DONE
- [x] Backup tar fix — proper tar.gz (BUG G)
- [x] WARP Debian 13 fix — lsb_release fallback (BUG H)
- [x] Bot token security — chmod 700 (BUG I)
- [x] SSH WS proxy — kept as-is, websockify deferred (BUG J)

### Priority 4 — GREEN (Enhancements) — ALL DONE
- [x] SSH auto-kill cron implementation (BUG K)
- [x] Reality destination configurable

### What Works Well (Don't Change — per MoClaw)
- Nginx + Xray split architecture
- Shell menu user management (add/delete/expire/reactivate)
- Per-user UUID + email tagging in Xray
- jq-based Xray config manipulation
- Multiple protocol support (VLESS/VMESS/Trojan + Reality)
- Xray Stats API design (just needs delta fix)
- WARP domain routing via Xray outbound
- Telegram bot inline keyboard UI
- Trial account system

## Phase 12: v2.3 Testing & Verification — DONE
- [x] Installed on Debian 13 VPS (103.200.219.100)
- [x] SSL via acme.sh — working
- [x] Nginx config valid — 3 server blocks, no errors
- [x] Xray running — all inbounds active
- [x] VLESS WS on `/vless-ws` — confirmed working (Nekobox, Netmod)
- [x] iptables-persistent — fixed non-interactive install
- [x] REPO_BRANCH — points to correct branch for testing
- [x] Multipath `/` — investigated, NOT working (reverted to stable config)
- [ ] V2rayNG — connection issues (suspected app-side, user will retest)

### Known Limitations
- Multipath `/` not yet supported — requires different Nginx approach (not `if` blocks)

### Status: MERGED TO init-branch (PR #6)

## Phase 13: v2.3.1 — Connection Fix After Merge — DONE
- [x] **Root cause identified**: Share link paths not URL-encoded (`/vless-ws` → `%2Fvless-ws`)
- [x] **URL encoding fix**: All share links now use `%2F` for path parameters (VLESS, VMESS, Trojan)
- [x] **wss_converter.sh fix**: Corrected default paths (`/` → `/vless-ws`, `/vless-hu` → `/vless-hup`)
- [x] **wss_converter.sh fix**: Corrected TLS ports (443 → 8443 for WS, 443 → 2083 for gRPC)
- [x] **Diagnostic tool**: Added `scripts/core/diagnose.sh` — comprehensive connection diagnostic
- [x] **Menu integration**: Diagnose accessible from menu option 17
- [x] **Tested and confirmed working**: VLESS WS connected, 36ms handshake, 136ms ping via CF CDN
- [x] **V2rayNG confirmed working**: Connected on port 80 via Cloudflare CDN (172.66.169.187)

### PR #8 (replaced #7): https://github.com/zizwanphgziz/freeflowasvpn/pull/8 — MERGED

## Phase 14: v2.3.2 — Install Fix: Services Not Starting — DONE
- [x] **Root cause identified**: Nginx NOT running after fresh install (5 bugs in install flow)
- [x] **Fix 1**: install_ssh_ws skips nginx config regen when nginx not installed
- [x] **Fix 2**: Stale freeflow.conf removed before nginx package install
- [x] **Fix 3**: Explicit `systemctl enable` for xray and nginx
- [x] **Fix 4**: Final service ensure block in setup.sh with retry logic
- [x] **Fix 5**: `mkdir -p /etc/nginx/conf.d` in generate_nginx_config
- [x] **Testing**: Ahmad confirmed — VLESS WS connects immediately after fresh install (48ms handshake)
- [x] PR #9 merged into init-branch

### PR #9: https://github.com/zizwanphgziz/freeflowasvpn/pull/9 — MERGED

## Phase 15: v2.3.3 — DNS Diagnostic & WARP Fix — DONE
- [x] **Bug 1**: DNS diagnostic false alarm — `dig` not installed, added `dnsutils` + fallback commands
- [x] **Bug 2**: WARP WireGuard fallback missing marker file + Xray outbound config
- [x] **Bug 3**: warp-svc daemon not started before warp-cli commands
- [x] **Bug 4**: Menu WARP status only checks file marker, not actual connection
- [x] Added `configure_xray_warp_wireguard()` — freedom outbound with sendThrough for WireGuard
- [x] Added WARP status section to diagnostic tool (section 12)
- [x] **Testing**: Ahmad confirmed diagnostic clean, WARP installs and shows ON
- [x] **BUT**: Domain bypass still not working (see Phase 16)

### PR #10: https://github.com/zizwanphgziz/freeflowasvpn/pull/10 — MERGED

## Phase 16: v2.3.4 — WARP Domain Routing Fix — IN PROGRESS
- [x] **Bug**: jq operator precedence in `add_warp_route()` — `| not` negated entire OR chain, deleting ALL routing rules
- [x] Fixed jq filter + prepended WARP rule instead of appending
- [x] Ahmad tested: **still not working** — domain bypass fails even after jq fix
- [x] Ahmad questioned fundamental WARP architecture — "it seems different from other autoscripts"

### PR #11: https://github.com/zizwanphgziz/freeflowasvpn/pull/11 — CREATED (not yet merged, may be superseded)

## Phase 17: WARP Architecture Research — DONE (research only, no code changes)

### Research Findings
Analyzed 5 reference implementations to compare with our WARP approach:
1. **fscarmen/warp** (2K+ stars) — THE reference WARP script used by most autoscripts
2. **marz-warp** (tawanamohammadi) — Marzban panel WARP setup
3. **hamid-gh98/x-ui-scripts** — WireProxy SOCKS5 approach
4. **Remnawave docs** — Best practice guide for Xray + WARP
5. **XTLS/Xray-core discussions** — Official routing guidance

### Key Discovery: Our Architecture is Wrong
| Feature | FreeFlow (Current) | Reference Scripts (Correct) |
|---------|-------------------|----------------------------|
| WARP client | warp-cli SOCKS5 proxy | Xray native `protocol: "wireguard"` |
| External daemon | Required (warp-svc) | None (Xray handles WireGuard internally) |
| Dependency | cloudflare-warp package | `wgcf` binary (Go, works everywhere) |
| Domain format | Plain: `"ecoss.kpdn.gov.my"` | With prefix: `"domain:kpdn.gov.my"` |
| domainStrategy | Not set | `"IPOnDemand"` |
| Outbound protocol | `"socks"` → 127.0.0.1:40000 | `"wireguard"` (native in Xray-core) |

### Proposed Fix
Rewrite `install_warp.sh` to use **Xray native WireGuard outbound** via `wgcf`:
1. Download `wgcf` binary
2. `wgcf register` + `wgcf generate` → get WireGuard keys from Cloudflare
3. Configure Xray `protocol: "wireguard"` outbound (no external daemon needed)
4. Domain routing with `"domain:"` prefix + `"domainStrategy": "IPOnDemand"`
5. Keep same menu interface

### Status: Research complete — IMPLEMENTED in Phase 18

## Phase 18: v2.4.0 — WARP Architecture Rewrite — DONE
- [x] **Complete rewrite** of `install_warp.sh` — removed warp-cli/SOCKS5, replaced with Xray native WireGuard
- [x] **wgcf integration** — downloads wgcf binary, registers with Cloudflare WARP, generates WireGuard keys
- [x] **Xray `protocol: "wireguard"` outbound** — no external daemon needed (no warp-svc, no wg-quick)
- [x] **`domainStrategy: "IPOnDemand"`** — added to routing config for proper domain resolution
- [x] **Domain routing format** — uses `"domain:example.com"` prefix for proper subdomain matching
- [x] **WARP rules prepended** — specific WARP rules placed before catch-all rules (per XTLS guidance)
- [x] **`kernelMode: false`** — uses userspace WireGuard (no kernel module needed)
- [x] **Menu updated** — WARP status checks Xray WireGuard outbound directly (no warp-cli dependency)
- [x] **Diagnostic updated** — checks native WireGuard outbound, domainStrategy, domain format
- [x] **Telegram bot updated** — WARP status command uses new method
- [x] **Uninstall cleanup** — removes wgcf, config, Xray outbound+routing in one operation
- [x] **README updated** — reflects all current features (v2.4.0)
- [x] **Version bumped** to 2.4.0
- [x] PR #11 closed (superseded by this rewrite)
- [x] `init-branch` merged to `main`

### Architecture Change
| Before (v2.3.x) | After (v2.4.0) |
|------------------|----------------|
| warp-cli SOCKS5 proxy (port 40000) | Xray native `protocol: "wireguard"` |
| External daemon required (warp-svc) | No external daemon (Xray handles WireGuard) |
| cloudflare-warp package dependency | `wgcf` binary (~5MB Go binary) |
| Plain domain format: `"ecoss.kpdn.gov.my"` | Prefix format: `"domain:kpdn.gov.my"` |
| No domainStrategy | `"domainStrategy": "IPOnDemand"` |
| WARP rules appended (wrong order) | WARP rules prepended (correct order) |
| sendThrough for WireGuard fallback | Native WireGuard in Xray-core |

## Changelog
| Date | Change |
|------|--------|
| 2026-05-14 | Project initialized, architecture decided (Nginx + Xray) |
| 2026-05-14 | Phase 1-7 completed: Full autoscript VPN with all features |
| 2026-05-14 | All shell scripts pass shellcheck (0 errors) |
| 2026-05-14 | v2.0: Added VMESS, Trojan, gRPC, XTLS Reality + 14 new features |
| 2026-05-14 | v2.0: Menu expanded to 46 options, Telegram bot updated |
| 2026-05-14 | v2.0: OS support extended to Debian 13 and Ubuntu 26.04 |
| 2026-05-14 | v2.1: Critical UX fix — domain-only setup, JinGGo-style menu + config output |
| 2026-05-14 | v2.1: Port 443 exclusively for Xray Reality, Nginx on 8443/2083/2087 |
| 2026-05-14 | v2.1: Share links generated for all protocols (vless://, vmess://, trojan://) |
| 2026-05-15 | MoClaw AI VPS audit — 5 bugs fixed on VPS, 11 bugs identified in source |
| 2026-05-15 | MoClaw confirmed VLESS working (Netmod + Nekobox) |
| 2026-05-15 | Nginx config redesigned: separate WS + gRPC server blocks |
| 2026-05-15 | Cloudflare settings documented (Flexible SSL, WS ON, gRPC ON) |
| 2026-05-15 | v2.3 fix plan created from MoClaw audit (17 items across 4 priorities) |
| 2026-05-17 | v2.3: All 17 MoClaw audit bugs fixed in source code |
| 2026-05-17 | v2.3: Tested on Debian 13 VPS — VLESS WS working on /vless-ws |
| 2026-05-17 | v2.3: Multipath / investigated — reverted (needs different approach) |
| 2026-05-18 | v2.3: Documentation updated, ready for merge to init-branch |
| 2026-05-18 | v2.3: Merged to init-branch (PR #6) |
| 2026-05-18 | v2.3.1: Fixed share link URL encoding (path=%2F), wss_converter defaults/ports |
| 2026-05-18 | v2.3.1: Added diagnostic tool (diagnose.sh), menu option 17 |
| 2026-05-18 | v2.3.1: VLESS WS confirmed working on V2rayNG via CF CDN (36ms handshake) |
| 2026-05-18 | v2.3.1: Merged to init-branch (PR #8) |
| 2026-05-18 | v2.3.2: Fixed 5 install-flow bugs causing Nginx/Xray not starting after fresh install |
| 2026-05-18 | v2.3.2: Ahmad confirmed — VLESS WS connects immediately after fresh install (48ms) |
| 2026-05-18 | v2.3.2: Merged to init-branch (PR #9) |
| 2026-05-18 | v2.3.3: Fixed DNS diagnostic false alarm (dnsutils not installed, added fallback) |
| 2026-05-18 | v2.3.3: Fixed WARP not working (WireGuard fallback missing marker+Xray config) |
| 2026-05-18 | v2.3.3: Fixed warp-svc not started, added connect verification |
| 2026-05-18 | v2.3.3: WARP menu shows actual connection status |
| 2026-05-18 | v2.3.3: Merged to init-branch (PR #10) |
| 2026-05-18 | v2.3.4: Fixed jq operator precedence bug in WARP domain routing (PR #11 created) |
| 2026-05-18 | v2.3.4: Domain bypass still not working after jq fix — architectural mismatch identified |
| 2026-05-18 | WARP research: Analyzed 5 reference implementations (fscarmen, marz-warp, hamid-gh98, Remnawave, XTLS) |
| 2026-05-18 | WARP research: Our approach (warp-cli SOCKS5) differs from standard (Xray native WireGuard via wgcf) |
| 2026-05-18 | WARP research: Proposed rewrite using Xray protocol:"wireguard" + wgcf — awaiting approval |
| 2026-05-19 | v2.4.0: WARP architecture rewrite — Xray native WireGuard via wgcf (no external daemon) |
| 2026-05-19 | v2.4.0: Domain routing uses "domain:" prefix + domainStrategy IPOnDemand |
| 2026-05-19 | v2.4.0: Diagnostic, menu, Telegram bot updated for new WARP method |
| 2026-05-19 | v2.4.0: README updated with all current features |
| 2026-05-19 | v2.4.0: PR #11 closed, init-branch merged to main |
