# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Dates are when the work landed on `main`.

## [Unreleased]

### Added
- **Chakra Sentinel — Google Gemini** as an explain-layer provider alongside NVIDIA NIM. `/etc/chakra/sentinel.conf` gains `GEMINI_API_KEY` / `GEMINI_MODEL` (default `gemini-2.0-flash`) / `GEMINI_BASE_URL`, plus `SENTINEL_LLM` to pin a provider (`gemini` | `nim` | `none`). Auto-picks Gemini if its key is set, else NIM, else offline. `CHAKRA_GEMINI_API_KEY` / `CHAKRA_NIM_API_KEY` / `CHAKRA_SENTINEL_LLM` env vars override the file. Unchanged: the LLM is never in the decision path (it only explains already-collected, Risk-0 output), no key is shipped in the image, and any failure falls back to raw data without blocking.

## 2026-09-03 — Phase 19: test harness & build hygiene

### Added
- `tests/` — a deterministic, read-only check suite. `sudo tests/run.sh` chroots into `build/rootfs`; `tests/run.sh --here` runs against the current system (use on the live ISO). Exit non-zero on any failure.
  - `unit/chakra-tools.sh` — every `chakra-*` CLI: installed, executable, `bash -n` clean, `--help` doesn't hang (time-boxed, `</dev/null`), and bare `--json` (where it's a status flag) is valid JSON. Chroot can't run podman/systemd/hardware, so "produced nothing there" is a SKIP; only non-empty-but-invalid JSON fails.
  - `integration/menus.sh` — every `config/*/tools.list` row → a `.desktop` (matched on `Name=`); every chakra `.desktop` → an `Exec` command on `PATH` + an `X-Chakra-*` category some `.menu` includes; every `.menu` → a real `.directory`.
  - `security/hardening.sh` — nftables input `policy drop` + established/related, hardening sysctls present *and `ptrace_scope` left open* (Phase 5), `auditd log_group = adm`, default user in `sudo`+`adm`, `chakra-core` layout, `/etc/chakra-release`, LibreOffice macro security ≥ High.
  - `lib.sh` assertion helpers; `boot/README.md` documents the QEMU `--test` smoke and the manual VirtualBox procedure.
- `build_iso.sh`: `run_checks` runs the suite after the `apply_*` steps (warns; fatal with the new `--check` flag); `cleanup_rootfs` strips `/tmp`, `~/.cache`, apt lists/archives, `machine-id`, and truncates `/var/log` before the squashfs is sealed.

### Fixed
- `chakra-devenv --json` emitted **nothing** in any directory without a `.env` file — `{…, env_file:($envfile|select(.!=""))}` makes jq suppress the entire object when the value stream is empty. Now `(if $envfile=="" then null else … end)`. (Caught by `tests/unit/chakra-tools.sh`.)

## 2026-09-02 — Phase 18: office & document safety

### Added
- **LibreOffice** (`libreoffice-writer` / `-calc` / `-impress` / `-gtk3`) as the office suite; its Writer / Calc / Impress launchers appear in the desktop's Office group. `hunspell-en-us` for spellcheck.
- The build sets LibreOffice **macro security to High** (level 2 — macros disabled, prompt to enable per document) + `DisableActiveContent`, seeded into `/etc/skel` and the live user's `registrymodifications.xcu`.
- `chakra-office` — the document-safety front-end:
  - `open FILE [--trusted] [--app writer|calc|impress]` — read-only in a firejail `--net=none` box by default.
  - `inspect FILE [--json]` — macros / auto-exec / suspicious keywords / OLE objects / external links, **without opening the file**: `oleid` + `olevba` for OLE and OOXML, `unzip` for the OOXML relationship graph.
  - `scrub FILE [OUT]` — a copy with VBA (`*/vbaProject.bin`) and metadata (`exiftool -all=`) removed; legacy `.doc`/`.xls` converted to the modern format first.
  - `status` / `--json` — LibreOffice version, macro-security level, oletools / firejail presence.
- Every state-changing action → Chakra Audit trail (`actor=chakra-office`). New **Office** menu section.
- `install_oletools()` in `build_iso.sh` builds an isolated venv at `/opt/chakra/venv/oletools` (olevba/oleid/mraptor aren't in Debian) and symlinks the entry points into `/usr/local/bin` — zero system-Python impact. Best-effort; `inspect` degrades to ZIP-level checks if the fetch fails. Packages: `python3-venv`, `zip`.

### Design / deferred
- Office documents are a leading malware-delivery vector — hence read-only-by-default open, inspect-before-you-trust, and a scrub path, mirroring Phase 17's `chakra-compat analyze` and Phase 13's `chakra-lab`.
- Deferred: OnlyOffice / a further MS-Office-compatible alternative, a real DLP / quarantine layer, `scrub` for exotic embedded content (ActiveX, RTF objects).

## 2026-09-02 — Phase 17: Windows compatibility

### Added
- `chakra-compat` — a Chakra front-end over Wine (64-bit; `wine` + `wine64` from bookworm):
  - `run FILE.exe [args]` — firejail sandbox (`--net=none`, `--caps.drop=all`, `--nonewprivs`) in a prefix under `~/.local/share/chakra/wine/`. `--online` allows network; `--prefix NAME` selects/creates a prefix.
  - `analyze FILE.exe` — fresh throwaway prefix, offline, 60 s cap, then a report: SHA-256, files created under `C:\`, registry Run/Winlogon/Services sections touched. Points at `chakra-lab` (Phase 13) for the deep dive.
  - `prefix new | list | rm [NAME]`, `winetricks ARGS` (passthrough to the default prefix), `status` / `--json`.
- Every state-changing action → Chakra Audit trail (`actor=chakra-compat`, risk tier 1–2).
- `install_winetricks()` in `build_iso.sh` fetches the upstream winetricks script (not in bookworm); `apply_compat()` installs the tool + a new **Compatibility** menu section. Packages: `wine`, `wine64`.

### Design / deferred
- The difference from bare `wine foo.exe`: that hands a Windows binary your network and your `$HOME`. `chakra-compat run` drops both by default; `analyze` also gives it a private, disposable filesystem.
- Deferred: 32-bit Windows apps (`wine32:i386` — a documented opt-in in `compatibility/wine/README.md`, not bundled), Proton / Steam / gaming (`compatibility/proton/` reserved — Steam isn't in Debian main), Bottles / Lutris GUIs, a full fake-internet detonation sandbox (same call as Phase 13).

## 2026-09-01 — Phase 16: Chakra Shell

### Added
- `chakra-shell` — the desktop-shell control CLI:
  - `theme dark | light | high-contrast | auto | fluent` — switch the colour scheme live (`plasma-apply-colorscheme` when a Plasma session is up) and persist to `kdeglobals` + `plasmarc`; `fluent` restores the Phase 3 Windows-11 look.
  - `auto [off]` — installs/removes a `systemd --user` timer (`chakra-shell-auto.timer`, every 15 min) that flips light ↔ dark by the clock (`AUTO_LIGHT` / `AUTO_DARK` in `~/.config/chakra/shell.conf`, default 07:00 / 19:00).
  - `layout reset` — rebuild the Chakra panel from the look-and-feel template (asks first).
  - `status` / `--json` — theme mode, colour scheme, look-and-feel, Plasma/icon theme, auto-timer state, and an explicit note that the launcher/dock/panel/notifications are stock Plasma.
- Three Chakra-branded `KColorScheme` files — `ChakraDark`, `ChakraLight`, `ChakraHighContrast` (orange-on-blue) — installed to `/usr/share/color-schemes/`.
- New **Appearance** menu section (`config/appearance-menu/`); `apply_shell()` in `build_iso.sh`. The Phase 3 boot default (Fluent-round-dark / FluentDark) is left untouched.
- `desktop/launcher/README.md`, `desktop/workspace-manager/README.md` — what the deferred custom-QML shell components entail.

### Design / deferred
- Rebuilding the launcher, dock, panel and notification centre as fully-custom Chakra QML components (the manual's Phase 16 aspiration) is a standalone Qt/QML project — Plasma's widgets are mature (multi-monitor, activities, accessibility, notification history) and a partial reimplementation would drop features. Stock Plasma stays, fully Chakra-themed and switchable. Same honest call as Phase 8's AppGuard / Phase 15's "the transport is KDE Connect".
- On a live ISO a theme change lasts the session; `chakra-snapshot save` persists `~/.config/chakra` + the kdeglobals edits.

## 2026-08-31 — Phase 15: mobile ecosystem

### Added
- `chakra-link` — one command over KDE Connect (`kdeconnect-cli` + `org.kde.kdeconnect` D-Bus) for the manual's Link → Sync → Share → Find:
  - `pair [NAME]` / `unpair NAME` — TLS pairing with pinned device certs.
  - `sync [NAME]` — which plugins (clipboard, notifications, run-command, MPRIS…) are live for a device.
  - `send FILE | --text "…" | --url URL [NAME]` — push to the phone.
  - `find [NAME]` — ring the phone; `find --ping` just tests the link.
  - `status` (default) / `--json` — daemon state, this device's id, paired/reachable devices + phone battery, network exposure.
- Security-first framing: KDE Connect listens on `1714-1764/tcp+udp` on all interfaces and Chakra is default-deny inbound, so `chakra-link` owns that trade-off — `firewall --open|--close|--status` (runtime nftables allow for RFC1918 LANs only, not persisted) and `off`/`on` (stop/start `kdeconnectd`, closing/reopening the ports). Desktop-initiated actions work without opening anything.
- Every state-changing action → Chakra Audit trail (`actor=chakra-link`, risk tier 1–2).
- New **Mobile** menu section (`config/mobile-menu/`); `apply_mobile()` in `build_iso.sh`. Package: `kdeconnect` (pinned; normally pulled by `kde-plasma-desktop`).

### Design / deferred
- The transport is KDE Connect — Phase 15 is the Chakra CLI/`--json`/audit/security layer on top, same as Phase 12 to Klipper.
- Deferred: a Chakra-built mobile app + custom sync protocol (the client is KDE Connect's Android app; iOS is background-sandbox-limited), "Find" as real location / geofencing / remote wipe, SFTP filesystem browsing (needs `kio-extras` + `sshfs`), phone-screen mirror, full SMS/call UX, and pairing that survives a live-session reboot (→ `chakra-snapshot save` / an installer).

## 2026-08-31 — Phase 14: identity & advanced boot hardening

### Added
- `chakra-identity` — the account's authentication posture in one place: password / autologin, FIDO2-U2F key registration + whether sudo requires one, fingerprint reader + enrolments, SSH password-auth, sudo `NOPASSWD` rules, Secure Boot / TPM / firmware. `--json`.
- Enrolment front-end: `sudo chakra-identity add-key` (`pamu2fcfg`), `require-key` / `require-password` (toggles a backed-up `pam_u2f.so` line in `/etc/pam.d/sudo`), `add-fingerprint` (`fprintd-enroll` when a reader is claimed).
- System Maintenance menu gains an *Identity* entry. Packages: `libpam-u2f`, `fprintd`, `libpam-fprintd`, `fido2-tools`.

### Deferred (needs an installer)
- Secure Boot / MOK enrolment, TPM measured boot, a signed+locked bootloader — a per-build hybrid ISO can't meaningfully do these. Same missing prerequisite as Phase 5's Secure Boot note and Phase 11's persistence.
- Passkeys are WebAuthn (browser-side; Firefox already supports them) — nothing OS-level to build.

## 2026-08-31 — Phase 13: security research environment

### Added
- `chakra-lab` — isolated workspace for untrusted samples. `new [--container]`, `enter [--online]` (firejail `--net=none --private` / podman `--network none`), `drop` (sample hashed sha256/1/md5 into a MANIFEST, `chmod 0400`), `scan` (file/hash/clamav/yara/ssdeep/exiftool/strings triage), `list`, `reset [--hard]`, `destroy`. Offline by default; `--online` prompts loudly. Every action → Chakra Audit trail (`actor=chakra-lab`, risk tier 2).
- `chakra-reporter` — structured findings-report builder from a pentest/IR template. `new`, `finding --severity`, `ioc <type> <value>`, `evidence <file>` (copied + hashed), `note` (timeline), `from-lab <lab>` (imports sample hashes as IOCs), `system` (Phase 6 tools' `--json` into the appendix), `build` (→ `report.md`, +`report.html` if pandoc), `list`.
- New **Security Research** menu section (`config/research-menu/`); `apply_research()` in `build_iso.sh`. Package: `xxd`.

### Design / deferred
- Built on Phase 8 (firejail sandbox) and Phase 10 (podman) — no new isolation mechanism.
- Deferred: a fake-internet sinkhole (inetsim) for dynamic malware analysis, an automated detonation sandbox (Cuckoo/CAPE-style), VM/microVM isolation, bundled pandoc (Markdown renders natively; HTML is an opt-in `apt install pandoc`).

## 2026-08-31 — Phase 12: performance & daily-use polish

### Added
- `chakra-perf` — Performance Engine: power profile / CPU governor / swappiness / memory-swap pressure / top hogs; `sudo chakra-perf {performance|balanced|powersave}` (via `power-profiles-daemon`, sysfs governor fallback); `chakra-perf slow` diagnoses current slowness. `--json`.
- `chakra-battery` — the manual's "Battery AI", implemented honestly as a heuristic advisor over `upower` telemetry (no ML): `status` (charge/health/drain), `advise` (estimate + concrete "turn these off"), `sudo chakra-battery save` (apply the power-saving set). Clean "no battery" path for desktops/VMs.
- `chakra-search` — one query across files (`plocate`), installed packages, running processes, systemd units, `$PATH` commands, grouped. `--update` refreshes the index. The CLI complement to KRunner + Baloo.
- `chakra-clip` — terminal clipboard: `get` / `set` / `history` (Klipper via D-Bus) / `pick` / `clear`; X11 (`xclip`) + Wayland (`wl-clipboard`).
- `chakra-perf` + `chakra-battery` join the System Maintenance menu; `chakra-search` + `chakra-clip` are CLI-first. `apply_performance()` in `build_iso.sh`.
- Packages: `power-profiles-daemon`, `powertop`, `plocate`, `xclip`, `wl-clipboard`.

### Design / deferred
- Plasma already ships the GUI layer (powerdevil, Klipper, KRunner/Baloo) — Phase 12 is the engine/CLI on top, not a replacement.
- Deferred: ML for battery/performance, a custom search/clipboard UI, undervolting/thermal/GPU tuning, persistent tuning (needs an installer).

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
