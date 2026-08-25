# Phase 1 status — Core Build System

## Host dependency check (Kali Linux, 2026-08-25)

| Tool | Status |
|---|---|
| git | present (2.40.1) |
| debootstrap | present (1.0.144) |
| mksquashfs | present (4.6.1) |
| grub-pc-bin | present |
| dosfstools (mkfs.vfat) | present |
| xorriso | **missing** |
| mtools | **missing** |
| grub-efi-amd64-bin | **missing** |
| qemu-system-x86_64 | **missing** (only needed for `--test`) |
| /dev/kvm | not present on this host |

Install the missing build-time dependencies with:

```
sudo apt-get install xorriso mtools grub-efi-amd64-bin
```

`qemu-system-x86` is optional — only needed to boot-test the ISO with `build_iso.sh --test`.

## What exists

- Full project directory skeleton per the architecture (empty dirs beyond Phase 1 hold `.gitkeep` only — no code for AI, forensics, security tooling, or mobile yet, per scope).
- `build/scripts/build_iso.sh` — debootstrap → package install → user/branding → squashfs → GRUB → ISO pipeline. Passed `bash -n` syntax check. **Not yet run end-to-end** — blocked on the missing host dependencies above, and it must run interactively as root (sudo) from a real terminal.
- `config/packages/packages.list`, `config/system/hostname`, `config/defaults/user.conf`, `config/boot/grub.cfg.template` — build inputs.
- `chroot_env/` — a separate, hand-built prototype rootfs (Debian bookworm + KDE Plasma + SDDM) created before this pipeline existed. Kept for reference, gitignored, not touched by `build_iso.sh`.

## Result

PARTIAL — scaffolding and build script are in place and syntax-valid; the ISO has not been built or boot-tested yet because three host dependencies are missing and the build requires an interactive sudo session this environment cannot supply.

## Next step

Run, from a real terminal on the Kali host:

```
sudo apt-get install xorriso mtools grub-efi-amd64-bin
sudo build/scripts/build_iso.sh --clean
```

Then validate against the §6/§56 checklist: boots in QEMU, GRUB menu appears, KDE Plasma loads, login works, terminal/file manager work, NetworkManager works, audio foundation present, shutdown/restart work.
