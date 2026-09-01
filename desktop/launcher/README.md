# desktop/launcher/ — reserved

The master manual's Phase 16 calls for a **fully custom Chakra
application launcher** replacing Plasma's Kickoff/Kicker — its own start
menu, search, categories, and pinned items as a bespoke QML plasmoid.

That is a standalone Qt/QML project, not something a live-ISO build
script produces:

- a real launcher is a `Plasmoid` package (QML + a `metadata.json`),
  installed to `/usr/share/plasma/plasmoids/org.chakra.launcher/`;
- it has to cover what Kickoff already does well — favourites, recent
  docs, session actions, keyboard nav, KRunner-backed search, activities,
  right-click config, RTL, accessibility — before it's a net win;
- it needs its own test surface (a running Plasma session, multiple
  screen sizes), which screenshot-driven ISO testing doesn't give.

**What Phase 16 shipped instead** (`desktop/bin/chakra-shell`,
`desktop/themes/`): the Chakra colour system — `ChakraDark`,
`ChakraLight`, `ChakraHighContrast` — with `light` / `dark` /
`high-contrast` / `auto` (day-night) modes and a one-command switch, plus
`layout reset`. Stock Plasma's launcher stays, fully Chakra-themed. The
Kali-style categorised **Security Tools** start menu from Phase 3 is
already data-driven (`config/security-menu/`).

When the custom launcher is built it lands here as
`org.chakra.launcher/` and `chakra-shell layout` learns to place it.
