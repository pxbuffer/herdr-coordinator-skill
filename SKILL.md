---
name: herdr-coordinator
description: Set up a multi-pane Herdr agent system — discovers the live topology, writes the role rules, and installs the dispatch scripts. Use when wiring panes into a coordinator/orchestrator/worker system, adding a project to one, or re-rendering its rules after a protocol change.
disable-model-invocation: true
---

# herdr-coordinator

Turn a set of running Herdr panes into a coordinated agent system, with the protocol enforced
by scripts rather than remembered from prose.

Three tiers, each owning exactly one thing:

- **coordinator** — one pane. Owns the **ledger** (beads) and the user. Lives in the design
  repo and is its only writer.
- **orchestrator** — one per project. Receives a **brief**, turns it into steps, dispatches
  them. Holds no ledger.
- **worker** — one per project. Does the work, with sub agents inside its own session.

Work flows down as briefs, outcomes flow up as **verdicts**. A brief is self-contained — bead
ID, the task in full, every document the receiver may read — because the receiver cannot look
anything up. That single-writer ledger is the design's load-bearing choice: it is what lets
the coordinator recycle its own context and still know where everything stands.

Produces, per project:

- `.claude/herdr/topology.json` — the role graph every script reads
- `CLAUDE.md` — role resolution and the tier's rules
- `docs/agents/…` — the protocol reference (coordinator) or doc-reading rules (project)

The scripts stay in this skill folder and are shared by every project, so the protocol has one
source of truth. Projects reference them by absolute path.

Set `S` to this skill's base directory before running anything below — the invocation header
names that directory, and the steps use `$S` throughout:

```bash
S=<this skill's base directory>
```

## 1. Preflight

Stop and say so if any of these fails — each one is a wall, not a warning:

```bash
test "${HERDR_ENV:-}" = 1          # inside a Herdr pane
command -v herdr bd                # the CLIs the system drives
herdr status                       # server running and protocol-compatible
```

`bd` is required because the coordinator tracks work in beads. Without it there is no ledger,
and with no ledger the verdict protocol has nowhere to land.

## 2. Discover the topology

Read what is actually running — never assume a shape:

```bash
herdr workspace list
herdr tab list --workspace <each workspace id>
herdr pane list --workspace <each workspace id>
herdr agent list
```

For each pane, record: pane id, workspace, tab label, cwd, whether an agent is live.

Group panes by **cwd**: panes sharing a directory share a `CLAUDE.md`, which is what makes
role resolution necessary in the first place. Each distinct cwd is one repo.

Note the gaps explicitly — a pane with no agent, a tab whose label carries no convention, a
repo that does not exist yet. Those become the by-hand list in step 8.

Done when every pane is either assigned to a role or explicitly excluded.

## 3. Propose the role graph, then confirm

Infer from tab labels: a tab named `main` is a coordinator or an orchestrator, `agent` is a
worker. Other labels carry no convention — propose from the cwd and the pane's current
contents, and mark your inference as a guess.

Exactly one role has no parent: the coordinator. It is the only pane that talks to the user
and the only one that runs `bd`. Every orchestrator is its child. **How many projects there
are is whatever you discovered** — one, two, nine. Nothing in this skill assumes a count.

Each project is exactly one orchestrator and one worker. A project's parallelism lives in
that worker's own sub agents, where one session still owns the repo; a second worker pane
would put two sessions in one working tree and buy coordination problems inside a repo to
save nothing. Propose a one-worker tier per project, and if you discovered a spare pane
sharing a project's cwd, exclude it explicitly in step 2 rather than wiring it in.

**Derive role names from the repo's directory name**, which is the one name the user already
chose: `<dirname>-main` for its orchestrator, `<dirname>-agent` for its worker. A directory
called `api-gateway` gives `api-gateway-main` and `api-gateway-agent`. Role names must match
`[a-z][a-z0-9_-]{0,31}`, so offer a shortening only when a directory name overruns that or
reads badly, and record whatever the user confirms. From that point the topology is the only
place the names live — nothing re-derives them at runtime, so an abbreviation the user
prefers keeps working.

Present the proposed graph as a table — role name, pane, kind, parent — and ask the user to
confirm or correct it in one question.

Settle the ledger prefix here too: one prefix for the whole system, since there is one
database. Ask rather than inferring it from a directory name.

Collect each project's **gate commands** — the lint, test and build steps that must pass
before a commit, in order. They go in that project's `gates` field. Ask; they cannot be
inferred from an empty repo. For a project whose toolchain is not chosen yet, set
`"gates": "pending"`: it renders, and the first brief it can accept is the
`--bootstrap` one that establishes them.

Settle the **writing style** as well — `style` in the topology, `ste100` (the default) or
`none`. It binds the coordinator alone, so the question is whether the user wants the
coordinator's replies and design documents in ASD-STE100 Simplified Technical English. Step 4
has the values.

Settle **where the rules land** — `rules` in the topology, `tracked` (the default) or `local`.
Ask whether any repo is shared with people outside this system. The rendered rules carry this
machine's absolute paths and pane IDs, so in a team repo they must stay out of commits, and a
team's own `CLAUDE.md` must stay untouched. Step 4 has the values.

Done when the user has confirmed the graph. Do not write a file before this.

## 4. Write the topology

**One `.claude/herdr/topology.json` for the whole system**, at the system root — the directory
above every repo, the same place this skill lives. Not one per repo: discovery is a walk up
from the cwd, so a single file above them all is found identically from every repo, and there
is nothing to keep in sync.

That placement is load-bearing. The coordinator's own repo looks like the natural home, but it
is a *sibling* of the project repos, not an ancestor, so a walk up from a project would never
reach it — it would need a pointer file in each repo, which is the per-repo artifact this
avoids.

Discovery takes the **nearest** match, so a copy inside a repo would shadow the canonical file
for everything run there, and would do it invisibly: run from that repo, the copy *is* what
discovery returns. `--check` therefore enforces a positional invariant rather than comparing
copies — a topology that lives inside a repo it lists as a project is rejected whichever file
won the walk-up.

The file lists **every** role in the system, because a script in one repo resolves roles in
another when reporting across a tier.

This file is the system's **single source of truth**. Every script reads it and nothing
re-derives a name from a directory at runtime, so correcting the topology is how you correct
the system. One illustrative coordinator record — the names here are an example, not a
convention to match:

```json
{
  "version": 2,
  "tracker": "beads",
  "ledger": "arch-main",
  "style": "ste100",
  "roles": {
    "arch-main": {
      "pane": "w1:p1", "workspace": "w1", "tab_label": "main",
      "kind": "coordinator", "parent": null,
      "children": ["web-app-main", "api-gateway-main", "ml-pipeline-main"],
      "cwd": "/abs/path/architecture", "prefix": "sys"
    },
    "web-app-main": {
      "pane": "w2:p2", "workspace": "w2", "tab_label": "main",
      "kind": "orchestrator", "parent": "arch-main", "children": ["web-app-agent"],
      "cwd": "/abs/path/web-app", "prefix": "sys",
      "gates": ["pnpm lint", "pnpm test", "pnpm build"]
    }
  }
}
```

`kind` is `coordinator`, `orchestrator`, or `worker`. `parent` is `null` for the coordinator
and only for it — `hc_top` fails loudly on a second one, because "who owns the ledger" has to
have one answer. Every child names its parent and every parent lists its children:
`send.sh` reads one and `report.sh` the other, so a mismatch silently severs a channel.

`prefix` is the same on every role: one ledger, one prefix.

`gates` is **required on every orchestrator**: the shell commands that must pass before its
worker commits, in the order they run. They are project-specific, so they live per project
here and nowhere else — the `## Gates` section in a project's `CLAUDE.md` is rendered output.
Edit the topology, never the rendered section. This script only reads the topology, so a gate
list is never rewritten by a render.

A project whose toolchain does not exist yet sets `"gates": "pending"`. That renders — so the
coordinator can run `wayfinder` to choose the stack — and `--check` reports it as a
**warning**, not a failure. What it blocks is dispatch: `brief.sh` refuses to send work to a
pending project, because a worker reaching the commit step with nothing to verify its work
would commit unchecked code.

The one exception is `brief.sh --bootstrap`, the toolchain-setup brief. That worker
establishes the lint, test and build commands, runs them, and commits the scaffold on its bead
branch if they all pass — leaving it uncommitted would strand the scaffold and make the next
bead branch on top of work in no commit. A failing gate is a `blocked` verdict with no commit.
Its `done` verdict reports the commands, the results and the commit hash; recording the
commands here ends the pending state.

An **absent** `gates` field stays a hard error. Pending has to be chosen on purpose, so that
forgetting the field never silently reads as "not decided yet".

Without this, the two rules deadlock: choosing a stack needs the coordinator's rules rendered,
and rendering needed the stack already chosen.

`style` is the writing-style rule for the **coordinator tier only**:

| Value | Effect |
|---|---|
| `ste100` | default. Renders `docs/agents/writing-style.md` with the ASD-STE100 Simplified Technical English rule, and a `## Writing style` section in the coordinator's `CLAUDE.md` |
| `none` | renders nothing, and leaves no reference to it in `CLAUDE.md`. An existing `writing-style.md` is removed |

Omitting the field gives `ste100`. Any other value is rejected by `--check` rather than
treated as a typo to guess at. No project-tier template carries the rule: a worker writes
code and a fixed-format verdict line, so a prose style there would add load and change
nothing.

`rules` is where every repo's rendered rules land:

| Value | Rules file | Agent docs | Use when |
|---|---|---|---|
| `tracked` | `CLAUDE.md` | `docs/agents/` | default. Every repo is yours, and the rules are versioned with it |
| `local` | `CLAUDE.local.md` | `.claude/herdr/docs/` | a repo is shared with a team. Both paths go into that repo's `.git/info/exclude`, so nothing reaches a commit, and a team `CLAUDE.md` stays as it is — Claude Code loads both files |

One value for the whole system, because the tiers point at each other's docs by relative path.
Elsewhere in this file, read `CLAUDE.md` and `docs/agents/` as the chosen layout's paths.

Write it once, at the system root. Verify immediately — the first command checks the graph's
internal consistency, the second checks it against what is actually running:

```bash
"$S/scripts/render-rules.py" --check
"$S/scripts/pane.sh" status
```

`--check` rejects a second parentless role, a parent/children pair that disagrees, two roles
on one pane, a mixed ledger prefix, an unknown `style` or `rules` value, an orchestrator with no `gates`
field or a malformed gate list, an orchestrator whose children are not exactly one worker,
and a project tier whose panes do not share a cwd. It also rejects a topology living inside a
repo it describes, and any repo-local copy of it. Pending gates are reported as a warning and
still render. Each of those would otherwise
render rules that quietly describe a different system than the scripts enforce. Validation
runs before any writing, so a rejected topology renders nothing at all rather than half a
system.

Done when `--check` says the topology is consistent and `pane.sh status` prints every role
with a live status.

## 5. Install the rules

One command renders every repo:

```bash
"$S/scripts/render-rules.py"              # write
"$S/scripts/render-rules.py" --dry-run    # list what it would write
```

It derives every value from the topology — project names from each repo's directory, role
names from the role graph, `DESIGN_REL` and the sibling list from the relative paths between
cwds, the channel diagram from the parent/child edges, and the per-project bead labels from
the project names. There is nothing to type, which is the point: a hand-typed role name is a
name that can disagree with the topology, and then the rules and the scripts describe
different systems.

Two template families, because the tiers hold different things:

- `templates/rules/coordinator/` → the coordinator's repo. Gets `CLAUDE.md` plus
  `orchestration.md`, `ledger.md`, `triage-labels.md`, `domain.md`, `wayfinder.md` under
  `docs/agents/`, and `writing-style.md` when `style` is not `none`.
- `templates/rules/project/` → every project repo, however many there are. Gets `CLAUDE.md`
  plus `design-docs.md`, and points at the coordinator's `orchestration.md` for the protocol.

Keeping one copy of the protocol is deliberate: two copies drift, and then the tiers disagree
about the rules while both believe they are following them.

Unresolved placeholders fail the render rather than producing a blank — fix the topology, never
the template. If you find yourself wanting to pass a value by hand, the value belongs in
`topology.json` and `render-rules.py` should derive it.

With `"rules": "local"` there is nothing to merge: the render writes `CLAUDE.local.md` beside
whatever `CLAUDE.md` the repo has, and never touches it.

When a `CLAUDE.md` already exists and holds anything the user wrote, merge rather than
overwrite: keep their sections and replace only the ones this skill owns. Show a diff before
writing. A `CLAUDE.md` this skill rendered previously is safe to overwrite wholesale.

Done when `render-rules.py` lists one `CLAUDE.md` per repo and exits clean.

## 6. Initialise the ledger

In the coordinator's repo only, when `.beads/` is absent:

```bash
bd init --prefix <prefix> --non-interactive --role maintainer --skip-agents --skip-hooks
```

`bd init` creates a git repository unconditionally, with no flag to decline. Tell the user
this happened; do not quietly leave a repo they didn't ask for.

A project repo gets no `.beads/`. One already there is a leftover from a previous shape:
archive it rather than deleting it, and say where it went — a directory named `.beads` sitting
in a worker's repo is a standing invitation to run `bd` there.

## 7. Bootstrap the panes

Long-running sessions predate the files you just wrote, so they hold none of it. A cleared
pane re-reads `CLAUDE.md`, which is the reliable fix:

```bash
"$S/scripts/send.sh" <role> "/clear"
"$S/scripts/pane.sh" repair
```

`send.sh` refuses to clear a `working` pane, since clearing discards anything it has not
reported. Let it settle, or pass `--force-clear` knowingly.

Then have each orchestrator bootstrap its own worker rather than reaching past it: the first
real exercise of the protocol, and it surfaces a broken channel immediately.

Ask each role to reply with the role it resolved and the tier it believes it is. Mismatched
answers mean the topology and the panes disagree — fix the topology before any real work
starts.

## 8. Report

Tell the user: the confirmed graph, which files were written, which panes were cleared, where
anything was archived, and the git repositories `bd init` created.

Then the by-hand list from step 2 — a pane with no agent running, a tab needing a label or a
cwd, a stray tab to close. Name the exact commands. These are the steps that leave the system
half-wired if they are skipped, so they belong in the report rather than in a follow-up.
