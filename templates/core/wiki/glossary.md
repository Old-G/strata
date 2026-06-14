---
title: Glossary
type: entity
created: {{DATE}}
updated: {{DATE}}
links:
---

# Glossary

Short definitions of project-specific terms, acronyms, and patterns. Each `ingest` adds
new terms here.

This table is **also the drift-protection source-of-truth**: for any fact that risks
diverging across pages (a formula, a schema name, a version number, a canonical value),
record the authoritative value here and point other pages at this row. When `lint`
finds a page contradicting the glossary, the glossary wins — fix the page.

| Term | Definition | Source of truth |
|---|---|---|
| Strata | The self-describing / self-correcting repo system: a curated, git-versioned `wiki/` the AI queries before grepping the codebase. | [[overview]] |
| ingest | The operation that turns a `raw/<file>.md` into wiki pages (source summary + entities + ADRs + glossary + index + log). | `wiki/WIKI.md` |
| drift | When `docs/`, `raw/`, and `wiki/` (or two wiki pages) disagree about a fact. Surfaced by `lint`, fixed by re-ingest — never auto-fixed. | `wiki/WIKI.md` |

_Add rows as you ingest — keep definitions to one line; put depth in `entities/`._
