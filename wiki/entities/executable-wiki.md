---
title: Executable wiki (self-verifying facts)
type: entity
created: 2026-08-15
updated: 2026-09-12
links: [gardener]
---

# Executable wiki (self-verifying facts)

## TLDR

Entity pages may carry claims with a `verify:` command and a freshness window; a failed check
flips the fact to `stale` — the wiki reports its own lies instead of waiting to be caught.

## Role

Closes the last gap between "curated knowledge" and "true knowledge". A wiki that cannot be
checked decays silently; one that checks itself turns drift into a dated line in the morning
digest.

## Current solutions

**First slice shipped in v0.14.0 — [[behaviour-specs]]:** a `## Requirements` scenario carries a
`test:` pointer, and `scripts/lib/requirements.py check` proves every pointer still resolves (the
file exists, the `::needle` is in it) — a wiki claim that names its own check. It does not run the
test and has no freshness window; the general `verify:` facts below are still backlog.

Approved, planned for P2/P3. Shape:

```yaml
facts:
  - claim: 'auth is handled only in middleware/auth.py'
    verify: "! grep -rl 'jwt.decode' src/ --include='*.py' | grep -v middleware/auth.py"
    freshness: 7d
    last_pass: 2026-08-14
```

Rules: verify commands are **read-only and repo-local**; start narrow with cheap, obvious
checks; never block on flaky verifies — one failure warns, two consecutive failures mark
stale. Execution belongs to [[gardener]] tier 1, which is why it costs nothing. `audit` gains a
lint for entities with zero verified facts on critical paths.

Open: verify sandboxing — plain subprocess with a timeout, or a read-only container (OQ#11).

The architecture form of this idea is the [[diagram-layer]] (P4): a diagram node pinned to
`path:line@commit` is a claim Archify's validator checks for free, with stable rule codes.

## Related

[[gardener]] · [[behaviour-specs]]

## Sources

[[vnext-brief]] §13.1 · [[p6-behaviour-specs]]
