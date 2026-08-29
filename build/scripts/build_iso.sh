#!/bin/bash
# Chakra OS reproducible ISO build pipeline (v0.1, codename "Sudarshana").
# See docs/roadmap.md for the full phase breakdown.
#
#   debootstrap -> package install -> user/branding config ->
#   squashfs -> ISO staging -> grub-mkrescue -> checksum -> (optional) QEMU test
#
# Usage:
#   sudo build/scripts/build_iso.sh [--clean] [--test]
#
#   --clean   wipe build/rootfs, build/iso, build/output before starting
#             (a fresh debootstrap takes a while; omit to reuse an existing rootfs)
#   --test    boot the finished ISO in QEMU after building

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config"
BUILD_DIR="$PROJECT_ROOT/build"
ROOTFS="$BUILD_DIR/rootfs"
ISO_STAGE="$BUILD_DIR/iso"
OUTPUT_DIR="$BUILD_DIR/output"

CHAKRA_VERSION="0.1"
ISO_NAME="ChakraOS-v${CHAKRA_VERSION}-amd64.iso"
DEBIAN_SUITE="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"

CLEAN=0
RUN_TEST=0
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --test) RUN_TEST=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

log() { echo -e "\n[chakra-build] $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "This script must run as root (it uses debootstrap/chroot/mount)." >&2
    echo "Run: sudo $0 $*" >&2
    exit 1
  fi
}

check_deps() {
  log "Checking host build dependencies..."
  local missing=()
  for bin in debootstrap mksquashfs xorriso grub-mkrescue mkfs.vfat mcopy; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing required host tools: ${missing[*]}" >&2
    echo "Install with: apt-get install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools" >&2
    exit 1
  fi
  log "All host dependencies present."
}

cleanup_mounts() {
  for m in dev/pts dev proc sys; do
    mountpoint -q "$ROOTFS/$m" 2>/dev/null && umount -lf "$ROOTFS/$m" 2>/dev/null || true
  done
}
trap cleanup_mounts EXIT

clean_build_dirs() {
  [[ "$CLEAN" -eq 1 ]] || return 0
  log "Cleaning previous build artifacts..."
  cleanup_mounts
  for d in "$ROOTFS" "$ISO_STAGE" "$OUTPUT_DIR"; do
    [[ "$d" == "$BUILD_DIR"/* ]] || { echo "Refusing to clean path outside build/: $d" >&2; exit 1; }
    rm -rf "${d:?}"
    mkdir -p "$d"
  done
}

bootstrap_rootfs() {
  if [[ -x "$ROOTFS/bin/bash" ]]; then
    log "Rootfs already bootstrapped at $ROOTFS, skipping debootstrap (use --clean to redo)."
    return 0
  fi
  log "Debootstrapping Debian $DEBIAN_SUITE into $ROOTFS..."
  mkdir -p "$ROOTFS"
  debootstrap --arch=amd64 "$DEBIAN_SUITE" "$ROOTFS" "$DEBIAN_MIRROR"
}

configure_base() {
  log "Applying base configuration (hostname, apt sources, resolv.conf)..."
  cp "$CONFIG_DIR/system/hostname" "$ROOTFS/etc/hostname"
  local host; host="$(cat "$CONFIG_DIR/system/hostname")"
  cat > "$ROOTFS/etc/hosts" <<EOF
127.0.0.1   localhost
127.0.1.1   $host
::1         localhost ip6-localhost ip6-loopback
EOF
  echo "deb $DEBIAN_MIRROR $DEBIAN_SUITE main" > "$ROOTFS/etc/apt/sources.list"
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
}

mount_virtual_fs() {
  log "Mounting virtual filesystems for chroot..."
  mount --bind /dev "$ROOTFS/dev"
  mount --bind /dev/pts "$ROOTFS/dev/pts"
  mount -t proc proc "$ROOTFS/proc"
  mount -t sysfs sys "$ROOTFS/sys"
}

install_packages() {
  log "Installing package set into rootfs (this downloads from the network)..."
  local pkgs=()
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -n "$line" ]] && pkgs+=("$line")
  done < "$CONFIG_DIR/packages/packages.list"

  chroot "$ROOTFS" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ${pkgs[*]}
    apt-get clean
  "
}

install_metasploit() {
  # Metasploit isn't in Debian's own repos — the official route is Rapid7's
  # installer script, which adds their own signed apt repo and pulls in its
  # dependencies (including PostgreSQL) that way. This is a large download
  # (multi-GB) and, unlike everything in packages.list, isn't a single
  # verifiable package name — best-effort and non-fatal if it fails.
  log "Installing Metasploit Framework (Rapid7 official installer — large download)..."
  # msfinstall's gpg key import prompts "Overwrite?" if a keyring from a
  # prior (e.g. interrupted) run already exists, and hangs forever since
  # nothing can answer that non-interactively — remove it first so reruns
  # are safe.
  rm -f "$ROOTFS/usr/share/keyrings/metasploit-framework.gpg"
  chroot "$ROOTFS" bash -c '
    set -e
    cd /tmp
    curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
    chmod 755 msfinstall
    ./msfinstall < /dev/null
    rm -f msfinstall
  ' || { log "WARNING: Metasploit installer failed (network issue?) — continuing without it."; return 0; }

  # The installer's own dependencies include PostgreSQL; enable it so the
  # service is available once actually booted (chroot has no running init
  # to start it now). msfdb init itself needs a live session, so that's a
  # one-time step for whoever first launches msfconsole.
  chroot "$ROOTFS" systemctl enable postgresql >/dev/null 2>&1 || true
  log "Metasploit installed — run 'msfdb init' the first time msfconsole is launched in the live session."
}

install_nikto() {
  # Not in Debian's repos (confirmed via dry-run earlier), but it's just a
  # lightweight Perl script with no heavy installer — plain git clone.
  log "Installing Nikto web server scanner from source (not in Debian repos)..."
  chroot "$ROOTFS" bash -c '
    set -e
    rm -rf /opt/nikto
    git clone --depth 1 https://github.com/sullo/nikto.git /opt/nikto
    chmod +x /opt/nikto/program/nikto.pl
    ln -sf /opt/nikto/program/nikto.pl /usr/local/bin/nikto
  ' || { log "WARNING: Nikto install failed (network issue?) — continuing without it."; return 0; }
}

install_burpsuite() {
  # Burp Suite Community isn't in Debian's repos, and unlike Metasploit,
  # PortSwigger doesn't publish documented silent-install flags for the
  # Community edition specifically (only Enterprise/DAST). This uses -q
  # from its BitRock InstallBuilder base as a best-effort guess — more
  # likely than anything else here to need manual follow-up in the live
  # session if the installer expects a display even in "quiet" mode.
  log "Installing Burp Suite Community Edition (best-effort — undocumented silent flags)..."
  chroot "$ROOTFS" bash -c '
    set -e
    cd /tmp
    curl -L -o burpsuite_installer.sh "https://portswigger.net/burp/releases/download?product=community&type=Linux"
    chmod +x burpsuite_installer.sh
    ./burpsuite_installer.sh -q -dir /opt/BurpSuiteCommunity
    rm -f burpsuite_installer.sh
    ln -sf /opt/BurpSuiteCommunity/BurpSuiteCommunity /usr/local/bin/burpsuite
  ' || { log "WARNING: Burp Suite installer failed or needs an interactive display — download and run it manually from the live session if needed: https://portswigger.net/burp/releases/community/latest"; return 0; }
}

create_default_user() {
  # shellcheck disable=SC1090
  source "$CONFIG_DIR/defaults/user.conf"
  if chroot "$ROOTFS" id "$CHAKRA_USERNAME" >/dev/null 2>&1; then
    log "User $CHAKRA_USERNAME already exists, skipping creation."
    return 0
  fi
  log "Creating default user '$CHAKRA_USERNAME'..."
  chroot "$ROOTFS" adduser --disabled-password --gecos "" "$CHAKRA_USERNAME"
  chroot "$ROOTFS" usermod -aG "$CHAKRA_USER_GROUPS" "$CHAKRA_USERNAME"

  echo "Set a password for the '$CHAKRA_USERNAME' account in the built image:"
  chroot "$ROOTFS" passwd "$CHAKRA_USERNAME"
}

apply_chakra_core() {
  log "Installing chakra-core (system identity, directories, environment)..."

  # Filesystem layout, declared once via systemd-tmpfiles (core/systemd/)
  # so it's self-healing on every boot, not just baked in at build time.
  mkdir -p "$ROOTFS/usr/lib/tmpfiles.d"
  cp "$PROJECT_ROOT/core/systemd/chakra-core.conf" "$ROOTFS/usr/lib/tmpfiles.d/chakra-core.conf"

  # Create them now too, so they exist in the shipped image immediately
  # rather than only after the first tmpfiles-setup run. Ownership here
  # matches the tmpfiles.d declaration above rather than relying on first
  # boot to reconcile it.
  mkdir -p "$ROOTFS/etc/chakra/policy.d" \
           "$ROOTFS/usr/lib/chakra" \
           "$ROOTFS/usr/share/chakra" \
           "$ROOTFS/var/lib/chakra" \
           "$ROOTFS/var/log/chakra"
  chmod 0750 "$ROOTFS/var/lib/chakra" "$ROOTFS/var/log/chakra"
  chroot "$ROOTFS" chown root:adm /var/log/chakra || true

  # This rootfs persists across rebuilds (build/rootfs is only wiped with
  # --clean). An earlier build wrote the neofetch ascii art to an ad hoc
  # /usr/share/chakra-os/ path before /usr/share/chakra/ was the
  # established chakra-core location -- remove that leftover so it
  # doesn't ship as orphaned, unreferenced cruft alongside the real one.
  rm -rf "$ROOTFS/usr/share/chakra-os"

  # Chakra's own machine-readable identity file -- distinct from
  # /etc/os-release, for future chakra-* tools to read directly.
  cat > "$ROOTFS/etc/chakra-release" <<EOF
CHAKRA_NAME="Chakra OS"
CHAKRA_VERSION="$CHAKRA_VERSION"
CHAKRA_CODENAME="Sudarshana"
CHAKRA_BASE="Debian GNU/Linux $DEBIAN_SUITE"
CHAKRA_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CHAKRA_HOME_URL="https://github.com/naresh1807/ChakraOS"
EOF

  # Same identity, as an environment variable, without needing to parse
  # the release file.
  mkdir -p "$ROOTFS/etc/profile.d"
  cat > "$ROOTFS/etc/profile.d/chakra.sh" <<EOF
export CHAKRA_VERSION="$CHAKRA_VERSION"
export CHAKRA_CODENAME="Sudarshana"
EOF
  chmod 644 "$ROOTFS/etc/profile.d/chakra.sh"
}

apply_security_substrate() {
  log "Installing security substrate (firewall, kernel hardening, audit, policy schema)..."
  local sec_cfg="$PROJECT_ROOT/core/security"

  # Firewall: default-deny inbound, permissive outbound (see the
  # ruleset's own comments for why -- this is a pentesting OS).
  cp "$sec_cfg/nftables.conf" "$ROOTFS/etc/nftables.conf"
  chroot "$ROOTFS" systemctl enable nftables >/dev/null 2>&1 || true

  # Kernel/network hardening -- deliberately excludes ptrace_scope; see
  # the file's own comment for why.
  mkdir -p "$ROOTFS/etc/sysctl.d"
  cp "$sec_cfg/sysctl-hardening.conf" "$ROOTFS/etc/sysctl.d/60-chakra-hardening.conf"

  # OS-level audit trail (auditd). The higher-level "Chakra Audit"
  # JSON-schema trail from the master manual is future work once
  # Sentinel/the Policy Engine actually produce decisions worth logging
  # -- this is the underlying log those would sit alongside.
  chroot "$ROOTFS" systemctl enable auditd >/dev/null 2>&1 || true

  # Policy schema foundation -- not yet enforced by anything; see
  # core/policies/README.md for why this is schema-only for now.
  mkdir -p "$ROOTFS/etc/chakra/policy.d"
  cp "$PROJECT_ROOT/core/policies/examples/"*.json "$ROOTFS/etc/chakra/policy.d/" 2>/dev/null || true
}

apply_branding_and_boot_target() {
  log "Applying Chakra OS branding and boot target..."
  sed -i \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Chakra OS '"$CHAKRA_VERSION"'"/' \
    -e 's/^NAME=.*/NAME="Chakra OS"/' \
    "$ROOTFS/etc/os-release"
  # This rootfs persists across rebuilds -- strip any block appended by an
  # earlier run before appending the current one, so os-release doesn't
  # grow a duplicate copy of these lines on every rebuild.
  sed -i '/# --- Chakra OS os-release fields ---/,/# --- end Chakra OS os-release fields ---/d' "$ROOTFS/etc/os-release"
  {
    echo ""
    echo "# --- Chakra OS os-release fields ---"
    echo "CHAKRA_VERSION=$CHAKRA_VERSION"
    echo "CHAKRA_CODENAME=\"Sudarshana\""
    echo "CHAKRA_BASE=\"Debian GNU/Linux $DEBIAN_SUITE\""
    echo "ANSI_COLOR=\"0;38;5;33\""
    echo "HOME_URL=\"https://github.com/naresh1807/ChakraOS\""
    echo "SUPPORT_URL=\"https://github.com/naresh1807/ChakraOS\""
    echo "BUG_REPORT_URL=\"https://github.com/naresh1807/ChakraOS/issues\""
    echo "# --- end Chakra OS os-release fields ---"
  } >> "$ROOTFS/etc/os-release"

  mkdir -p "$ROOTFS/usr/share/doc/chakra-os"
  cat > "$ROOTFS/usr/share/doc/chakra-os/ATTRIBUTION.txt" <<EOF
Chakra OS is built on Debian GNU/Linux ($DEBIAN_SUITE).
Debian is a trademark of Software in the Public Interest, Inc.
See /usr/share/doc/*/copyright for individual package licenses.
EOF

  # Static login banner (tty + ssh). A short, low-risk branding touch —
  # plain text, no ANSI codes, so it renders identically everywhere.
  cat > "$ROOTFS/etc/motd" <<EOF

  Welcome to Chakra OS $CHAKRA_VERSION
  Built on Debian GNU/Linux ($DEBIAN_SUITE)

EOF

  ln -sf /lib/systemd/system/graphical.target "$ROOTFS/etc/systemd/system/default.target"
  chroot "$ROOTFS" systemctl enable NetworkManager sddm >/dev/null 2>&1 || true

  log "Setting default timezone to Asia/Kolkata (IST)..."
  echo "Asia/Kolkata" > "$ROOTFS/etc/timezone"
  chroot "$ROOTFS" ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
  chroot "$ROOTFS" dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true
}

apply_boot_and_login_branding() {
  # shellcheck disable=SC1090
  source "$CONFIG_DIR/defaults/user.conf"
  local assets="$CONFIG_DIR/branding"
  log "Installing Plymouth boot splash, SDDM background, wallpaper, and neofetch branding..."

  # --- Plymouth boot splash ---
  if command -v chroot >/dev/null 2>&1 && [[ -d "$assets/plymouth" ]]; then
    mkdir -p "$ROOTFS/usr/share/plymouth/themes/chakra"
    cp "$assets/plymouth/"* "$ROOTFS/usr/share/plymouth/themes/chakra/"
    chroot "$ROOTFS" plymouth-set-default-theme -R chakra \
      || log "WARNING: plymouth-set-default-theme failed — boot will fall back to the stock splash/text mode."
  fi

  # --- Desktop wallpaper (installed as a proper wallpaper package dir so it
  # also shows up named "Chakra OS" in Plasma's wallpaper picker) ---
  local wp_dir="$ROOTFS/usr/share/wallpapers/ChakraOS/contents/images"
  mkdir -p "$wp_dir"
  cp "$assets/wallpaper/wallpaper-1920x1080.png" "$wp_dir/1920x1080.png"
  cat > "$ROOTFS/usr/share/wallpapers/ChakraOS/metadata.desktop" <<EOF
[Desktop Entry]
Name=Chakra OS
X-KDE-PluginInfo-Name=ChakraOS
EOF

  # --- SDDM login background (Breeze theme's supported override file) ---
  mkdir -p "$ROOTFS/usr/share/backgrounds"
  cp "$assets/sddm/sddm-background-1920x1080.png" "$ROOTFS/usr/share/backgrounds/chakra-sddm-background.png"
  if [[ -d "$ROOTFS/usr/share/sddm/themes/breeze" ]]; then
    cat > "$ROOTFS/usr/share/sddm/themes/breeze/theme.conf.user" <<EOF
[General]
background=/usr/share/backgrounds/chakra-sddm-background.png
EOF
  fi
  mkdir -p "$ROOTFS/etc/sddm.conf.d"
  cat > "$ROOTFS/etc/sddm.conf.d/chakra-theme.conf" <<EOF
[Theme]
Current=breeze
EOF

  # --- neofetch: system-wide ascii art + per-user config override.
  # image_source pointing at a plain text file makes neofetch cat it
  # directly as the logo (no colors unless the file has raw ANSI codes,
  # which this one deliberately doesn't, to render identically everywhere).
  # Lives under the chakra-core /usr/share/chakra/ path (see core/filesystem/README.md). ---
  mkdir -p "$ROOTFS/usr/share/chakra"
  cp "$assets/neofetch/ascii-logo.txt" "$ROOTFS/usr/share/chakra/ascii-logo.txt"
  local chakra_home="$ROOTFS/home/$CHAKRA_USERNAME"
  mkdir -p "$chakra_home/.config/neofetch"
  cat > "$chakra_home/.config/neofetch/config.conf" <<'EOF'
image_source="/usr/share/chakra/ascii-logo.txt"
EOF
  chroot "$ROOTFS" chown -R "$CHAKRA_USERNAME:$CHAKRA_USERNAME" "/home/$CHAKRA_USERNAME/.config" 2>/dev/null || true
}

apply_windows11_theme() {
  # shellcheck disable=SC1090
  source "$CONFIG_DIR/defaults/user.conf"
  log "Installing Windows 11-style theme (Fluent icons/cursors + global theme)..."

  chroot "$ROOTFS" bash -c '
    set -e
    rm -rf /tmp/theme-build
    mkdir -p /tmp/theme-build
    cd /tmp/theme-build

    git clone --depth 1 https://github.com/vinceliuice/Fluent-icon-theme.git
    (cd Fluent-icon-theme && ./install.sh -a -d /usr/share/icons)

    git clone --depth 1 https://github.com/vinceliuice/Fluent-kde.git
    (cd Fluent-kde && ./install.sh --round --color dark)
  ' || { log "WARNING: theme download/install failed (network issue?) — continuing without Windows 11 theme."; return 0; }

  # Discover the actual names the installers used rather than hardcoding guesses,
  # since these upstream projects can rename variants between releases.
  local icon_theme aurorae_theme kvantum_theme color_scheme lnf_id
  icon_theme="$(chroot "$ROOTFS" bash -c "ls /usr/share/icons 2>/dev/null | grep -i '^Fluent.*dark' | head -1")"
  [[ -n "$icon_theme" ]] || icon_theme="$(chroot "$ROOTFS" bash -c "ls /usr/share/icons 2>/dev/null | grep -i fluent | head -1")"
  aurorae_theme="$(chroot "$ROOTFS" bash -c "ls /usr/share/aurorae/themes 2>/dev/null | grep -i fluent | head -1")"
  kvantum_theme="$(chroot "$ROOTFS" bash -c "ls /usr/share/Kvantum 2>/dev/null | grep -i fluent | head -1")"
  color_scheme="$(chroot "$ROOTFS" bash -c "ls /usr/share/color-schemes 2>/dev/null | grep -i fluent | head -1" | sed 's/\.colors$//')"
  lnf_id="$(chroot "$ROOTFS" bash -c "ls /usr/share/plasma/look-and-feel 2>/dev/null | grep -i fluent | head -1")"

  log "Theme components found — icons: ${icon_theme:-none}, aurorae: ${aurorae_theme:-none}, kvantum: ${kvantum_theme:-none}, color-scheme: ${color_scheme:-none}, look-and-feel: ${lnf_id:-none}"

  # Pre-seed the default user's config directly. There is no live Plasma/D-Bus
  # session available inside a chroot to "apply" the theme normally, so we
  # write the config keys the running session would otherwise have written.
  local chakra_home="$ROOTFS/home/$CHAKRA_USERNAME"
  mkdir -p "$chakra_home/.config"

  {
    echo "[Icons]"
    echo "Theme=${icon_theme:-breeze-dark}"
    echo ""
    echo "[KDE]"
    echo "widgetStyle=kvantum"
    echo ""
    echo "[General]"
    [[ -n "$color_scheme" ]] && echo "ColorScheme=$color_scheme"
  } > "$chakra_home/.config/kdeglobals"

  if [[ -n "$aurorae_theme" ]]; then
    {
      echo "[org.kde.kdecoration2]"
      echo "library=org.kde.kwin.aurorae"
      echo "theme=__aurorae__svg__${aurorae_theme}"
    } > "$chakra_home/.config/kwinrc"
  fi

  if [[ -n "$kvantum_theme" ]]; then
    mkdir -p "$chakra_home/.config/Kvantum"
    {
      echo "[General]"
      echo "theme=$kvantum_theme"
    } > "$chakra_home/.config/Kvantum/kvantum.kvconfig"
  fi

  {
    echo "[Mouse]"
    echo "cursorTheme=${icon_theme:-breeze_cursors}"
  } > "$chakra_home/.config/kcminputrc"

  # Taskbar stays at Plasma's own default (left-aligned) layout. An earlier
  # build baked a centered layout into this same persistent rootfs — remove
  # that leftover file so Plasma regenerates its true stock default instead
  # of reusing the old centered one.
  rm -f "$chakra_home/.config/plasma-org.kde.plasma.desktop-appletsrc"

  chroot "$ROOTFS" chown -R "$CHAKRA_USERNAME:$CHAKRA_USERNAME" "/home/$CHAKRA_USERNAME/.config"

  chroot "$ROOTFS" rm -rf /tmp/theme-build

  # Point the active look-and-feel's own "defaults" file at the Chakra OS
  # wallpaper, rather than hand-writing the containment/panel layout
  # ourselves — this is the officially-supported hook Plasma reads when it
  # self-generates a fresh desktop config, so it doesn't fight with the
  # "let Plasma regenerate its own stock panel layout" decision above.
  local wallpaper_file="/usr/share/wallpapers/ChakraOS/contents/images/1920x1080.png"
  if [[ -n "$lnf_id" && -f "$ROOTFS/usr/share/plasma/look-and-feel/$lnf_id/contents/defaults" && -f "$ROOTFS$wallpaper_file" ]]; then
    local defaults_file="$ROOTFS/usr/share/plasma/look-and-feel/$lnf_id/contents/defaults"
    # Strip any override block from a previous run of this same build (this
    # rootfs persists across rebuilds), then append a fresh one.
    sed -i '/# --- Chakra OS wallpaper override ---/,/# --- end Chakra OS wallpaper override ---/d' "$defaults_file"
    {
      echo ""
      echo "# --- Chakra OS wallpaper override ---"
      echo "[Wallpaper][org.kde.image][General]"
      echo "Image=$wallpaper_file"
      echo "# --- end Chakra OS wallpaper override ---"
    } >> "$defaults_file"
    log "Default wallpaper set via $lnf_id look-and-feel defaults."
  else
    log "WARNING: could not locate look-and-feel defaults file — desktop wallpaper will stay at the theme's own default."
  fi

  # The defaults-file hook above turned out NOT to be sufficient on its
  # own (confirmed by boot-testing: the desktop still showed
  # Fluent-kde's own bundled wallpaper package, not ours). Fluent-kde
  # ships its own wallpaper package name-matched to the look-and-feel
  # (e.g. /usr/share/wallpapers/Fluent-round-dark/contents/images/3840x2160.png)
  # which takes precedence over the generic defaults hook. Fix: overwrite
  # that package's actual image file with ours directly, so whatever
  # mechanism is already correctly finding and displaying it shows our
  # design instead -- sidesteps needing to know the exact selection logic.
  local wp_pkg_dir wp_src_4k="$CONFIG_DIR/branding/wallpaper/wallpaper-3840x2160.png"
  for wp_pkg_dir in "$ROOTFS/usr/share/wallpapers/"Fluent*; do
    [[ -d "$wp_pkg_dir/contents/images" ]] || continue
    local img
    for img in "$wp_pkg_dir/contents/images/"*.png; do
      [[ -f "$img" ]] || continue
      cp "$wp_src_4k" "$img"
    done
    log "Overwrote bundled wallpaper images in $(basename "$wp_pkg_dir") with the Chakra wallpaper."
  done
}

apply_desktop_icons() {
  # shellcheck disable=SC1090
  source "$CONFIG_DIR/defaults/user.conf"
  log "Adding Windows-style desktop icons (This PC, Recycle Bin, Network, Home, Control Panel)..."

  # Plasma's stock desktop containment is Folder View pointed at ~/Desktop
  # by default, so dropping .desktop launchers there is enough to make them
  # show up as icons — no containment/appletsrc surgery needed. Genuinely
  # unverified until boot-tested, since that default can in principle be
  # overridden elsewhere in the theme stack.
  local chakra_home="$ROOTFS/home/$CHAKRA_USERNAME"
  local desktop_dir="$chakra_home/Desktop"
  mkdir -p "$desktop_dir"
  local f name
  for f in "$CONFIG_DIR/desktop-icons/"*.desktop; do
    name="$(basename "$f")"
    sed "s|@@CHAKRA_HOME@@|/home/$CHAKRA_USERNAME|g" "$f" > "$desktop_dir/$name"
    chmod +x "$desktop_dir/$name"
  done
  chroot "$ROOTFS" chown -R "$CHAKRA_USERNAME:$CHAKRA_USERNAME" "/home/$CHAKRA_USERNAME/Desktop"
}

apply_friendly_app_names() {
  log "Renaming KDE app menu entries to familiar Windows/Kali-style names..."
  local apps_dir="$ROOTFS/usr/share/applications"
  [[ -d "$apps_dir" ]] || { log "WARNING: $apps_dir not found — skipping app rename pass."; return 0; }

  _chakra_rename_app() {
    local pattern="$1" new_name="$2"
    local m
    # Discover the actual shipped filename(s) rather than hardcoding an
    # exact desktop-file-id, since that varies by package/version — same
    # approach used for the Fluent theme component discovery above.
    for m in $(ls "$apps_dir" 2>/dev/null | grep -i "$pattern" || true); do
      # Replace only the first, unlocalized "Name=" line; leave any
      # localized Name[xx]= entries alone.
      sed -i "0,/^Name=/{s/^Name=.*/Name=$new_name/}" "$apps_dir/$m"
    done
  }

  _chakra_rename_app "konsole"        "Terminal"
  _chakra_rename_app "dolphin"        "File Explorer"
  _chakra_rename_app "kate"           "Text Editor"
  _chakra_rename_app "kwrite"         "Notepad"
  _chakra_rename_app "discover"       "Software Center"
  _chakra_rename_app "systemsettings" "Control Panel"
  _chakra_rename_app "spectacle"      "Snipping Tool"
  unset -f _chakra_rename_app

  # The Kali-style "two terminals" split: the renamed Terminal above stays a
  # normal-user shell; this adds a second, separate menu entry that opens
  # straight into a root shell via sudo (chakra is already in the sudo
  # group from create_default_user), same pairing Kali's menu has long
  # offered and that Windows 11's Start menu mirrors as "Terminal" /
  # "Terminal (Admin)".
  cat > "$apps_dir/chakra-terminal-admin.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminal (Admin)
Comment=Terminal with administrator (root) privileges
Icon=utilities-terminal
Exec=konsole -e sudo -s
Terminal=false
Categories=System;TerminalEmulator;
EOF
}

apply_security_menu() {
  log "Building Kali-style categorized security tools menu..."
  local menu_cfg="$PROJECT_ROOT/config/security-menu"
  local apps_dir="$ROOTFS/usr/share/applications"
  local dirs_dir="$ROOTFS/usr/share/desktop-directories"
  local merged_dir="$ROOTFS/etc/xdg/menus/applications-merged"
  mkdir -p "$apps_dir" "$dirs_dir" "$merged_dir"

  # Root menu structure: a "Security Tools" submenu with 10 numbered
  # categories, merged in via the standard XDG <DefaultMergeDirs/>
  # mechanism rather than editing the system's own root menu file.
  cp "$menu_cfg/chakra-security-tools.directory" "$dirs_dir/"
  cp "$menu_cfg/chakra-security-tools.menu" "$merged_dir/"

  # Per-category .directory files, generated from categories.list so
  # adding a category later is a one-line data change, not new code.
  local id name icon
  while IFS='|' read -r id name icon; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    cat > "$dirs_dir/chakra-$id.directory" <<EOF
[Desktop Entry]
Type=Directory
Name=$name
Icon=$icon
EOF
  done < "$menu_cfg/categories.list"

  # Per-tool launchers, generated from tools.list. Same explicit
  # "konsole -e bash -c ..." + Terminal=false pattern already proven to
  # work for the Terminal (Admin) entry above, rather than Terminal=true
  # (which depends on KDE's default-terminal-app resolution actually
  # landing on Konsole -- one less unproven variable across ~50 new files).
  local tname cat exec_cmd needs_root safe_id run_cmd
  while IFS='|' read -r tname cat exec_cmd needs_root; do
    [[ -z "$tname" || "$tname" == \#* ]] && continue
    safe_id="$(echo "$tname" | tr -c 'a-zA-Z0-9' '-' | tr -s '-')"
    run_cmd="$exec_cmd"
    [[ "$needs_root" == "1" ]] && run_cmd="sudo $exec_cmd"
    cat > "$apps_dir/chakra-tool-$safe_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$tname
Icon=utilities-terminal
Exec=konsole -e bash -c "$run_cmd; echo; echo '--- press Enter to close ---'; read"
Terminal=false
Categories=X-Chakra-$cat;
EOF
  done < "$menu_cfg/tools.list"

  # Burp Suite is a GUI app with no Debian-provided .desktop file.
  if [[ -x "$ROOTFS/usr/local/bin/burpsuite" ]]; then
    cat > "$apps_dir/chakra-tool-burpsuite.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Burp Suite
Icon=utilities-terminal
Exec=burpsuite
Terminal=false
Categories=X-Chakra-03-web-app-analysis;
EOF
  fi

  # Tools that already ship their own GUI .desktop file: add our category
  # to it rather than creating a duplicate entry with a different
  # desktop-file-id. Discovered by pattern, not hardcoded, since the
  # exact filename/providing sub-package can vary (e.g. Wireshark's GUI
  # comes from wireshark-qt, not the wireshark package itself).
  _chakra_add_category() {
    local file="$1" cat="$2"
    [[ -f "$file" ]] || return 0
    grep -q "X-Chakra-$cat" "$file" && return 0
    if grep -q "^Categories=" "$file"; then
      sed -i "s/^Categories=/Categories=X-Chakra-$cat;/" "$file"
    else
      echo "Categories=X-Chakra-$cat;" >> "$file"
    fi
  }
  local f
  for f in $(ls "$apps_dir" 2>/dev/null | grep -i wireshark); do
    _chakra_add_category "$apps_dir/$f" "07-sniffing-spoofing"
  done
  _chakra_add_category "$apps_dir/ettercap.desktop" "07-sniffing-spoofing"
  _chakra_add_category "$apps_dir/guymager.desktop" "08-forensics"
  unset -f _chakra_add_category
}

apply_chakra_tools() {
  log "Installing Chakra Tools (Phase 6 read-only observability scripts + menu)..."
  local dash_cfg="$PROJECT_ROOT/core/dashboard"
  local menu_cfg="$PROJECT_ROOT/config/chakra-tools-menu"
  local apps_dir="$ROOTFS/usr/share/applications"
  local dirs_dir="$ROOTFS/usr/share/desktop-directories"
  local merged_dir="$ROOTFS/etc/xdg/menus/applications-merged"
  local bin_dir="$ROOTFS/usr/lib/chakra/bin"
  mkdir -p "$apps_dir" "$dirs_dir" "$merged_dir" "$bin_dir"

  # The actual Chakra system API scripts, in the chakra-core-reserved
  # /usr/lib/chakra/ path, symlinked into /usr/local/bin for direct use.
  local f name
  for f in "$dash_cfg/bin/"*; do
    name="$(basename "$f")"
    cp "$f" "$bin_dir/$name"
    chmod +x "$bin_dir/$name"
    ln -sf "/usr/lib/chakra/bin/$name" "$ROOTFS/usr/local/bin/$name"
  done

  # Menu: same DefaultMergeDirs mechanism as apply_security_menu(), a
  # separate top-level "Chakra Tools" section.
  cp "$menu_cfg/chakra-tools.directory" "$dirs_dir/"
  cp "$menu_cfg/chakra-tools.menu" "$merged_dir/"

  local tname cat exec_cmd needs_root safe_id run_cmd
  while IFS='|' read -r tname cat exec_cmd needs_root; do
    [[ -z "$tname" || "$tname" == \#* ]] && continue
    safe_id="$(echo "$tname" | tr -c 'a-zA-Z0-9' '-' | tr -s '-')"
    run_cmd="$exec_cmd"
    [[ "$needs_root" == "1" ]] && run_cmd="sudo $exec_cmd"
    cat > "$apps_dir/chakra-tool-dash-$safe_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$tname
Icon=utilities-system-monitor
Exec=konsole -e bash -c "$run_cmd; echo; echo '--- press Enter to close ---'; read"
Terminal=false
Categories=X-Chakra-$cat;
EOF
  done < "$menu_cfg/tools.list"
}

apply_chakra_sentinel() {
  log "Installing Chakra Sentinel (Phase 7, read-only mode)..."
  local bin_dir="$ROOTFS/usr/lib/chakra/bin"
  local apps_dir="$ROOTFS/usr/share/applications"
  mkdir -p "$bin_dir" "$apps_dir" "$ROOTFS/etc/chakra"

  # Audit writer (core/security/) + the Sentinel dispatcher itself
  # (ai-agent/reasoning/) both land in the same canonical chakra-core
  # bin path used by the Phase 6 tools they call.
  cp "$PROJECT_ROOT/core/security/bin/chakra-audit-log" "$bin_dir/chakra-audit-log"
  cp "$PROJECT_ROOT/ai-agent/reasoning/chakra-sentinel" "$bin_dir/chakra-sentinel"
  chmod +x "$bin_dir/chakra-audit-log" "$bin_dir/chakra-sentinel"
  ln -sf /usr/lib/chakra/bin/chakra-audit-log "$ROOTFS/usr/local/bin/chakra-audit-log"
  ln -sf /usr/lib/chakra/bin/chakra-sentinel "$ROOTFS/usr/local/bin/chakra-sentinel"

  # NVIDIA NIM stays off (blank key) unless the user edits this
  # themselves -- see ai-agent/README.md for why that's deliberate.
  cp "$PROJECT_ROOT/ai-agent/reasoning/sentinel.conf.example" "$ROOTFS/etc/chakra/sentinel.conf"

  cat > "$apps_dir/chakra-tool-dash-Chakra-Sentinel.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chakra Sentinel
Comment=Ask about system health, processes, network, updates, security, or devices
Icon=utilities-system-monitor
Exec=konsole -e chakra-sentinel
Terminal=false
Categories=X-Chakra-Tools;
EOF
}

apply_permission_enforcement() {
  log "Installing permission & privacy enforcement (Phase 8: USB Guard, Vault, File Inspector, Sandbox)..."
  local sec_cfg="$PROJECT_ROOT/core/security"
  local bin_dir="$ROOTFS/usr/lib/chakra/bin"
  local apps_dir="$ROOTFS/usr/share/applications"
  mkdir -p "$bin_dir" "$apps_dir" "$ROOTFS/etc/usbguard"

  # Real CLI tools: Vault (LUKS2), File Inspector, Sandbox (firejail wrapper).
  cp "$sec_cfg/bin/chakra-vault" "$bin_dir/chakra-vault"
  cp "$sec_cfg/bin/chakra-file-inspector" "$bin_dir/chakra-file-inspector"
  cp "$PROJECT_ROOT/isolation/sandbox/chakra-sandbox" "$bin_dir/chakra-sandbox"
  chmod +x "$bin_dir/chakra-vault" "$bin_dir/chakra-file-inspector" "$bin_dir/chakra-sandbox"
  ln -sf /usr/lib/chakra/bin/chakra-vault "$ROOTFS/usr/local/bin/chakra-vault"
  ln -sf /usr/lib/chakra/bin/chakra-file-inspector "$ROOTFS/usr/local/bin/chakra-file-inspector"
  ln -sf /usr/lib/chakra/bin/chakra-sandbox "$ROOTFS/usr/local/bin/chakra-sandbox"

  # USB Guard: the real daemon, bootstrapped to allow what's connected
  # at boot and block new insertions by default. See
  # core/security/usbguard/README.md for the honest gap (no interactive
  # "ask" prompt yet -- Daily mode's "ask" degrades to "block").
  cp "$sec_cfg/usbguard/usbguard-daemon.conf" "$ROOTFS/etc/usbguard/usbguard-daemon.conf"
  mkdir -p "$ROOTFS/lib/systemd/system"
  cp "$sec_cfg/usbguard/chakra-usbguard-bootstrap.service" \
    "$ROOTFS/lib/systemd/system/chakra-usbguard-bootstrap.service"
  chroot "$ROOTFS" systemctl enable chakra-usbguard-bootstrap.service >/dev/null 2>&1 || true
  chroot "$ROOTFS" systemctl enable usbguard >/dev/null 2>&1 || true

  # Vault gets a menu entry (genuinely interactive: create/open/close/list);
  # File Inspector and Sandbox both need a target argument, so they're
  # CLI-first like the offensive tools in the Security Tools menu --
  # available via /usr/local/bin, not force-fit into a launcher here.
  cat > "$apps_dir/chakra-tool-dash-Chakra-Vault.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chakra Vault
Comment=Encrypted storage (LUKS2) -- create, open, close, list vaults
Icon=utilities-system-monitor
Exec=konsole -e bash -c "chakra-vault list; echo; echo 'Try: sudo chakra-vault create <name> <size_mb>'; exec bash"
Terminal=false
Categories=X-Chakra-Tools;
EOF
}

build_squashfs() {
  log "Building squashfs from rootfs..."
  mkdir -p "$ISO_STAGE/live" "$ISO_STAGE/boot/grub"
  mksquashfs "$ROOTFS" "$ISO_STAGE/live/filesystem.squashfs" \
    -noappend -comp xz -e boot \
    2>&1 | tail -5
}

stage_kernel_and_grub() {
  log "Staging kernel, initrd, and GRUB configuration..."
  local kernel initrd
  kernel="$(ls "$ROOTFS"/boot/vmlinuz-* | sort -V | tail -1)"
  initrd="$(ls "$ROOTFS"/boot/initrd.img-* | sort -V | tail -1)"
  cp "$kernel" "$ISO_STAGE/live/vmlinuz"
  cp "$initrd" "$ISO_STAGE/live/initrd.img"
  sed "s/@@CHAKRA_VERSION@@/$CHAKRA_VERSION/g" \
    "$CONFIG_DIR/boot/grub.cfg.template" > "$ISO_STAGE/boot/grub/grub.cfg"
}

build_iso() {
  log "Generating $ISO_NAME with grub-mkrescue..."
  mkdir -p "$OUTPUT_DIR"
  grub-mkrescue -o "$OUTPUT_DIR/$ISO_NAME" "$ISO_STAGE"
  ( cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256" )
  log "ISO written to $OUTPUT_DIR/$ISO_NAME"
}

boot_test() {
  [[ "$RUN_TEST" -eq 1 ]] || return 0
  if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "qemu-system-x86_64 not installed; skipping --test." >&2
    return 0
  fi
  log "Booting $ISO_NAME in QEMU..."
  local accel=()
  [[ -e /dev/kvm ]] && accel=(-enable-kvm)
  qemu-system-x86_64 "${accel[@]}" -m 2048 -cdrom "$OUTPUT_DIR/$ISO_NAME" -boot d
}

main() {
  require_root "$@"
  check_deps
  clean_build_dirs
  bootstrap_rootfs
  configure_base
  mount_virtual_fs
  install_packages
  install_metasploit
  install_nikto
  install_burpsuite
  create_default_user
  apply_chakra_core
  apply_security_substrate
  apply_branding_and_boot_target
  apply_boot_and_login_branding
  apply_windows11_theme
  apply_desktop_icons
  apply_friendly_app_names
  apply_security_menu
  apply_chakra_tools
  apply_chakra_sentinel
  apply_permission_enforcement
  cleanup_mounts
  build_squashfs
  stage_kernel_and_grub
  build_iso
  boot_test
  log "Done."
}

main "$@"
