# compatibility/wine/

Wine config notes. The binaries come from Debian (`wine`, `wine64`); the
Chakra front-end is `compatibility/bin/chakra-compat`.

## Prefixes

`chakra-compat` keeps its prefixes under
`~/.local/share/chakra/wine/<name>` (default: `default`), created
`WINEARCH=win64` with `mscoree` / `mshtml` disabled (no Mono/Gecko
nag on first boot). A live-session prefix doesn't persist a reboot —
`chakra-snapshot save` keeps it, or install to disk.

## Adding 32-bit Windows support

Only 64-bit Wine is installed. Many older tools and installers are
32-bit. To add it in a running session (it pulls ~300–500 MB and is not
persisted):

```
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine32:i386
```

Then new prefixes can be `WINEARCH=win32`. This isn't in the ISO by
default to keep the image lean; if it proves to be the common case it
moves into `packages.list` + an `i386` line in the build.

## winetricks

Not in Debian bookworm — `apply_compat()` fetches the upstream script to
`/usr/local/bin/winetricks`. Use it via `chakra-compat winetricks …` so
it targets the Chakra default prefix.
