# The ledger

One beads database for the whole system: `bd`, prefix `{{PREFIX}}-`, under `.beads/` in this
repo. **{{TOP}}** is its only reader and only writer. No other pane runs `bd` at all, and the
projects below have no `.beads/` of their own.

That single-writer rule is what the brief-and-verdict protocol buys. The cost is that the
ledger is only as accurate as the verdicts you write into it, so writing one is not
bookkeeping you can defer — it is the only record that the work happened.

Load the context once per session with `bd prime` (`restore.sh` does this for you). The
command reference lives there and in `bd <command> --help`; this file records only what those
cannot tell you.

## Publishing

```bash
bd create "<title>" --type feature --description "..." --acceptance "..." \
  --labels needs-triage --priority 2
```

`--type` takes `task` (default), `bug`, `feature`, `chore`, `epic`, `decision`, `spike`,
`story`. `--parent` nests under an epic; `--deps blocked-by:<id>` declares a blocking edge and
`blocks:<id>` reverses it; `--file plan.md` creates one bead per `##` heading, which is how
`/to-tickets` publishes; `--silent` prints only the ID, for scripting.

A bead's description has to be good enough to render a complete brief from, because the
brief is all the receiver ever sees. Write it for that purpose.

## Which project a bead belongs to

One database spans every project, so a label is what tells them apart. The convention is
`project-<repo directory name>`, which for this system means:

{{PROJECT_LABELS}}

`bd list --label project-<name>` is then one project's queue. The authoritative list of
projects is `{{TOPOLOGY}}`, never a list kept in prose — a project added
there is a label available here.

Routing stays a coordinator decision. A bead labelled for the wrong project comes back as a
`bounced` verdict, which is the system working.

## Status through a dispatch

`bd ready` lists what is genuinely claimable. Claim a bead when you dispatch it —
`bd update <ID> --claim` — because from then until the verdict lands, work is happening
somewhere you cannot see, and an unclaimed bead invites a second brief for the same work.

`bd note <ID>` holds the verdict detail. Put it there rather than leaving it in the
transcript: your transcript is disposable by design and notes survive the recycle.

A dead claim from a crashed pane is cleared by `bd reclaim`, not by `--force`. Forcing over a
live claim takes work away from a pane that is still doing it.

## Posting text to a bead

Use a new temp file name for each `bd` text, and read the text back after you post it. Reusing
one filename across posts is how a note ends up holding the previous bead's body, and a note
you did not verify is a note you cannot trust later — it is the record that outlives your
context.

Give every long shell command a time limit, and give every wait loop a deadline.

## One bead, one branch

A bead's branch is named after the bead: `{{PREFIX}}-a3f2dd` is both the ID and the branch.
The orchestrator creates it before briefing its worker, the worker commits and pushes there
(a solo orchestrator does both), and the `done` verdict reports the branch and the commit
hash — put both in the bead's note, because they are how the work is found again after you
recycle.

Merging into `main` is the user's move. No pane does it.

## Single source of truth

The database holds task state. `.beads/issues.jsonl` is an export for viewing and
interchange — reading it as truth means reading a stale snapshot. A parallel markdown list of
what is in flight produces two answers to the same question, and the one in your context is
the one that goes stale first.
