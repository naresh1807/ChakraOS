# desktop/workspace-manager/ — reserved

Phase 16's other custom-component targets: a **Chakra dock/panel** and a
**Chakra notification centre**, plus workspace/activity switching, as
bespoke QML replacing Plasma's panel containment, system tray, and
notifications applet.

Deferred for the same reason as `desktop/launcher/`: these are QML
plasmoid/containment packages and a Qt project in their own right, and
Plasma's versions are mature (do-not-disturb, notification history,
jobs/progress, per-app rules, multi-monitor panels, edit mode). A
partial reimplementation would lose features users rely on.

**What Phase 16 shipped instead:** `chakra-shell` (theme modes + panel
reset) and the Chakra colour schemes in `desktop/themes/`. The panel,
tray and notifications are stock Plasma, Chakra-themed and switchable.

The `chakra-shield-notify` / `chakra-usb-prompt` desktop popups
(Phases 8–9) already use the freedesktop notification spec, so they work
regardless of which notification UI is in place.
