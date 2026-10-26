#!/usr/bin/env bash
# Report a bead's verdict upward to your parent. The only upward path.
#
#   report.sh <bead> done        [detail...]
#   report.sh <bead> blocked     <reason...>
#   report.sh <bead> needs-info  <question...>
#   report.sh <bead> bounced     <why it exceeds the brief...>
#
#   report.sh <bead> done "POST /login → 200 {token}; src/auth/login.ts, +tests"
#   report.sh <bead> bounced "three independent endpoints, not one — split per endpoint"
#
# <bead> is a ledger ID, whose prefix comes from the topology — not a fixed string.
#
# Only the coordinator holds the ledger, so this line is the sole evidence it
# gets that the bead moved. The format is fixed because the coordinator parses
# it to update the ledger; prose it cannot parse leaves the ledger wrong.
#
# Sent without --wait on purpose: blocking your own pane on the coordinator's
# reply stalls the branch below you.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

bead="${1:?usage: report.sh <bead> <done|blocked|needs-info|bounced> [detail...]}"
verdict="${2:?usage: report.sh <bead> <done|blocked|needs-info|bounced> [detail...]}"
shift 2
detail="$*"

case "$verdict" in
  done) ;;
  blocked|needs-info|bounced)
    [ -n "$detail" ] || hc_die "$verdict needs a reason — it is the coordinator's only input for deciding what to do next" ;;
  *) hc_die "unknown verdict: $verdict (done|blocked|needs-info|bounced)" ;;
esac

prefix="$(hc_prefix)"
case "$bead" in
  "$prefix"-*) ;;
  *) hc_die "bead must be a ledger ID of the form $prefix-<id>, got: $bead" ;;
esac

self="$(hc_self)"
[ -n "$self" ] || hc_die "this pane is not in the topology — check 'pane.sh status'"

parent="$(hc_parent "$self")"
[ -n "$parent" ] || hc_die "$self owns the ledger — update it with bd rather than reporting outward"

line="$bead $verdict"
[ -n "$detail" ] && line="$line: $detail"

target="$(hc_target "$parent")"
herdr agent prompt "$target" "$line" >/dev/null || hc_die "could not reach $parent"
printf 'reported → %s\n%s\n' "$parent" "$line"
