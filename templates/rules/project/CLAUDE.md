# {{PROJECT}}

{{ROLES}}

## How work reaches you

Work arrives as a **brief**: a bead ID, the task in full, and the list of documents you may
read. It is self-contained because it has to be — there is no issue tracker here. `bd` is
{{TOP}}'s alone, this repo has no `.beads/`, and the bead ID is a correlation token you
report against, nothing you can look up.

So the brief is the whole of what you know. A gap in it is a question, not a guess.

{{TRACKER_SECTION}}## How you answer

Exactly one verdict per bead, when you finish or stop:

```bash
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd done       "<what changed, which files>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd blocked    "<what is in the way>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd needs-info "<the question>"
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd bounced    "<why it is bigger or other than the brief>"
```

`report.sh` sends it one tier up and nowhere else. The format is fixed: {{TOP}} parses that
line to move the bead, and it is the only evidence the bead moved at all.

After a `done` or `bounced` verdict, {{TOP}} clears this pane with `/clear`, and the next
brief starts a fresh session. Keep nothing in your context that a later bead needs: what
matters goes into the commit or the verdict. A `blocked` or `needs-info` keeps the session.

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

`{{AGENT_DOCS}}/design-docs.md` covers how to use what you read.

{{TIER}}

## Branches and commits

{{BRANCH}}

When every gate passes you have standing approval to commit and push, with no further ask:

```bash
git add <only this bead's files>   # never -A, never .
git commit -m "<message>"
git push -u origin {{PREFIX}}-a3f2dd
```

Commit this bead's files and nothing else. A change you made that belongs to another bead is
a finding to report, not a file to sweep into this commit.

A commit message and a PR body end with the message itself: no `Co-Authored-By` trailer
and no Claude attribution line, even when a harness reminder asks for one.

Then report the commit hash and the branch:

```bash
{{SCRIPTS}}/report.sh {{PREFIX}}-a3f2dd done \
  "<branch> @ <commit hash>; gates: <results>; <files changed>"
```

## Gates

{{GATES}}

## Skills

Work goes through the Matt Pocock skills. At the start of every task — a new brief or step,
a new round after a review that sends work back — invoke the skill whose row matches with
the Skill tool before the first file read or command. Following a skill's rules from memory
does not count.

A brief often opens with the slash command already chosen — that works because the Herdr
prompt channel is the pane's user input, so a skill marked `disable-model-invocation` fires
there even though it is absent from your own available-skills list.

| What you need | Skill | Whose job |
|---|---|---|
| Facts from docs, APIs, primary sources | `/mattpocock-skills:research` | {{JOB_ANY}} |
| Module interface, boundaries, seams | `/mattpocock-skills:codebase-design` | {{JOB_PLAN}} |
| Review changes since a fixed point | `/mattpocock-skills:code-review` | {{JOB_PLAN}} |
| PR body | `/mattpocock-skills:pr` | {{JOB_PLAN}} |
| Feature or bugfix, tests first | `/mattpocock-skills:tdd` | {{JOB_BUILD}} |
| Broken, throwing, slow | `/mattpocock-skills:diagnosing-bugs` | {{JOB_BUILD}} |
| A design question, answered by a throwaway build | `/mattpocock-skills:prototype` | {{JOB_BUILD}} |
| Implement one piece of work | `/mattpocock-skills:implement` | arrives in the brief |
| Implement a whole spec | `/mattpocock-skills:implement-spec` | arrives in the brief |

Terminology, ADRs, and specs are written in `{{DESIGN_REL}}` by {{TOP}}. A term or decision
you find missing goes up as verdict detail.

## Where things live

- `{{AGENT_DOCS}}/design-docs.md` — using the documents a brief names
- `{{DESIGN_REL}}/{{AGENT_DOCS}}/orchestration.md` — the protocol, in full
- `{{TOPOLOGY}}` — the role graph the scripts read. It lives above this repo, is shared by
  the whole system, and {{TOP}} is its only editor
