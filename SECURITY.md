# Security Policy

Chakra OS ships a substantial offensive security toolkit (Metasploit, Burp Suite, hydra, hashcat, aircrack-ng, and more — see `config/packages/packages.list`) alongside the OS itself. That toolkit is intentional and by design. This policy is about vulnerabilities *in Chakra OS itself* — the build pipeline, the custom branding/config it applies, and (as later phases land) `chakra-core` and the Chakra-specific services — not about the third-party security tools it bundles, which have their own upstream reporting channels.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Instead, report it privately via a GitHub Security Advisory on this repository, or contact the maintainer directly. Include:
- What's affected (build script, a specific config, a running ISO)
- Steps to reproduce
- Impact, as you understand it

## Scope

In scope:
- `build/scripts/build_iso.sh` and everything it configures (default credentials, permissions, world-writable paths introduced by the build, etc.)
- `chakra-core` and later Chakra-specific services, once they exist
- Anything that would let an unprivileged user or a live-session default account gain privileges it shouldn't have

Out of scope:
- Vulnerabilities in bundled third-party tools (Metasploit, Firefox, KDE Plasma, etc.) — report those upstream
- The fact that this OS ships offensive security tooling at all — that's the point of the distro, not a vulnerability

## Response

This is an early-stage solo project — there's no formal SLA yet. Reports will be acknowledged and triaged as soon as reasonably possible.
