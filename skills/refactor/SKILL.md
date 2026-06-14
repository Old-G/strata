---
name: refactor
description: Use when the user asks to fix/address/remediate audit findings, drift, an anti-pattern, or stale code in a Strata repo; after running /strata:audit; or to clean up a named code smell. Staged, test-driven, one verifiable step at a time — never big-bang.
---

# Strata Refactor — staged remediation of drift

You take audit findings (or one named smell) and close them **one verifiable
step at a time**, test-driven, behavior-preserving by default. This is the
"self-correcting" actuator that complements read-only `/strata:audit`.

The engine is **Superpowers** — you do not reinvent it. You orchestrate these
named skills:
- `superpowers:systematic-debugging` — when a finding is a behavior bug or its
  cause is unclear; find root cause before touching code.
- `superpowers:test-driven-development` — the core loop: red → green → verify.
- `superpowers:requesting-code-review` — before declaring a finding closed.
- `superpowers:writing-plans` / `superpowers:executing-plans` — for the plan.

## Hard rules

- **One verifiable step at a time. Never big-bang.** Each step has a `verify`
  command; the step is not done until verify passes. Commit per step.
- **Behavior-preserving by default.** A refactor's diff must NOT change
  behavior — *unless the finding IS a behavior bug*, in which case the failing
  test that reproduces the bug is the point. State which mode each finding is
  in (refactor vs bugfix) in the spec.
- **Tests green before AND after.** If the suite is red at the start, you fix
  or quarantine that first (or stop and report) — you don't refactor on red.
- **If a finding can't be safely fixed in isolation, log it and move on.**
  Don't force a tangled change. Record it in the plan as `deferred` with why.
- **Evidence before assertion.** A finding is "closed" only when (a) its test
  is green and (b) re-running the relevant audit slice no longer flags it.

## Phase 0 — Resolve input (verify: a concrete finding list)

1. Input is either a specific finding/cluster (from the user) OR the latest
   audit report. If unspecified, read the newest
   `docs/superpowers/specs/<date>-strata-audit.md`.
2. Parse findings into a ranked work list. **Cluster** related findings (same
   file, same rule, same root cause) so one TDD cycle can close several.
3. Confirm the baseline suite is green: run the project's test command
   (`pytest -m "not slow"`, `npm test`, etc. — read `CLAUDE.md`/`README`).
   If red, stop and report — refactoring on a red suite is unsafe.

**Verify:** you can list the findings/clusters you will work, in order, and
the baseline test command exits 0.

## Phase 1 — Spec + plan per finding/cluster (verify: dated files exist)

For each finding (or cluster), write a DATED pair under `docs/superpowers/`:

1. **Design** → `docs/superpowers/specs/<YYYY-MM-DD>-<slug>-design.md`:
   - **Problem** — the finding, with its `file:line` + cited rule.
   - **Current state** — what the code does now (quote the smell).
   - **Target** — desired shape (cite the SAR pattern/§ it should match).
   - **Mode** — `behavior-preserving refactor` or `bugfix` (changes behavior).
   - **Risks** — blast radius, callers affected, why it's safe in isolation
     (or why it must be deferred).
2. **Plan** → `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`:
   ordered steps, **each step carries a `verify`** (the exact command/observable
   that proves the step). Use `superpowers:writing-plans` for structure.

Smallest safe unit: prefer many small clusters over one mega-refactor.

## Phase 2 — Execute via TDD, one step at a time

For each step, run the `superpowers:test-driven-development` loop:

1. **RED** — write a failing test that reproduces the smell or the desired
   invariant. For a behavior bug, the test reproduces the bug (currently
   fails). For a pure refactor, the test pins current behavior (the
   characterization test) so the refactor can't change it — it passes now and
   must keep passing.
2. **GREEN** — make the **minimal** change to satisfy the step. For structure
   findings, follow the SAR pattern named in the design (e.g. Strangler-Fig
   move of SQL into a repository method — migrate one call site, leave the old
   path until the last caller is gone).
3. **VERIFY** — run the step's `verify` command. Step is done only when it
   passes AND the full fast suite is still green (no regression). If a behavior
   bug is involved or the cause is murky, invoke
   `superpowers:systematic-debugging` before changing code.
4. **COMMIT** — one commit per step, message naming the finding + rule
   (`refactor(orders): move raw SQL to OrderRepository — SAR §15`). Never
   `--no-verify`.

Never batch multiple steps into one commit. Never skip the verify to "save
time" — a step claimed done without a green verify is not done.

## Phase 3 — Review, close, sync (verify: finding no longer flagged)

After a finding's steps are all green:

1. Run `superpowers:requesting-code-review` on the diff (or the council:
   `strata-eng-review`) — address feedback via
   `superpowers:receiving-code-review` (verify, don't perform agreement).
2. **If docs changed**, trigger `/strata:wiki-ingest` on the touched
   `docs/` files so `raw/` + `wiki/` stay in sync (knowledge self-heals with
   the code).
3. **Re-run the relevant audit slice** — invoke `/strata:audit` scoped to the
   touched files/category (or just re-run that check's grep/lint). A finding
   is **CLOSED** only when its test is green AND the audit no longer reports
   it. Record CLOSED / DEFERRED in the plan file with evidence (the green
   test name + the now-empty audit result).

## Phase 4 — Wrap up

- Update the plan file: each finding marked CLOSED (with proof) or DEFERRED
  (with reason — e.g. "can't fix in isolation; needs schema migration first").
- Use `superpowers:finishing-a-development-branch` to present merge/PR options.
- Print a chat summary: closed N, deferred M (with reasons), commits made,
  and any new findings surfaced during the work (feed back to `/strata:audit`).

**Verify (skill done only when all pass):**
- Every targeted finding is CLOSED (test green + audit clean) or explicitly
  DEFERRED with a logged reason.
- Fast test suite green at the end (run it, paste the exit/summary).
- Dated design + plan files exist for each cluster worked.
- If docs changed, `/strata:wiki-ingest` ran (or is noted as not needed).

If any verify cannot run in this environment (no test runner, no audit
script, can't reach a service), say so explicitly and do NOT claim the finding
closed. Evidence before assertions — always.
