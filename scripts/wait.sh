#!/usr/bin/env bash
# Wait for a role to settle, and classify what came back.
#
#   wait.sh <role> [--timeout MS] [--until STATUS]
#
# Exit codes let a caller branch without parsing prose:
#   0  settled idle/done        — work finished, read the tracker
#   3  blocked                  — a dialog is open; inspect, then ask a human
#   4  timeout or stalled       — undetermined: the prompt may still have landed
#
# A timeout never proves the prompt was not delivered. Read state before resending.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

role="${1:?usage: wait.sh <role> [--timeout MS] [--until STATUS]}"; shift
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) args+=(--timeout "${2:?--timeout needs a value}"); shift ;;
    --until)   args+=(--until   "${2:?--until needs a value}");   shift ;;
    *) hc_die "unknown argument: $1" ;;
  esac
  shift
done

target="$(hc_target "$role")"
out="$(herdr agent wait "$target" "${args[@]}" 2>&1)"; rc=$?

status="$(printf '%s' "$out" | python3 -c '
import json,sys
try: print(json.load(sys.stdin)["result"]["agent"]["agent_status"])
except Exception: print("")' 2>/dev/null)"

if [ $rc -ne 0 ] || [ -z "$status" ]; then
  printf '%s\n' "$out" >&2
  case "$out" in
    *agent_blocked*|*blocked*) echo "$role: blocked"; exit 3 ;;
    *) echo "$role: undetermined — inspect with read.sh before resending"; exit 4 ;;
  esac
fi

echo "$role: $status"
case "$status" in
  blocked) exit 3 ;;
  idle|done) exit 0 ;;
  *) exit 4 ;;
esac
