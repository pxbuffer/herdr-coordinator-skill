# Triage labels

The skills speak in five canonical triage roles. Labels in beads are free-form, so there is
nothing to create up front — they exist from the first time they are applied.

| Role in mattpocock/skills | Label here | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | Needs to be evaluated |
| `needs-info` | `needs-info` | Waiting on the requester |
| `ready-for-agent` | `ready-for-agent` | Fully specified, ready to brief |
| `ready-for-human` | `ready-for-human` | Requires a human |
| `wontfix` | `wontfix` | Will not be actioned |

```bash
bd label add {{PREFIX}}-a3f2dd ready-for-agent
bd list --label needs-triage
bd label list-all
```

`ready-for-agent` means something sharper here than elsewhere: a brief rendered from this
bead would be complete on its own, naming every document the receiver needs. A bead that
still assumes the reader can look things up is not ready.

`wontfix` records a decision; `bd close` ends the bead. Applying the label alone leaves the
bead open and in the queue.

A `needs-info` bead is waiting on a person, and you are the only pane that can reach one.
Take the question to the user — a label nobody is watching is not a question.
