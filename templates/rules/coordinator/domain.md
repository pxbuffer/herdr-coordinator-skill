# Domain docs

`{{PROJECT}}/` is the system's design repo and you are its only writer. Layout:

- `GLOSSARY-MAP.md` — the bounded contexts, their relationships and the system-wide terms
- `docs/contexts/<context>/GLOSSARY.md` — the terms of each context
- `docs/adr/` — decisions, `ADR-NNNN-<slug>.md`
- `docs/requirements/` — requirements, in four files:
  - `business-goals.md` — why the system exists
  - `functional.md` — what the system does (FR)
  - `non-functional.md` — how well it does it (NFR)
  - `parameters.md` — the owner's values, each with status `estimate` or `decided`
- `docs/design/` — design docs and specs

The glossaries live here rather than in the projects on purpose. The usual argument against
hoisting vocabulary — that it couples codebases — is the argument for it here: no project
can read another, so a shared definition in a place they can all read is the only way they
agree on what a word means. A term lives in its home context's glossary; `GLOSSARY-MAP.md`
holds the terms every context shares and says how the contexts relate.

## Writing

`/mattpocock-skills:domain-modeling` creates a term or a decision at the moment it actually
resolves. Writing either one ahead of that produces documents nobody needed yet.

An ADR that changes a contract between projects gets written **before** the briefs that
depend on it, and every one of those briefs names it with `--doc`. That file is how panes
that cannot see each other build the same thing.

## Reading, below you

A brief names the documents its receiver may read, and that list is the whole of what it
knows. So naming documents is part of writing a brief, not a courtesy:

```bash
{{SCRIPTS}}/brief.sh <role> {{PREFIX}}-a3f2dd \
  --task "..." --doc "../{{PROJECT}}/docs/adr/ADR-0007.md"
```

Use the glossary's own terms in bead titles and briefs, including where it rejects a synonym.
A concept missing from the glossary is a signal: either the language is invented and worth
reconsidering, or the gap is real and worth an entry before the brief goes out.

A receiver whose work contradicts an ADR says so in its verdict detail. That is a bounce
worth acting on — reopen the decision here rather than letting the code drift from it.
