# herdr-coordinator

A Claude Code skill that turns a set of running [Herdr](https://herdr.dev) panes into a
coordinated agent system, with the protocol enforced by scripts rather than remembered from
prose.

Three tiers, each owning exactly one thing:

```
user ──► coordinator                design repo · the ledger · the only pane you talk to
            │
            ├──► orchestrator ──► worker ──► sub agents (Task tool)
            │    project repo     project repo
            │
            └──► … one pair per project, however many there are

briefs flow down · verdicts flow up · no horizontal calls
```

- **coordinator** — one pane. Owns the beads **ledger** and the user. Lives in the design repo
  (ADRs, business requirements, design docs, glossary) and is its only writer.
- **orchestrator** — one per project. Receives a **brief**, splits it into steps, dispatches
  them. Holds no ledger.
- **worker** — one per project. Does the work, parallelising inside its own session with sub
  agents.

A **brief** is self-contained — bead ID, the task in full, and every document the receiver may
read — because the receiver cannot look anything up. A **verdict** (`done` / `blocked` /
`needs-info` / `bounced`) travels back one tier per hop. That single-writer ledger is the
load-bearing choice: it is what lets the coordinator clear its own context and still know
where everything stands.

## What it generates

Run once per system, the skill writes:

| File | Where |
|---|---|
| `topology.json` | the system root, above every repo — one file for the whole system |
| `CLAUDE.md` | each repo, rendered for its tier |
| `docs/agents/{orchestration,ledger,triage-labels,domain,wayfinder,writing-style}.md` | the design repo |
| `docs/agents/design-docs.md` | each project repo |

With `"rules": "local"` in `topology.json`, the rules go to `CLAUDE.local.md` and the docs to
`.claude/herdr/docs/` instead, and both are listed in each repo's `.git/info/exclude`. Use it
when a repo is shared with a team: the rendered rules carry your machine's absolute paths and
pane IDs, so they must not reach a shared commit, and the team's own `CLAUDE.md` stays as it is.

Everything is derived from `topology.json`: project names from each repo's directory, role
names from the role graph, relative paths between repos, the channel diagram, per-project bead
labels and gate commands. Nothing is typed twice.

The scripts stay in this repo and every project references them by absolute path, so the
protocol has one source of truth.

## Dependencies

All three are required. The skill is inert without them, and nothing currently checks for the
third.

| | Why |
|---|---|
| [Herdr](https://herdr.dev) | the panes, and the `herdr agent prompt` channel every dispatch rides on. The skill refuses to run outside a Herdr pane (`HERDR_ENV=1`) |
| [`bd`](https://github.com/steveyegge/beads) (beads) | the ledger. Without it there is nowhere for a verdict to land |
| [`mattpocock-skills`](https://github.com/mattpocock/skills) plugin | the rendered rules route work through `tdd`, `code-review`, `implement`, `wayfinder`, `domain-modeling` and others — 19 skills in total. `brief.sh` opens every dispatch with `/mattpocock-skills:<skill>` |

Install the plugin with `/plugin marketplace add mattpocock/skills`, then
`/plugin install mattpocock-skills`.

## Install

Clone this repo straight into your user skills directory, so the skill sits at
`~/.claude/skills/herdr-coordinator`:

```bash
git clone <this repo> ~/.claude/skills/herdr-coordinator
```

The directory name matters: it is the skill's name, so keep it `herdr-coordinator`.

It is a **user-level** skill, which means every project sees it. It is also marked
`disable-model-invocation: true`, so Claude never reaches for it on its own — you invoke it
deliberately:

```
/herdr-coordinator
```

## Update

```bash
cd ~/.claude/skills/herdr-coordinator && git pull
```

Scripts are referenced by absolute path, which does not change across a pull, so an update
takes effect immediately for every pane. Re-render afterwards if the pull changed anything
under `templates/`:

```bash
~/.claude/skills/herdr-coordinator/scripts/render-rules.py
```

Rendered `CLAUDE.md` files are output. Edit the templates here, never the rendered files.

## Setup, and where `topology.json` comes from

`topology.json` is **not** in this repo. It describes one specific machine — absolute repo
paths and Herdr pane IDs like `w1:p1` — so it belongs to the system it describes, not to the
skill. Invoking the skill is what creates it.

The skill reads the live Herdr session (`herdr workspace list`, `tab list`, `pane list`,
`agent list`), groups panes by working directory, proposes a role graph, and asks you to
confirm it before writing anything. Then it writes `topology.json` and renders every repo's
rules from it.

It goes at the **system root**: the directory above every repo.

```
<system root>/
├── .claude/herdr/topology.json     ← the one topology, and the only thing to version here
├── design/                          coordinator's repo
├── frontend/                        project repo
└── backend/                         project repo
```

That placement is load-bearing. Discovery is a walk up from the current directory, so one file
above every repo resolves identically from all of them, with nothing to keep in sync. The
coordinator's own repo looks like the natural home, but it is a *sibling* of the project
repos, not an ancestor — a walk up from a project would never reach it.

Discovery takes the **nearest** match, so a copy inside a repo would shadow the real one for
everything run there, invisibly: run from that repo, the copy *is* what discovery returns.
`render-rules.py --check` therefore rejects any topology that lives inside a repo it lists as a
project, whichever file won the walk-up.

Version `topology.json` in its own small repo at the system root, alongside a `.gitignore` that
excludes the project repos — they are each their own repository.

## Checking a system

```bash
scripts/render-rules.py --check      # validate the graph, write nothing
scripts/render-rules.py --dry-run    # list what would be written
scripts/render-rules.py             # render every repo
scripts/pane.sh status              # the graph against what is actually running
```

`--check` is strict, because a topology that renders wrong produces rules that quietly
describe a different system than the scripts enforce. It rejects: a second parentless role, a
parent/children pair that disagrees, two roles on one pane, a mixed ledger prefix, an unknown
`style`, a missing or malformed `gates` list, an orchestrator whose children are not exactly
one worker, a project tier whose panes do not share a directory, and a shadowing topology
copy. Pending gates are a warning.

## Day to day

```bash
scripts/restore.sh                            # coordinator, at session start
scripts/brief.sh <role> <bead> --task "…" --doc "…"   # dispatch
scripts/report.sh <bead> done "…"             # the one path upward
scripts/recycle.sh --flushed                  # coordinator clears its own context
scripts/read.sh <role> --state                # a pane that went quiet
```

`SKILL.md` is the setup procedure. The generated
`<design repo>/docs/agents/orchestration.md` is the protocol reference for a running system,
and the one copy of it — project repos point at it rather than carrying their own.
