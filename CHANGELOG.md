# Changelog

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Dates are when the work landed on `main`.

## [Unreleased] — Phase 4: Foundation restructure

### Added
- `chakra-core`: `/etc/chakra-release`, `/etc/chakra/`, `/usr/lib/chakra/`, `/usr/share/chakra/`, `/var/lib/chakra/`, `/var/log/chakra/`, declared via `systemd-tmpfiles` so the layout self-heals on every boot.
- `docs/roadmap.md`, `LICENSE` (GPL-3.0-or-later), `CONTRIBUTING.md`, `SECURITY.md`, this changelog.

## 2026-08-28 — Phase 3: branding & desktop identity

### Added
- Windows 11-style theming: Fluent icon/cursor theme, Fluent-kde global theme, Kvantum, Firefox as the default browser, IST default timezone.
- Custom Sudarshana Chakra visual identity: hand-generated (pure-Python, no external rasterizer) 24-spoke discus logo with serrated blade tips, fiery orange-to-gold gradient on blue — applied to the Plymouth boot splash (with an animated orbiting-dot spinner), desktop wallpaper, and SDDM login background.
- Windows-style desktop icons: This PC, Recycle Bin, Network, Home, Control Panel.
- Familiar app naming: Konsole → Terminal, Dolphin → File Explorer, Kate → Text Editor, KWrite → Notepad, Discover → Software Center, System Settings → Control Panel, Spectacle → Snipping Tool, plus a Kali-style "Terminal" / "Terminal (Admin)" split.
- `/etc/os-release` extended with `ANSI_COLOR`/`HOME_URL`/`SUPPORT_URL`/`BUG_REPORT_URL`; static `/etc/motd` banner.

### Fixed
- Metasploit's `msfinstall` hanging on a stale GPG keyring prompt from an earlier interrupted build (`rm -f` the stale keyring before install, feed the installer `/dev/null` so any future unexpected prompt fails fast instead of hanging).

## 2026-08-28 — Phase 2: security/forensics tooling

### Added
- ~49 curated apt packages across network recon, wireless security, web app testing, password/credential attacks, malware analysis, reverse engineering, OSINT, network monitoring, and digital forensics (disk/file, acquisition/hashing, metadata, steganography) — every name verified against the Debian bookworm package index before inclusion.
- Metasploit Framework (Rapid7's official installer), Nikto (from source), Burp Suite Community Edition (PortSwigger's installer) — each installed via its own method since none are Debian packages.

## 2026-08-27 — Windows 11 theming, browser, timezone

### Added
- Initial Fluent icon/cursor/global theme, Firefox as the browser, Asia/Kolkata default timezone.

### Fixed
- `mksquashfs`'s `-e boot` flag silently swallowing the following `-noappend` argument, causing every rebuild after the first to append onto a stale, broken squashfs instead of starting clean. This was the root cause blocking Chakra OS from ever booting to a working desktop; reordering the flags (`-noappend -comp xz -e boot`) fixed it.

## 2026-08-25 — Initial Phase 1 scaffold

### Added
- Reproducible Debian 12 (bookworm) + KDE Plasma 5.27 live-ISO build pipeline: debootstrap → package install → user/branding config → squashfs → GRUB staging → `grub-mkrescue` → checksum.
- Full long-term project directory scaffold (`ai-agent/`, `forensics/`, `security-workspace/`, `mobile/`, etc.) as empty placeholders for later phases.
