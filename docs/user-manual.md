# Chakra OS Manual

**v0.1 "Sudarshana"** — Debian 12 (bookworm) + KDE Plasma 5.27, a
Windows 11–styled security-focused live operating system.

A designed, shareable version of this manual is published as an
Artifact; this file is the canonical source.

---

## 1. Getting started

Chakra OS boots from a USB stick or DVD as a **live session**: the whole
system runs from a compressed image in RAM with a writable overlay on
top. Nothing is written back to the boot media, and **nothing survives a
reboot** unless you save it deliberately (§14).

### Write the ISO and boot it

Write `ChakraOS-v0.1-amd64.iso` to a USB stick — `dd`, Balena Etcher, or
Rufus in *DD image* mode — set your firmware to boot from it, and start
the machine. Works on BIOS and UEFI.

### The GRUB menu

| Entry | Use |
|---|---|
| Try Chakra OS 0.1 | the normal live session |
| … (safe graphics) | `nomodeset` — black or garbled screen |
| … (debug — verbose boot log) | a boot that stalls |
| … (serial console debug) | boot log to `ttyS0`, headless machines |
| Chakra OS 0.1 (recovery mode) | rescue shell → `chakra-fixer` |

### First login

Chakra logs in automatically as **chakra** and starts KDE Plasma — no
login screen. The account has **no password by default**: when a command
asks for a `sudo` password, press **Enter**. (An installed system, once
the installer exists, sets a real one.)

### Open a terminal

Almost every Chakra tool is a command. Open **Terminal** from the Start
menu (KDE's Konsole, renamed), or press <kbd>Alt</kbd>+<kbd>Space</kbd>,
type `konsole`, Enter.

```
$ chakra-health      # one-screen system summary
$ chakra-score       # 0–100 security score with fixes
```

**Conventions:** `$` is your normal prompt; `sudo` means press Enter at
the password prompt. Every tool prints help with `-h` / `--help`, and
most support `--json`.

---

## 2. The desktop

Deliberately styled to look and behave like Windows 11: a bottom panel
with a Start button, system tray and clock, and desktop icons — **This
PC**, **Recycle Bin**, **Network**, **Home**, **Control Panel**. KDE apps
are renamed: Konsole → **Terminal**, Dolphin → **File Explorer**, plus a
**Terminal (Admin)** split like Kali's.

Start-menu sections: **Security Tools · Chakra Tools · Security Research ·
Developer Tools · System Maintenance · Identity · Mobile · Appearance ·
Compatibility · Office.**

Each Chakra menu entry opens a terminal running the matching command and
waits for Enter so you can read the output. **Security Tools** is a
Kali-style catalogue of the bundled pentest/forensics programs in ten
numbered categories.

Firefox is the browser; NetworkManager (tray) handles Wi-Fi/Ethernet.
Change the look with `chakra-shell` (§10).

---

## 3. Chakra Tools & Sentinel

Chakra's read-only "system API" — each answers one question, does nothing
but look, speaks `--json`.

| Command | Shows |
|---|---|
| `chakra-health` | uptime, load, memory/swap, disk, temperature, failed services, pending updates |
| `chakra-processlens` | processes by CPU and memory with owners |
| `chakra-netguard` | firewall state, listening services, active connections |
| `chakra-devicewatch` | connected hardware — disks, USB, network, audio, PCI |
| `chakra-loglens` | unified system / security / application logs |
| `chakra-command-center` | a menu-driven TUI over all of the above |

### Chakra Sentinel

Ask a plain question; Sentinel matches it to one of the tools above, runs
it, records the dispatch in the audit trail, and shows the result.

```
$ chakra-sentinel "why is my system slow?"
$ chakra-sentinel                 # interactive prompt
```

It is a deterministic keyword router, **not a language model** — it only
handles questions it recognises (health, processes, memory, network,
updates, security, logs, devices).

An **optional** explain layer adds a plain-language summary. Set a key in
`/etc/chakra/sentinel.conf`:

- `GEMINI_API_KEY=` — Google Gemini ([aistudio.google.com/apikey](https://aistudio.google.com/apikey))
- `NIM_API_KEY=` — NVIDIA NIM ([build.nvidia.com](https://build.nvidia.com))

Off by default; never decides which tool runs; only ever sees data the
dispatcher already collected; any failure falls back to raw output. **No
key is shipped in the image.** Pin a provider with
`SENTINEL_LLM=gemini|nim|none`.

---

## 4. Security Tools

~50 standard tools, catalogued Kali-style. These are the upstream
programs — reach for them here, not a Chakra wrapper.

| Category | Includes |
|---|---|
| 01 Info gathering | `nmap` `whois` `dig` `recon-ng` `arp-scan` `netdiscover` |
| 02 Vuln analysis | `nikto` `whatweb` |
| 03 Web app | `sqlmap` `dirb` `gobuster` `ffuf` `wapiti` |
| 04 Passwords | `hydra` `john` `hashcat` `medusa` `crunch` `cewl` |
| 05 Wireless | `aircrack-ng` `wifite` `reaver` `airmon-ng` |
| 06 Exploitation | `msfconsole` (Metasploit) |
| 07 Sniffing | `tcpdump` `masscan` `ettercap` `wireshark` |
| 08 Forensics | `autopsy` `testdisk` `foremost` `binwalk` `scalpel` `ddrescue` `ewf-tools` `exiftool` `clamscan` `yara` `ssdeep` `steghide` |
| 09 Reverse eng. | `gdb` `strace` `ltrace` `checksec` |
| 10 Net monitoring | `iftop` `nethogs` `vnstat` |

Metasploit, Nikto and Burp Suite Community aren't Debian packages — each
is installed by its own method. Run `msfdb init` before your first
`msfconsole`.

Chakra deliberately does **not** restrict `ptrace` (`gdb`/`strace`/
`ltrace` need it). The firewall is default-deny **inbound**, permissive
**outbound** (scanning and reverse shells need outbound).

---

## 5. Security Research

**Chakra Lab** — an isolated workspace for untrusted samples: firejail
(no network) by default, or a podman container for harder isolation.
Samples are hashed and made read-only; every action is audit-logged.

```
$ chakra-lab new case-01
$ chakra-lab drop ~/Downloads/suspicious.bin case-01
$ chakra-lab scan case-01        # file/hash/clamav/yara/ssdeep/strings
$ chakra-lab enter case-01       # shell inside (offline; --online asks first)
$ chakra-lab reset case-01       # wipe work, keep samples  (--hard = all)
```

**Chakra Reporter** — turns a session into a structured Markdown/HTML
report: findings by severity, IOCs, evidence, timeline.

```
$ chakra-reporter new "Incident 2026-04"
$ chakra-reporter finding weak-ssh --severity high --title "Password SSH exposed"
$ chakra-reporter ioc weak-ssh ip 203.0.113.7
$ chakra-reporter from-lab weak-ssh case-01
$ chakra-reporter build weak-ssh
```

---

## 6. Developer Tools

Chakra is a security OS, not a dev distro — these **inspect** an
environment rather than manage one.

| Command | Does |
|---|---|
| `chakra-portwatch` | listening sockets + owner + `local`/`EXPOSED`; `chakra-portwatch 3000` shows what's on a port and how to kill it |
| `chakra-containers` | formatted view over rootless podman: `ps` / `all` / `images` / `stats` / `logs` / `ports` / `prune` |
| `chakra-devenv` | project kind, runtime versions vs. what the project pins, `.env` keys |
| `chakra-apiwatch` | `sudo chakra-apiwatch 8080` — plaintext HTTP on a local port |
| `chakra-devhub` | a TUI over all four |

---

## 7. System Maintenance

| Command | Does |
|---|---|
| `chakra-fixer` | diagnoses common breakage; `sudo chakra-fixer --fix` applies safe repairs |
| `chakra-update` | refreshes the index, lists upgradable; `sudo chakra-update --apply` runs the upgrade (warns it won't persist) |
| `chakra-clean` | reclaims overlay/RAM space (apt cache, journal, `~/.cache`, `/tmp`, podman); shows the plan, asks first |
| `chakra-snapshot` | `save` / `list` / `restore` a `.tar.zst` of `/etc/chakra` + Chakra `/etc` + home. A config archive, not a filesystem snapshot |
| `chakra-perf` | power profile / governor / swappiness; `sudo chakra-perf performance\|balanced\|powersave`; `chakra-perf slow` |
| `chakra-battery` | charge / health / drain + advice; `sudo chakra-battery save` |

CLI-first (not in the menu): `chakra-search <query>` (files, packages,
processes, units, `$PATH`); `chakra-clip` (the clipboard from the shell).

---

## 8. Identity & login

`chakra-identity` reports how you log in and how hard it is to become
you — password, autologin, FIDO2 key, fingerprint, SSH, `sudo` rules,
Secure Boot / TPM / firmware.

```
$ chakra-identity
$ sudo chakra-identity add-key            # register a FIDO2 / U2F key
$ sudo chakra-identity require-key        # sudo now needs the key too
$ sudo chakra-identity add-fingerprint    # needs a reader
$ sudo chakra-identity require-password   # revert to password-only sudo
```

Enrolments live only in this session — `chakra-snapshot save` to keep
them. Secure Boot / MOK enrolment, TPM measured boot and a locked
bootloader are **deferred to a future installer**.

---

## 9. Mobile — your phone

`chakra-link` pairs a phone over KDE Connect (install the KDE Connect app
from F-Droid / Play Store): pair → sync → share → find.

```
$ chakra-link                # status: daemon, devices, exposure
$ chakra-link pair Pixel
$ chakra-link send report.pdf Pixel
$ chakra-link find Pixel                 # ring it, even on silent
$ sudo chakra-link firewall --open       # let the phone reach the desktop (LAN)
$ chakra-link off                        # stop the daemon, close 1714–1764
```

KDE Connect listens on 1714–1764 on every interface; Chakra is
default-deny inbound — desktop-initiated actions work immediately, a
phone-initiated connection needs `firewall --open` first (not saved
across a reboot).

---

## 10. Appearance

```
$ chakra-shell                       # current theme + state
$ chakra-shell theme dark            # dark | light | high-contrast | fluent
$ chakra-shell theme auto            # switch light/dark by the clock
$ chakra-shell layout reset          # rebuild the Chakra panel
```

`dark` / `light` / `high-contrast` use Chakra's orange-on-blue schemes;
`fluent` restores the default Windows 11 look. `auto` flips at 07:00 /
19:00 (`~/.config/chakra/shell.conf`).

The launcher/dock/panel/notification centre are stock Plasma, fully
themed; custom Chakra components are a separate project.

---

## 11. Windows compatibility

`chakra-compat` runs a Windows `.exe` on Wine 8.0 (64-bit), **boxed by
default**: firejail sandbox, no network, in a Wine prefix under
`~/.local/share/chakra/wine/`.

```
$ chakra-compat                       # status
$ chakra-compat run setup.exe         # sandboxed
$ chakra-compat run --online app.exe  # allow the network
$ chakra-compat analyze sample.exe    # offline throwaway prefix + change report
$ chakra-compat prefix new games      # a separate, named prefix
```

- **64-bit only.** A 32-bit `.exe` prints the `wine32:i386` steps (not bundled).
- **Not everything runs.** It's Wine — anticheat games and some installers don't.
- **Session only.** The prefix vanishes on reboot; `chakra-snapshot save` keeps it. No Steam / Proton.

---

## 12. Office & documents

The suite is **LibreOffice** (Writer, Calc, Impress); macro security is
set to **High** out of the box. `chakra-office` treats every document as
suspect.

```
$ chakra-office open report.docx        # read-only, no network
$ chakra-office open --trusted mine.odt # full edit
$ chakra-office inspect invoice.xlsm    # macros / OLE / links, without opening it
$ chakra-office scrub invoice.xlsm      # a macro- and metadata-free copy
```

`inspect` uses `oleid` + `olevba` for VBA macros, auto-execute triggers,
suspicious keywords, OLE objects and external links — and hands off to
Chakra Lab for a deeper look.

---

## 13. How Chakra works

**Everything is audited.** Every Chakra tool action is written to
`/var/log/chakra/audit/sentinel.jsonl`, one JSON object per line:
`{timestamp, actor, action, target, risk_tier, approved_by, result}`.
Read it with `chakra-loglens --source security` or `tail` it. Your
account is in `adm` so unprivileged tools can append.

**Risk tiers.** Actions are classified 0–3. Tier 0 is read-only and runs
without asking; higher tiers change the system and prompt or elevate.
Today everything automatic (Sentinel especially) is tier 0. The Policy
Engine for tiers 1–3 has a schema but isn't a running gate yet.

**Read-only first, `--json` everywhere.** The observability tools only
look; the ones that change things ask first and show the plan.

**Honest about what's deferred.** A real local LLM, an app-permission
broker (AppGuard), Secure Boot, and disk persistence all wait on a
future phase. Each area's `README.md` spells out what's real and pending.

---

## 14. Persistence & limits

> **Nothing persists by default.** v0.1 is a live ISO. The filesystem is
> a RAM overlay — installed packages, files, paired phones, enrolled
> keys, theme choices and Wine prefixes are all gone after a reboot.

To keep configuration between sessions:

```
$ chakra-snapshot save my-setup           # writes my-setup-*.tar.zst
# … copy that file to a USB stick …
$ chakra-snapshot restore my-setup-2026-04-01.tar.zst
```

Not in v0.1, pending the installer:

- A real install to disk, with persistence and disk encryption at rest
- Secure Boot / MOK enrolment, TPM measured boot, a signed+locked bootloader
- Block-level snapshots and rollback
- Unattended security upgrades
- A bundled local LLM, AppGuard, a custom Chakra shell, 32-bit Wine, Steam/Proton

---

## 15. Building the ISO

One script, from a Debian host with `debootstrap`, `squashfs-tools`,
`xorriso`, `grub-pc-bin`, `grub-efi-amd64-bin`, `mtools`, `dosfstools`:

```
sudo build/scripts/build_iso.sh            # reuse an existing build/rootfs
sudo build/scripts/build_iso.sh --clean    # from-scratch debootstrap (reproducible)
sudo build/scripts/build_iso.sh --check    # abort if tests/run.sh fails
sudo build/scripts/build_iso.sh --test     # boot the finished ISO in QEMU
```

`tests/run.sh` is a read-only check suite (every `chakra-*` command,
every menu entry, the security substrate). GitHub Actions runs `lint` on
every push and the full `--clean` `build-iso` on version tags. Pipeline:
*debootstrap → package install → branding → squashfs → GRUB → ISO.*

---

*Chakra OS v0.1 "Sudarshana" — named after Lord Vishnu's Sudarshana
Chakra, a tool meant to do everything. Full history in
[`roadmap.md`](roadmap.md) and [`../CHANGELOG.md`](../CHANGELOG.md).*
