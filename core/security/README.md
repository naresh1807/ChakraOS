# chakra-core security substrate (Phase 5)

Installed by `apply_security_substrate()` in `build/scripts/build_iso.sh`.

| File | Installed to | Purpose |
|---|---|---|
| `nftables.conf` | `/etc/nftables.conf` | Default-deny inbound firewall, permissive outbound (see rationale in the file itself — this is a pentesting OS, outbound has to stay open). |
| `sysctl-hardening.conf` | `/etc/sysctl.d/60-chakra-hardening.conf` | Kernel/network hardening: hidden kernel pointers, restricted dmesg, anti-spoofing, SYN cookies, no ICMP redirects. Deliberately does **not** restrict `ptrace_scope` — see the comment in the file for why. |
| *(auditd config)* | `/etc/audit/auditd.conf` | `apply_security_substrate` sets `log_group = adm` so `/var/log/audit/audit.log` is `0640 root:adm`. Without this, `chakra-loglens --source security` (called by Sentinel as the unprivileged user) silently returns nothing. |

## The audit-access model

The read-only Chakra system-API tools and Chakra Sentinel run as the **unprivileged desktop user** (the menu launchers are `konsole -e chakra-…`, not `sudo …`). Two things they need therefore hang off the `adm` group, which that user is in (`config/defaults/user.conf`):

- **Reading** `/var/log/audit/audit.log` and the full systemd journal — granted by `adm` (+ the `log_group=adm` change above).
- **Appending** to the Chakra Audit trail `/var/log/chakra/audit/sentinel.jsonl` — the directory is `2770 root:adm` and the file is pre-created `0664 root:adm` (`core/systemd/chakra-core.conf`, `apply_chakra_core`).

Before this, both failed silently for the normal user — every `chakra-audit-log` write and every security-log read was `2>/dev/null`, so a Sentinel dispatch that logged nothing looked identical to one that logged fine. `chakra-audit-log` now exits non-zero and prints to stderr if the append fails.

**Not tamper-evident yet.** `2770` means any `adm` member can also rewrite or truncate `sentinel.jsonl`. A real audit trail needs append-only enforcement (`chattr +a`, which needs root to set/clear) or a small privileged writer daemon the user talks to over a socket. That's deferred to when there's a threat model that includes a local attacker who is already the desktop user — until then the trail is honest record-keeping, not evidence.

## What's deliberately not here yet

- **Secure Boot / TPM / disk encryption** — these apply to an *installed* system with a persistent disk, which doesn't exist yet (Chakra OS is still live-boot only). Revisit once the live installer phase lands.
- **A running Policy Engine** — see `core/policies/README.md`. The schema is defined and USB Guard (Phase 8) enforces one policy from it, but there's still no general evaluator that resolves the current Sentinel mode and looks up an action.
- **A tamper-evident Chakra Audit trail** — the trail itself exists now (`chakra-audit-log`, Phase 7; records at `/var/log/chakra/audit/sentinel.jsonl`), but see "The audit-access model" above for why it's record-keeping rather than evidence today.
