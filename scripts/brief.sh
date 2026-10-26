#!/usr/bin/env bash
# Dispatch one bead downward as a self-contained brief.
#
#   brief.sh <role> <bead> --task <text> [--doc <path>]... [--skill <name>|--no-skill]
#            [--bootstrap] [--wait] [--discard-input]
#   brief.sh <role> <bead> --task "Implement the login form" \
#            --doc ../<design-repo>/docs/adr/ADR-0007.md
#   brief.sh <role> <bead> --no-skill --task "Which role did you resolve?"
#
# Role names and the ledger prefix come from the topology. `pane.sh roles` lists
# what this system actually has.
#
# A project whose gates are "pending" has nothing to verify a commit with, so
# dispatch to it is refused. --bootstrap is the single exception: a brief whose
# whole job is to establish the toolchain and report its gate commands back, so
# the coordinator can record them and end the pending state.
#
# The receiver never reads the ledger, so the brief is the entire contract: the
# bead ID as a correlation token, the task in full, and every document it may
# read. A doc you do not name is a doc it does not know exists.
#
# Fire-and-forget by default. The verdict arrives later as a push from
# report.sh, landing in your pane as input — so blocking here buys nothing and
# costs you the ability to dispatch the next brief. Pass --wait only when you
# genuinely intend to sit on this one bead.
#
# Unsent text in the receiver's input line stops the brief with exit 5, as in
# send.sh. Pass --discard-input only when the user says so.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
hc_require_herdr

role="${1:?usage: brief.sh <role> <bead> --task <text> [--doc <path>]... [--skill <name>] [--wait]}"
bead="${2:?usage: brief.sh <role> <bead> --task <text> [--doc <path>]... [--skill <name>] [--wait]}"
shift 2

task=""; skill=""; no_skill=0; bootstrap=0; wait=0; timeout=""; discard=0; docs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --task)    task="${2:?--task needs text}"; shift ;;
    --doc)     docs+=("${2:?--doc needs a path}"); shift ;;
    --skill)   skill="${2:?--skill needs a name}"; shift ;;
    --no-skill) no_skill=1 ;;
    --bootstrap) bootstrap=1 ;;
    --wait)    wait=1 ;;
    --discard-input) discard=1 ;;
    --timeout) timeout="${2:?--timeout needs a value}"; shift ;;
    *) hc_die "unknown argument: $1" ;;
  esac
  shift
done

[ -n "$task" ] || hc_die "a brief without --task tells the receiver nothing it can act on"

# Gates are what make a commit mean anything. Without them, only the brief that
# creates them may run.
gates_state="$(hc_gates_state "$role")"
if [ "$(hc_kind "$role")" = worker ]; then
  gates_owner="$(hc_parent "$role")"
else
  gates_owner="$role"
fi

if [ "$gates_state" = pending ] && [ "$bootstrap" != 1 ]; then
  printf '%s\n' \
    "herdr-coordinator: $role's project has gates \"pending\" — nothing there can verify a" \
    "  commit yet. Dispatch the toolchain-setup brief first:" \
    "" \
    "      brief.sh $role <bead> --bootstrap --task \"Choose the toolchain, establish the gates\"" \
    "" \
    "  It establishes the gates, runs them, and commits the scaffold if they pass. Its done" \
    "  verdict reports the gate commands, the results and the commit hash. Record the" \
    "  commands in topology.json under roles.$gates_owner.gates, then dispatch normally." >&2
  exit 1
fi
if [ "$bootstrap" = 1 ] && [ "$gates_state" = defined ]; then
  echo "note: $gates_owner already has gates defined; this bootstrap brief would replace them" >&2
fi

prefix="$(hc_prefix)"
case "$bead" in
  "$prefix"-*) ;;
  *) hc_die "bead must be a ledger ID of the form $prefix-<id>, got: $bead" ;;
esac

# Name the skill the tier below should route through, by its kind. --no-skill is
# for a brief that asks rather than builds: a bootstrap check, a question.
if [ "$no_skill" = 1 ]; then
  [ -z "$skill" ] || hc_die "--skill and --no-skill contradict each other"
elif [ -z "$skill" ]; then
  # A solo orchestrator has no worker below it, so it writes the code itself.
  case "$(hc_kind "$role")" in
    worker)       skill="implement" ;;
    orchestrator) [ -n "$(hc_children "$role")" ] || skill="implement" ;;
    *)            skill="" ;;
  esac
fi
line_skill=""
if [ -n "$skill" ]; then
  # A slash command naming a skill that is not installed reaches the pane as plain text.
  "$HC_SCRIPTS/check-skills.py" "$skill" >/dev/null || exit 1
  line_skill="/mattpocock-skills:$skill "
fi

if [ "${#docs[@]}" -gt 0 ]; then
  doc_block="$(printf '  - %s\n' "${docs[@]}")"
else
  doc_block="  (none — everything you need is in the task above)"
fi

self="$(hc_self)"
bootstrap_block=""
if [ "$bootstrap" = 1 ]; then
  IFS= read -r -d '' bootstrap_block <<'BLK' || true

**This is a toolchain-setup brief.** This project has no gates yet, so no other work reaches
it until it does. Establishing them is the whole of this bead.

Set up the toolchain. Then run the gate commands you set up, in the order they must run.

**If every gate passes:** commit the scaffold on this bead's branch and push it. An
uncommitted scaffold would sit in the working tree with nothing recording it, and the next
bead would branch on top of work that is not in any commit.

**If any gate fails:** report `blocked` with the failing output, and commit nothing. A
scaffold whose own gates do not pass is not a toolchain yet.

Report the gate commands verbatim as a JSON array, the gate results, and the commit hash. The
commands go straight into the topology:

    report.sh <bead> done 'gates: ["<lint>", "<test>", "<build>"]; results: all pass; <branch> @ <hash>'
BLK
fi

prompt="$("$HC_SCRIPTS/render.py" "$HC_SKILL/templates/brief.md" \
  BEAD="$bead" TASK="$task" DOCS="$doc_block" SKILL="$line_skill" \
  PARENT="${self:-your coordinator}" SCRIPTS="$HC_SCRIPTS" \
  BOOTSTRAP="$bootstrap_block")" \
  || hc_die "could not render the brief template"

args=("$role" "$prompt")
[ "$wait" = 1 ] && args+=(--wait)
[ -n "$timeout" ] && args+=(--timeout "$timeout")
[ "$discard" = 1 ] && args+=(--discard-input)
"$HC_SCRIPTS/send.sh" "${args[@]}" || exit $?

if [ "$wait" = 1 ]; then
  "$HC_SCRIPTS/wait.sh" "$role" ${timeout:+--timeout "$timeout"}; rc=$?
  case $rc in
    3) hc_die "$role is blocked on a dialog — inspect with read.sh and ask a human" ;;
    4) hc_die "$role did not settle — inspect with read.sh; the brief may still have landed" ;;
  esac
fi
