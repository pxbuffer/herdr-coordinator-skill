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
# reply stalls the branch below you. But without --wait, `herdr agent prompt`
# exits 0 when the keys are sent, not when the line is submitted. So delivery is
# checked on the parent's input line, before and after:
#
#   Before: text a human typed and did not send would join the verdict. It is
#   never erased, because the user may be typing. This waits about 30 s for the
#   line to become empty, then stops with exit 5 and quotes the text.
#   After:  the line must no longer hold the verdict. An idle session starts a
#   turn; a working one queues the message. A line that stays gets one Enter.
#
# "reported → <parent>" means the parent's session took the line. Any other end
# means the verdict was NOT delivered: run report.sh again. When the parent's
# pane shows no prompt box, the line goes without the checks, with a warning.

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

# not_delivered <exit code> <reason...>
not_delivered() {
  local code="$1"; shift
  printf 'herdr-coordinator: %s\n  The verdict was NOT delivered. Run report.sh again; do not treat it as delivered.\n' "$*" >&2
  exit "$code"
}

checked=1
for try in 1 2 3 4 5 6 7; do
  pending="$(hc_pending_input "$parent")"; prc=$?
  if [ $prc -eq 2 ]; then
    echo "note: no input line found in $parent's pane; the verdict goes without the delivery checks" >&2
    checked=0; break
  fi
  [ -z "$pending" ] && break
  [ "$try" = 7 ] && not_delivered 5 "$parent has unsent input after 30 s: \"$pending\". The user may be typing; ask them to send or erase it."
  sleep 5
done

target="$(hc_target "$parent")"
out="$(herdr agent prompt "$target" "$line" 2>&1)" || {
  printf '%s\n' "$out" | grep -qi 'agent_blocked' && not_delivered 1 "$parent is sitting on a dialog."
  not_delivered 1 "could not reach $parent: $out"
}

if [ "$checked" = 1 ]; then
  hc_await_submit "$parent" "$bead"; rc=$?
  case $rc in
    0) ;;
    2) echo "note: the input line of $parent went out of view; the submit is not confirmed" >&2 ;;
    *) not_delivered 1 "the verdict stays in $parent's input line after an Enter: \"$(hc_pending_input "$parent")\"." ;;
  esac
fi
printf 'reported → %s\n%s\n' "$parent" "$line"
