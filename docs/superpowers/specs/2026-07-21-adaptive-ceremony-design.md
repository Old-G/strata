# Design — Adaptive ceremony for `/strata:feature` (Strata v0.3)

**Date:** 2026-07-21
**Status:** DRAFT — approved in brainstorm; pending spec review → plan
**Topic:** Make Strata's feature flow scale its process to the size and risk of the task, so trivial work is fast and cheap while risky work still gets full guardrails — automatically, without the human having to choose.

---

## 1. Problem & the bet

Heavy, fixed-ceremony workflows (Superpowers and peers) apply the same full pipeline — spec → plan → per-step TDD → per-step review — to every task. On frontier models this is widely seen as over-engineered and token-hungry for small work ("pay like a Ferrari, drive like a Lada"); even Superpowers' own author pivoted to a lighter v6 (~60% cheaper, review loops removed after "no measurable quality gain"). The opposite pole (raw vibe-coding, disposable-plan loops) is cheap but has no guardrails.

**The market gap (validated by research):** nobody **auto-calibrates** ceremony to the task. Every tool makes the *human* decide when to go light vs full. And the landscape splits into "simple but no guarantees" vs "high-quality but heavy/expert-only" — with little in between.

**Strata's bet:** own the empty middle — *an adaptive-ceremony framework that is simple enough for a non-expert ("vibe coder") but keeps senior-grade guardrails*, built as thin glue over native Claude Code primitives plus Strata's wiki / architecture-canon / review-council spine.

**Acceptance (one sentence):** a trivial change runs end-to-end without council or per-step TDD yet is still verified, safe, and reversible; a task touching a risk surface gets the full flow **even if it looks small** — and the framework, not the human, made that call.

---

## 2. Decisions locked (from brainstorm, 2026-07-21)

| Decision | Choice |
|---|---|
| Scope | All-in, unified around **adaptive ceremony** (also covers lean intent-spec/plan + Superpowers decoupling as consequences) |
| Who decides the tier | **Auto-classify + transparent override** — AI classifies, shows tier + why + what it'll skip, proceeds without a gate; human can bump up/down anytime |
| Non-negotiable floor | All four, calibrated (see §5) |
| Architecture | **Single tiered `/strata:feature`** — a Phase 0 triage + a tier→phase table; no separate config file (YAGNI) |
| Tiers | 3 — `trivial` / `standard` / `risky` |
| Process-layer ownership | **L2 — Strata owns a small, first-class, lean process spine** (lean-plan · adaptive-verify · light-finish), tuned for tiers + frontier models. Superpowers is demoted from a recommended prerequisite to an **optional power-up**. Adapt the *ideas* (MIT + attribution), never fork the code. |
| Version | 0.3.0 (minor — significant feature) |

---

## 3. Tiers

- **trivial** — small, well-understood change: ~1–2 files, no new dependencies, no risk surface, no architectural change, unambiguous ask.
- **standard** — a normal feature/change: several files, maybe one new dependency, real logic, but bounded and no high-risk surface.
- **risky** — large / novel / dangerous: many files or a new subsystem, a significant new external dependency, a **risk surface** (auth, secrets, PII, money, external/untrusted input, data migration, public API), an architectural shift, or ambiguous requirements.

## 4. Phase 0 — Triage (new; always runs)

The classifier reads signals — files/diff scope, new dependencies, risk-surface keywords, rough size, and clarity of the request — and emits: **tier + one-line rationale + what it will skip.** It then proceeds (no confirmation gate). The human can say "go higher / lower" at any point and the flow re-scales.

- **Auto-escalation (floor #2):** any risk-surface hit forces at least `risky`, regardless of apparent size.
- **Ambiguity → up:** if the ask isn't clear enough to name a success criterion, bump toward `standard`/`risky` (which run office-hours).
- The rubric (signals → tier) lives in `skills/feature/sections/triage.md` so `SKILL.md` stays focused.

## 5. The floor (always, calibrated by tier)

1. **Verify per change** — always; scales: `trivial` = a quick smoke/observable, `risky` = full tests. Core "evidence before assertion."
2. **Risk-surface auto-escalation** — always, flat; makes auto-classification safe (can't under-shoot a dangerous task).
3. **Drift-close (wiki/docs)** — always *checked*; acts only if docs or a documented fact were touched (a no-op on pure trivial code).
4. **Git safety** — always, flat: work on a branch, reversible commits, never a silent write to the default branch.

Net: even `trivial` guarantees it works (verify), can't be silently dangerous (escalation), can't silently rot docs, and is reversible. That is the "senior guardrails at vibe-coder UX" promise.

## 6. Tier → phase mapping (the core)

| Phase | trivial | standard | risky |
|---|---|---|---|
| 1 Think (office-hours) | skip — restate the ask in one line | light: confirm intent + a success criterion (no full 6-question interrogation) | full `/strata:office-hours` → design doc (or require an existing one) |
| 2 Plan | skip — hold the step-list inline | short plan: bullet steps, each with a `verify`; **no inlined code** | full dated plan — intent + constraints + per-step verifies, **not** code dumps |
| 3 Council | skip | scaled: one pass — `eng` (+ `cso` if any risk touch); surface disagreements | full panel — `ceo`/`eng`/`cso` (+ `design` if the stack has a frontend) |
| 4 Build | direct implement + smoke verify | test-first on the core logic (not every line) | full per-step TDD |
| 5 Code review | self-review + the floor verify | **batched review of the whole diff once**, focused on risky spots | full code review; resolve findings with evidence |
| 6 Finish | commit on a branch | branch + merge/PR per the human's choice | + an explicit integration gate |
| 7 Drift-close | no-op unless docs touched | `wiki-ingest` changed docs + a scoped mini-audit | full `wiki-ingest` + mini-audit |

**Verification cadence (the dial):** `trivial` = one smoke at the end; `standard` = test the core + one review of the whole diff; `risky` = verify per step + full review. This is the direct answer to "tests + review after every trivial step."

## 7. Lean, intent-first spec & plan

Even at `risky`, the plan carries **intent + constraints + per-step verifies — not inlined code and not a dictated library/framework choice.** The model chooses the implementation. This answers both "overengineering on the spec" and "the plan bloats past what the model can hold in context." office-hours runs only for `risky`/ambiguous; `trivial`/`standard` skip or lightly touch it.

## 8. Own the process spine; Superpowers becomes an optional power-up (L2)

Our adaptive-lean bet is philosophically **opposite** to Superpowers' heavy, per-step, code-in-the-plan style — so *wrapping* it on `risky` pulls us back toward the paradigm we're escaping. Strata therefore **owns its own small, first-class, lean process spine**, tuned for the tiers and for frontier models. We already own the highest-value pieces (office-hours > brainstorming; the council > code-review); this closes the loop by owning the remaining three as lean, native skills:

- **`lean-plan`** — produce the tier-appropriate plan: intent + constraints + per-step `verify`, **no inlined code, no dictated libraries** (this is §7, made a first-class owned capability instead of `superpowers:writing-plans`).
- **`adaptive-verify`** (TDD-lite) — apply the §6 verification cadence: `trivial` = one smoke; `standard` = test the core + one batched diff review; `risky` = test-first per step + full review. Owns "how testing/review is used," not the test runner.
- **`light-finish`** — verify green → merge/PR/keep/discard per the human's choice → clean up the branch (a lean take on finishing-a-development-branch).

**Superpowers is now optional, not a prerequisite.** When installed, its skills MAY be used as accelerators on `risky` work for teams that want the heavier discipline; when absent (the common case), the native spine is the default and full path — nothing degrades. This reverses the 0.2.1 messaging that pushed installing Superpowers: v0.3 stops recommending it as needed (§9 updates onboarding/README accordingly).

**Guardrails on this decision (so it stays "thin glue," not a fork):**
- We adapt the *patterns* (red-green discipline, plan rigor, review) into new lean skills; we do **not** copy or vendor Superpowers' code. Superpowers is MIT — attribute the adapted ideas, as we already do for gstack.
- The owned surface stays **small**: exactly the three skills above. We do NOT rebuild Superpowers' breadth.
- The hard rule "don't reimplement memory / token-proxying / testing" still holds — that's about claude-mem, RTK, and test *runners*, not about owning our own process orchestration. We keep composing claude-mem, RTK, and native Claude Code subagents/skills/plan-mode.
- "Higher effort / better result" comes from the adaptive *design* (right verification cadence, the floor, letting frontier models self-direct), not from ownership per se. Ownership buys us the control to tune it.

## 9. Components / where it lives

- **Rewrite** `skills/feature/SKILL.md` around Phase 0 triage + the tier→phase table. Keep it focused; push the classifier rubric to `skills/feature/sections/triage.md`.
- **New owned process-spine skills (§8):** `skills/lean-plan/SKILL.md`, `skills/adaptive-verify/SKILL.md`, `skills/light-finish/SKILL.md` — small, lean, tier-aware. `feature` delegates to these instead of to `superpowers:*`. Each stays focused; heavy detail (if any) goes to a `sections/` subfile.
- office-hours / autoplan / council remain their own skills, invoked **conditionally by tier** (not always).
- **Demote Superpowers in onboarding:** update `BOOTSTRAP.md` Step 1 + `skills/onboard/SKILL.md` Step 3 so Superpowers moves from "strongly recommended" to "optional power-up (heavier discipline for teams that want it)"; the native spine needs nothing installed. (Reverses the 0.2.1 push.)
- Update `skills/using-strata/SKILL.md` (routing note), `README.md` (adaptive-ceremony positioning + "own lean process engine, not a wrapper"), `CLAUDE.md` (phase table), `CHANGELOG.md` → `[0.3.0]`, and bump `plugin.json` + `marketplace.json` to `0.3.0`.
- **Attribution:** note in `CONTRIBUTING.md`/`README` credits that the lean process skills adapt *ideas* from Superpowers (MIT) and gstack — no vendored code.
- No new config file, no new runtime — thin glue over native primitives (validated by research: bespoke machinery loses). The owned surface is deliberately just the three lean skills.

## 10. Verify (acceptance for the redesign)

1. A `trivial` task completes without council/full-TDD but still runs a verify and lands on a branch (reversible).
2. A small task that touches a risk surface (e.g. auth or secrets) **auto-escalates to `risky`** and gets the full flow.
3. A `standard` task gets a light plan + one batched review — **not** per-step review.
4. Token usage on a `trivial` task is dramatically lower than the full flow (measure a before/after on one representative task).
5. Override works: the human can force a tier up or down and the flow re-scales.
6. With Superpowers absent (the default case), all tiers complete fully on the native spine; with it installed, `risky` MAY use it as an accelerator — nothing is blocked or degraded either way.

## 11. Out of scope (YAGNI)

- A tunable tiers **config file** (rejected — single skill for v0.3).
- Extracting a reusable `strata:triage` skill (possible later once the classifier settles; inline for now).
- Re-tiering `init`/`adopt`/`audit`/`refactor` — this spec is `/strata:feature` only (other commands can adopt triage later).
- Auto-installing Superpowers (now optional; onboarding just mentions it).
- **Forking or vendoring Superpowers' code** — explicitly rejected. We adapt *ideas* into three small lean skills; we do not copy its source or rebuild its breadth. The owned process surface is exactly `lean-plan` + `adaptive-verify` + `light-finish`.

## 12. Risks

- **R1 — misclassification.** A `risky` task read as `trivial` skips guardrails. Mitigation: the floor (esp. auto-escalation) + transparent tier display so the human catches an obvious mis-call + easy override. Bias the classifier to round **up** on doubt.
- **R2 — "trivial" erodes into vibe-coding.** Mitigation: the floor is non-negotiable at every tier; `trivial` still verifies + is reversible.
- **R3 — classifier adds its own overhead/tokens.** Keep Phase 0 cheap: a short rubric, a few signals, one short output — not a mini-analysis.
