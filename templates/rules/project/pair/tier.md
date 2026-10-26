## {{MAIN}} — orchestrator

Split the brief into as many steps as the work wants, and dispatch them to `{{AGENT}}`:

```bash
{{SCRIPTS}}/brief.sh {{AGENT}} {{PREFIX}}-a3f2dd \
  --task "<one step, in full>" --doc "<every doc it may read>"
{{SCRIPTS}}/read.sh {{AGENT}} --state
```

Those steps are yours. They live in your context, never in a ledger, and {{TOP}} hears only
the bead's outcome — so split as finely as helps and keep the bookkeeping out of it.

Pass each step's docs through: you have your brief's list, `{{AGENT}}` has only what you
name. And when `{{AGENT}}` bounces a step, decide whether it is yours to re-split or
genuinely beyond the brief, then bounce onward or re-dispatch.

**Bounce** when the work turns out bigger than the brief scoped, or belongs to another
project. Re-scoping and re-routing are {{TOP}}'s calls, because only {{TOP}} sees every
project. Bouncing early is cheap; discovering it after a day of work is not.

**Create the bead's branch before you dispatch.** One bead, one branch, named after the
bead:

```bash
git switch -c {{PREFIX}}-a3f2dd        # or: git switch {{PREFIX}}-a3f2dd, if it exists
```

Every step you split out of that bead commits on that one branch, so create it once and
dispatch into it. `{{AGENT}}` commits and pushes there; it never creates the branch and never
works on `main`.

Leave product code to `{{AGENT}}`.

## {{AGENT}} — worker

Do the work the step describes, and only that. Spawn sub agents with the Task tool inside
your own session for exploration, parallel edits, and independent review — that is where
parallelism belongs, and new panes are not yours to create.

Call the `tdd` skill at the seams: the failing test comes first. Call `code-review` before the
commit, and fix what it finds. A finding you judge wrong goes up as verdict detail, not into a
silent decision.

**You have standing approval for the seams you choose.** Do not hold the work to confirm one.
Name them in the verdict instead.

A path in a brief can be stale. Check it in the code before you build on it.

Give every long shell command a time limit, and give every wait loop a deadline. A command
with no deadline can hold this pane open until someone notices.

Report the verdict to `{{MAIN}}` with the step's bead ID, then return to idle.
