# chakra-core policy schema (Phase 5 — foundation only)

**Nothing reads these files yet.** No Policy Engine exists in Chakra OS today — this defines the schema now so Phase 7 (Chakra Sentinel) and Phase 8 (AppGuard/USB Guard/enforcement) have a concrete format to build against, instead of inventing one under time pressure once an AI agent actually needs to check a permission. Building a real, running policy-evaluation engine before anything consumes its output would be scaffolding for its own sake — see `docs/roadmap.md`'s Phase 5 scoping note.

Policy files live in `/etc/chakra/policy.d/*.json` (the directory chakra-core already creates — see `core/filesystem/README.md`).

## Schema

```json
{
  "id": "unique-policy-id",
  "description": "Human-readable summary",
  "resource": "dot.separated.resource.path",
  "condition": "expression describing when this policy applies",
  "risk_tier": 0,
  "modes": {
    "mode-name": "block | ask | allow"
  }
}
```

- `risk_tier` follows the master manual's classification: 0 = read-only, 1 = low-impact, 2 = system change (needs confirmation), 3 = critical (needs strong confirmation).
- `modes` maps Sentinel's operating modes (Daily, Developer, Privacy, Defense, Security Lab, Forensics, System Admin — see the manual's Sentinel Modes section) to an action. A future Policy Engine resolves the *current* mode and looks up its action here.

## Example

`examples/usb-storage.policy.json` — the exact scenario the master manual itself uses to illustrate the concept: an unknown USB storage device should be blocked in Lockdown, asked-about in Daily use, and allowed only inside a Security Lab session.
