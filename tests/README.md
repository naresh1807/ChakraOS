# tests/

A deterministic, read-only check suite for a built Chakra image. It
inspects `build/rootfs` (or a running system) — it never changes it.

```
sudo tests/run.sh          # chroot into build/rootfs and run everything
tests/run.sh --here        # run against the current system (use on the live ISO)
CHAKRA_ROOTFS=/mnt/x tests/run.sh
```

Exit status is non-zero if any check fails. `build/scripts/build_iso.sh`
runs it automatically after the `apply_*` steps (see `run_checks`); a
failure warns by default and is fatal under `--check`.

| Area | File | Checks |
|---|---|---|
| unit | `unit/chakra-tools.sh` | every `chakra-*` CLI: installed, executable, `bash -n` clean, `--help` doesn't crash, `--json` (where advertised) is valid JSON; audit-dir perms |
| integration | `integration/menus.sh` | every `tools.list` row → a `.desktop`; every `.desktop` → a real command + a category a `.menu` includes; every `.menu` → a real `.directory` |
| security | `security/hardening.sh` | nftables default-deny, hardening sysctls (and ptrace_scope left *open*), `auditd log_group=adm`, default user in `sudo`+`adm`, `chakra-core` layout, LibreOffice macro security |
| boot | `boot/README.md` | how the ISO is smoke-booted (`--test` → QEMU) and the manual VirtualBox procedure |
| forensic | reserved | — |

`lib.sh` is the assertion helper (`ok` / `fail` / `skip` / `assert` /
`refute`). Add a file under `unit/`, `integration/`, or `security/` and
`run.sh` picks it up — no registration.

Not covered (needs a running desktop, not a chroot): live theme
switching, `kdeconnectd` pairing, `wine`/LibreOffice actually launching,
USB insertion prompts. Those are the VirtualBox boot-test each phase got.
