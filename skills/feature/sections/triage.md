# Triage rubric — classify a request into a tier

Used by `/strata:feature` Phase 0. Emit ONE tier + a one-line reason + what gets skipped. **Bias UP when in doubt.**

## Tiers

- **trivial** — ~1–2 files, no new dependency, no risk surface, no architectural change, the ask is unambiguous.
- **standard** — several files, maybe one new dependency, real but bounded logic, no risk surface.
- **risky** — many files or a new subsystem; a significant new external dependency; ANY risk surface; an architectural shift; or an ambiguous ask.

## Risk surfaces → force `risky` (non-negotiable, however small the change looks)

Authentication / authorization · secrets, credentials, tokens · PII or personal data · money, payments, billing · external or untrusted input (network, uploads, user-supplied) · data migrations, schema changes, destructive DB operations · a public API or published contract · concurrency and locking · anything the user calls security-sensitive.

## Signals to read (cheap — do not turn this into an analysis)

File scope · new dependencies · presence of a risk surface · rough size · whether the ask is clear enough to name a one-line success criterion.

## Ambiguity

If you cannot state a one-line success criterion from the ask, treat it as at least `standard`.

## Output

> **Tier: <trivial|standard|risky>** — <one-line why>. Skipping: <phases>. Effort: <low|medium|high>. Say "go higher / lower" to override.

Then proceed; do not wait for confirmation unless the user overrides.
