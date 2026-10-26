# {{PROJECT}}

Two panes share this directory, and therefore this file. Resolve which one you are before
anything else:

```bash
{{SCRIPTS}}/pane.sh self
```

- `{{MAIN}}` → **orchestrator**. A brief arrives; you turn it into steps and dispatch them.
- `{{AGENT}}` → **worker**. You do the work in the repo.

Empty output means this pane is not in the topology — ask rather than guess.
`{{SCRIPTS}}/pane.sh status` shows every role and whether it is live.

## How work reaches you

Work arrives as a **brief**: a bead ID, the task in full, and the list of documents you may
read. It is self-contained because it has to be — there is no issue tracker here. `bd` is
{{TOP}}'s alone, this repo has no `.beads/`, and the bead ID is a correlation token you
report against, nothing you can look up.

So the brief is the whole of what you know. A gap in it is a question, not a guess.

## How you answer

Exactly one verdict per bead, when you finish or stop:

```bash
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd done       "<what changed, which files>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd blocked    "<what is in the way>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd needs-info "<the question>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd bounced    "<why it is bigger or other than the brief>"
```

`report.sh` sends it one tier up and nowhere else. The format is fixed: {{TOP}} parses that
line to move the bead, and it is the only evidence the bead moved at all.

Give `needs-info` your recommended answer along with the question — `"<question> — recommend:
<answer>"`. You have the most context on it, and a question that arrives with a recommendation
resolves in one hop instead of three.

## What you may read

- **This repo** — freely.
- **`{{DESIGN_REL}}`** — read-only, and only the paths your brief named. Write nothing there.
- **Every other project** — out of bounds:

{{SIBLINGS}}

  What you need from one of them arrives in a brief, not in a file read. Ask with
  `needs-info` and {{TOP}} will carry it across. `{{TOPOLOGY}}` lists what exists; a repo
  appearing there is still a repo you may not read.

`docs/agents/design-docs.md` covers how to use what you read.

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

## Branches and commits

The branch is the bead: `{{MAIN}}` created `{{PREFIX}}-a3f2dd` before briefing you, and that
is where the work lands. `main` is never a working branch, and merging into it is the user's
move alone — {{TOP}} does not do it either.

When every gate passes you have standing approval to commit and push, with no further ask:

```bash
git add <only this bead's files>   # never -A, never .
git commit -m "<message>"
git push -u origin {{PREFIX}}-a3f2dd
```

Commit this bead's files and nothing else. A change you made that belongs to another bead is
a finding to report, not a file to sweep into this commit.

Then report the commit hash and the branch:

```bash
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd done \
  "<branch> @ <commit hash>; gates: <results>; <files changed>"
```

## Gates

{{GATES}}

## Skills

Work goes through the Matt Pocock skills. When a task matches a row, invoke the skill rather
than paraphrasing it from memory.

A brief often opens with the slash command already chosen — that works because the Herdr
prompt channel is the pane's user input, so a skill marked `disable-model-invocation` fires
there even though it is absent from your own available-skills list.

| What you need | Skill | Whose job |
|---|---|---|
| Facts from docs, APIs, primary sources | `/mattpocock-skills:research` | both |
| Module interface, boundaries, seams | `/mattpocock-skills:codebase-design` | {{MAIN}} |
| Review changes since a fixed point | `/mattpocock-skills:code-review` | {{MAIN}} |
| PR body | `/mattpocock-skills:pr` | {{MAIN}} |
| Feature or bugfix, tests first | `/mattpocock-skills:tdd` | {{AGENT}} |
| Broken, throwing, slow | `/mattpocock-skills:diagnosing-bugs` | {{AGENT}} |
| A design question, answered by a throwaway build | `/mattpocock-skills:prototype` | {{AGENT}} |
| Implement one piece of work | `/mattpocock-skills:implement` | arrives in the brief |
| Implement a whole spec | `/mattpocock-skills:implement-spec` | arrives in the brief |

Terminology, ADRs, and specs are written in `{{DESIGN_REL}}` by {{TOP}}. A term or decision
you find missing goes up as verdict detail.

## Where things live

- `docs/agents/design-docs.md` — using the documents a brief names
- `{{DESIGN_REL}}/docs/agents/orchestration.md` — the protocol, in full
- `{{TOPOLOGY}}` — the role graph the scripts read. It lives above this repo, is shared by
  the whole system, and {{TOP}} is its only editor
