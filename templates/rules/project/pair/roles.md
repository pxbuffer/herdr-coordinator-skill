Two panes share this directory, and therefore this file. Resolve which one you are before
anything else:

```bash
{{SCRIPTS}}/pane.sh self
```

- `{{MAIN}}` → **orchestrator**. A brief arrives; you turn it into steps and dispatch them.
- `{{AGENT}}` → **worker**. You do the work in the repo.

Empty output means this pane is not in the topology — ask rather than guess.
`{{SCRIPTS}}/pane.sh status` shows every role and whether it is live.
