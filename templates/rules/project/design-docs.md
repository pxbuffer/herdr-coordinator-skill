# Using the documents a brief names

{{DESIGN_REL}} is the system's design repo: `GLOSSARY.md`, `docs/adr/`, `docs/br/`,
`docs/design/`. It is read-only from here, and {{TOP}} is its only writer.

Read the paths your brief named. That list is deliberate, not a sample — {{TOP}} chose it
knowing what this bead touches, and a document it left out is one this bead does not need.
Browsing the rest of the repo is how you end up building against a decision that was
superseded for reasons your brief would have told you.

## Vocabulary

When your work names a domain concept — a type, a test name, a verdict detail — use the term
as `GLOSSARY.md` defines it, including where the glossary explicitly rejects a synonym. It is
one glossary for every project in the system, so a word you redefine locally is a word the
others will read differently.

A concept the glossary does not have goes up in your verdict detail. Either the language is
invented and worth reconsidering, or the gap is real and {{TOP}} should close it.

## Contradicting an ADR

Say so explicitly, in the verdict:

> _Contradicts ADR-0007 (…), but worth reopening because…_

An ADR is how projects that cannot read each other build the same thing, so quietly
diverging from one breaks the others without any pane being able to see it. Reopening
a decision is cheap; discovering the mismatch at integration is not.
