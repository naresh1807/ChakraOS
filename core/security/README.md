# chakra-core security substrate (Phase 5)

Installed by `apply_security_substrate()` in `build/scripts/build_iso.sh`.

| File | Installed to | Purpose |
|---|---|---|
| `nftables.conf` | `/etc/nftables.conf` | Default-deny inbound firewall, permissive outbound (see rationale in the file itself — this is a pentesting OS, outbound has to stay open). |
| `sysctl-hardening.conf` | `/etc/sysctl.d/60-chakra-hardening.conf` | Kernel/network hardening: hidden kernel pointers, restricted dmesg, anti-spoofing, SYN cookies, no ICMP redirects. Deliberately does **not** restrict `ptrace_scope` — see the comment in the file for why. |

## What's deliberately not here yet

- **Secure Boot / TPM / disk encryption** — these apply to an *installed* system with a persistent disk, which doesn't exist yet (Chakra OS is still live-boot only). Revisit once the live installer phase lands.
- **A running Policy Engine** — see `core/policies/README.md`. The schema is defined; nothing evaluates it yet, because nothing (Sentinel, AppGuard) consumes its decisions yet.
- **The "Chakra Audit" JSON-schema trail** described in the master manual (who/what/when/target/permission/result) — that's a higher-level service that wraps *decisions* made by Sentinel/the Policy Engine. What's installed now (`auditd`) is the underlying OS-level audit log those future decisions would be recorded alongside, not a replacement for it.
