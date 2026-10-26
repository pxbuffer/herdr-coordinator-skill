#!/usr/bin/env bash
# Topology queries and name repair.
#
#   pane.sh roles                 list every role
#   pane.sh self                  which role is this pane
#   pane.sh show <role>           one role's record
#   pane.sh target <role>         resolve to a live Herdr target, repairing the name
#   pane.sh status                live status of every role
#   pane.sh repair                restore every dropped name

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

cmd="${1:-status}"; shift || true

case "$cmd" in
  roles) hc_roles ;;
  self)  hc_self ;;
  show)
    role="${1:?usage: pane.sh show <role>}"
    for f in pane workspace tab_label kind parent children cwd prefix; do
      printf '%-10s %s\n' "$f" "$(hc_field "$role" "$f")"
    done
    ;;
  target) hc_target "${1:?usage: pane.sh target <role>}" ;;
  status)
    printf '%-14s %-8s %-13s %-10s %s\n' ROLE PANE KIND STATUS LIVE-NAME
    while read -r role; do
      [ -n "$role" ] || continue
      pane="$(hc_field "$role" pane)"
      info="$(herdr agent get "$pane" 2>/dev/null)"
      if [ -n "$info" ]; then
        read -r st nm <<<"$(printf '%s' "$info" | python3 -c '
import json,sys
a=json.load(sys.stdin)["result"]["agent"]
print(a.get("agent_status","?"), a.get("name","<unnamed>"))')"
      else
        st="no-agent"; nm="-"
      fi
      printf '%-14s %-8s %-13s %-10s %s\n' "$role" "$pane" "$(hc_kind "$role")" "$st" "$nm"
    done < <(hc_roles)
    ;;
  repair)
    while read -r role; do
      [ -n "$role" ] || continue
      if t="$(hc_target "$role" 2>/dev/null)"; then
        printf 'ok    %-14s → %s\n' "$role" "$t"
      else
        printf 'FAIL  %-14s (%s)\n' "$role" "$(hc_field "$role" pane)"
      fi
    done < <(hc_roles)
    ;;
  *) hc_die "unknown command: $cmd (roles|self|show|target|status|repair)" ;;
esac
