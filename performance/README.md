# Phase 12 — Performance & daily-use polish

Plasma already ships the GUI pieces here — powerdevil (power management),
Klipper (clipboard history), KRunner + Baloo (search). Phase 12 adds the
CLI/engine layer on top, installed by `apply_performance()` in
`build/scripts/build_iso.sh`.

| Tool | What it is |
|---|---|
| **`chakra-perf`** | The Performance Engine. Shows power profile / CPU governor / swappiness / memory-swap pressure / top hogs; `sudo chakra-perf {performance\|balanced\|powersave}` switches in one call (drives `power-profiles-daemon` where present — the same thing Plasma's battery applet uses — else the sysfs governor). `chakra-perf slow` is a quick "what's slowing me down right now". `--json`. |
| **`chakra-battery`** | The manual's "Battery AI" — **honestly a heuristic advisor, not ML**. Reads the real numbers (`upower`), works out an estimate from the current drain, and gives a concrete "turn these off" list (`advise`); `sudo chakra-battery save` applies the safe power-saving set. Handles "no battery" (desktop/VM) cleanly. |
| **`chakra-search`** | One query across files (`plocate`), installed packages, running processes, systemd units, and `$PATH` commands, grouped by where the hit is. The terminal complement to KRunner/Baloo; `chakra-search --update` refreshes the file index. |
| **`chakra-clip`** | The clipboard from the shell: `get` / `set` / `history` (from Klipper over D-Bus) / `pick` / `clear`. X11 (`xclip`) and Wayland (`wl-clipboard`). |

`chakra-perf` and `chakra-battery` get **System Maintenance** menu
entries; `chakra-search` and `chakra-clip` are CLI-first (like
`chakra-apiwatch`). New packages: `power-profiles-daemon`, `powertop`,
`plocate`, `xclip`, `wl-clipboard`.

## What's deliberately not here

- **Machine learning for battery / performance.** `chakra-battery`'s
  advice and `chakra-perf`'s diagnosis are legible heuristics over real
  telemetry. An actual model would be a separate, deliberate thing.
- **A custom search or clipboard UI.** KRunner + Baloo and Klipper are
  already the Plasma-native GUIs; these tools are the CLI layer, not a
  replacement.
- **Undervolting / thermal / GPU tuning.** Hardware-specific and risky;
  out of scope for a generic image.
- **Persistent tuning.** Everything `chakra-perf`/`chakra-battery` set is
  session-scoped on a live ISO — persisting it needs the installer.
