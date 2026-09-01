# desktop/ — Phase 16: the Chakra Shell

Phase 3 gave Chakra its visual identity (boot splash, wallpaper, SDDM
login, Fluent icons, familiar app naming, the categorised Security Tools
menu). Phase 16 completes the shell story with the piece Phase 3 left
open: a **colour system with real theme modes** and a command to drive
the desktop.

## What's here

| Path | What |
|---|---|
| `bin/chakra-shell` | `theme dark\|light\|high-contrast\|auto\|fluent`, `auto [off]`, `layout reset`, `status` / `--json`. Applies live (`plasma-apply-colorscheme`) and persists to `kdeglobals`. Audit-logged. |
| `themes/Chakra{Dark,Light,HighContrast}.colors` | Chakra-branded KColorScheme files — orange-on-blue, installed to `/usr/share/color-schemes/`. |
| `launcher/`, `workspace-manager/` | **reserved** — the manual's fully-custom QML launcher / dock / panel / notification centre. See each README for why that's a separate project and what ships in its place. |

`auto` mode installs a `systemd --user` timer (`chakra-shell-auto.timer`,
every 15 min) that flips light ↔ dark by the clock (`AUTO_LIGHT` /
`AUTO_DARK` in `~/.config/chakra/shell.conf`, default 07:00 / 19:00).

The build (`apply_shell()` in `build/scripts/build_iso.sh`) installs the
schemes and the tool and adds an **Appearance** menu entry; it does **not**
change the Phase 3 boot default (Fluent-round-dark + FluentDark), so
`chakra-shell theme fluent` always gets you back.

## What's deferred

The launcher, dock, panel and notification centre are **stock Plasma**,
fully Chakra-themed and switchable. Rebuilding them as custom Chakra QML
components — the manual's aspiration — is a standalone Qt project; a
partial version would drop multi-monitor, activities, accessibility and
notification-history support that Plasma's widgets already have. This is
the same honest call as Phase 8's AppGuard and Phase 15's "the transport
is KDE Connect". On a live ISO, theme changes last the session — persist
with `chakra-snapshot save`.
