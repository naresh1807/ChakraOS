# chakra-core filesystem layout

Declared in `core/systemd/chakra-core.conf` (systemd-tmpfiles format), installed by `apply_chakra_core()` in `build/scripts/build_iso.sh`, and re-applied on every boot by `systemd-tmpfiles-setup.service` — so the layout self-heals even if something under it gets wiped.

| Path | Purpose |
|---|---|
| `/etc/chakra-release` | Chakra OS's own machine-readable identity file (name, version, codename, base, build date) — distinct from `/etc/os-release`, for `chakra-*` tools to read without parsing the freedesktop file. |
| `/etc/chakra/` | System-wide Chakra configuration. |
| `/etc/chakra/policy.d/` | Reserved for the Policy Engine (Phase 5) — not populated yet. |
| `/usr/lib/chakra/` | Reserved for core Chakra libraries/binaries shipped by future `chakra-*` packages — not populated yet. |
| `/usr/share/chakra/` | Shared, architecture-independent Chakra data (e.g. the neofetch ASCII logo). Distinct from `/usr/share/doc/chakra-os/`, which holds Debian-convention package documentation/attribution. |
| `/var/lib/chakra/` | Persistent state for Chakra services (Phase 5+). Empty until a service needs it. |
| `/var/log/chakra/` | Logs for Chakra services, including the future Chakra Audit trail (Phase 5). Group `adm` so admin users can read logs without root. |

This is deliberately minimal for Phase 4 — it's the directory/identity foundation, not the Policy Engine or Audit trail themselves (those are Phase 5).
