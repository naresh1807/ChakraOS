#!/bin/bash
# Chakra OS test harness.
#
#   sudo tests/run.sh            # from the repo root: test build/rootfs via chroot
#   tests/run.sh --here          # test the system this runs on (use on the live ISO)
#   CHAKRA_ROOTFS=/path tests/run.sh
#
# Exit status is non-zero if any check fails. The suite is deterministic
# and read-only -- it inspects the built image, it doesn't change it.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
MODE=chroot
[[ "${1:-}" == "--here" ]] && MODE=here

if [[ "$MODE" == chroot ]]; then
  ROOTFS="${CHAKRA_ROOTFS:-$REPO/build/rootfs}"
  [[ -d "$ROOTFS/usr/lib/chakra" ]] || { echo "no built rootfs at $ROOTFS (run the build first, or use --here)" >&2; exit 2; }
  [[ $EUID -eq 0 ]] || { echo "chroot mode needs root; try: sudo tests/run.sh" >&2; exit 2; }
  stage="$ROOTFS/opt/.chakra-tests"
  rm -rf "$stage"; mkdir -p "$stage"
  cp -r "$HERE" "$stage/tests"
  cp -r "$REPO/config" "$stage/config"          # for the repo-vs-image menu cross-check
  mnt=0; mountpoint -q "$ROOTFS/proc" || { mount --bind /proc "$ROOTFS/proc" && mnt=1; }
  chroot "$ROOTFS" bash /opt/.chakra-tests/tests/run.sh --here
  rc=$?
  [[ $mnt -eq 1 ]] && umount "$ROOTFS/proc" 2>/dev/null
  rm -rf "$stage"
  exit $rc
fi

# ---- --here: the actual run -------------------------------------------------
# shellcheck source=/dev/null
. "$HERE/lib.sh"

# repo config: either alongside (dev checkout) or staged next to us (chroot)
CHK_CONFIG=""
for c in "$REPO/config" "$HERE/../config"; do [[ -d "$c/security-menu" ]] && CHK_CONFIG="$(cd "$c" && pwd)" && break; done
export CHK_CONFIG

fail_files=()
for d in unit integration security; do
  for t in "$HERE/$d"/*.sh; do
    [[ -e "$t" ]] || continue
    # shellcheck source=/dev/null
    . "$t"
  done
done

chk_summary
