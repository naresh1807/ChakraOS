# Chakra Reporter (Phase 13)

`chakra-reporter` — turn an analysis session into a report. It keeps a
structured store (`.report.json`) plus an `evidence/` directory, and
renders both to Markdown (and HTML, if `pandoc` is installed) from a
pentest / incident-response template:

> Summary · Scope · Methodology · Findings (by severity) · IOCs · Timeline · Appendix

## Workflow

```
chakra-reporter new "Compromise of build host, 2026-08"
chakra-reporter finding <slug> --severity high --title "Unsigned persistence via cron" --desc "..."
echo "long description..." | chakra-reporter finding <slug> --severity medium --title "..."
chakra-reporter ioc <slug> hash   7f3a...          "dropper"
chakra-reporter ioc <slug> domain evil.example     "c2"
chakra-reporter evidence <slug> ~/chakra-labs/sample-42/triage-*.txt "lab triage output"
chakra-reporter note <slug> "first observed the beacon at 14:02"
chakra-reporter from-lab <slug> sample-42          # pull the lab's sample hashes in as IOCs
chakra-reporter system <slug>                      # chakra-health/netguard/processlens --json into the appendix
chakra-reporter build <slug>                       # -> report.md  (+ report.html if pandoc)
```

Reports live in `~/chakra-reports/<slug>/`. `build` is idempotent — run
it whenever, it regenerates `report.md` from the JSON store. Edit
Summary / Scope / Methodology by editing `.report.json` (they start
empty) or the generated `report.md` before you ship it.

## Integrations

- **`from-lab`** reads a `chakra-lab` MANIFEST and files every sample
  SHA256 as a `hash` IOC.
- **`system`** captures the Phase 6 read-only tools' `--json` output so
  the report carries a point-in-time system state.
- **`evidence`** copies a file into `evidence/` and records its SHA256,
  so the report references immutable, hashed attachments.

## Deferred

- **PDF** — `pandoc` renders it, but pandoc pulls a large Haskell
  toolchain, so it's an opt-in `apt install pandoc`, not bundled.
- **A GUI report editor** — this is the CLI; the rendered Markdown/HTML
  opens in any editor / browser.
