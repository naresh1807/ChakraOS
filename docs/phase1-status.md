# Phase 1 status — Core Build System

> **Historical record.** Phase 1 closed on 2026-08-27; the project is at
> **v0.1 (Phase 19)**. For current status see [`roadmap.md`](roadmap.md)
> and `CHANGELOG.md`. What's still accurate here: the build-environment
> notes and the mksquashfs bug write-up.

## Build environment

Development moved from Kali Linux to Windows 10 + WSL2 (Ubuntu, kernel
`6.18.33.2-microsoft-standard-WSL2`) on 2026-08-27, due to unrelated login
issues on the Kali host. `debootstrap` / `chroot` / `mksquashfs` /
`grub-mkrescue` all work the same under WSL2's real Linux kernel. The
**ISO builds from a checkout on WSL's native filesystem** (an ext4 path
such as `~/dev/ChakraOS`), not from a drvfs-mounted Windows path
(`/mnt/...`), where `chroot` / `mount --bind` is unreliable. Editing can
happen anywhere; only the build has this constraint. (WSL2's `LxssManager`
service is also prone to hanging on long builds — see the CI `build-iso`
workflow, which does the from-scratch `--clean` build in a stable runner.)

Host dependencies: `debootstrap`, `squashfs-tools`, `xorriso`,
`grub-pc-bin`, `grub-efi-amd64-bin`, `mtools`, `dosfstools`, and
`qemu-system-x86` for `--test` (the Ubuntu package is `qemu-system-x86`,
not `qemu-system-x86_64`).

## Default account

Created `--disabled-password` by `create_default_user()`; the password is
set interactively at build time and **no credential is committed** (see
`config/defaults/user.conf`). On a live ISO it doesn't persist a reboot
anyway. From Phase 14, `chakra-identity` reports and manages the account's
auth posture.

## Bug found and fixed (kept as a cautionary tale)

`build_squashfs()` called `mksquashfs ... -comp xz -e boot -noappend`. In
mksquashfs, `-e` (exclude) greedily consumes every argument after it as an
exclude pattern — so `-noappend` was silently swallowed as a harmless
no-op exclude instead of taking effect as a flag. Without a working
`-noappend`, mksquashfs fell back to its append/update mode against
whatever squashfs already existed on disk, so rootfs changes made after
the first squashfs build never actually made it into later ISOs even
though every step reported success. Fixed by reordering to
`-noappend -comp xz -e boot` so `-e`'s list contains only `boot`.

## Result

**PASS** — the v0.1 ISO builds end-to-end and boots (QEMU, software
emulation on this host) to a working Plasma desktop as the `chakra` user.
Everything after Phase 1 is in `CHANGELOG.md`.
