# Chakra OS

A secure, modular, AI-assisted desktop and mobile operating system ecosystem, built on Debian GNU/Linux. See `docs/` for phase-by-phase status.

## Status

**Phase 1 — Core Build System.** Only a bootable Debian + KDE Plasma desktop is in scope. AI, forensics, security tooling, and mobile are structural placeholders only (`.gitkeep`) until their phases begin.

## Layout

- `build/scripts/build_iso.sh` — reproducible pipeline: debootstrap → package install → branding → squashfs → GRUB → ISO. Run as root; see `--help` in the script header.
- `config/` — inputs to the build (package list, hostname, default user, GRUB template).
- `chroot_env/` — a hand-built v0.1 prototype rootfs kept for reference; **not** part of the reproducible build and excluded from git. `build/scripts/build_iso.sh` builds a fresh rootfs independently.
- Every other top-level directory (`ai-agent/`, `forensics/`, `security-workspace/`, `mobile/`, …) mirrors the project's long-term architecture and is currently empty scaffolding for later phases.

## Building the v0.1 ISO

```
sudo build/scripts/build_iso.sh
```

Requires on the host: `debootstrap`, `squashfs-tools`, `xorriso`, `grub-pc-bin`, `grub-efi-amd64-bin`, `mtools`, `dosfstools`. See `docs/phase1-status.md` for what's currently installed on this machine.
