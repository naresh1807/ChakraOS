# Phase 18 — Office & document safety

The suite is **LibreOffice** (`libreoffice-writer` / `-calc` / `-impress`
+ `-gtk3` for the Plasma theme). Its own Writer / Calc / Impress
launchers appear in the desktop's Office group as usual.

The Chakra layer treats every document as suspect — because office
documents (VBA macros, DDE, embedded OLE, external links) are a leading
malware-delivery vector.

## What's here

`chakra-office` (`office/bin/`, **Office** menu → "Document Safety"):

| Command | Does |
|---|---|
| `open FILE` | opens **read-only** in a firejail sandbox (`--net=none`). `--trusted` = full edit + network; `--app writer\|calc\|impress`. |
| `inspect FILE` | macro / auto-exec / suspicious-keyword / OLE-object / external-link report **without opening the file** — `oleid` + `olevba` for OLE and OOXML, `unzip` for the OOXML relationship graph. `--json`. |
| `scrub FILE [OUT]` | a copy with VBA macros (`word/vbaProject.bin` …) and metadata (`exiftool -all=`) removed. Legacy `.doc`/`.xls` are converted to the modern format first. |
| `status` / `--json` | LibreOffice version, current macro-security level, oletools / firejail presence. |

Every action → Chakra Audit (`actor=chakra-office`).

## Macro security

The build sets LibreOffice **macro security to High** (level 2 — macros
disabled, enable-per-document prompt) in `/etc/skel` and the live user's
profile (`registrymodifications.xcu`). Change it in
Tools → Options → Security → Macro Security, or drop it to a lower level
in that file.

## oletools

`oleid` / `olevba` / `mraptor` aren't in Debian — the build installs
them into a dedicated venv at `/opt/chakra/venv/oletools` and symlinks
the entry points into `/usr/local/bin` (isolated; no system-Python
impact). If the fetch failed at build time, `inspect` still does the
ZIP-level checks; for the full analysis:
`sudo /opt/chakra/venv/oletools/bin/pip install -U oletools`.

## Deferred

- OnlyOffice / a Microsoft-Office-compatible alternative beyond what
  LibreOffice already does.
- A real DLP / content-filtering layer, and quarantine automation.
- `scrub` for exotic embedded content (ActiveX, RTF objects) — it covers
  VBA + metadata, the common case; `chakra-lab` is the deep dive.
