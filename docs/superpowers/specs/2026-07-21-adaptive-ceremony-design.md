# Design — Adaptive ceremony for `/strata:feature` (Strata v0.3)

**Date:** 2026-07-21 (revised same day after the Claude-5 / Opus-5 guidance review)
**Status:** DRAFT — approved in brainstorm; pending spec review → plan
**Topic:** Scale the feature flow to the size and risk of the task — automatically — so trivial work is fast and cheap while risky work still gets real guardrails. Built for frontier models: **less scaffolding, not more.**

---

## 1. Problem & the bet

Fixed-ceremony workflows (Superpowers and peers) run the same pipeline — spec → plan → per-step TDD → per-step review — on every task. On frontier models that is over-engineered and token-hungry for small work; Superpowers' own author shipped a lighter v6 (~60% cheaper) after finding review loops gave "no measurable quality gain." The opposite pole (vibe-coding, disposable-plan loops) is cheap but unguarded.

**The market gap (validated by research):** nobody **auto-calibrates** ceremony to the task — every tool makes the *human* choose. And the field splits into "simple but no guarantees" vs "high-quality but heavy/expert-only," with little in between.

**Strata's bet:** own the empty middle — *adaptive ceremony: simple enough for a non-expert, with senior-grade guardrails* — as thin glue over native Claude Code primitives plus Strata's wiki / canon / council spine.

**Acceptance:** a trivial change runs end-to-end without council or plan ceremony, yet still produces evidence it works and stays reversible; a task touching a risk surface gets the full treatment **even if it looks small** — and the framework, not the human, made the call.

---

## 2. Guiding constraint — build for frontier models

This release follows Anthropic's current guidance (Claude-5 context engineering + the Opus 5 prompting guide). It is the reason v0.3 **removes** machinery rather than adding it:

- **Don't over-constrain.** Anthropic removed >80% of Claude Code's system prompt "with no measurable loss." State intent; let the model judge.
- **Don't instruct self-verification.** *"Claude Opus 5 verifies its own work without being told to. If your prompt contains explicit verification instructions … remove them: instructions like these cause over-verification … and removing them reduces wasted tokens with no loss in quality. The same applies to legacy harness scaffolding that adds separate verification steps."*
- **Don't use subagents to double-check your own work.** Delegate only for "large tasks that are genuinely independent and parallelizable."
- **Effort is the primary cost lever.** `low`/`medium` give strong quality at a fraction of the tokens; step up for demanding work.
- **Complete spec up front, then leave it alone.** Opus 5 "performs best when given the complete task specification up front and left to run."
- **Progressive disclosure, no repetition, design over examples.** Short `SKILL.md`; detail in `sections/` loaded only when relevant; each instruction in exactly one authoritative place.

**The distinction that reconciles our "evidence" rule with the above:** *telling the model to double-check itself* is banned scaffolding; *requiring real evidence* (run the test, show the output) is ground truth and stays. We ask for **proof, not reminders**.

---

## 3. Decisions locked

| Decision | Choice |
|---|---|
| Tiers | 3 — `trivial` / `standard` / `risky` |
| Who decides | **Auto-classify + transparent override** — AI shows tier + why + what it skips, proceeds without a gate; human can bump anytime |
| Floor | Evidence · risk auto-escalation · drift-close · git safety (§5) |
| Effort policy | Per tier — the main token lever (§6) |
| Council | **Risk-triggered, lens-selected** — not a fixed panel (§7) |
| Think phase | office-hours upgraded with grill-style questioning (§8) |
| Plan | Complete-but-lean, high-fidelity references, no invented code dumps (§9) |
| Owned skills | `lean-plan` + `light-finish`. **Verification is NOT a skill** — folded into `feature` as a short evidence-cadence block (avoids verification scaffolding) |
| Superpowers | Optional power-up, never required |
| Version | 0.3.0 |

---

## 4. Tiers & Phase 0 triage

**Tiers.** `trivial` — ~1–2 files, no new dependency, no risk surface, no architectural change, unambiguous. `standard` — several files, maybe one dependency, real but bounded logic. `risky` — many files / new subsystem, significant new dependency, **any risk surface**, architectural shift, or an ambiguous ask.

**Risk surfaces (force `risky`):** auth/authz · secrets/credentials · PII · money/billing · external or untrusted input · data migration / destructive DB ops · public API contract · concurrency · anything the user calls security-sensitive.

**Phase 0** reads cheap signals (file scope, new deps, risk keywords, size, clarity), emits **tier + one-line why + what's skipped**, and proceeds. Bias **up** on doubt. Rubric lives in `skills/feature/sections/triage.md` (progressive disclosure).

## 5. The floor — always, every tier

1. **Evidence** — the change is demonstrated to work by something real (the test/command run and its output), scaled by tier. Not "remember to verify" — *show the proof*.
2. **Risk auto-escalation** — a risk surface forces `risky`, however small the change looks.
3. **Drift-close** — if docs or a documented fact changed, `/strata:wiki-ingest` them; otherwise no-op.
4. **Git safety** — branch, reversible commits, never a silent write to the default branch.

## 6. Effort policy (the main token lever)

Per Anthropic, effort — not ceremony surgery — is the primary control on cost:

| Tier | Effort | Rationale |
|---|---|---|
| trivial | `low` | Strong quality at a fraction of tokens |
| standard | `medium` | Default working level |
| risky | `high` (→ `xhigh` for demanding agentic/coding work) | Where depth actually pays |

Prefer thinking enabled at low effort over disabling thinking.

## 7. Tier → phases

| Phase | trivial | standard | risky |
|---|---|---|---|
| Think | skip — restate the ask in one line | light grill: recommend-and-confirm intent + success criterion (§8) | `/strata:office-hours` — grill branches to convergence → design doc |
| Plan | skip | `lean-plan`, short | `lean-plan`, complete-but-lean (§9) |
| Council | none | none by default | **1–2 risk-matched lenses** (below) |
| Build | implement; produce evidence (floor #1) | implement; evidence on the core | implement; evidence per meaningful step |
| Finish | `light-finish` | `light-finish` | `light-finish` + explicit gate |
| Drift-close | floor #3 | wiki-ingest + scoped mini-audit | wiki-ingest + mini-audit |

**Council — risk-triggered, lens-selected.** Do not run a fixed panel, and do not use it to double-check ordinary work. On `risky`, pick the **1–2 lenses that match the actual risk**: security/PII → `strata-cso-review` · frontend/UX → `strata-design-review` · architecture/complexity → `strata-eng-review` · scope/"right problem" → `strata-ceo-review`. Full panel only when several risks genuinely coincide. Its value is **independent adversarial perspective on a risky surface** — something same-context self-review can't supply — not routine verification. When prompting a reviewer, ask it to **report everything and filter afterwards** (telling it "only high-severity" makes it literally report less).

## 8. Grill-style questioning (adapted from grill-me)

Folded into `/strata:office-hours` rather than shipped as a duplicate skill:

1. **Every question carries your recommended answer** — one question at a time, with a recommendation so a non-expert can confirm rather than invent. The decision stays the user's; wait for the answer.
2. **Grill to convergence, scaled by tier** — on `risky`, walk branch by branch until the possibility space collapses to one clearly-specified idea; on `standard`, a short recommend-and-confirm pass suffices. Determine yourself whatever you can; bring only genuine decisions.
3. **Do nothing until the user confirms**, and prefer one thin working slice first.

## 9. Plan: complete but lean, with high-fidelity references

Opus 5 works best "given the complete task specification up front and left to run" — so the goal is **complete, not minimal**, while staying free of noise:

- Carry **intent + constraints + the success criterion**; do not dictate libraries or paste invented implementation code.
- **Prefer high-fidelity references over prose** ("rich references over simple specs"): a failing test that defines the behavior, a pointer to real code to mirror, an acceptance rubric. **Point at real artifacts; don't invent fake ones.**
- Keep it short enough to hold in context.

## 10. Superpowers

Native paths are the default and complete at every tier. If `superpowers:*` is installed it MAY be used as an accelerator on `risky` work; absent (the common case), nothing degrades. Not a prerequisite — onboarding stops pushing it.

## 11. Components

- **Rewrite** `skills/feature/SKILL.md`: Phase 0 triage → floor → effort policy → tier→phase table → delegation. Includes a short **evidence-cadence** block (replaces a separate verify skill).
- **New:** `skills/feature/sections/triage.md` (rubric), `skills/lean-plan/SKILL.md`, `skills/light-finish/SKILL.md`.
- **Upgrade** `skills/office-hours/SKILL.md` with §8 grill behavior.
- **Update** `skills/autoplan/SKILL.md` + the council agents' usage: lens selection, "report everything, filter after."
- **Demote Superpowers** in `BOOTSTRAP.md` Step 1 and `skills/onboard/SKILL.md` Step 3.
- **Docs:** `using-strata`, `README`, `CLAUDE.md`, `CONTRIBUTING` (attribution: ideas adapted from Superpowers/gstack/grill-me, no vendored code), `CHANGELOG` → `[0.3.0]`, bump both manifests to `0.3.0`.
- No new config, no new runtime.

## 12. Verify (acceptance)

1. `trivial` completes with no council and no plan ceremony, still produces evidence and lands on a branch.
2. A small risk-surface task **auto-escalates** to `risky`.
3. `standard` gets a light plan and **no council by default**.
4. On a `risky` security task, only the matching lens(es) run — not the full panel.
5. Override works (human moves the tier; flow re-scales).
6. Skills contain **no** "double-check / re-verify / add a verification step" scaffolding (grep) — only evidence requirements.
7. Trivial-task token use is dramatically below the old full flow.

## 13. Out of scope (YAGNI)

- A tiers config file · a reusable `strata:triage` skill · re-tiering `init`/`adopt`/`audit`/`refactor` · auto-installing Superpowers · **forking or vendoring Superpowers' code** (adapt ideas only) · a separate `grill` skill (would duplicate office-hours) · a separate verification skill (would be the scaffolding Anthropic says to remove).

## 14. Risks

- **R1 — misclassification.** Mitigation: floor + auto-escalation + visible tier + easy override; bias up on doubt.
- **R2 — `trivial` erodes into vibe-coding.** Mitigation: the floor holds at every tier (evidence + reversible).
- **R3 — triage costs its own tokens.** Keep Phase 0 cheap: few signals, short output.
- **R4 — under-guarding after cutting the council back.** Mitigation: risk surfaces are broad and force `risky` + a matched adversarial lens; the cut is to *routine* review, not to risky-surface review.
