#!/usr/bin/env bash
# Send a prompt — or a slash command — to a role, with the protocol enforced.
#
#   send.sh <role> <text...> [--wait] [--timeout MS] [--force-clear] [--discard-input]
#   send.sh <role> "/clear"
#   send.sh <role> "/mattpocock-skills:implement <brief>"
#
# <role> is a role name from the topology; this system's names are whatever
# .claude/herdr/topology.json says, so read them with pane.sh roles.
#
# The Herdr prompt channel is the pane's user input, so slash commands fire
# there — including skills marked disable-model-invocation and built-ins.
#
# Addressing is checked against the topology: you may send to your own children
# only. Verdicts travel upward through report.sh. Set HC_FORCE=1 to override
# when driving the system by hand from outside any role.
#
# Prefer brief.sh for dispatching work; this is the raw channel underneath it.
#
# The prompt goes into the pane's input line. When that line holds text that a
# human typed and did not send, the new text is joined to it. So send.sh reads
# the line first, and refuses with exit 5 when it is not empty. The user decides
# what to do with that text: they send it, or they let you pass --discard-input,
# which erases the line and confirms that it is empty before the delivery.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

role="${1:?usage: send.sh <role> <text...> [--wait] [--timeout MS] [--force-clear] [--discard-input]}"; shift
wait=0; timeout=""; force_clear=0; discard=0; parts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) wait=1 ;;
    --timeout) timeout="${2:?--timeout needs a value}"; shift ;;
    --force-clear) force_clear=1 ;;
    --discard-input) discard=1 ;;
    *) parts+=("$1") ;;
  esac
  shift
done
[ "${#parts[@]}" -gt 0 ] || hc_die "nothing to send"
text="${parts[*]}"

self="$(hc_self)"
if [ -n "$self" ] && [ "${HC_FORCE:-0}" != 1 ]; then
  if [ "$role" = "$(hc_parent "$self")" ]; then
    hc_die "$self reports upward through report.sh, not send.sh"
  fi
  if ! hc_children "$self" | grep -qx "$role"; then
    hc_die "$self may not address $role (children: $(hc_children "$self" | tr '\n' ' '))"
  fi
fi

# A cleared session loses whatever it had not yet reported. Let it settle first.
case "$text" in
  /clear*)
    if [ "$force_clear" != 1 ]; then
      st="$(hc_status "$role")"
      case "$st" in
        working) hc_die "$role is working — wait for its verdict, or pass --force-clear. Clearing now discards work it has not reported" ;;
      esac
    fi
    ;;
esac

# Text already in the input line would join the delivery. Only the user may
# discard it, because it can be their own work in progress.
pending="$(hc_pending_input "$role")"; prc=$?
if [ $prc -eq 2 ]; then
  echo "note: no input line found in $role's pane; the delivery runs without the check" >&2
elif [ -n "$pending" ]; then
  if [ "$discard" != 1 ]; then
    printf '%s
' \
      "herdr-coordinator: $role has unsent input: \"$pending\"." \
      "  Ask the user to send or erase it, then retry. Pass --discard-input to erase it." >&2
    exit 5
  fi
  hc_erase_input "$role" || hc_die "could not erase the input line of $role; it still holds: \"$(hc_pending_input "$role")\""
  echo "erased the unsent input of $role: \"$pending\"" >&2
fi

target="$(hc_target "$role")"

args=(agent prompt "$target" "$text")
[ "$wait" = 1 ] && args+=(--wait)
[ -n "$timeout" ] && args+=(--timeout "$timeout")

out="$(herdr "${args[@]}" 2>&1)"; rc=$?

# /clear replaces the pane's session, so Herdr drops the name. Put it back
# before anyone addresses this role again.
case "$text" in
  /clear*) sleep 2; hc_target "$role" >/dev/null 2>&1 || true ;;
esac

if [ $rc -ne 0 ]; then
  printf '%s\n' "$out" >&2
  printf '%s\n' "$out" | grep -qi 'agent_blocked' && \
    hc_die "$role is sitting on a dialog; read it with read.sh and ask before answering"
  hc_die "prompt to $role failed (rc=$rc)"
fi

printf '%s' "$out" | python3 -c '
import json,sys
try:
    a=json.load(sys.stdin)["result"]["agent"]
    print("sent \u2192", a.get("name", a["pane_id"]), "(%s)" % a["agent_status"])
except Exception:
    print("sent")'
