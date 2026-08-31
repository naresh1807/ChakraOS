# Chakra Shield

`chakra-shield` — a rule-based active-defense watcher. Runs as
`chakra-shield.service` (root, lightly sandboxed) and loops every
`SHIELD_INTERVAL` seconds.

## What it checks

1. **Network exposure.** `ss -H -tuln` filtered to listeners on
   `0.0.0.0` / `[::]` / `*`. A port not in `/var/lib/chakra/shield/seen-ports.list`
   is new → alert. The list is seeded silently on first run so the
   services already up at boot don't all fire.
2. **Auth-failure bursts.** New bytes of `/var/log/audit/audit.log` since
   the last pass, filtered to `type=USER_AUTH` / `type=USER_LOGIN` with
   `res=failed`, tallied by `addr=` (or `hostname=`). A source reaching
   `SHIELD_AUTH_FAIL_THRESHOLD` in one interval → alert.

## What an alert does

- `logger -t chakra-shield` → journald. `chakra-shield-notify` (session
  autostart) follows that tag and raises a desktop notification.
- Appends a JSON line to `/var/lib/chakra/shield/alerts.jsonl`.
- `chakra-audit-log --actor chakra-shield …` → the Chakra Audit trail.

With `SHIELD_ACTIVE_BLOCK=1` it *also* adds an nftables drop rule
(`inet chakra_filter` / `input` chain) for the port or source. See the
project `security-workspace/README.md` for why that's off by default.

## CLI

```
chakra-shield status      # service state, mode, last pass, watched ports, blocks, recent alerts
chakra-shield check       # run one pass right now and print new alerts (does not need the service)
sudo chakra-shield unblock <ip|port>   # remove a rule Shield added
chakra-shield score       # -> chakra-score
```

## Config — `/etc/chakra/shield.conf`

| Key | Default | Meaning |
|---|---|---|
| `SHIELD_INTERVAL` | `60` | seconds between passes |
| `SHIELD_ACTIVE_BLOCK` | `0` | `1` = also drop offending ports/IPs via nftables |
| `SHIELD_AUTH_FAIL_THRESHOLD` | `10` | failed auths from one source in one interval before alerting |

## State — `/var/lib/chakra/shield/`

`seen-ports.list`, `alerts.jsonl`, `blocked.list`, `heartbeat`,
`authlog.pos`. All ephemeral in a live boot; Shield rebuilds its
baseline every start.
