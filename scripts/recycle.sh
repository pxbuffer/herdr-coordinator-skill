#!/usr/bin/env bash
# Clear the coordinator's own context, once the ledger holds everything.
#
#   recycle.sh --flushed
#   recycle.sh                 # dry run: prints the flush checklist and stops
#
# The ledger is the coordinator's memory, so clearing is safe exactly when the
# ledger is complete and never before. This script makes that an assertion you
# sign rather than a habit you keep: run it bare, read the checklist, write
# anything missing into the ledger, then run it with --flushed.
#
# Ordering is the whole hazard. /clear last, after the writes — a bead you
# meant to update and did not is gone, because nothing else remembers it.
#
# Timing takes care of itself here: /clear arrives on this pane's own input
# queue and fires when the current turn ends, so it cannot land mid-response.
# Clearing someone else is the case that needs an idle check — send.sh has it.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

flushed=0
while [ $# -gt 0 ]; do
  case "$1" in
    --flushed) flushed=1 ;;
    *) hc_die "unknown argument: $1 (--flushed)" ;;
  esac
  shift
done

self="$(hc_self)"
[ -n "$self" ] || hc_die "this pane is not in the topology — check 'pane.sh status'"
[ "$self" = "$(hc_top)" ] || hc_die "$self reads its work from a brief, not from the ledger — recycling is the coordinator's move"

ledger="$(hc_ledger_cwd)"

echo "--- in flight (the ledger must already say what you know) ---"
( cd "$ledger" && bd list --status in_progress,blocked --brief 2>&1 )

echo
echo "--- children ---"
while read -r role; do
  [ -n "$role" ] || continue
  printf '%-14s %s\n' "$role" "$(hc_status "$role")"
done < <(hc_children "$self")

if [ "$flushed" != 1 ]; then
  echo
  echo "Dry run. Write any outcome the ledger is missing, then: recycle.sh --flushed"
  exit 0
fi

echo
echo "Clearing $self. A verdict arriving after this lands in a fresh session,"
echo "which restores itself with restore.sh and finds the bead by its ID."

pane="$(hc_field "$self" pane)"
herdr agent prompt "$pane" "/clear" >/dev/null || hc_die "could not queue /clear on $pane"
sleep 2
herdr agent rename "$pane" "$self" >/dev/null 2>&1 || true
echo "queued → /clear on $self ($pane)"
