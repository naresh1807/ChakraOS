# Chakra OS roadmap

Phases are ordered by dependency, not just topic — each phase only depends on phases before it. This is a large, multi-year scope as written; phases are not sized to be equal effort.

## Done

- **Phase 1 — Core build system.** Reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live ISO pipeline (`build/scripts/build_iso.sh`): debootstrap → package install → branding → squashfs → GRUB → ISO. Boots to a working Plasma desktop.
- **Phase 2 — Security/forensics tooling.** ~49 curated apt packages (network recon, wireless, web app testing, password/credential, malware analysis, reverse engineering, OSINT, network monitoring, digital forensics) plus Metasploit, Nikto, and Burp Suite Community (each installed via its own method, since none are Debian packages).
- **Phase 3 — Branding & desktop identity.** Windows 11-style theming (Fluent icons/cursors/theme), a custom Sudarshana Chakra visual identity (logo, boot splash, wallpaper, SDDM login background) in orange-on-blue, Windows-style desktop icons (This PC, Recycle Bin, Network, Home, Control Panel), and familiar app naming (Konsole → Terminal, Dolphin → File Explorer, etc., plus a Kali-style Terminal/Terminal (Admin) split).

## In progress

- **Phase 4 — Foundation restructure.** `chakra-core`: `/etc/chakra-release` (Chakra's own identity file), `/etc/chakra/`, `/usr/lib/chakra/`, `/usr/share/chakra/`, `/var/lib/chakra/`, `/var/log/chakra/` — the directory/identity foundation every later Chakra service registers into. Lives in `core/`.

## Planned

- **Phase 5 — Security substrate.** Policy Engine, Chakra Audit (the trail), nftables firewall, boot security (Secure Boot/TPM/disk encryption). Prerequisite for Sentinel — no AI action reaches the system without going through this. → `core/policies/`, `core/security/`
- **Phase 6 — Read-only observability apps.** Command Center, Process Lens, Log Lens, Health, Device Watch, NetGuard (display only) — Risk-0 (read-only) tools that also establish the "Chakra system API" pattern Sentinel will later call into. → `dashboard/`
- **Phase 7 — Chakra Sentinel, read-only mode.** The AI agent: local-first runtime, tool system, memory — scoped to Risk 0 only (answer questions, explain logs, analyze) until Phase 8 exists. → `ai-agent/`
- **Phase 8 — Permission & privacy enforcement.** AppGuard, USB Guard, Privacy Center, Vault, Sandbox, File Inspector. → `privacy/`, `isolation/`
- **Phase 9 — Active defense: Chakra Shield.** Shield + Security Score, built on Phase 6's observability and Phase 8's enforcement. → `security-workspace/`
- **Phase 10 — Developer tooling suite.** DevHub, Env Manager, Port Watch, API Watch, Container Center. No AI/policy dependency — could run in parallel with 6–9. → `developer-tools/`
- **Phase 11 — System maintenance & reliability.** Update, Snapshot, Recovery, Fixer, Clean, Store, Build Center. → `updater/`, `recovery/`, `app-center/`, `installer/`
- **Phase 12 — Performance & daily-use polish.** Performance Engine, Battery AI, Search, Clipboard.
- **Phase 13 — Security research environment.** Chakra Lab, Chakra Reporter — built on Phase 8's Sandbox and Phase 10's containers. → `security-workspace/`, `isolation/`
- **Phase 14 — Identity & advanced boot hardening.** Passkeys, FIDO2, biometrics; matured boot chain.
- **Phase 15 — Mobile ecosystem.** Link (pairing) → Sync → Share → Find, in that order. → `mobile/`
- **Phase 16 — Custom Chakra Shell.** Replacing stock KDE's launcher/dock/panel/notification center with fully custom Chakra components, plus light/auto/high-contrast theme modes — the most disruptive UI rewrite, deliberately last. → `desktop/launcher/`, `desktop/workspace-manager/`

## Directories reserved but not yet active

`office/`, `compatibility/` (Wine/Proton) — not yet placed in a phase; scope to be defined when reached.
