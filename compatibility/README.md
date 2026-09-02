# Phase 17 — Windows compatibility

Running Windows programs matters for a security OS in two ways: some
Windows-only RE / forensics utilities, and looking at Windows samples.
The compatibility layer is **Wine** (`wine` / `wine64`, Debian bookworm);
Phase 17 is the Chakra wrapper that runs an unknown `.exe` **contained**
instead of letting it behave like a native app.

## What's here

`chakra-compat` (`compatibility/bin/`, in the **Compatibility** menu):

| Command | Does |
|---|---|
| `run FILE.exe [args]` | firejail sandbox — `--net=none`, `--caps.drop=all`, `--nonewprivs` — in a Wine prefix under `~/.local/share/chakra/wine/`. `--online` allows network; `--prefix NAME` picks a prefix. |
| `analyze FILE.exe` | fresh throwaway prefix, offline, 60 s limit, then a report: SHA-256, files created under `C:\`, registry Run/Winlogon/Services sections touched. Points at `chakra-lab`. |
| `prefix new\|list\|rm [NAME]` | manage isolated `WINEPREFIX`es. |
| `winetricks ARGS` | winetricks against the default prefix (fetched from upstream — it isn't in bookworm). |
| `status` / `--json` | Wine version, arch, winetricks, firejail, prefixes. |

Every action → Chakra Audit (`actor=chakra-compat`, risk tier 1–2).

The difference from bare `wine foo.exe`: that gives a Windows binary your
network and your `$HOME`. `chakra-compat run` drops both by default;
`analyze` also gives it a private, disposable filesystem.

## What's deferred

- **32-bit Windows apps.** Only `wine64` is installed. Full 32-bit
  support needs `dpkg --add-architecture i386` + `wine32:i386` and
  roughly doubles the Wine footprint — see `wine/README.md` for the
  exact steps to add it in a running session.
- **Proton / Steam / gaming.** Steam isn't in Debian main (needs
  non-free + i386), Proton is large, and GPU passthrough / DXVK tuning
  is a project of its own. `compatibility/proton/` stays reserved.
- **Bottles / Lutris** GUI prefix managers.
- **A full dynamic-analysis sandbox** (fake-internet / inetsim, automated
  detonation) — the same deferral as Phase 13; `analyze` is the
  lightweight version, `chakra-lab` is the manual deep dive.
