# Phase 1 status — Core Build System

## Build environment

Development moved from Kali Linux to Windows 10 + WSL2 (Ubuntu, kernel
`6.18.33.2-microsoft-standard-WSL2`) on 2026-08-27, due to unrelated login
issues on the Kali host. `debootstrap`/`chroot`/`mksquashfs`/`grub-mkrescue`
all work the same under WSL2's real Linux kernel; the working checkout lives
in WSL's native filesystem (`~/dev/ChakraOS`), not under `/mnt/e/...`, since
`chroot`/`mount --bind` on a drvfs-mounted Windows path is unreliable.

Host dependencies (`debootstrap`, `squashfs-tools`, `xorriso`, `grub-pc-bin`,
`grub-efi-amd64-bin`, `mtools`, `dosfstools`, `qemu-system-x86` — note the
Ubuntu package is `qemu-system-x86`, not `qemu-system-x86_64`) are all
installed and confirmed present.

## What exists

- Full project directory skeleton per the architecture (empty dirs beyond Phase 1 hold `.gitkeep` only — no code for AI, forensics, security tooling, or mobile yet, per scope).
- `build/scripts/build_iso.sh` — debootstrap → package install → user/branding → squashfs → GRUB → ISO pipeline. **Run end-to-end successfully.**
- `config/packages/packages.list`, `config/system/hostname`, `config/defaults/user.conf`, `config/boot/grub.cfg.template` — build inputs. `grub.cfg.template` also gained debug/verbose and serial-console GRUB entries, useful for any future boot troubleshooting.
- `chroot_env/` — a separate, hand-built prototype rootfs (Debian bookworm + KDE Plasma + SDDM) created before this pipeline existed. Kept for reference, gitignored, not touched by `build_iso.sh`.

## Bug found and fixed

`build_squashfs()` called `mksquashfs ... -comp xz -e boot -noappend`. In
mksquashfs, `-e` (exclude) greedily consumes every argument after it as an
exclude pattern — so `-noappend` was silently swallowed as a harmless,
no-op exclude pattern instead of taking effect as a flag. Without a working
`-noappend`, mksquashfs fell back to its default append/update mode against
whatever squashfs already existed on disk, so rootfs changes made after the
first squashfs build (password resets, branding, SDDM config, etc.) never
actually made it into later ISOs even though every build step reported
success. Fixed by reordering to `-noappend -comp xz -e boot` so `-e`'s
exclude list only contains `boot`, its intended single argument.

## Result

**PASS** — the v0.1 ISO now builds end-to-end and boots successfully in
QEMU (software-emulated; this host's CPU/BIOS doesn't support nested
virtualization, so no KVM acceleration): GRUB menu appears, kernel and
KDE Plasma load, and the `chakra` user reaches a working Plasma desktop
(Dolphin, Discover, System Settings, application menu, system tray all
present and functional). SDDM autologin is currently configured
(`/etc/sddm.conf` in the rootfs, `User=chakra`, `Session=plasma`) for
convenience; the `chakra` account's real password (`chakra123`) is also
confirmed working if autologin is removed. Terminal/file manager and
NetworkManager were confirmed present and started in the boot log; audio
foundation (pipewire/pipewire-pulse/wireplumber) and shutdown/restart are
installed/available but not yet individually exercised.

## Next step

Phase 1's core goal (bootable Debian + KDE Plasma desktop) is achieved.
Remaining before formally closing the phase: verify audio playback and a
full shutdown/restart cycle inside the live session. After that, Phase 1
is done and the project can move on to later phases — desktop theming is
the next one the user wants to prioritize (see project memory: goal is to
make the Plasma desktop visually resemble Windows 11).
