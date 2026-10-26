#!/usr/bin/env bash
# Read a pane that went quiet without reporting. The fallback channel.
#
#   read.sh <role> [--lines N]      transcript, soft wraps joined
#   read.sh <role> --state          status only
#
# report.sh is the agreed channel and it pushes, so reaching for this means
# something did not report. Use it to find out why, then fix the cause.
#
# Ledger state is not here: `bd` in the coordinator's own cwd is the one way to
# read a bead, and no other tier reads beads at all.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

role="${1:?usage: read.sh <role> [--lines N|--state]}"; shift
lines=200; state=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lines) lines="${2:?--lines needs a value}"; shift ;;
    --state) state=1 ;;
    *) hc_die "unknown argument: $1 (--lines N|--state)" ;;
  esac
  shift
done

target="$(hc_target "$role")"

if [ "$state" = 1 ]; then
  herdr agent get "$target" | python3 -c '
import json,sys
a=json.load(sys.stdin)["result"]["agent"]
print(a.get("name", a["pane_id"]), a["agent_status"], a["cwd"])'
  exit 0
fi

herdr agent read "$target" --source recent-unwrapped --lines "$lines"
