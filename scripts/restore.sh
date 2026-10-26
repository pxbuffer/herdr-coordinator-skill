#!/usr/bin/env bash
# Rebuild the coordinator's state from the ledger. Run at session start.
#
#   restore.sh
#
# Closes the loop that makes recycling survivable: work → write the ledger →
# /clear → restore.sh → work. Everything below is push-driven and stateless, so
# the ledger plus the live pane statuses is the entire system state.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

self="$(hc_self)"
top="$(hc_top)"
[ -z "$self" ] || [ "$self" = "$top" ] || \
  hc_die "$self takes its state from its brief — the ledger is $top's"

ledger="$(hc_ledger_cwd)"

echo "=== ledger: $(hc_prefix)- in $ledger ==="
( cd "$ledger" && bd prime 2>&1 )

echo
echo "=== dispatched, awaiting a verdict ==="
( cd "$ledger" && bd list --status in_progress,blocked --long 2>&1 )

echo
echo "=== claimable now ==="
( cd "$ledger" && bd ready 2>&1 )

echo
echo "=== panes ==="
"$HC_SCRIPTS/pane.sh" status
