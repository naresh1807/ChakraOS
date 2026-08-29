# chakra-core filesystem layout

Declared in `core/systemd/chakra-core.conf` (systemd-tmpfiles format), installed by `apply_chakra_core()` in `build/scripts/build_iso.sh`, and re-applied on every boot by `systemd-tmpfiles-setup.service` — so the layout self-heals even if something under it gets wiped.

| Path | Purpose |
|---|---|
| `/etc/chakra-release` | Chakra OS's own machine-readable identity file (name, version, codename, base, build date) — distinct from `/etc/os-release`, for `chakra-*` tools to read without parsing the freedesktop file. |
| `/etc/chakra/` | System-wide Chakra configuration. |
| `/etc/chakra/policy.d/` | Policy Engine schema files (Phase 5). Holds `usb-storage.policy.json`; enforced so far only by USB Guard (Phase 8). |
| `/usr/lib/chakra/` | Core Chakra binaries. `bin/` holds the Phase 6 system-API tools, Sentinel, the audit writer, Vault, File Inspector, and Sandbox, each symlinked into `/usr/local/bin`. |
| `/usr/share/chakra/` | Shared, architecture-independent Chakra data (e.g. the neofetch ASCII logo). Distinct from `/usr/share/doc/chakra-os/`, which holds Debian-convention package documentation/attribution. |
| `/var/lib/chakra/` | Persistent state for Chakra services. `vaults/` holds Chakra Vault's LUKS2 containers (Phase 8). `0750`. |
| `/var/log/chakra/` | `2750 root:adm` — admin users (the desktop user is in `adm`) can read Chakra service logs without root. |
| `/var/log/chakra/audit/` | The Chakra Audit trail (`sentinel.jsonl`, Phase 7). `2770 root:adm` so the unprivileged desktop user can *append* dispatch records when Sentinel/Vault/Sandbox run without sudo. Group-write means it isn't tamper-*evident* yet — see `core/security/README.md`. |

The layout started as the Phase 4 directory/identity foundation; Phases 5–8 populate it as their services land.
