# Chakra OS test harness -- shared helpers. Sourced by every tests/*/*.sh.
# No shebang: this file is sourced, never executed.

: "${CHK_PASS:=0}" "${CHK_FAIL:=0}" "${CHK_SKIP:=0}"
CHK_CURRENT=""

_c() { case "${NO_COLOR:-}" in "") printf '\033[%sm' "$1";; *) :;; esac; }

section() { CHK_CURRENT="$1"; printf '\n%s== %s ==%s\n' "$(_c '1;36')" "$1" "$(_c 0)"; }

ok()   { CHK_PASS=$((CHK_PASS+1)); printf '  %sPASS%s %s\n' "$(_c '32')" "$(_c 0)" "$1"; }
fail() { CHK_FAIL=$((CHK_FAIL+1)); printf '  %sFAIL%s %s\n' "$(_c '31')" "$(_c 0)" "$1"; [[ -n "${2:-}" ]] && printf '       %s\n' "$2"; }
skip() { CHK_SKIP=$((CHK_SKIP+1)); printf '  %sSKIP%s %s\n' "$(_c '33')" "$(_c 0)" "$1"; }

# assert "label" <command...>   -- pass if the command exits 0
assert() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else fail "$label" "\$ $*"; fi
}
# refute "label" <command...>   -- pass if the command exits non-zero
refute() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$label" "\$ $* (expected failure)"; else ok "$label"; fi
}

chk_summary() {
  printf '\n%s---------------------------------------%s\n' "$(_c '1')" "$(_c 0)"
  printf '  %d passed, %s%d failed%s, %d skipped\n' \
    "$CHK_PASS" "$( [[ $CHK_FAIL -gt 0 ]] && _c '1;31' )" "$CHK_FAIL" "$(_c 0)" "$CHK_SKIP"
  [[ $CHK_FAIL -eq 0 ]]
}
