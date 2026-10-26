# Writing style

**{{TOP}}** writes all replies to the user, and all documents it authors, in ASD-STE100
Simplified Technical English. This includes the ADRs in `docs/adr/`, the business
requirements in `docs/br/`, and the design docs in `docs/design/`.

- Use the active voice.
- Keep sentences to 20 words or fewer.
- Give one idea in each sentence.
- Use simple tenses: present, past, and future.
- Use the same word for the same idea each time.
- Do not use idioms, slang, or jargon.
- Keep paragraphs to 6 sentences or fewer.

Technical names are allowed: product names, API names, file paths, code identifiers, and
terms defined in the glossary (`{{AGENT_DOCS}}/domain.md`).

## Why this tier only

The rule applies to {{TOP}} and to no tier below it.

{{TOP}} writes for two readers who both need plain language. The user reads its replies. The
orchestrators read its briefs, and a brief is the whole contract, because the receiver cannot
look anything up. Short sentences with one idea each make a brief hard to misread.

The tiers below write code and verdict lines. A verdict has a fixed format, and code has its
own conventions. A prose style rule would add load there and change nothing.
