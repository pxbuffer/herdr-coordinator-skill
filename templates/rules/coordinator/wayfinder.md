# Working a map

`/mattpocock-skills:wayfinder` plans an effort that is larger than one session. The map and
its decision tickets live in the ledger, and the grilling rounds are a conversation with the
user. Both of those are **{{TOP}}**'s alone, so the map is worked here and not sent down.

The context it costs is the reason `recycle.sh` exists. Work a ticket, write the result to the
ledger, recycle, and take the next one.

## One ticket at a time

Take the first frontier ticket. Resolve that one ticket. Then stop.

A map tempts you to keep going while the thread is warm. Resolving two tickets in one pass
means the second one was decided with the first one's context still in the room, which is how
a map stops being a sequence of real decisions.

## A grilling ticket

Ask the questions in rounds. Give your recommended answer for each question. Then stop, and
wait for the user's answers.

Write every round to a file as well:

```
{{SCRATCH}}/round-<ticket id>-<n>.md
```

`<n>` is the round number. Never write over another ticket's file. A long round scrolls off
the user's screen, and the start of it is usually the part that matters.

## A research ticket

Do not start a sub agent in a git worktree. Inside a worktree, Claude Code refuses every
command that names `github`, so the research stalls in a way that looks like a network fault.

Fetch sources into `{{SCRATCH}}`, and make the research branch there:

```bash
git worktree add {{SCRATCH}}/<name> -b research/<name>
```

Read the research of closed tickets from its branch, without checking the branch out:

```bash
git show research/<name>:docs/research/<name>.md
```

## What a map ticket may change

Change no code. A map decides; it does not build.

When `/mattpocock-skills:domain-modeling` calls for a `GLOSSARY.md` entry or an ADR, raise it
in the grilling round rather than writing it straight away. After the user agrees: run the
documentation gates, commit only those files on the current branch, and push.

If the ticket produces the map's destination — a plan, for example — create the plan beads
the map's Notes ask for, once the user has agreed. Do not begin implementing them. Dispatching
them is a separate decision, made after the map is finished.

## Finishing

Follow the map's Notes, and `CLAUDE.md`.

Give every long shell command a time limit, and give every wait loop a deadline.

Report the resolution, the new tickets, and the frontier. Then stop.
