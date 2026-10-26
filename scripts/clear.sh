#!/usr/bin/env bash
# Clear a child's context once its bead is finished.
#
#   clear.sh <role> [--timeout MS] [--discard-input]
#
# The coordinator runs this after a done or bounced verdict, so every bead
# starts in a fresh session that holds only its own brief and the rules file.
#
# The verdict arrives while the child is still ending the turn that sent it,
# and send.sh refuses to clear a working pane. So this waits for the child to
# settle first, with a deadline. A child that does not settle is not cleared:
# it may still hold work it has not reported.
#
# Unsent text in the pane's input line stops the clear with exit 5, as in
# send.sh. Pass --discard-input only when the user says so.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

role="${1:?usage: clear.sh <role> [--timeout MS] [--discard-input]}"; shift
timeout=120000; discard=()
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) timeout="${2:?--timeout needs a value}"; shift ;;
    --discard-input) discard=(--discard-input) ;;
    *) hc_die "unknown argument: $1" ;;
  esac
  shift
done

"$HC_SCRIPTS/wait.sh" "$role" --timeout "$timeout" >/dev/null; rc=$?
case $rc in
  0) ;;
  3) hc_die "$role is blocked on a dialog — not cleared. Read it with read.sh and ask a human" ;;
  *) hc_die "$role did not settle within ${timeout}ms — not cleared. Check read.sh $role --state, then run clear.sh again" ;;
esac

"$HC_SCRIPTS/send.sh" "$role" "/clear" ${discard[@]+"${discard[@]}"}
