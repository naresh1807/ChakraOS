# Chakra Lab (Phase 13)

`chakra-lab` — an isolated place to look at things you don't trust.
Built on primitives Chakra already has: **firejail** (Phase 8) for the
default lab, **podman** (Phase 10) for a harder one.

## The two lab kinds

| | `chakra-lab new <name>` (default) | `chakra-lab new <name> --container` |
|---|---|---|
| Isolation | firejail: `--private=<labdir>` (the lab dir *is* the filesystem the shell sees), `--net=none`, `--caps.drop=all`, `--nonewprivs` | podman: a kernel-namespaced container, `--network none`, lab dir bind-mounted at `/lab` |
| Tools | the host's — yara, ssdeep, binwalk, gdb, strace, clamscan, exiftool, … all on `PATH` | a slim base image built once (`FROM debian:bookworm-slim` + a small RE set) — needs network for the one-time build |
| Snapshot | wipe `work/` + `output/`, keep `samples/` | `podman commit` the container |

Both are **offline by default**. `chakra-lab enter <name> --online` gives
the lab the network — it asks first, loudly, because a live sample can
then call home / pull a second stage.

## Workflow

```
chakra-lab new sample-42
chakra-lab drop ~/Downloads/suspicious.bin sample-42   # hashed, chmod 0400, logged
chakra-lab scan sample-42          # file / sha256 / clamav / yara / ssdeep / exif / strings
chakra-lab enter sample-42         # poke around with the RE tools, offline
chakra-lab reset sample-42         # back to clean, keep the samples
chakra-lab destroy sample-42
```

Every action is written to the Chakra Audit trail (`actor=chakra-lab`,
risk tier 2). Samples live in `~/chakra-labs/<name>/samples/` with a
`MANIFEST` of `timestamp  name  sha256  sha1  md5`.

YARA rules: drop `*.yar` files in `~/chakra-labs/.yara/` and `scan` picks
them up. Chakra doesn't bundle a rule pack (there's no good Debian one);
grab e.g. the community `yara-rules` repo.

## Deferred

- **A fake internet** (inetsim / fakedns / a sinkhole) for dynamic
  analysis — real, in Debian, but wiring it into the lab's network
  namespace is its own piece of work. For now: offline, or `--online`
  with eyes open.
- **Automated detonation + behavioural reports** (Cuckoo/CAPE-style) —
  a much larger, separate system.
- **VM / microVM isolation** — this is namespaces, not a VM.
  `isolation/microvm/` stays reserved.
