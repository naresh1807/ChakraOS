# Chakra OS

A secure, modular, AI-assisted desktop and mobile operating system ecosystem, built on Debian GNU/Linux. Named after Lord Vishnu's Sudarshana Chakra — a tool meant to do everything.

See `docs/` for phase-by-phase status and the full roadmap.

## Status

**Phases 1–3 complete.** A reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live ISO: boots to a themed desktop, ships ~49 curated security/forensics tools plus Metasploit/Nikto/Burp Suite, and carries a full Chakra-branded identity (Sudarshana Chakra boot splash, wallpaper, login screen, desktop icons, familiar app naming).

**Phase 4 in progress.** `chakra-core` — the system-level identity and directory foundation every later Chakra service will build on.

Everything past Phase 4 (`ai-agent/`, `forensics/`, `security-workspace/`, `mobile/`, …) mirrors the project's long-term architecture and is currently empty scaffolding (`.gitkeep`) until its phase begins. See `docs/roadmap.md` for the full phase breakdown and what each directory is reserved for.

## Layout

- `build/scripts/build_iso.sh` — reproducible pipeline: debootstrap → package install → branding → squashfs → GRUB → ISO. Run as root; see the script header for `--clean`/`--test` flags.
- `config/` — inputs to the build (package list, hostname, default user, GRUB template, branding assets, desktop icons).
- `core/` — `chakra-core`: the OS-level foundation (filesystem layout, systemd integration, identity) that everything else registers into.
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
