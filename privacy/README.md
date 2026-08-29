# Phase 8 — Permission & privacy enforcement

## What's real here

| Piece | What it actually is | Lives in |
|---|---|---|
| **USB Guard** | The real `usbguard` daemon, bootstrapped to allow what's connected at boot and block new insertions by default — the first thing to actually enforce a `/etc/chakra/policy.d/` policy (Phase 5's `usb-storage.policy.json`). | `core/security/usbguard/` |
| **Chakra Vault** | Genuine LUKS2 disk encryption via `cryptsetup` — file-backed encrypted containers, create/open/close. | `core/security/bin/chakra-vault` |
| **File Inspector** | A real Chakra system API tool (SHA256, MIME type, permissions, setuid/setgid warnings, EXIF for images) — same `--json` pattern as the Phase 6 tools. | `core/security/bin/chakra-file-inspector` |
| **Sandbox** | A thin wrapper around `firejail` (a real, established sandboxing tool) — private filesystem, no network by default. | `isolation/sandbox/chakra-sandbox` |

## What's deliberately not here yet

**AppGuard** (per-app Camera/Microphone/Location/Network/Clipboard/USB/Documents permissions) and the rest of **Privacy Center** (tracking *when* an app accessed the camera/mic, browser privacy, telemetry status) both need something this desktop doesn't have yet: a real permission-broker/portal layer sitting between apps and hardware — the mechanism Flatpak's `xdg-desktop-portal` or Android's permission model provide. None of the apps this OS ships (Firefox aside, which has its own internal permission prompts) go through anything like that; they talk to hardware directly. Building a fake AppGuard that doesn't actually intercept anything would be worse than not building it — it would look like protection that isn't there.

This is the same category of honest deferral as Secure Boot in Phase 5 (needs an installer first) or the real GUI in Phase 6 (needs a different toolchain investment) — not skipped because it's unimportant, but because building it properly is its own dedicated phase requiring an actual architecture decision (portal integration vs. a custom LSM/seccomp layer), not something to approximate under time pressure.

## Closing the loop from Phase 5

`usb-storage.policy.json`'s "ask" behavior in Daily mode still isn't real — usbguard defaults new devices to blocked, not "ask," since there's no interactive prompt UI yet (see `core/security/usbguard/README.md`). That gap is the concrete next piece once there's a reason to build device-notification UI, not something papered over here.
