#!/usr/bin/env bash
# Shared environment for herdr-coordinator scripts. Source it; don't run it.
#
#   . "$(dirname "$0")/env.sh"
#
# Resolves the topology and exposes role lookups. Every other script depends on
# this one.

set -uo pipefail

HC_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HC_SKILL="$(dirname "$HC_SCRIPTS")"
export HC_SCRIPTS HC_SKILL

hc_die() { printf 'herdr-coordinator: %s\n' "$*" >&2; exit 1; }

hc_require_herdr() {
  [ "${HERDR_ENV:-}" = 1 ] || hc_die "not running inside a Herdr pane (HERDR_ENV is unset)"
  command -v herdr >/dev/null 2>&1 || hc_die "herdr not found in PATH"
}

# Walk up from $PWD for .claude/herdr/topology.json. There is exactly one, at the
# system root above every repo, so each repo resolves the same file and there is
# nothing to keep in sync. The nearest match wins, which is why render-rules
# rejects a per-repo copy: it would shadow the canonical one for that repo only.
hc_topology() {
  if [ -n "${HC_TOPOLOGY:-}" ]; then printf '%s\n' "$HC_TOPOLOGY"; return 0; fi
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.claude/herdr/topology.json" ]; then
      printf '%s\n' "$dir/.claude/herdr/topology.json"; return 0
    fi
    dir="$(dirname "$dir")"
  done
  hc_die "no .claude/herdr/topology.json found above $PWD — run the herdr-coordinator skill first"
}

# hc_field <role> <field>  → prints the value, empty if absent.
hc_field() {
  python3 - "$(hc_topology)" "$1" "$2" <<'PY'
import json, sys
topo, role, field = sys.argv[1], sys.argv[2], sys.argv[3]
r = json.load(open(topo))["roles"].get(role)
if r is None:
    sys.exit(f"unknown role: {role}")
v = r.get(field, "")
print(",".join(v) if isinstance(v, list) else (v if v is not None else ""))
PY
}

hc_roles() {
  python3 - "$(hc_topology)" <<'PY'
import json, sys
print("\n".join(json.load(open(sys.argv[1]))["roles"]))
PY
}

# The coordinator: the one role with no parent. It owns the ledger.
hc_top() {
  python3 - "$(hc_topology)" <<'PY'
import json, sys
roles = json.load(open(sys.argv[1]))["roles"]
tops = [n for n, r in roles.items() if not r.get("parent")]
if len(tops) != 1:
    sys.exit(f"topology must have exactly one role with no parent, found {len(tops)}: {tops}")
print(tops[0])
PY
}

# Where `bd` runs. One ledger for the whole system, in the coordinator's cwd.
hc_ledger_cwd() { hc_field "$(hc_top)" cwd; }
hc_prefix()     { hc_field "$(hc_top)" prefix; }

# Which role is this pane? Empty when the pane is not in the topology.
hc_self() {
  [ -n "${HERDR_PANE_ID:-}" ] || return 0
  python3 - "$(hc_topology)" "$HERDR_PANE_ID" <<'PY'
import json, sys
topo, pane = sys.argv[1], sys.argv[2]
for name, r in json.load(open(topo))["roles"].items():
    if r.get("pane") == pane:
        print(name); break
PY
}

# Resolve a role to a live Herdr target, repairing a name dropped by /clear.
# The rename only sticks once the new session registers, so it retries.
hc_target() {
  local role="$1" pane
  pane="$(hc_field "$role" pane)" || return 1
  [ -n "$pane" ] || hc_die "role $role has no pane in the topology"
  local i
  for i in 1 2 3 4 5; do
    if herdr agent get "$role" >/dev/null 2>&1; then printf '%s\n' "$role"; return 0; fi
    herdr agent rename "$pane" "$role" >/dev/null 2>&1 && continue
    sleep 1
  done
  # The name would not hold; address the pane directly if an agent lives there.
  if herdr agent get "$pane" >/dev/null 2>&1; then printf '%s\n' "$pane"; return 0; fi
  hc_die "role $role ($pane) hosts no live agent — check 'herdr agent list'"
}

hc_status() {
  herdr agent get "$(hc_field "$1" pane)" 2>/dev/null | python3 -c '
import json,sys
try: print(json.load(sys.stdin)["result"]["agent"].get("agent_status","?"))
except Exception: print("no-agent")' 2>/dev/null || echo no-agent
}

# hc_gates_state <role> → pending | defined | none
# Resolves the gates of the role's PROJECT: an orchestrator's own gates (a solo
# orchestrator's included), or a worker's parent's. A role in no project (the coordinator) resolves to "none".
hc_gates_state() {
  python3 - "$(hc_topology)" "$1" <<'GATESPY'
import json, sys
topo, role = sys.argv[1], sys.argv[2]
roles = json.load(open(topo))["roles"]
r = roles.get(role)
if r is None:
    sys.exit(f"unknown role: {role}")
if r.get("kind") == "orchestrator":
    owner = r
elif r.get("kind") == "worker" and roles.get(r.get("parent"), {}).get("kind") == "orchestrator":
    owner = roles[r["parent"]]
else:
    print("none"); raise SystemExit(0)
g = owner.get("gates")
if g == "pending":
    print("pending")
elif isinstance(g, list) and g:
    print("defined")
else:
    print("none")
GATESPY
}

# hc_pending_input <role> → the text a human typed into the pane's input line,
# empty when there is none. Exit 2 when no Claude Code prompt box is on the screen.
#
# `herdr agent prompt` types into that line and submits it. Text a human typed and
# did not send is joined to the new text, so a /clear becomes plain text. The line
# is read from the screen: the "❯" row between the last two horizontal rules, and
# the rows under it up to the second rule. `herdr agent explain` shows the same
# box, but it cuts long text short, so it cannot quote what is there.
#
# An empty line can show a prompt suggestion in grey. On plain text it looks the
# same as typed text, so the read keeps the ANSI attributes: Claude Code draws a
# suggestion dim (SGR 2), and typed text has no dim. Dim text is not input.
hc_pending_input() {
  local pane
  pane="$(hc_field "$1" pane)" || return 1
  herdr agent read "$pane" --source recent --format ansi --lines 60 2>/dev/null | python3 -c '
import re, sys

ESC = re.compile(r"\x1b\[([0-9;?]*)([A-Za-z])|\x1b[^\[]")

def plain(line):
    """The row as text, without the characters drawn dim."""
    out, dim, pos = [], False, 0
    for m in ESC.finditer(line):
        if not dim:
            out.append(line[pos:m.start()])
        pos = m.end()
        if m.group(2) != "m":
            continue
        codes = (m.group(1) or "0").split(";")
        i = 0
        while i < len(codes):
            c = codes[i] or "0"
            if c in ("38", "48", "58"):          # extended colour: skip its arguments
                i += 3 if codes[i + 1:i + 2] == ["5"] else 5
                continue
            if c == "0" or c == "22":
                dim = False
            elif c == "2":
                dim = True
            i += 1
    if not dim:
        out.append(line[pos:])
    return "".join(out).replace("\r", "")

raw = sys.stdin.read().split("\n")
lines = [plain(l) for l in raw]
bare = [ESC.sub("", l).replace("\r", "") for l in raw]
rule = [i for i, l in enumerate(bare) if len(l.strip()) >= 10 and set(l.strip()) == {"─"}]
for top, bottom in reversed(list(zip(rule, rule[1:]))):
    body = lines[top + 1:bottom]
    if body and bare[top + 1].lstrip().startswith("❯"):
        body[0] = body[0].lstrip()[1:]
        print(" ".join(p for p in (l.strip("  ") for l in body) if p))
        raise SystemExit(0)
raise SystemExit(2)'
}

# hc_erase_input <role> — clear the pane input line with key presses.
# ctrl+u erases one row of the box only, so each pass sends ctrl+e ctrl+u
# backspace for a number of rows, then reads the line again. These keys do not
# stop a working agent, and on an empty line they do nothing. A suggestion that
# comes back on the empty line is not input, so the line then counts as empty.
# Exit 1 when typed text stays after every pass.
hc_erase_input() {
  local pane keys=() i pass
  pane="$(hc_field "$1" pane)" || return 1
  for i in $(seq 1 10); do keys+=(ctrl+e ctrl+u backspace); done
  for pass in 1 2 3 4 5; do
    herdr agent send-keys "$pane" "${keys[@]}" >/dev/null 2>&1 || return 1
    sleep 0.5
    [ -z "$(hc_pending_input "$1")" ] && return 0
  done
  return 1
}

# hc_await_submit <role> <needle> → did the pane take a line that holds <needle>?
# `herdr agent prompt` without --wait exits 0 when the keys are sent, not when the
# line is submitted. A line that stays in the input box is lost when a later
# prompt or a human overwrites it. So this reads the input line for some seconds.
# When <needle> leaves the line, the session took it: an idle session starts a
# turn, and a working one queues the message. When the line still holds <needle>,
# or the "[Pasted text" marker that stands in for a long paste, this sends one
# Enter and reads again.
# Exit 0 when the line is free of the needle, 1 when it stays after the Enter,
# 2 when no prompt box is on the screen.
hc_await_submit() {
  local role="$1" needle="$2" pane line rc i enter
  pane="$(hc_field "$role" pane)" || return 1
  for enter in 0 1; do
    if [ "$enter" = 1 ]; then
      herdr agent send-keys "$pane" enter >/dev/null 2>&1 || return 1
    fi
    for i in $(seq 1 10); do
      sleep 0.5
      line="$(hc_pending_input "$role")"; rc=$?
      [ $rc -eq 2 ] && return 2
      case "$line" in
        *"$needle"*|*"[Pasted text"*) ;;
        *) return 0 ;;
      esac
    done
  done
  return 1
}

hc_children() { hc_field "$1" children | tr ',' '\n' | grep -v '^$' || true; }
hc_parent()   { hc_field "$1" parent; }
hc_kind()     { hc_field "$1" kind; }
