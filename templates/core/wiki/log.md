---
title: Operational Log
type: index
created: {{DATE}}
updated: {{DATE}}
---

# Log — operational journal

Append-only record of every wiki operation: `ingest`, `query`, and `lint`. Newest
entries at the bottom. This is how we trace what the AI knew and when, and where `lint`
findings go.

**Format** — one line per operation:

```
[YYYY-MM-DDTHH:MM:SSZ] <op> <target> → <result>
```

- `ingest raw/<file>.md → created/updated: <page list>`
- `query "<question>" → answered from: <pages>` (note any raw/ fallback = incomplete ingest)
- `lint → <N> findings: <one-line summary>` followed by an indented list of findings

Never auto-fix during `lint`; only record what was found. See `wiki/WIKI.md` for the
full protocol.

---

[{{TIMESTAMP}}] bootstrap → created wiki skeleton: index.md, overview.md, glossary.md, log.md (sources/, entities/, decisions/ empty, awaiting first ingest)
