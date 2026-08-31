# Chakra OS

A secure, modular, AI-assisted desktop and mobile operating system ecosystem, built on Debian GNU/Linux. Named after Lord Vishnu's Sudarshana Chakra — a tool meant to do everything.

See `docs/` for phase-by-phase status and the full roadmap.

## Status

**Phases 1–9 complete.** A reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live ISO that:

- boots to a Windows 11-styled Plasma desktop with a full Sudarshana Chakra identity (boot splash, wallpaper, login screen, desktop icons, familiar app naming);
- ships ~49 curated security/forensics apt packages plus Metasploit, Nikto and Burp Suite Community, in a Kali-style categorized "Security Tools" menu;
- carries `chakra-core` — Chakra's own `/etc/chakra-release`, directory layout and identity that every later service registers into;
- has a **security substrate**: nftables (default-deny inbound), kernel/network hardening, `auditd`, and a risk-tiered Policy Engine schema;
- has **read-only observability**: five `--json`-capable "Chakra system API" CLIs (`chakra-health`, `chakra-processlens`, `chakra-loglens`, `chakra-devicewatch`, `chakra-netguard`) and a TUI Command Center;
- has **Chakra Sentinel** (read-only mode) — a deterministic Intent Engine routing questions to those tools, every dispatch written to the Chakra Audit trail (optional NVIDIA NIM explain-layer, off by default, never in the decision path);
- has **permission & privacy enforcement**: the real `usbguard` daemon (with an interactive Allow/Block prompt on insertion), Chakra Vault (LUKS2), File Inspector, and a `firejail`-based Sandbox;
- has **active defense**: `chakra-shield` — a rule-based watcher of network exposure and auth-failure bursts (alert-only by default, opt-in nftables blocking) — and `chakra-score`, a 0–100 Security Score with a per-check breakdown.

Everything past Phase 9 (`developer-tools/`, `mobile/`, `updater/`, …) mirrors the project's long-term architecture and is empty scaffolding until its phase begins. See `docs/roadmap.md` for the full breakdown — deliberate deferrals (a real local LLM, AppGuard, Secure Boot) are called out there and in each area's `README.md`.

## Layout

- `build/scripts/build_iso.sh` — reproducible pipeline: debootstrap → package install → branding → squashfs → GRUB → ISO. Run as root; see the script header for `--clean`/`--test` flags.
- `config/` — inputs to the build (package list, hostname, default user, GRUB template, branding assets, desktop icons, security/tools menus).
- `core/` — `chakra-core` foundation, plus `core/security/` (substrate + Vault/File Inspector/USB Guard), `core/dashboard/` (the system-API tools), `core/policies/` (Policy Engine schema).
- `ai-agent/` — Chakra Sentinel (`ai-agent/reasoning/`); the other subdirs are reserved for later AI-defense phases.
- `isolation/` — `isolation/sandbox/` (the `firejail` wrapper); containers/microvm reserved.
- `privacy/` — Phase 8 notes; AppGuard/Privacy Center land here when the portal layer exists.
- `security-workspace/` — Phase 9: `shield/` (the active-defense watcher + service) and `score/` (the Security Score).
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
