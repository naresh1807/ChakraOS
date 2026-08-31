# Phase 11 — Updater (Update + Clean)

Part of the Phase 11 system-maintenance suite (see `recovery/README.md`
for Fixer + Snapshot). Installed by `apply_maintenance()` in
`build/scripts/build_iso.sh`, in the **System Maintenance** menu.

## `chakra-update`

An apt front-end with the context that matters on Chakra:

```
chakra-update              refresh the index, show what's upgradable (+ security count)
sudo chakra-update --apply run the full-upgrade, then list services needing a restart
chakra-update --json
```

It says which **Chakra OS version** you're on, and — loudly, when it
detects a live session — that `/` is a RAM overlay so upgrades **do not
survive a reboot**. Persisting them needs an installed system (no
installer phase yet). It also makes clear that Chakra's *own* components
(the `chakra-*` tools, the ISO) aren't updated in place — you rebuild /
re-flash from a newer ISO; this tool is for the Debian base underneath.

`needrestart` (a package this phase adds) powers the "services that need
a restart" list after `--apply`.

## `chakra-clean`

Reclaim space — which on a live session is actual RAM:

```
chakra-clean               show a plan with sizes, ask, then clean
chakra-clean --dry-run
chakra-clean --yes
sudo chakra-clean --autoremove   also apt-get autoremove --purge
```

Clears: the apt package cache, the system journal (keeps the last 50 MB),
`~/.cache`, thumbnail caches, old files in `/tmp` / `/var/tmp`, and
dangling podman data. Nothing here removes your documents; `apt
autoremove` is opt-in behind `--autoremove`. Shows free space before and
after.

## What Phase 11 does *not* try to be

- **A software store.** Discover is already the GUI software centre
  (renamed "Software Center" in Phase 3); `chakra-update` is the CLI for
  the base system. No `chakra-store`.
- **A build centre.** The ISO is built by `build/scripts/build_iso.sh`
  on a build host with the debootstrap/squashfs toolchain — not from
  inside the running live system.
- **Unattended upgrades.** Pointless without persistence; revisit with
  the installer.
