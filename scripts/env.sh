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
# Resolves the gates of the role's PROJECT: an orchestrator's own gates, or a
# worker's parent's. A role in no project (the coordinator) resolves to "none".
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

hc_children() { hc_field "$1" children | tr ',' '\n' | grep -v '^$' || true; }
hc_parent()   { hc_field "$1" parent; }
hc_kind()     { hc_field "$1" kind; }
