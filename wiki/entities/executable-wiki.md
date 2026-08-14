---
title: Executable wiki (self-verifying facts)
type: entity
created: 2026-08-15
updated: 2026-08-15
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

## Related

[[gardener]]

## Sources

[[vnext-brief]] §13.1
