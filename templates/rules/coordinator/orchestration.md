# Orchestration protocol

The reference copy for the whole system. Every pane may read this file; only
**{{TOP}}** writes it. The live role graph is `{{TOPOLOGY}}` — one file for the whole
system, above every repo, and
`{{SCRIPTS}}/pane.sh status` renders it against what is actually running.

## Channels

{{CHANNELS}}

Three tiers, each with exactly one thing it owns: the coordinator owns the ledger and the
user, an orchestrator owns how a brief becomes steps, a worker owns the code. Work flows
down as **briefs**, outcomes flow up as **verdicts**, and there are no horizontal calls —
two panes that need each other's output have a missing parent, not a missing channel.

One worker per orchestrator, deliberately. A worker parallelises inside its own session with
sub agents, so a second worker pane would add nothing but two sessions writing one working
tree. `render-rules.py --check` enforces this.

The writing-style rule binds {{TOP}} alone. {{TOP}} writes the user's replies and the design
documents, and it writes the briefs that are a receiver's whole contract — plain short
sentences make a brief hard to misread. The tiers below produce code and fixed-format verdict
lines, which a prose rule cannot improve. See `writing-style.md`, and `style` in
`{{TOPOLOGY}}`.

`send.sh` refuses an address outside your children; `report.sh` is the only upward path. The
graph is enforced, not remembered.

## The brief

The receiver cannot look anything up: it has no ledger and no list of design docs. So the
brief is the entire contract.

```bash
{{SCRIPTS}}/brief.sh <role> {{PREFIX}}-a3f2dd \
  --task "<the whole task, in full>" \
  --doc "<every document it may read>" \
  --doc "<one --doc per path>"
```

The bead ID travels as a **correlation token** — enough to report against, never enough to
look up. That is deliberate: it keeps the ledger single-writer, and it forces each brief to
be complete at the moment it is written instead of implicitly depending on a database the
reader cannot reach.

`brief.sh` is fire-and-forget. The verdict arrives later as input to the sender's pane, so
blocking buys nothing. Pass `--wait` only to sit deliberately on one bead.

## The verdict

```bash
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd done       "<what changed, which files>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd blocked    "<what is in the way>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd needs-info "<the question>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd bounced    "<why it exceeds the brief>"
```

One bead, one verdict, reported once. `report.sh` enforces the format because the coordinator
parses it to move the bead — prose it cannot parse leaves the ledger wrong, and the ledger
being wrong is the one failure this design cannot absorb.

A verdict hops one tier at a time. A worker reports to its orchestrator, which reports
onward — each bead individually, as it lands, rather than batched. The ledger stays live
and the coordinator recycles its context when that gets expensive.

## One bead, one branch

A bead's ID is also its branch name. The orchestrator creates the branch before it briefs its
worker; the worker commits only that bead's files there, pushes, and reports the branch and
commit hash in its `done` verdict. `main` is never a working branch, and merging into it is
the user's move — no pane does it.

Gates run before the commit. Each project's gate commands live in its own `gates` field in
`{{TOPOLOGY}}` and are rendered into that project's `CLAUDE.md`. A malformed
or missing field is rejected at render time rather than left to commit unverified work.

A project whose toolchain is not chosen yet carries `"gates": "pending"`. It renders, so you
can plan it; `brief.sh` refuses to dispatch to it. Send `brief.sh --bootstrap` instead. That
worker sets up the toolchain, runs the gates it established, and — only if they all pass —
commits the scaffold on the bead's branch and pushes. Its `done` verdict reports the gate
commands, the gate results and the commit hash. If a gate fails it reports `blocked` and
commits nothing, because a scaffold its own gates reject is not a toolchain.

Record the commands here, and the project opens for normal work. The scaffold is already
committed by then, so the next bead branches from something real.

## Split, or bounce

An orchestrator may break one brief into as many steps for its worker as it likes, off its
own context, and the ledger never hears about them. Only the bead's outcome is ledger
business.

It bounces instead when the work exceeds what the brief scoped, or belongs to another
project. Re-scoping and re-routing are the coordinator's calls, because only the coordinator
sees every project.

## Driving a pane

`herdr agent prompt` writes to the pane's user input, so any slash command works there —
user-only skills and built-ins alike.

```bash
{{SCRIPTS}}/send.sh <role> "/clear"
{{SCRIPTS}}/send.sh <role> "/compact"
```

`/clear` starts a new session, so Herdr drops the agent's name; `send.sh` restores it, and
the restore is racy enough to need retries, which is why it is scripted rather than typed.
A cleared pane re-reads `CLAUDE.md`, which makes `/clear` the way to push a rules change
into a long-running session.

Two hazards, both handled in the scripts rather than left to memory:

- **Ordering.** Clearing discards whatever has not been reported. `send.sh` refuses to clear
  a `working` pane; `recycle.sh` prints a flush checklist before clearing the coordinator.
- **Timing.** A `/clear` aimed at this pane queues on its own input and fires at the end of
  the turn, so self-clearing is safe by construction. Clearing someone else is the case that
  needs the idle check.

`/compact` keeps both the session and the name, and is the cheaper move when the thread still
matters.

## When something comes back wrong

`wait.sh` exits `3` on blocked and `4` on timeout or stall.

**Blocked** means a dialog is open. Read it, then ask a human. Answering an approval prompt
on someone's behalf is the one thing no script here will do for you.

**Undetermined** means exactly that: the prompt may have landed and the work may still be
running. Read the state before resending — a duplicate brief gives one bead two workers.

Silence is not a verdict. `read.sh <role> --state`, then `--lines 200`, is the fallback for a
pane that went quiet; reaching for it means something failed to report, so fix that cause
rather than settling into transcript-reading as a habit.

## Boundaries

Leave workspaces, tabs, panes, and sessions you did not create alone, and keep
`herdr server stop` out of your scripts — it ends every pane in the session, including the
one you are reading this in.

Background work should not move the user's focus. `focus` also marks an agent as seen, which
collapses the `idle` / `done` distinction the scripts rely on.
