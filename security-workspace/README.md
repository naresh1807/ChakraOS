# security-workspace/

Two phases live here.

## Phase 13 — Security research environment

- **`lab/`** — `chakra-lab`: an isolated (firejail `--net=none --private`,
  or podman) workspace to triage untrusted samples. `new` / `drop`
  (hashed, `0400`) / `scan` / `enter` / `reset` / `destroy`, all
  audit-logged. See `lab/README.md`.
- **`reporter/`** — `chakra-reporter`: a structured findings-report
  builder (`finding` / `ioc` / `evidence` / `timeline` / `from-lab` /
  `system` → Markdown, +HTML with pandoc). See `reporter/README.md`.
- New **Security Research** menu section; package `xxd`. Built by
  `apply_research()`.

## Phase 9 — Active defense: Chakra Shield

Phases 6 and 8 gave Chakra read-only observability and per-device
enforcement. Phase 9 is the layer that *watches* and *acts*: a rule-based
active-defense watcher, a security score, and the interactive USB prompt
Phase 8 left as a stub.

Installed by `apply_chakra_shield()` in `build/scripts/build_iso.sh`.

## What's real here

| Piece | What it is | Lives in |
|---|---|---|
| **`chakra-score`** | A deterministic Security Score 0–100 with a per-check pass/warn/fail breakdown and a one-line fix for each amber/red item. Checks Chakra's own declared posture (nftables default-deny, hardening sysctls *actually live*, auditd, USB Guard blocking, Shield running, pending updates, failed units, network exposure, the audit trail) plus notes on what's N/A for a live system (Secure Boot, disk encryption). `--json`. Read-only. | `security-workspace/score/` |
| **`chakra-shield`** | A systemd service (`chakra-shield.service`) that every `SHIELD_INTERVAL` seconds diffs the set of services listening on all interfaces against what it has seen, and scans new `/var/log/audit/audit.log` lines for auth-failure bursts from one source. Each finding → journald (tag `chakra-shield`) + `/var/lib/chakra/shield/alerts.jsonl` + a Chakra Audit record. CLI: `status`, `check`, `unblock`, `score`. | `security-workspace/shield/` |
| **`chakra-shield-notify`** | Session component (autostart) that follows the `chakra-shield` journal tag and pops a desktop notification per alert — the system service can't reach the session bus itself. | `security-workspace/shield/` |
| **`chakra-usb-prompt`** | The interactive USB "ask". Replaces usbguard-notifier's autostart: on a blocked insertion it pops a notification with **Allow / Allow-and-remember / Keep blocked** and, on Allow, calls `usbguard allow-device`. | `core/security/usbguard/` |

Two menu entries land in **Chakra Tools**: *Chakra Shield* (`chakra-shield status`) and *Security Score* (`chakra-score`). A new package: `libnotify-bin` (for `notify-send`).

## Blocking is opt-in

`chakra-shield` **alerts only** by default. With `SHIELD_ACTIVE_BLOCK=1`
in `/etc/chakra/shield.conf` it also adds an nftables drop rule for a
newly-exposed port or an auth-failure source. Off by default *on
purpose*: this is a pentesting OS — you open listeners and hammer hosts
deliberately, and auto-blocking them would be wrong far more often than
right. Runtime rules are cleared on `systemctl reload nftables` / reboot;
Shield re-evaluates from a clean baseline each boot.

## Letting the session authorise USB devices

`chakra-usb-prompt` needs `modify` on the usbguard IPC, so Phase 9
changes `IPCAccessControl.d/chakra-desktop` from `list,listen` to
`list,modify,listen` for the `sudo` group. This means a process in the
desktop session can now allow/block USB devices — the trade-off the
Phase 8 notes flagged. For a single-operator desktop where the
alternative is "blocked devices are simply stuck", it's the right call,
and it's the whole point of an *interactive* prompt. `sudo usbguard
allow-device` still works for anyone who wants to stay out of the
session path.

## What's deliberately not here

- **No anomaly detection / ML / behavioural baselining** beyond "new vs.
  what I've already seen". Shield's rules are simple and legible.
- **No IDS/IPS engine** (Suricata, Snort). That's a heavier, stateful,
  signature-driven thing and its own decision; Shield is a lightweight
  rule watcher built on the Phase 6 probes.
- **No GUI.** `chakra-shield status` / `chakra-score` are CLI, reachable
  from the Chakra Tools menu — same call as Phase 6.
- **The auth-failure window is one `SHIELD_INTERVAL`**, not a true
  sliding window (which would need persistent per-source timestamp
  state). Good enough to catch a burst; documented so it isn't a
  surprise.
