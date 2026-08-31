# Phase 10 — Developer tooling suite

Chakra is a security OS, not a dev distro — it ships `python3` and `git`
and not much else in the way of runtimes. So Phase 10 is mostly about
**inspecting and managing** a dev setup rather than being one. Five
tools, all Risk tier 0 unless noted, installed to `/usr/lib/chakra/bin/`
and symlinked into `/usr/local/bin/`, reachable from a new **Developer
Tools** menu section.

Installed by `apply_dev_tools()` in `build/scripts/build_iso.sh`.

| Tool | What it does |
|---|---|
| **`chakra-portwatch`** | What's listening (TCP/UDP), who owns it, and whether it's on localhost or `EXPOSED` to the network. `chakra-portwatch 3000` → what's on that port and how to kill it. `--json`, `--watch`. Process/PID shown for your own processes without root; `sudo` for the rest — same limit as `ss`. |
| **`chakra-containers`** | A formatted view over **podman** (`ps` / `all` / `images` / `stats` / `logs <name>` / `ports` / `prune`). Chakra ships podman — rootless, daemonless, containers run as your user; no root daemon. Prefer Docker? Install it yourself. |
| **`chakra-apiwatch`** | `sudo chakra-apiwatch <port> [iface]` — a formatted `tcpdump` showing HTTP request lines and response status lines on a local port. For the "my frontend on :5173 is calling my API on :3000 over http and I want to watch it" case. **Plaintext only** — for HTTPS use mitmproxy / Burp from the Security Tools menu. Sniffs, doesn't proxy. Needs root (packet capture). |
| **`chakra-devenv`** | `chakra-devenv [dir]` — recognises the project kind from its manifest, lists installed language runtimes + versions, shows the version a project *pins* (`.nvmrc`, `go.mod`, `.python-version`, …) vs. what's installed, and reads a `.env` (keys only unless `--show-values`). `--json`. |
| **`chakra-devhub`** | `dialog` TUI over the four, same shape as `chakra-command-center` (Phase 6). |

## What's deliberately not here

- **Per-project runtime version management** (asdf / mise / nvm-style
  switching). `chakra-devenv` *reports* the mismatch; it doesn't fix it.
  `direnv` is one `apt install` away and `chakra-devenv` says so.
- **A bundled polyglot toolchain.** The base ISO stays lean; `chakra-devenv`
  tells you the apt package for whatever runtime a project needs.
- **HTTPS/TLS API interception.** That's mitmproxy / Burp territory, and
  they're already in the Security Tools menu — `chakra-apiwatch` is the
  lightweight plaintext-localhost case and points at them for the rest.
- **A GUI.** CLI + `dialog`, reached from the menu — same call as Phase 6.
- **Docker.** podman is the default (no root daemon on a security OS);
  Docker is an explicit opt-in the user installs themselves.
