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

# latest <owner/repo> -> tag (e.g. v2.16.0) via the un-rate-limited
# /releases/latest redirect -- no GitHub API, no token needed.
latest() {
  local u
  u="$(curl -fsSL -o /dev/null -w '%{url_effective}' --max-time 25 -A "$UA" \
        "https://github.com/$1/releases/latest" 2>/dev/null)"
  case "$u" in */releases/tag/*) echo "${u##*/tag/}" ;; *) return 1 ;; esac
}

_get() { curl -fsSL --max-time 180 -A "$UA" -o "$2" "$1"; }
_place() {  # <src-file> <tool>  -- install a found binary
  install -m 0755 "$1" "$BIN/$2" && log "$2 $3"
}

# --- ProjectDiscovery: <tool>_<ver>_linux_amd64.zip, binary named <tool> ---
pd() {
  local tool="$1" tag ver url
  [[ -x "$BIN/$tool" ]] && { log "$tool already in $BIN"; return; }
  tag="$(latest "projectdiscovery/$tool")" || { warn "$tool: no release tag"; return; }
  ver="${tag#v}"
  url="https://github.com/projectdiscovery/$tool/releases/download/$tag/${tool}_${ver}_linux_amd64.zip"
  if _get "$url" "$TMP/$tool.zip" && unzip -o -q "$TMP/$tool.zip" -d "$TMP/$tool" \
     && _place "$(find "$TMP/$tool" -type f -name "$tool" | head -1)" "$tool" "$ver"; then :; \
  else warn "$tool: fetch/install failed ($url)"; fi
}

# --- tar.gz release: <repo> <tool> <asset-template with @VER@ / @TAG@> ---
rel_targz() {
  local repo="$1" tool="$2" tmpl="$3" tag ver url f
  [[ -x "$BIN/$tool" ]] && { log "$tool already in $BIN"; return; }
  tag="$(latest "$repo")" || { warn "$tool: no release tag"; return; }
  ver="${tag#v}"
  url="https://github.com/$repo/releases/download/$tag/${tmpl//@VER@/$ver}"
  url="${url//@TAG@/$tag}"
  if _get "$url" "$TMP/$tool.tgz" && mkdir -p "$TMP/$tool" \
     && tar -xzf "$TMP/$tool.tgz" -C "$TMP/$tool" 2>/dev/null \
     && f="$(find "$TMP/$tool" -type f \( -name "$tool" -o -name "${tool}*" \) -perm -u+x -o -type f -name "$tool" | head -1)" \
     && [[ -n "$f" ]] && _place "$f" "$tool" "$ver"; then :; \
  else warn "$tool: fetch/install failed ($url)"; fi
}

# --- raw binary release: <repo> <tool> <asset-template> ---
rel_raw() {
  local repo="$1" tool="$2" tmpl="$3" tag ver url
  [[ -x "$BIN/$tool" ]] && { log "$tool already in $BIN"; return; }
  tag="$(latest "$repo")" || { warn "$tool: no release tag"; return; }
  ver="${tag#v}"
  url="https://github.com/$repo/releases/download/$tag/${tmpl//@VER@/$ver}"
  url="${url//@TAG@/$tag}"
  if _get "$url" "$BIN/$tool" && chmod 0755 "$BIN/$tool" && [[ -s "$BIN/$tool" ]]; then
    log "$tool $ver"
  else warn "$tool: fetch/install failed ($url)"; rm -f "$BIN/$tool"; fi
}

install_one() {
  case "$1" in
    subfinder|dnsx|httpx|nuclei|katana|notify|naabu) pd "$1" ;;
    gau)          rel_targz lc/gau                gau         'gau_@VER@_linux_amd64.tar.gz' ;;
    waybackurls)  rel_targz tomnomnom/waybackurls waybackurls 'waybackurls-linux-amd64-@VER@.tgz' ;;
    dalfox)       rel_targz hahwul/dalfox         dalfox      'dalfox-@TAG@-linux-x86_64.tar.gz' ;;
    gowitness)    rel_raw   sensepost/gowitness   gowitness   'gowitness-@VER@-linux-amd64' ;;
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
  if [[ -x "$BIN/nuclei" ]]; then
    log "updating nuclei templates..."
    HOME=/opt/chakra/bounty "$BIN/nuclei" -update-templates -silent 2>/dev/null || warn "nuclei template update failed"
  fi
fi
log "done -- 'chakra-bounty tools' shows what's installed."
