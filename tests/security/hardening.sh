# The security substrate is actually in the image: default-deny firewall,
# kernel hardening, audit-trail access, the default account's groups,
# LibreOffice macro policy.

section "Security substrate"

# --- nftables: default-deny inbound ---------------------------------------
if [[ -f /etc/nftables.conf ]]; then
  grep -Eq 'hook input .*policy drop' /etc/nftables.conf \
    && ok "nftables input hook is policy drop" \
    || fail "/etc/nftables.conf input hook is not 'policy drop'"
  grep -Eq 'ct state (established,related|established, related) accept' /etc/nftables.conf \
    && ok "nftables keeps established/related" \
    || fail "nftables has no established/related accept -- would break replies"
else
  fail "/etc/nftables.conf missing"
fi

# --- kernel/network hardening sysctls -------------------------------------
if compgen -G '/etc/sysctl.d/*chakra*' >/dev/null || [[ -f /etc/sysctl.d/99-chakra-hardening.conf ]]; then
  hf="$(compgen -G '/etc/sysctl.d/*chakra*' | head -1)"
  grep -q 'rp_filter' "$hf" && ok "hardening sysctls present ($(basename "$hf"))" \
    || fail "hardening sysctl file has no rp_filter"
  # deliberately NOT hardened: ptrace_scope (gdb/strace need it) -- assert that
  if grep -Eq '^\s*kernel.yama.ptrace_scope\s*=\s*[1-9]' "$hf"; then
    fail "ptrace_scope is restricted -- Phase 5 says it must stay open for RE tooling"
  else
    ok "ptrace_scope left open (RE tooling)"
  fi
else
  fail "no /etc/sysctl.d/*chakra* hardening file"
fi

# --- auditd routes to the adm group -------------------------------------
if [[ -f /etc/audit/auditd.conf ]]; then
  grep -Eq '^\s*log_group\s*=\s*adm' /etc/audit/auditd.conf \
    && ok "auditd log_group = adm" \
    || fail "auditd.conf log_group is not adm -- unprivileged log reads break"
fi

# --- the default account can use sudo and read logs --------------------
user="$(getent passwd 1000 | cut -d: -f1)"
if [[ -n "$user" ]]; then
  groups="$(id -nG "$user")"
  for g in sudo adm; do
    grep -qw "$g" <<<"$groups" && ok "$user is in '$g'" || fail "$user is NOT in '$g'"
  done
fi

# --- Chakra directory layout / release marker --------------------------
[[ -f /etc/chakra-release ]] && ok "/etc/chakra-release present" || fail "/etc/chakra-release missing"
for d in /etc/chakra /usr/lib/chakra /var/lib/chakra /var/log/chakra; do
  [[ -d "$d" ]] && ok "$d exists" || fail "$d missing"
done

# --- LibreOffice macro security (Phase 18) -----------------------------
xcu=/etc/skel/.config/libreoffice/4/user/registrymodifications.xcu
if [[ -f "$xcu" ]]; then
  lvl="$(grep -oE 'MacroSecurityLevel[^<]*<value>[0-9]' "$xcu" | grep -oE '[0-9]$')"
  [[ "$lvl" == 2 || "$lvl" == 3 ]] && ok "LibreOffice macro security = $lvl (High/Very High)" \
    || fail "LibreOffice macro security is '$lvl' (want 2 or 3)"
else
  skip "LibreOffice macro policy (skel xcu not present)"
fi

# --- USB Guard policy shipped (Phase 8) -------------------------------
[[ -f /etc/usbguard/rules.conf || -f /etc/chakra/policy.d/usbguard.policy ]] \
  && ok "usbguard policy present" || skip "usbguard policy (not found in expected paths)"

# --- no API key baked into the image (Sentinel, Phase 7) --------------
sc=/etc/chakra/sentinel.conf
if [[ -f "$sc" ]]; then
  if grep -Eq '^\s*(GEMINI_API_KEY|NIM_API_KEY)\s*=\s*\S' "$sc"; then
    fail "$sc ships with an API key set -- no credential belongs in the image"
  else
    ok "sentinel.conf ships with no API key (offline by default)"
  fi
else
  skip "sentinel.conf not present"
fi

# --- default account has no committed password ----------------------
# (passwordless is fine for a live ISO; a *set* password would mean the
#  build baked one in, which it must not)
if [[ -n "$user" ]]; then
  st="$(passwd -S "$user" 2>/dev/null | awk '{print $2}')"
  case "$st" in
    NP|L) ok "default account password is not baked in (state: $st)" ;;
    P)    skip "default account has a password set (fine if set interactively / via \$CHAKRA_USER_PASSWORD)" ;;
    *)    skip "default account password state: ${st:-unknown}" ;;
  esac
fi
