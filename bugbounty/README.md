# Phase 20 — Bug bounty workspace

Bug bounty is authorised testing, but only *inside a program's scope and
rate limits*. Step outside them on a live program and you get banned. So
this phase makes **scope a first-class object**: `chakra-bounty` routes
every target through a scope check before any tool touches it, and ships
with conservative rate limits you raise per program.

## chakra-bounty

`bugbounty/bin/chakra-bounty`, in the **Bug Bounty** menu. Each program
is a directory under `~/bounty/<handle>/` — `meta.json`, `scope.txt`,
`out.txt`, `notes.md`, `recon/`, `urls/`, `loot/`.

| Command | Does |
|---|---|
| `program new <handle> [--platform hackerone\|bugcrowd\|intigriti\|private]` | create a program workspace and make it active |
| `program list \| show <handle> \| use <handle>` | — |
| `scope add <handle> <pattern>…` | `*.example.com`, `api.example.com`, `1.2.3.0/24` |
| `scope out <handle> <pattern>…` | explicitly out of scope |
| `scope check <handle> <target>` | exit 0 if in scope (in-scope **and** not out-of-scope) |
| `recon [<handle>] [--dry-run]` | `subfinder → dnsx → httpx` over the wildcard roots, **scope-filtered**, into `recon/` |
| `urls [<handle>]` | `gau` + `waybackurls` + `katana` → dedupe → `urls/params.txt` |
| `scan [<handle>]` | `nuclei` against `recon/live.txt`, rate-limited |
| `note <handle> "…"` | timeline entry |
| `report <handle>` | scaffold a `chakra-reporter` (Phase 13) report, pre-filled, + the platform submit URL |
| `h1 programs \| import <handle>` | HackerOne API — list your programs, pull structured scope into `scope.txt` |
| `status` / `--json`, `tools`, `wordlists` | inventory / SecLists fetch |

Every state-changing action → Chakra Audit (`actor=chakra-bounty`,
risk tier 1–2). The default rate limit is 25 req/s; edit
`~/bounty/<handle>/meta.json` `"rate_limit"` per program.

## The tools

`bugbounty/install.sh` fetches official static release binaries into
`/opt/chakra/bounty/bin` (no Go toolchain): **subfinder, dnsx, httpx,
nuclei, katana, notify** (ProjectDiscovery), **gau, waybackurls, dalfox,
gowitness**. `ffuf` comes from Debian. `nuclei -update-templates` runs at
build. A failed download is a warning — `chakra-bounty tools` shows what
landed, and `sudo /opt/chakra/bounty/install.sh <tool>` re-tries one.

ProjectDiscovery's `httpx` shadows Debian's `python3-httpx` CLI at the
`httpx` name via `/opt/chakra/bounty/bin` on `PATH` — the Python
*library* is unaffected.

`chakra-bounty wordlists` clones **SecLists** (~1 GB) to
`/opt/chakra/bounty/SecLists` on demand — not bundled.

## HackerOne

Put a token in `~/.config/chakra/bounty.conf` (never committed):

```
H1_API_USER=your-h1-username
H1_API_TOKEN=xxxxxxxx        # HackerOne → Settings → API Tokens
```

Then `chakra-bounty h1 import <handle>` pulls the program's structured
scope directly — in-scope URL/DOMAIN/WILDCARD/IP/CIDR assets into
`scope.txt`, ineligible assets into `out.txt`.

## What's deferred

- **Automated report submission.** `report` scaffolds and opens the
  submit page; it does not file the report (creating H1 reports via API
  unattended is a footgun).
- **Continuous monitoring / ASM** — scheduled re-recon with `notify`
  alerts on new assets. `notify` is installed; the scheduler isn't.
- **Burp Suite Professional** — Community is in the Security Tools menu.
- **Cloud / distributed recon** (axiom / fleet-style).
- Parameter brute-forcing (`arjun`, `x8`) and JS secret hunting beyond
  what `katana` + `nuclei` cover.
