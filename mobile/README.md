# Phase 15 — Mobile ecosystem

The master manual wants a phone ecosystem in this order: **Link** (pair a
device) → **Sync** (clipboard, notifications) → **Share** (files) →
**Find** (locate the phone).

Plasma already ships the transport for all four: **KDE Connect**
(`kdeconnect`, pulled in by `kde-plasma-desktop`) — a system-tray applet,
a Settings page, and `kdeconnect-cli`. Phase 15 is the Chakra layer on
top, the same relationship Phase 12 has to Klipper / power-profiles-daemon.

## What's real here

`chakra-link` (`mobile/bin/`, in the **Mobile** menu) — one command over
`kdeconnect-cli` + the `org.kde.kdeconnect` D-Bus API:

| Verb | Does |
|---|---|
| `status` / `--json` | daemon state, this device's id, paired/reachable devices + phone battery, **and the network exposure** (see below) |
| `devices` | every known device with id / trust / reachability |
| `pair [NAME]` / `unpair NAME` | **Link** — TLS pairing with pinned device certs |
| `sync [NAME]` | **Sync** — which plugins (clipboard, notifications, run-command, MPRIS…) are live for a device; toggling stays in KDE Connect Settings |
| `send FILE\|--text\|--url [NAME]` | **Share** — push to the phone |
| `find [NAME]` / `find --ping` | **Find** — ring the phone (sounds through silent) / test the link |
| `firewall --open\|--close\|--status` | add/remove a *runtime* nftables allow for 1714-1764 from RFC1918 LANs |
| `off` / `on` | stop / start `kdeconnectd` (closes / reopens the ports) |

Every state-changing action writes a Chakra Audit record
(`actor=chakra-link`, risk tier 1–2).

### The security angle

KDE Connect listens on **udp/tcp 1714-1764 on every interface**. Chakra's
firewall is **default-deny inbound**, so out of the box:

- desktop-initiated actions (`pair`, `send`, `find`) work — outbound is allowed;
- a **phone-initiated** connection (the phone waking the desktop, incoming
  shares) is dropped until `sudo chakra-link firewall --open`.

`chakra-link status` shows this plainly, and `chakra-link off` removes the
exposure entirely. The firewall opening is **runtime only** — it is not
written to `/etc/nftables.conf`, so a reboot closes it again (persisting it
is an installed-system / installer concern, like everything else since
Phase 5).

## What's deferred

- **A Chakra-built mobile app / custom sync protocol.** The client is the
  KDE Connect **Android** app (F-Droid / Play Store). iOS support is
  limited by the iOS background sandbox. Building our own app + protocol
  is a whole project, not a phase.
- **"Find" as real device location.** `find` rings the phone. Live GPS,
  geofencing, and remote wipe/lock beyond KDE Connect's own `--lock` need
  an account service and MDM-style enrolment — deferred.
- **Filesystem browsing / phone-screen mirroring / call & full SMS UX.**
  KDE Connect's SFTP plugin needs `kio-extras` + `sshfs`; `kdeconnect-sms`
  is a separate GUI. Not wrapped here to keep the ISO lean.
- **Persistent pairing across live-session reboots** — `chakra-snapshot
  save` keeps `~/.config/kdeconnect`; otherwise wait for an installed
  system.
