# chakra-core dashboard (Phase 6)

Five real, callable "Chakra system API" scripts, all Risk tier 0 (read-only) per the master manual's classification, plus a TUI dashboard tying them together.

## Scope, honestly

The master manual describes these as full custom GUI applications (a tabbed Command Center, a graphical process-tree viewer, etc.). That's a materially different, much larger undertaking than anything built in this project so far — nothing here has compiled a GUI application; everything to date is shell scripting, config generation, and packaging. Building real Qt/QML apps belongs in its own dedicated phase once there's a reason to invest in that toolchain, not bolted onto Phase 6 under time pressure.

What's actually here instead: each tool is a genuine, structured CLI command (installed to `/usr/lib/chakra/bin/`, symlinked into `/usr/local/bin/` for direct use, and reachable from the Start menu). Every one supports `--json` for machine-readable output — that's not decoration, it's the actual point: this **is** the API surface Chakra Sentinel (Phase 7) will call when it needs to answer "why is my system slow?" or "show network connections." Writing these as real callable tools now, instead of stub placeholders, means Phase 7 has something real to wrap.

## The tools

| Command | Reports |
|---|---|
| `chakra-health` | CPU temp (if `lm-sensors` finds a sensor — often unavailable in a VM), RAM/swap, root disk usage, failed systemd units, kernel errors since boot, pending updates |
| `chakra-processlens [--pid N]` | Top processes by CPU, process tree; with `--pid`, detail on one process (cmdline, cwd, open file count, network connections) |
| `chakra-loglens [--source boot\|kernel\|security\|app]` | Recent journald logs by source; `security` reads `/var/log/audit/audit.log` instead (needs root — run from Terminal (Admin) if it looks empty) |
| `chakra-devicewatch` | Connected USB devices, block/storage devices, network interfaces, paired Bluetooth |
| `chakra-netguard` | Firewall (nftables) status, listening ports, established connections — display only; *active* blocking/alerting is Phase 9 (Chakra Shield) |
| `chakra-command-center` | `dialog`-based TUI menu over all five — the "Command Center" from the master manual, minus the GUI polish |

## What's deliberately not here yet

- A real GUI (see above).
- Any write/enforcement action — these tools only read and report. Phase 8 (AppGuard, USB Guard, etc.) is where read-only observation turns into enforcement.
- Sentinel actually calling these — Phase 7. They're built to be called, not called yet.
