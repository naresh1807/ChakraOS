# Phase 11 — Recovery (Fixer + Snapshot)

Part of the Phase 11 system-maintenance suite (see `updater/README.md`
for Update + Clean). Installed by `apply_maintenance()` in
`build/scripts/build_iso.sh`, reachable from the **System Maintenance**
menu.

## `chakra-fixer`

"What's broken, and can you fix it." Checks the things that commonly go
wrong and reports each `OK` / `WARN` / `FAIL` with a one-line remedy;
with `sudo chakra-fixer --fix` it applies the safe repairs — every one
of them something you'd reasonably run by hand:

| Check | `--fix` action |
|---|---|
| failed systemd units | `reset-failed` + `restart` |
| dpkg / apt state | `dpkg --configure -a`, `apt --fix-broken install` |
| DNS resolution | restart `systemd-resolved`, write a fallback `resolv.conf` |
| system clock | `timedatectl set-ntp true` |
| firewall | `systemctl enable --now nftables`, reload `/etc/nftables.conf` |
| Chakra core services (shield/usbguard/auditd/…) | start them |
| chakra-core layout | re-run `systemd-tmpfiles` for `chakra-core.conf` |
| `/` overlay space | warn, point at `chakra-clean` |

`--json` for scripting. It's the first command the **GRUB "recovery
mode"** entry tells you to run.

## `chakra-snapshot`

**Honestly: a config archive, not a filesystem snapshot.** A real
snapshot needs an installed system on btrfs/LVM/ZFS, and Chakra has no
installer phase yet. What this does:

```
chakra-snapshot save [name] [dir]      tar+zstd of /etc/chakra + the chakra
                                       bits of /etc + ~ (minus caches/junk)
chakra-snapshot list [dir]
chakra-snapshot restore <file.tar.zst>
```

Snapshots go to `/var/lib/chakra/snapshots/` (root) or
`~/chakra-snapshots` (user); pass a directory to write to a mounted USB
instead. The point on a live system: **keep your session tweaks across a
reboot**, or carry your setup onto another machine / a future install.

## Recovery mode

`grub.cfg.template` has a **Chakra OS (recovery mode)** entry:
`systemd.unit=rescue.target nomodeset` → a root shell with the graphical
stack and most services held back. `/etc/profile.d/chakra-recovery-hint.sh`
prints what to do: `chakra-fixer`, then `sudo chakra-fixer --fix`, then
`systemctl default` to continue booting.

## Deferred

- **An installer / persistence.** Everything here is in-session on a live
  ISO. Real recovery-of-an-install, rollback, and persistent config all
  wait on the installer (flagged since Phase 5).
- **Block-level / btrfs snapshots and rollback.**
- **`initramfs` / bootloader repair from within recovery mode** — the
  live ISO's boot chain isn't the one you'd be repairing; that's an
  installed-system concern.
