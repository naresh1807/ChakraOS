# Chakra OS

A secure, modular, AI-assisted desktop and mobile operating system ecosystem, built on Debian GNU/Linux. Named after Lord Vishnu's Sudarshana Chakra — a tool meant to do everything.

See `docs/` for phase-by-phase status and the full roadmap.

## Status

**Phases 1–18 complete** (the roadmap through office & document safety). A reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live ISO that:

- boots to a Windows 11-styled Plasma desktop with a full Sudarshana Chakra identity (boot splash, wallpaper, login screen, desktop icons, familiar app naming);
- ships ~49 curated security/forensics apt packages plus Metasploit, Nikto and Burp Suite Community, in a Kali-style categorized "Security Tools" menu;
- carries `chakra-core` — Chakra's own `/etc/chakra-release`, directory layout and identity that every later service registers into;
- has a **security substrate**: nftables (default-deny inbound), kernel/network hardening, `auditd`, and a risk-tiered Policy Engine schema;
- has **read-only observability**: five `--json`-capable "Chakra system API" CLIs (`chakra-health`, `chakra-processlens`, `chakra-loglens`, `chakra-devicewatch`, `chakra-netguard`) and a TUI Command Center;
- has **Chakra Sentinel** (read-only mode) — a deterministic Intent Engine routing questions to those tools, every dispatch written to the Chakra Audit trail (optional NVIDIA NIM explain-layer, off by default, never in the decision path);
- has **permission & privacy enforcement**: the real `usbguard` daemon (with an interactive Allow/Block prompt on insertion), Chakra Vault (LUKS2), File Inspector, and a `firejail`-based Sandbox;
- has **active defense**: `chakra-shield` — a rule-based watcher of network exposure and auth-failure bursts (alert-only by default, opt-in nftables blocking) — and `chakra-score`, a 0–100 Security Score with a per-check breakdown;
- has a **developer tooling suite**: `chakra-portwatch` (listening ports + owners), `chakra-containers` (rootless podman), `chakra-apiwatch` (plaintext HTTP sniff on a local port), `chakra-devenv` (project/runtime/`.env` inspector), `chakra-devhub` (TUI);
- has **system-maintenance tools**: `chakra-fixer` (diagnose + repair common breakage), `chakra-update`, `chakra-clean`, `chakra-snapshot` (config archive), and a GRUB recovery-mode entry;
- has **performance & daily-use tools**: `chakra-perf` (power profiles / "what's slow"), `chakra-battery` (heuristic advisor), `chakra-search` (unified CLI search), `chakra-clip` (terminal clipboard);
- has a **security research environment**: `chakra-lab` (isolated firejail/podman workspace for untrusted samples — drop/scan/triage) and `chakra-reporter` (structured findings-report builder);
- has **`chakra-identity`** — auth-posture report + FIDO2 security-key / fingerprint enrolment (Secure Boot / TPM boot-chain hardening is deferred to an installer);
- has **`chakra-link`** — phone ⟷ desktop over KDE Connect (pair / sync / send / ring), with `--json`, an audit record per action, and an explicit view + on/off switch for the 1714-1764 exposure it adds;
- has **`chakra-shell`** — the shell-control CLI: `light` / `dark` / `high-contrast` / `auto` (day-night) theme modes over three Chakra-branded colour schemes, plus `layout reset`; the stock Plasma launcher/dock/panel/notifications stay, fully Chakra-themed (custom QML components are deliberately deferred — see `desktop/`);
- has **`chakra-compat`** — run Windows `.exe` files on Wine (64-bit), boxed in a no-network firejail sandbox by default, with an `analyze` mode (offline throwaway prefix + change report) for untrusted Windows samples that pairs with `chakra-lab`;
- has **LibreOffice + `chakra-office`** — the suite, with macro security forced High, plus `open` (read-only, sandboxed), `inspect` (macro / OLE / external-link triage via oletools without opening the file), and `scrub` (a macro- and metadata-free copy).

`compatibility/proton/` (Steam/Proton gaming) isn't yet placed in a phase, and a few things are deliberately deferred to a future installer (a real local LLM, AppGuard, Secure Boot, persistence, custom shell widgets, 32-bit Wine) — all called out in `docs/roadmap.md` and each area's `README.md`.

## Layout

- `build/scripts/build_iso.sh` — reproducible pipeline: debootstrap → package install → branding → squashfs → GRUB → ISO. Run as root; see the script header for `--clean`/`--test` flags.
- `config/` — inputs to the build (package list, hostname, default user, GRUB template, branding assets, desktop icons, security/tools menus).
- `core/` — `chakra-core` foundation, plus `core/security/` (substrate + Vault/File Inspector/USB Guard), `core/dashboard/` (the system-API tools), `core/policies/` (Policy Engine schema).
- `ai-agent/` — Chakra Sentinel (`ai-agent/reasoning/`); the other subdirs are reserved for later AI-defense phases.
- `isolation/` — `isolation/sandbox/` (the `firejail` wrapper); containers/microvm reserved.
- `privacy/` — Phase 8 notes; AppGuard/Privacy Center land here when the portal layer exists.
- `security-workspace/` — Phase 9: `shield/` (the active-defense watcher + service) and `score/` (the Security Score).
- `developer-tools/` — Phase 10: `bin/` (Port Watch, Container Center, API Watch, Dev Env, DevHub).
- `updater/`, `recovery/` — Phase 11: `chakra-update`/`chakra-clean` and `chakra-fixer`/`chakra-snapshot`.
- `performance/` — Phase 12: `chakra-perf`, `chakra-battery`, `chakra-search`, `chakra-clip`.
- `identity/` — Phase 14: `chakra-identity`.
- `mobile/` — Phase 15: `chakra-link` (KDE Connect front-end).
- `desktop/` — Phase 16: `chakra-shell` + Chakra colour schemes; `launcher/` and `workspace-manager/` reserved for the deferred custom QML components.
- `compatibility/` — Phase 17: `chakra-compat` (Wine front-end); `proton/` reserved for gaming.
- `office/` — Phase 18: `chakra-office` (LibreOffice + document-safety front-end).
- Every other top-level directory mirrors the project's long-term architecture; see `docs/roadmap.md`.

## Building the ISO

```
sudo build/scripts/build_iso.sh
```

Requires on the host: `debootstrap`, `squashfs-tools`, `xorriso`, `grub-pc-bin`, `grub-efi-amd64-bin`, `mtools`, `dosfstools`. See `docs/phase1-status.md` for what's currently installed on the reference build machine.

## Contributing

See `CONTRIBUTING.md`. Security issues: see `SECURITY.md` — please don't open a public issue for a vulnerability.

## License

GPL-3.0-or-later — see `LICENSE`.
