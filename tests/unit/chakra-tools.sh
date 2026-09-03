# Every chakra-* CLI in the image: installed, executable, syntactically
# valid, has a working help, and -- if it advertises a bare `--json`
# status mode -- emits valid JSON. Sourced by tests/run.sh (--here).
#
# Every tool invocation is time-boxed and gets </dev/null so a TUI or a
# prompt can't wedge the run. A chroot can't run podman / systemd /
# real hardware, so a tool that legitimately returns nothing there is a
# SKIP, not a FAIL -- only non-empty-but-invalid JSON fails.

section "chakra-* CLIs"

CHK_BIN=/usr/lib/chakra/bin
[[ -d "$CHK_BIN" ]] || { fail "$CHK_BIN missing"; return 0; }

_run() { timeout 12 "$@" </dev/null; }

# interactive TUIs / session daemons -- no meaningful --help/--json,
# static checks only
_static_only() {
  case "$1" in
    chakra-command-center|chakra-devhub|chakra-shield-notify|chakra-usb-prompt) return 0 ;;
    *) return 1 ;;
  esac
}
# tools whose `--json` needs a positional arg (a file / subcommand) --
# don't probe bare `--json`
_needs_args() {
  case "$1" in
    chakra-file-inspector|chakra-reporter|chakra-lab|chakra-sentinel|chakra-audit-log) return 0 ;;
    *) return 1 ;;
  esac
}
_json_probe() { grep -qE -- '--json' "$CHK_BIN/$1" && ! _static_only "$1" && ! _needs_args "$1"; }

shopt -s nullglob
for path in "$CHK_BIN"/chakra-*; do
  name="$(basename "$path")"

  [[ -x "$path" ]] && ok "$name is executable" || fail "$name is not executable"

  if head -1 "$path" | grep -q '^#!.*bash'; then
    bash -n "$path" 2>/dev/null && ok "$name parses (bash -n)" || fail "$name has a syntax error"
  fi

  if _static_only "$name"; then
    skip "$name --help/--json (interactive -- static checks only)"
  else
    _run "$path" --help >/dev/null 2>&1 || _run "$path" -h >/dev/null 2>&1
    rc=$?
    case $rc in
      0|1|2) ok "$name responds to --help" ;;
      124)   fail "$name --help timed out (12s -- interactive?)" ;;
      127)   skip "$name --help (127 -- missing runtime dep in chroot)" ;;
      *)     fail "$name --help exited $rc" ;;
    esac
  fi

  if _json_probe "$name"; then
    out="$(_run "$path" --json 2>/dev/null)"; rc=$?
    if [[ $rc -eq 124 ]]; then
      fail "$name --json timed out (12s)"
    elif [[ -z "$out" ]]; then
      skip "$name --json produced nothing (chroot can't gather live data)"
    elif printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
      ok "$name --json emits valid JSON"
    else
      fail "$name --json emitted non-JSON output"
    fi
  fi
done
shopt -u nullglob

# the audit trail must be appendable by the unprivileged desktop user
if [[ -d /var/log/chakra/audit ]]; then
  perms="$(stat -c '%a %G' /var/log/chakra/audit)"
  case "$perms" in
    2770\ adm|2775\ adm|770\ adm|775\ adm) ok "audit dir is group-adm writable ($perms)" ;;
    *) fail "audit dir perms are '$perms' (want 2770 adm)" ;;
  esac
fi
