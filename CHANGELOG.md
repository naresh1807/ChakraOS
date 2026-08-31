# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Dates are when the work landed on `main`.

## [Unreleased]

## 2026-08-31 — Phase 11: system maintenance & reliability

### Added
- `chakra-fixer` — diagnose (`OK`/`WARN`/`FAIL` + remedy) and `sudo chakra-fixer --fix` (apply the safe repairs) over: failed systemd units, broken dpkg/apt state, DNS resolution, clock sync, nftables not loaded, Chakra core services down, chakra-core layout, `/` overlay space. `--json`.
- `chakra-update` — apt front-end: Chakra version, upgradable + security count, `sudo chakra-update --apply` runs `full-upgrade` then lists services needing a restart (`needrestart`, added). Warns loudly that a live session's `/` is a RAM overlay so upgrades don't persist.
- `chakra-clean` — reclaims space (apt cache, journal → last 50 MB, `~/.cache`, thumbnail caches, `/tmp` /`/var/tmp`, podman dangling); shows a plan with sizes, asks, reports free space before/after. `--dry-run`, `--yes`, `--autoremove`.
- `chakra-snapshot` — `save` / `list` / `restore` a tar+zstd of `/etc/chakra` + the Chakra bits of `/etc` + `~` (minus caches). Honestly a config archive, not a filesystem snapshot.
- GRUB **recovery mode** entry (`systemd.unit=rescue.target nomodeset`) + `/etc/profile.d/chakra-recovery-hint.sh` pointing at `chakra-fixer`.
- New **System Maintenance** menu section (`config/maintenance-menu/`); `apply_maintenance()` in `build_iso.sh`.

### Design / deferred
- Everything is in-session on a live ISO. Persistence, block-level snapshots/rollback, a Store beyond Discover, a Build Center, and unattended upgrades all wait on an installer phase (flagged since Phase 5).

## 2026-08-31 — Phase 10: developer tooling suite

### Added
- `chakra-portwatch` — listening TCP/UDP sockets with owner + `local`/`EXPOSED` scope; `chakra-portwatch <port>` for detail + how to kill it; `--json`, `--watch`.
- `chakra-containers` — a formatted view over rootless/daemonless **podman** (`ps`/`all`/`images`/`stats`/`logs`/`ports`/`prune`). Package: `podman`.
- `chakra-apiwatch` — `sudo chakra-apiwatch <port>`: a `tcpdump`-formatted stream of HTTP request/response lines on a local port. Plaintext only (points at mitmproxy/Burp for TLS); sniffs, doesn't proxy.
- `chakra-devenv` — project-kind detection from manifests, installed runtime versions vs. what a project pins (`.nvmrc`/`go.mod`/`.python-version`/…), `.env` inspection (keys only unless `--show-values`). `--json`.
- `chakra-devhub` — `dialog` TUI over the four.
- New **Developer Tools** menu section (`config/dev-tools-menu/`); `apply_dev_tools()` in `build_iso.sh`.

### Design
- Chakra ships `python3` + `git` and little else — this phase *inspects/manages* a dev environment rather than being one; `chakra-devenv` names the apt package for anything missing.
- Deferred: runtime version management (asdf/mise — `direnv` is one `apt install` away), a bundled polyglot toolchain, HTTPS API interception, Docker (podman is the default).

## 2026-08-31 — Phase 9: active defense (Chakra Shield)

### Added
- `chakra-score` — a deterministic Security Score 0–100 (`--json`) with a per-check pass/warn/fail breakdown and a one-line fix each: nftables default-deny, hardening sysctls actually live, auditd, USB Guard implicit-block, Shield running, pending updates, failed units, network exposure, the audit trail; plus notes on what's N/A for a live system.
- `chakra-shield` + `chakra-shield.service` — a rule-based active-defense watcher: every `SHIELD_INTERVAL` it diffs services listening on all interfaces and scans new `/var/log/audit/audit.log` lines for auth-failure bursts. Findings → journald (tag `chakra-shield`) + `/var/lib/chakra/shield/alerts.jsonl` + the Chakra Audit trail. CLI: `status` / `check` / `unblock` / `score`.
- `chakra-shield-notify` — session autostart that turns the `chakra-shield` journal tag into desktop notifications.
- `chakra-usb-prompt` — replaces usbguard-notifier's autostart for the insertion case: a blocked USB device now raises Allow / Allow-and-remember / Keep blocked, wired to `usbguard allow-device`.
- Package: `libnotify-bin` (`notify-send`). `IPCAccessControl.d/chakra-desktop` gains `modify` so the session can authorise a device.
- "Chakra Shield" and "Security Score" entries in the Chakra Tools menu.

### Design
- Shield's nftables blocking is **opt-in** (`SHIELD_ACTIVE_BLOCK=0` default): this is a pentesting OS, and auto-blocking the operator's deliberate listeners and peers would be wrong far more often than right. Runtime rules clear on `nftables` reload / reboot.
- No ML/anomaly detection, no IDS engine (Suricata/Snort), no GUI — Shield's rules are simple and legible, reachable from the menu as CLI like Phase 6.

## 2026-08-31 — Phase 8 loose ends

### Added
- `usbguard-notifier` in the session so a blocked USB insertion is *notified* rather than silent (`IPCAccessControl.d/:sudo` listen grant + `usbguard-dbus.service` + autostart).

### Fixed
- The Fluent look-and-feel was never made active (`apply_windows11_theme` set icons/colours/kvantum only), so Plasma generated its first desktop from Debian's default LnF — Debian wallpaper, plain panel. Now sets `LookAndFeelPackage` + the matching plasma desktop theme.
- Fluent-kde's `layouts/org.kde.plasma.desktop-layout.js` hardcodes the wallpaper as `file:///home/vince/.local/share/wallpapers/...jpg` (the theme author's home dir) → black desktop here. `sed`-rewritten to the Chakra wallpaper at build time; also written into the Debian/Breeze LnF defaults, with a self-deleting first-login `plasma-apply-wallpaperimage` autostart as a safety net.

### Build
- `install_metasploit` / `install_nikto` / `install_burpsuite` / the Fluent theme clone now short-circuit when their artifact is already in the persistent `build/rootfs` (`--clean` still forces a full reinstall) — a no-clean rebuild drops from ~35 min to ~14. Added `curl --connect-timeout`/`--max-time` so a hung endpoint fails fast into the existing non-fatal path.

## 2026-08-29 — Phase 8: permission & privacy enforcement

### Added
- The real `usbguard` daemon: a boot-time oneshot (`chakra-usbguard-bootstrap.service`) runs `usbguard generate-policy` to allow connected devices, then new insertions are blocked (`InsertedDevicePolicy=block`). First thing to enforce a `/etc/chakra/policy.d/` policy.
- Chakra Vault (`chakra-vault`): file-backed LUKS2 containers via `cryptsetup` under `/var/lib/chakra/vaults/` — create/open/close/list.
- File Inspector (`chakra-file-inspector`): SHA256, MIME/type, permissions, setuid/setgid warnings, EXIF for images; `--json` like the Phase 6 tools.
- Sandbox (`chakra-sandbox`): a `firejail` wrapper — private filesystem, no network by default.
- Packages: `usbguard`, `cryptsetup`, `firejail`.

### Fixed
- The Chakra Audit trail and `chakra-loglens --source security` silently no-op'd when run unprivileged — which is their normal path (menu launchers run as the desktop user, not via sudo). The audit dir was `0750 root:adm` and the user wasn't in `adm`; `auditd` kept `audit.log` root-only. Now: the desktop user is in `sudo,adm`; `/var/log/chakra/audit` is `2770 root:adm` with `sentinel.jsonl` pre-created `0664 root:adm`; `auditd.conf` gets `log_group = adm`. `chakra-audit-log` now exits non-zero + prints to stderr on a failed append instead of dropping the record.
- `chakra-loglens --source app` was `journalctl --user-unit=` (empty value, malformed) → now `--facility=user,daemon`.

### Deferred
- AppGuard and the rest of Privacy Center — need an `xdg-desktop-portal`-style permission broker between apps and hardware that this desktop lacks. A fake AppGuard that intercepts nothing would be worse than none. See `privacy/README.md`.

## 2026-08-29 — Phase 7: Chakra Sentinel (read-only mode)

### Added
- `chakra-sentinel`: a deterministic keyword-matching Intent Engine that routes a question to one of the Phase 6 tools (Risk tier 0 only), runs it, and shows the result. Interactive prompt or one-shot.
- `chakra-audit-log` (`core/security/bin/`): the first real Chakra Audit trail — one `{timestamp, actor, action, target, risk_tier, approved_by, result}` JSON object per line at `/var/log/chakra/audit/sentinel.jsonl`. Every Sentinel dispatch, matched or not, is recorded.
- Optional NVIDIA NIM explain-layer: `/etc/chakra/sentinel.conf` ships with `NIM_API_KEY=` blank. When set, NIM only ever sees the *already-collected* tool output and is asked to phrase it plainly — it never decides which tool runs and never gets raw system access. Fully offline and functional without it.

## 2026-08-29 — Phase 6: read-only observability tools

### Added
- Five callable "Chakra system API" CLIs, each with `--json`: `chakra-health`, `chakra-processlens`, `chakra-loglens`, `chakra-devicewatch`, `chakra-netguard`. Installed to `/usr/lib/chakra/bin/`, symlinked into `/usr/local/bin/`.
- `chakra-command-center`: a `dialog`-based TUI over all five, in a new "Chakra Tools" Start-menu section (`config/chakra-tools-menu/`).
- Deliberately CLI/TUI, not a real GUI — that is its own toolchain investment (see `core/dashboard/README.md`). This is the surface Sentinel (Phase 7) calls.

## 2026-08-29 — Phase 5: security substrate

### Added
- nftables firewall: default-deny inbound, permissive outbound (this is a pentesting OS — the bundled tools need arbitrary outbound). `/etc/nftables.conf`, `nftables.service` enabled.
- Kernel/network hardening (`/etc/sysctl.d/60-chakra-hardening.conf`): hidden kernel pointers, restricted dmesg, rp_filter, SYN cookies, no ICMP redirects. Deliberately does **not** touch `ptrace_scope` — gdb/strace/ltrace are core RE tools here.
- `auditd` enabled for OS-level audit logging.
- Policy Engine **schema** only (`core/policies/`, JSON, risk-tiered, one worked example `usb-storage.policy.json`) — no running evaluator yet, since nothing consumed its decisions at the time.

### Deferred
- Secure Boot / TPM / disk encryption — apply to an installed system with a persistent disk, which doesn't exist yet.

## 2026-08-28 — Phase 4: Foundation restructure

### Added
- `chakra-core`: `/etc/chakra-release`, `/etc/chakra/`, `/usr/lib/chakra/`, `/usr/share/chakra/`, `/var/lib/chakra/`, `/var/log/chakra/`, declared via `systemd-tmpfiles` so the layout self-heals on every boot.
- `docs/roadmap.md`, `LICENSE` (GPL-3.0-or-later), `CONTRIBUTING.md`, `SECURITY.md`, this changelog.

## 2026-08-28 — Phase 3: branding & desktop identity

### Added
- Windows 11-style theming: Fluent icon/cursor theme, Fluent-kde global theme, Kvantum, Firefox as the default browser, IST default timezone.
- Custom Sudarshana Chakra visual identity: hand-generated (pure-Python, no external rasterizer) 24-spoke discus logo with serrated blade tips, fiery orange-to-gold gradient on blue — applied to the Plymouth boot splash (with an animated orbiting-dot spinner), desktop wallpaper, and SDDM login background.
- Windows-style desktop icons: This PC, Recycle Bin, Network, Home, Control Panel.
- Familiar app naming: Konsole → Terminal, Dolphin → File Explorer, Kate → Text Editor, KWrite → Notepad, Discover → Software Center, System Settings → Control Panel, Spectacle → Snipping Tool, plus a Kali-style "Terminal" / "Terminal (Admin)" split.
- `/etc/os-release` extended with `ANSI_COLOR`/`HOME_URL`/`SUPPORT_URL`/`BUG_REPORT_URL`; static `/etc/motd` banner.

### Fixed
- Metasploit's `msfinstall` hanging on a stale GPG keyring prompt from an earlier interrupted build (`rm -f` the stale keyring before install, feed the installer `/dev/null` so any future unexpected prompt fails fast instead of hanging).

## 2026-08-28 — Phase 2: security/forensics tooling

### Added
- ~49 curated apt packages across network recon, wireless security, web app testing, password/credential attacks, malware analysis, reverse engineering, OSINT, network monitoring, and digital forensics (disk/file, acquisition/hashing, metadata, steganography) — every name verified against the Debian bookworm package index before inclusion.
- Metasploit Framework (Rapid7's official installer), Nikto (from source), Burp Suite Community Edition (PortSwigger's installer) — each installed via its own method since none are Debian packages.

## 2026-08-27 — Windows 11 theming, browser, timezone

### Added
- Initial Fluent icon/cursor/global theme, Firefox as the browser, Asia/Kolkata default timezone.

### Fixed
- `mksquashfs`'s `-e boot` flag silently swallowing the following `-noappend` argument, causing every rebuild after the first to append onto a stale, broken squashfs instead of starting clean. This was the root cause blocking Chakra OS from ever booting to a working desktop; reordering the flags (`-noappend -comp xz -e boot`) fixed it.

## 2026-08-25 — Initial Phase 1 scaffold

### Added
- Reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live-ISO build pipeline: debootstrap → package install → user/branding config → squashfs → GRUB staging → `grub-mkrescue` → checksum.
- Full long-term project directory scaffold (`ai-agent/`, `forensics/`, `security-workspace/`, `mobile/`, etc.) as empty placeholders for later phases.
