#!/bin/bash
# Chakra OS reproducible ISO build pipeline (Phase 1 / v0.1).
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

apply_branding_and_boot_target() {
  log "Applying Chakra OS branding and boot target..."
  sed -i \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Chakra OS '"$CHAKRA_VERSION"'"/' \
    -e 's/^NAME=.*/NAME="Chakra OS"/' \
    "$ROOTFS/etc/os-release"
  {
    echo ""
    echo "CHAKRA_VERSION=$CHAKRA_VERSION"
    echo "CHAKRA_BASE=\"Debian GNU/Linux $DEBIAN_SUITE\""
  } >> "$ROOTFS/etc/os-release"

  mkdir -p "$ROOTFS/usr/share/doc/chakra-os"
  cat > "$ROOTFS/usr/share/doc/chakra-os/ATTRIBUTION.txt" <<EOF
Chakra OS is built on Debian GNU/Linux ($DEBIAN_SUITE).
Debian is a trademark of Software in the Public Interest, Inc.
See /usr/share/doc/*/copyright for individual package licenses.
EOF

  ln -sf /lib/systemd/system/graphical.target "$ROOTFS/etc/systemd/system/default.target"
  chroot "$ROOTFS" systemctl enable NetworkManager sddm >/dev/null 2>&1 || true

  log "Setting default timezone to Asia/Kolkata (IST)..."
  echo "Asia/Kolkata" > "$ROOTFS/etc/timezone"
  chroot "$ROOTFS" ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
  chroot "$ROOTFS" dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true
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
  create_default_user
  apply_branding_and_boot_target
  apply_windows11_theme
  cleanup_mounts
  build_squashfs
  stage_kernel_and_grub
  build_iso
  boot_test
  log "Done."
}

main "$@"
