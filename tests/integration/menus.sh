# The Start-menu wiring: every tools.list row has a .desktop, every
# .desktop points at a command that exists and a category that a .menu
# actually includes, every .menu names a .directory that exists.

section "Start-menu wiring"

APPS=/usr/share/applications
DIRS=/usr/share/desktop-directories
MENUS=/etc/xdg/menus/applications-merged
CFG="${CHK_CONFIG:-}"

[[ -d "$APPS" ]] || { fail "$APPS missing"; return 0; }

# --- .menu files reference a real .directory + a category -------------------
shopt -s nullglob
for m in "$MENUS"/chakra-*.menu; do
  d="$(grep -oE '<Directory>[^<]+</Directory>' "$m" | sed 's/<[^>]*>//g' | head -1)"
  [[ -n "$d" && -f "$DIRS/$d" ]] && ok "$(basename "$m") -> $d exists" \
    || fail "$(basename "$m") references missing directory '$d'"
  grep -qE '<Category>X-Chakra-[^<]+</Category>' "$m" \
    && ok "$(basename "$m") includes an X-Chakra category" \
    || fail "$(basename "$m") has no X-Chakra category include"
done

# --- every chakra .desktop: Exec resolves, Category is served by a .menu ----
all_menu_cats="$(grep -hoE 'X-Chakra-[A-Za-z0-9-]+' "$MENUS"/chakra-*.menu 2>/dev/null | sort -u)"
for f in "$APPS"/chakra-tool-*.desktop; do
  base="$(basename "$f")"
  exec_line="$(sed -n 's/^Exec=//p' "$f" | head -1)"
  # unwrap `konsole -e bash -c "CMD; ..."`
  cmd="$(sed -E 's/.*bash -c "([^;"]+).*/\1/' <<<"$exec_line")"
  cmd="$(awk '{print $1}' <<<"$cmd")"
  if command -v "$cmd" >/dev/null 2>&1; then ok "$base -> '$cmd' on PATH"
  else fail "$base Exec command '$cmd' not found"; fi

  cat="$(grep -oE 'X-Chakra-[A-Za-z0-9-]+' "$f" | head -1)"
  if grep -qxF "$cat" <<<"$all_menu_cats"; then ok "$base category $cat is in a .menu"
  else fail "$base category '$cat' not included by any .menu"; fi
done
shopt -u nullglob

# --- every tools.list row produced a .desktop (matched on Name=) ----------
if [[ -n "$CFG" ]]; then
  names="$(grep -hE '^Name=' "$APPS"/chakra-tool-*.desktop 2>/dev/null | sed 's/^Name=//' | sort -u)"
  while IFS= read -r listing; do
    while IFS='|' read -r tname _ _ _; do
      [[ -z "$tname" || "$tname" == \#* ]] && continue
      if grep -qxF "$tname" <<<"$names"; then
        ok "menu entry '$tname' has a .desktop"
      else
        fail "menu entry '$tname' (${listing##*/config/}) has no .desktop"
      fi
    done < "$listing"
  done < <(find "$CFG" -name tools.list)
else
  skip "tools.list cross-check (repo config not available)"
fi
