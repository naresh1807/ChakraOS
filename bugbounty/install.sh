#!/bin/bash
# Fetch the bug bounty tool binaries into /opt/chakra/bounty/bin.
#
# Run by the Chakra build (apply_bounty). Also usable on a live system to
# (re)install one tool:   sudo /opt/chakra/bounty/install.sh nuclei
# or all of them:         sudo /opt/chakra/bounty/install.sh
#
# Every tool here ships an official static linux/amd64 release binary --
# no Go toolchain needed. Best-effort: a failed download is a warning,
# not a fatal error, and chakra-bounty degrades to the tools it has.
set -u
BIN=/opt/chakra/bounty/bin
mkdir -p "$BIN"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
UA="chakra-bounty-installer"

log()  { echo "[bounty] $*"; }
warn() { echo "[bounty] WARNING: $*" >&2; }

# latest <owner/repo>  -> tag (e.g. v2.16.0)
latest() {
  curl -fsSL --max-time 20 -A "$UA" "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' | cut -d'"' -f4
}

# --- ProjectDiscovery: <tool>_<ver>_linux_amd64.zip, binary named <tool> ---
pd() {
  local tool="$1" tag ver url
  command -v "$tool" >/dev/null 2>&1 && { log "$tool already present"; return; }
  tag="$(latest "projectdiscovery/$tool")"; ver="${tag#v}"
  [[ -n "$ver" ]] || { warn "$tool: no release tag"; return; }
  url="https://github.com/projectdiscovery/$tool/releases/download/$tag/${tool}_${ver}_linux_amd64.zip"
  if curl -fsSL --max-time 120 -A "$UA" -o "$TMP/$tool.zip" "$url" \
     && unzip -o -q "$TMP/$tool.zip" -d "$TMP/$tool" \
     && install -m 0755 "$TMP/$tool/$tool" "$BIN/$tool"; then
    log "$tool $ver"
  else
    warn "$tool: fetch/install failed ($url)"
  fi
}

# --- generic release: fn <repo> <tool> <asset-glob> <path-in-archive> ---
rel_targz() {
  local repo="$1" tool="$2" asset="$3" inner="${4:-$2}" tag ver url
  command -v "$tool" >/dev/null 2>&1 && { log "$tool already present"; return; }
  tag="$(latest "$repo")"; ver="${tag#v}"
  [[ -n "$ver" ]] || { warn "$tool: no release tag"; return; }
  url="https://github.com/$repo/releases/download/$tag/${asset//@VER@/$ver}"
  if curl -fsSL --max-time 120 -A "$UA" -o "$TMP/$tool.tgz" "$url" \
     && mkdir -p "$TMP/$tool" && tar -xzf "$TMP/$tool.tgz" -C "$TMP/$tool" \
     && install -m 0755 "$(find "$TMP/$tool" -type f -name "$inner" | head -1)" "$BIN/$tool"; then
    log "$tool $ver"
  else
    warn "$tool: fetch/install failed ($url)"
  fi
}

rel_raw() {  # <repo> <tool> <asset-glob-with-@VER@>
  local repo="$1" tool="$2" asset="$3" tag ver url
  command -v "$tool" >/dev/null 2>&1 && { log "$tool already present"; return; }
  tag="$(latest "$repo")"; ver="${tag#v}"
  url="https://github.com/$repo/releases/download/$tag/${asset//@VER@/$ver}"
  if curl -fsSL --max-time 120 -A "$UA" -o "$BIN/$tool" "$url" && chmod 0755 "$BIN/$tool"; then
    log "$tool $ver"
  else
    warn "$tool: fetch/install failed ($url)"; rm -f "$BIN/$tool"
  fi
}

install_one() {
  case "$1" in
    subfinder|dnsx|httpx|nuclei|katana|notify|naabu) pd "$1" ;;
    gau)          rel_targz lc/gau gau 'gau_@VER@_linux_amd64.tar.gz' gau ;;
    waybackurls)  rel_targz tomnomnom/waybackurls waybackurls 'waybackurls-linux-amd64-@VER@.tgz' waybackurls ;;
    dalfox)       rel_targz hahwul/dalfox dalfox 'dalfox_@VER@_linux_amd64.tar.gz' dalfox ;;
    gowitness)    rel_raw sensepost/gowitness gowitness 'gowitness-@VER@-linux-amd64' ;;
    *) warn "unknown tool '$1'"; return 1 ;;
  esac
}

command -v curl  >/dev/null || { echo "curl required" >&2; exit 1; }
command -v unzip >/dev/null || { echo "unzip required" >&2; exit 1; }

if [[ $# -gt 0 ]]; then
  for t in "$@"; do install_one "$t"; done
else
  for t in subfinder dnsx httpx nuclei katana notify gau waybackurls dalfox gowitness; do
    install_one "$t"
  done
  # nuclei templates (small, ~30 MB) -- non-fatal
  if [[ -x "$BIN/nuclei" ]]; then
    log "updating nuclei templates..."
    HOME=/opt/chakra/bounty "$BIN/nuclei" -update-templates -silent 2>/dev/null || warn "nuclei template update failed"
  fi
fi
log "done. chakra-bounty tools  shows what's installed."
