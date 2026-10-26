{{SKILL}}{{BEAD}}: {{TASK}}

Documents you may read for this bead:
{{DOCS}}
{{BOOTSTRAP}}
The bead ID is a correlation token. The ledger lives with {{PARENT}} and you do not read it,
so everything this bead needs is in this message. Something missing is a `needs-info`
verdict, never a guess.

Report once, when you finish or stop:

```bash
{{SCRIPTS}}/report.sh {{BEAD}} done       "<what changed, which files>"
{{SCRIPTS}}/report.sh {{BEAD}} blocked    "<what is in the way>"
{{SCRIPTS}}/report.sh {{BEAD}} needs-info "<the question>"
{{SCRIPTS}}/report.sh {{BEAD}} bounced    "<why this is bigger or other than the brief>"
```

This project's rules file (`CLAUDE.md`, or `CLAUDE.local.md` where the rules are
local) says how your role carries this out.
