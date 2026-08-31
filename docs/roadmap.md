# Chakra OS roadmap

Phases are ordered by dependency, not just topic — each phase only depends on phases before it. This is a large, multi-year scope as written; phases are not sized to be equal effort.

## Done

- **Phase 1 — Core build system.** Reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live ISO pipeline (`build/scripts/build_iso.sh`): debootstrap → package install → branding → squashfs → GRUB → ISO. Boots to a working Plasma desktop.
- **Phase 2 — Security/forensics tooling.** ~49 curated apt packages (network recon, wireless, web app testing, password/credential, malware analysis, reverse engineering, OSINT, network monitoring, digital forensics) plus Metasploit, Nikto, and Burp Suite Community (each installed via its own method, since none are Debian packages).
- **Phase 3 — Branding & desktop identity.** Windows 11-style theming (Fluent icons/cursors/theme), a custom Sudarshana Chakra visual identity (logo, boot splash, wallpaper, SDDM login background) in orange-on-blue, Windows-style desktop icons (This PC, Recycle Bin, Network, Home, Control Panel), familiar app naming (Konsole → Terminal, Dolphin → File Explorer, etc., plus a Kali-style Terminal/Terminal (Admin) split), and a Kali-style categorized "Security Tools" Start menu (10 numbered categories, 49 tool launchers, data-driven from `config/security-menu/`).
- **Phase 4 — Foundation restructure.** `chakra-core`: `/etc/chakra-release` (Chakra's own identity file), `/etc/chakra/`, `/usr/lib/chakra/`, `/usr/share/chakra/`, `/var/lib/chakra/`, `/var/log/chakra/` — the directory/identity foundation every later Chakra service registers into. Lives in `core/`. Boot-verified (`/etc/chakra-release` confirmed correct in the live session).

- **Phase 5 — Security substrate.** nftables firewall (default-deny inbound, permissive outbound — this is a pentesting OS), kernel/network hardening (deliberately excludes `ptrace_scope`, since gdb/strace/ltrace need it), `auditd` for OS-level audit logging, and a Policy Engine *schema* (JSON, risk-tiered, one worked example) — explicitly not a running engine yet, since nothing (Sentinel, AppGuard) exists to consume its decisions. Secure Boot/TPM/disk encryption deferred to when there's an installer and an actual persistent disk to protect. Boot-verified: `nft list ruleset` and `systemctl status auditd` both confirmed matching what was built. → `core/security/`, `core/policies/`

- **Phase 6 — Read-only observability apps.** Five real, callable "Chakra system API" CLI tools (`chakra-health`, `chakra-processlens`, `chakra-loglens`, `chakra-devicewatch`, `chakra-netguard`, each supporting `--json`) plus a `dialog`-based TUI Command Center tying them together, reachable from a new "Chakra Tools" Start menu section. Deliberately CLI/TUI, not a real GUI (see `core/dashboard/README.md`) — that's a materially larger, separate undertaking. This *is* the API surface Sentinel (Phase 7) calls, not a placeholder for it. → `core/dashboard/`

- **Phase 7 — Chakra Sentinel, read-only mode.** `chakra-sentinel`: a deterministic keyword-matching Intent Engine routing questions to the Phase 6 tools, every dispatch logged via `chakra-audit-log` (the first real Chakra Audit implementation — Phase 5 deferred this until something existed to log). NVIDIA NIM available as an *optional* explain-layer upgrade (off by default, never in the decision path — see `ai-agent/README.md`), not a replacement for the real local-first LLM the manual describes, which remains a separate future phase. Routing verified against every example query the master manual itself uses. → `ai-agent/`

- **Phase 8 — Permission & privacy enforcement.** The real `usbguard` daemon (bootstrapped to allow boot-time devices, block later insertions — the first thing to enforce a `/etc/chakra/policy.d/` policy), with `usbguard-notifier` in the session so a blocked insertion raises a desktop notification instead of being silent; Chakra Vault (file-backed LUKS2 via `cryptsetup`), File Inspector (SHA256/MIME/perms/setuid/EXIF, `--json` like the Phase 6 tools), and Sandbox (a `firejail` wrapper — private fs, no network). AppGuard and the rest of Privacy Center are **deferred** — they need a real permission-broker/portal layer between apps and hardware that this desktop doesn't have; a fake AppGuard that intercepts nothing would be worse than none (see `privacy/README.md`). Also fixed here: the Chakra Audit trail and `chakra-loglens --source security` silently no-op'd when run unprivileged (their normal path) — now bridged via the `adm` group (see `core/security/README.md`); and the Fluent look-and-feel is now actually made active (`LookAndFeelPackage`) so the desktop stops falling back to Debian's wallpaper and panel. → `privacy/`, `isolation/`, `core/security/`

- **Phase 9 — Active defense: Chakra Shield.** `chakra-score` — a deterministic Security Score 0–100 with a per-check breakdown and one-line fixes (nftables default-deny, hardening sysctls *actually live*, auditd, USB Guard blocking, Shield running, updates, exposure, audit trail). `chakra-shield` — a systemd service that diffs network exposure and scans the OS audit log for auth-failure bursts; each finding → journald + `alerts.jsonl` + the Chakra Audit trail, with a `chakra-shield-notify` session bridge for desktop pop-ups. Blocking (nftables drop rules) is **opt-in** (`SHIELD_ACTIVE_BLOCK`, off by default — auto-blocking a pentest OS's deliberate listeners/peers would be wrong constantly). And `chakra-usb-prompt` — the interactive USB "ask" Phase 8 stubbed: a blocked insertion now pops Allow / Allow-and-remember / Keep blocked, wired to the usbguard IPC (the ACL gains `modify` for the session — the deliberate trade-off). Deferred: no ML/anomaly detection, no IDS engine (Suricata), no GUI. → `security-workspace/`

## In progress

*(nothing active — Phase 10 is next)*

## Planned

- **Phase 10 — Developer tooling suite.** DevHub, Env Manager, Port Watch, API Watch, Container Center. No AI/policy dependency — could run in parallel with 6–9. → `developer-tools/`
- **Phase 11 — System maintenance & reliability.** Update, Snapshot, Recovery, Fixer, Clean, Store, Build Center. → `updater/`, `recovery/`, `app-center/`, `installer/`
- **Phase 12 — Performance & daily-use polish.** Performance Engine, Battery AI, Search, Clipboard.
- **Phase 13 — Security research environment.** Chakra Lab, Chakra Reporter — built on Phase 8's Sandbox and Phase 10's containers. → `security-workspace/`, `isolation/`
- **Phase 14 — Identity & advanced boot hardening.** Passkeys, FIDO2, biometrics; matured boot chain.
- **Phase 15 — Mobile ecosystem.** Link (pairing) → Sync → Share → Find, in that order. → `mobile/`
- **Phase 16 — Custom Chakra Shell.** Replacing stock KDE's launcher/dock/panel/notification center with fully custom Chakra components, plus light/auto/high-contrast theme modes — the most disruptive UI rewrite, deliberately last. → `desktop/launcher/`, `desktop/workspace-manager/`

## Directories reserved but not yet active

`office/`, `compatibility/` (Wine/Proton) — not yet placed in a phase; scope to be defined when reached.
