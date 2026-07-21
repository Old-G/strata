# Strata v0.3 — Adaptive Ceremony Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/strata:feature` auto-classify each task (trivial/standard/risky) and run only the ceremony that fits — with a non-negotiable safety floor — and give Strata its own small, lean process spine so Superpowers becomes optional.

**Architecture:** A new Phase-0 triage rubric drives a tier→phase table in a rewritten `feature` skill. Three new lean skills (`lean-plan`, `adaptive-verify`, `light-finish`) own the plan/build-verify/finish phases natively; office-hours + council + wiki + audit were already native. Superpowers is demoted to an optional accelerator. No new runtime/config — thin glue over native Claude Code primitives.

**Tech Stack:** Claude Code plugin — Markdown skills + `sections/` subfiles; `scripts/validate.sh` (bash + python3) is the structural check.

**Spec:** [docs/superpowers/specs/2026-07-21-adaptive-ceremony-design.md](../specs/2026-07-21-adaptive-ceremony-design.md)

**Note on verification:** these are Markdown skills, not code — so per-task verification is `bash scripts/validate.sh` (structure/frontmatter) + grep anchors for required content. The **behavioral** acceptance (does trivial skip council? does a risk surface escalate? is token use lower?) cannot be checked by `validate.sh`; it is a manual dogfood run in Task 8. Do not claim behavioral acceptance from `validate.sh` alone.

---

## File structure

| File | New/Mod | Responsibility |
|---|---|---|
| `skills/feature/sections/triage.md` | new | The classifier rubric: signals → tier, risk surfaces, escalation, output format |
| `skills/lean-plan/SKILL.md` | new | Intent-first, tier-aware plan (no inlined code / dictated libs) |
| `skills/adaptive-verify/SKILL.md` | new | Verification cadence dial by tier (smoke / core+batch / per-step+full) |
| `skills/light-finish/SKILL.md` | new | Lean branch integration (verify → merge/PR/keep/discard → cleanup) |
| `skills/feature/SKILL.md` | rewrite | Phase-0 triage + floor + tier→phase table + delegation |
| `BOOTSTRAP.md` | mod | Demote Superpowers: strongly-recommended → optional power-up |
| `skills/onboard/SKILL.md` | mod | Same demotion in the Step-3 prereq table |
| `skills/using-strata/SKILL.md` | mod | Note adaptive-ceremony in the routing description |
| `README.md` | mod | Adaptive-ceremony positioning; "own lean process engine, not a wrapper" |
| `CLAUDE.md` | mod | Phase table row + state line |
| `CONTRIBUTING.md` | mod | Attribution: lean skills adapt Superpowers/gstack ideas (no vendored code) |
| `CHANGELOG.md` | mod | `[0.3.0]` entry |
| `.claude-plugin/plugin.json` + `marketplace.json` | mod | Bump to `0.3.0` |

Order matters: the new skills (Tasks 1–4) must exist before the `feature` rewrite (Task 5) references them.

---

## Task 1: Triage rubric

**Files:**
- Create: `skills/feature/sections/triage.md`

- [ ] **Step 1: Create the rubric**

Create `skills/feature/sections/triage.md`:

```markdown
# Triage rubric — classify a feature request into a tier

Used by `/strata:feature` Phase 0. Emit ONE tier + a one-line reason + what will be skipped. **Bias UP when in doubt.**

## Tiers

- **trivial** — ~1–2 files, no new dependency, no risk surface, no architectural change, the ask is unambiguous.
- **standard** — several files, maybe one new dependency, real logic, bounded, no high-risk surface.
- **risky** — many files or a new subsystem; a significant new external dependency; ANY risk surface; an architectural shift; or an ambiguous ask.

## Risk surfaces → force at least `risky` (auto-escalation, non-negotiable)

Authentication / authorization · secrets / credentials / tokens · PII or personal data · money / payments / billing · external or untrusted input (network, uploads, user-supplied) · data migrations / schema changes / destructive DB ops · public API or a published contract · concurrency / locking · anything the user calls security-sensitive.

If any is touched, the tier is `risky` even if the change looks tiny.

## Signals to read (cheap — do NOT over-analyze)

Scope of files/diff · new dependencies · presence of a risk-surface keyword above · rough size · whether the ask is clear enough to name a one-line success criterion.

## Ambiguity rule

If you cannot state a one-line success criterion from the ask, treat it as at least `standard` (which runs office-hours to clarify).

## Output format

> **Tier: <trivial|standard|risky>** — <one-line why>. Skipping: <phases skipped>. Say "go higher / lower" to override.

Then proceed without waiting for confirmation, unless the user overrides.
```

- [ ] **Step 2: Verify**

Run: `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and
`grep -q 'Risk surfaces' skills/feature/sections/triage.md && grep -q 'Bias UP' skills/feature/sections/triage.md && grep -q 'Output format' skills/feature/sections/triage.md && echo ANCHORS`
Expected: `OK` and `ANCHORS`. (validate.sh globs `skills/*/SKILL.md`, so a `sections/` file doesn't need frontmatter.)

- [ ] **Step 3: Commit**

```bash
git add skills/feature/sections/triage.md
git commit -m "feat(feature): add triage rubric (tier classifier)"
```
End the commit body with a blank line then: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## Task 2: `lean-plan` skill

**Files:**
- Create: `skills/lean-plan/SKILL.md`

- [ ] **Step 1: Create the skill**

Create `skills/lean-plan/SKILL.md`:

```markdown
---
name: lean-plan
description: Use when /strata:feature needs a plan for a standard or risky task, or when the user asks for a lean implementation plan. Produces an intent-first plan — goal, constraints, and a per-step verify — WITHOUT inlined code or dictated libraries, so a capable model picks the implementation.
---

# lean-plan — an intent-first, tier-aware plan

Produce the smallest plan that still makes the work verifiable. **Never inline code. Never dictate libraries or frameworks** — state intent and constraints; the implementing model chooses how. Keep the whole plan short enough to hold in context.

## By tier

- **trivial** — no written plan; hold a 1–3 step list inline and go.
- **standard** — a short bullet plan (3–8 steps). Each step: what changes + a concrete `verify` (a command or observable). No code.
- **risky** — a dated plan file at `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`, still lean: **Goal · Constraints** (stack / ADRs / data / security) **· Steps** (each with a verify) **· Success criteria.** Intent, not code.

## Every step names a verify

A step isn't done until its verify passes (evidence before assertion). If a step has no observable verify, it's too vague — split or sharpen it.

## Hand off

Return the plan (or its path) to `/strata:feature`, which drives the build via `adaptive-verify`.
```

- [ ] **Step 2: Verify**

Run: `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and
`grep -q 'name: lean-plan' skills/lean-plan/SKILL.md && grep -q 'Never inline code' skills/lean-plan/SKILL.md && echo ANCHORS`
Expected: `OK` (validate lists `✓ skills/lean-plan/SKILL.md`) and `ANCHORS`.

- [ ] **Step 3: Commit**

```bash
git add skills/lean-plan/SKILL.md
git commit -m "feat: add lean-plan skill (intent-first, no code dumps)"
```
(Same Co-Authored-By trailer as Task 1.)

---

## Task 3: `adaptive-verify` skill

**Files:**
- Create: `skills/adaptive-verify/SKILL.md`

- [ ] **Step 1: Create the skill**

Create `skills/adaptive-verify/SKILL.md`:

```markdown
---
name: adaptive-verify
description: Use when /strata:feature builds and checks a change and you need the right amount of testing/review for the task's tier, or when the user asks to verify work without over-testing. Sets the verification cadence — smoke for trivial, test-core + one batched review for standard, test-first per step + full review for risky. Owns HOW testing/review is applied, not the test runner.
---

# adaptive-verify — verification cadence as a dial, not a dogma

Apply the least verification that still makes the change trustworthy, scaled to tier. This is the answer to "tests + review after every trivial step burns tokens."

## Cadence by tier

- **trivial** — implement directly, then ONE smoke / observable that it works. Self-review the diff.
- **standard** — test the CORE logic (not every line); implement; then ONE batched review of the whole diff, focused on risky spots.
- **risky** — test-first per step (red → green → refactor); full code review (via the council, or `superpowers:requesting-code-review` if installed); resolve findings with evidence.

## Always (the floor, every tier)

- At least one real verify that the change works — never claim done on faith.
- When you test, assert behavior, not mocks.
- Batch, don't babysit: never run a full test+review cycle after every micro-edit on trivial/standard work.

## Testing uses the project's own runner

Detect and use the repo's test command (`pytest` / `npm test` / `go test` / …). This skill owns cadence, not the runner.
```

- [ ] **Step 2: Verify**

Run: `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and
`grep -q 'name: adaptive-verify' skills/adaptive-verify/SKILL.md && grep -q "don't babysit" skills/adaptive-verify/SKILL.md && echo ANCHORS`
Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit**

```bash
git add skills/adaptive-verify/SKILL.md
git commit -m "feat: add adaptive-verify skill (tiered test/review cadence)"
```

---

## Task 4: `light-finish` skill

**Files:**
- Create: `skills/light-finish/SKILL.md`

- [ ] **Step 1: Create the skill**

Create `skills/light-finish/SKILL.md`:

```markdown
---
name: light-finish
description: Use when a /strata:feature change is implemented and verified and needs integrating, or when the user asks to wrap up a branch. Confirms tests are green, then offers merge / PR / keep / discard, does the chosen one, and cleans up. A lean take on finishing a development branch.
---

# light-finish — integrate the work, minimally

## Steps

1. **Verify green.** Run the project's test/verify command; if it fails, STOP and report — do not integrate broken work.
2. **Offer the choice** (one question): merge to base locally · push + open PR · keep the branch · discard.
3. **Execute the choice.** Respect git safety: never a silent write to the default branch; keep commits reversible; on the default branch, branch first.
4. **Clean up** the branch when the user chose merge or discard.

Do not gold-plate: no changelog/version ceremony here unless the project's release rule requires it (see `CONTRIBUTING.md`).
```

- [ ] **Step 2: Verify**

Run: `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and
`grep -q 'name: light-finish' skills/light-finish/SKILL.md && grep -q 'Verify green' skills/light-finish/SKILL.md && echo ANCHORS`
Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit**

```bash
git add skills/light-finish/SKILL.md
git commit -m "feat: add light-finish skill (lean branch integration)"
```

---

## Task 5: Rewrite `feature` around adaptive ceremony

**Files:**
- Modify (full rewrite of body): `skills/feature/SKILL.md`

- [ ] **Step 1: Replace the file contents**

Overwrite `skills/feature/SKILL.md` with exactly:

```markdown
---
name: feature
description: Use when someone wants to build a feature/change end-to-end and wants the process scaled to the task — says "build X", "ship X properly", "run the flow", or has a design doc to take to a merged change. Auto-classifies the task (trivial/standard/risky) and runs only the ceremony that fits, with a non-negotiable safety floor.
---

# Feature — adaptive-ceremony feature flow

Strata's PROCESS spine. It scales the flow to the task: trivial work goes fast, risky work gets the full treatment — and the framework decides, not the human. This flow is **native** (office-hours, lean-plan, council, adaptive-verify, light-finish, wiki-ingest, audit); Superpowers is an optional accelerator, never required.

## Phase 0 — Triage (always)

Classify the request using `${CLAUDE_PLUGIN_ROOT}/skills/feature/sections/triage.md`. Emit **tier + one-line why + what you'll skip**, then proceed (no gate). The user may say "go higher / lower" anytime and you re-scale. Bias UP on doubt.

## The floor — ALWAYS, every tier (non-negotiable)

1. **Verify** — every change gets a real observable/test that it works (scaled by tier via `adaptive-verify`). Never claim done on faith.
2. **Risk auto-escalation** — if the work touches a risk surface (see triage), the tier is `risky`, however small it looks.
3. **Drift-close** — if docs or a documented fact changed, run `/strata:wiki-ingest` on them; otherwise no-op.
4. **Git safety** — work on a branch; reversible commits; never a silent write to the default branch.

## Tier → phases

Run the phases marked for the tier; skip the rest. Each phase's verify must pass before advancing.

| Phase | trivial | standard | risky |
|---|---|---|---|
| Think | skip (restate the ask in 1 line) | light: confirm intent + a success criterion | full `/strata:office-hours` (design doc) |
| Plan | skip (inline steps) | `lean-plan` (short) | `lean-plan` (dated, still lean) |
| Review plan (council) | skip | `eng` (+ `cso` if any risk touch) | `/strata:autoplan` — full panel |
| Build + verify | `adaptive-verify` (trivial cadence) | `adaptive-verify` (standard) | `adaptive-verify` (risky) |
| Finish | `light-finish` | `light-finish` | `light-finish` + an explicit gate |
| Drift-close | floor #3 | `/strata:wiki-ingest` + scoped mini-`/strata:audit` | full `/strata:wiki-ingest` + mini-audit |

## Delegation

- Think → `/strata:office-hours` · Plan → `lean-plan` · Review plan → `/strata:autoplan` (or spawn the `strata-*-review` council agents in parallel) · Build & verify → `adaptive-verify` · Finish → `light-finish` · Knowledge → `/strata:wiki-ingest` + `/strata:audit`.
- **Superpowers (optional):** if `superpowers:*` skills are installed, you MAY use `writing-plans` / `test-driven-development` / `requesting-code-review` as accelerators on `risky` work. If absent (the default), the native skills above are the full path — nothing degrades.

## Never

Skip the floor. Auto-decide a risk-surface task as trivial. Batch past a phase's verify. Claim a phase done without its verify passing.
```

- [ ] **Step 2: Verify**

Run:
```bash
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q 'Phase 0 — Triage' skills/feature/SKILL.md \
&& grep -q 'The floor' skills/feature/SKILL.md \
&& grep -q 'Tier → phases' skills/feature/SKILL.md \
&& grep -q 'lean-plan' skills/feature/SKILL.md \
&& grep -q 'adaptive-verify' skills/feature/SKILL.md \
&& grep -q 'light-finish' skills/feature/SKILL.md \
&& grep -q 'Superpowers (optional)' skills/feature/SKILL.md \
&& echo ANCHORS
```
Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "feat(feature): rewrite around adaptive ceremony (triage + tiers + floor)"
```

---

## Task 6: Demote Superpowers in onboarding

**Files:**
- Modify: `BOOTSTRAP.md` (Step 1 Superpowers bullet)
- Modify: `skills/onboard/SKILL.md` (Step 3 Superpowers row)

- [ ] **Step 1: BOOTSTRAP.md** — Read it, then replace the Superpowers bullet in "Step 1 — Prerequisite scan". Find the bullet starting `- **Superpowers** — *strongly recommended*.` and replace that whole bullet with:

```markdown
- **Superpowers** — *optional power-up*. Are `superpowers:*` skills available? Strata's feature flow is now native and complete without it; if installed, it can add heavier discipline (plan/TDD/review) on `risky` work for teams that want it. Not required — do not push installing it.
```

- [ ] **Step 2: onboard Step 3** — Read `skills/onboard/SKILL.md`, then in the prerequisite table replace the Superpowers row (`| **Superpowers** — strongly recommended | … |`) with:

```markdown
| **Superpowers** — optional power-up | are `superpowers:*` skills available? | `/plugin install superpowers@claude-plugins-official` (only if the team wants heavier discipline) | Strata's feature flow is native and complete without it; if installed, it can add extra plan/TDD/review rigor on `risky` work. Not required. |
```

Also, in the sentence after that table, change "Recommend installing Superpowers before `/strata:feature`" to "Superpowers is optional — the native flow needs nothing installed".

- [ ] **Step 3: Verify**

Run:
```bash
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q 'optional power-up' BOOTSTRAP.md && grep -q 'optional power-up' skills/onboard/SKILL.md && echo ANCHORS
grep -c 'strongly recommend' BOOTSTRAP.md skills/onboard/SKILL.md
```
Expected: `OK`, `ANCHORS`, and the `strongly recommend` count is `0` in both files.

- [ ] **Step 4: Commit**

```bash
git add BOOTSTRAP.md skills/onboard/SKILL.md
git commit -m "feat(onboarding): demote Superpowers to optional power-up"
```

---

## Task 7: Docs, attribution, and version bump to 0.3.0

**Files:**
- Modify: `skills/using-strata/SKILL.md`, `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: using-strata** — Read it; in the `/strata:feature` row of the skills table, replace its "What it does" cell text with: `Adaptive-ceremony feature flow — auto-scales process to the task (trivial/standard/risky) with a safety floor`.

- [ ] **Step 2: README** — Read it; in the Commands table row for `/strata:feature`, replace its Purpose cell with: `Adaptive feature flow: triage → (office-hours) → lean plan → council → tiered TDD/review → finish → wiki+audit`. Then in "The four layers" Process row, change its "Owns" cell to mention "scaled to the task (adaptive ceremony)".

- [ ] **Step 3: CLAUDE.md** — Read it; add this row to the Phase/status table (after the onboarding row):
```markdown
| Adaptive ceremony in /strata:feature (triage + tiers + owned lean spine) | 🔄 building |
```
Confirm the file stays ≤ 200 lines.

- [ ] **Step 4: CONTRIBUTING** — Read it; in the "Attribution" section, add a sentence: `The lean process skills (lean-plan, adaptive-verify, light-finish) adapt *ideas* from Superpowers and gstack — no vendored code.`

- [ ] **Step 5: CHANGELOG** — Read it; insert a new section directly under `## [Unreleased]`:
```markdown
## [0.3.0] — 2026-07-21

### Changed
- **`/strata:feature` is now adaptive-ceremony.** A Phase-0 triage classifies each task
  (trivial / standard / risky) and runs only the ceremony that fits, behind a non-negotiable floor
  (verify · risk auto-escalation · drift-close · git safety). Answers "full pipeline burns tokens on
  trivial work."
- **Strata owns a lean process spine.** New `lean-plan` (intent-first, no code dumps),
  `adaptive-verify` (tiered test/review cadence), and `light-finish` (lean branch integration) skills.
  **Superpowers is now an optional power-up, not a prerequisite** — the flow is native and complete
  without it; installed, it can add heavier discipline on `risky` work. (Reverses the 0.2.1 push.)
```

- [ ] **Step 6: Version bump** — Read `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`; change `"version": "0.2.2"` to `"version": "0.3.0"` in both.

- [ ] **Step 7: Verify**

Run:
```bash
grep '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
awk 'END{print "CLAUDE.md lines:", NR}' CLAUDE.md
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q '0.3.0' CHANGELOG.md && grep -q 'adapt' CONTRIBUTING.md && echo DOCS
```
Expected: both versions `0.3.0`; CLAUDE.md ≤ 200; `OK`; `DOCS`.

- [ ] **Step 8: Commit**

```bash
git add skills/using-strata/SKILL.md README.md CLAUDE.md CONTRIBUTING.md CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "release: 0.3.0 — adaptive ceremony + owned lean process spine"
```

---

## Task 8: Behavioral dogfood (manual acceptance — not automatable)

**Files:** none (verification only). This is the real acceptance test (spec §10); `validate.sh` cannot check behavior.

- [ ] **Step 1: Automated suite**

Run: `bash scripts/validate.sh` — expect `✅ Strata plugin validation PASSED`. Paste the tail.

- [ ] **Step 2: Manual behavioral runs (record observed outcome for each)**

In a session with the 0.3.0 plugin loaded, run `/strata:feature` on three representative asks and confirm:
1. **trivial** (e.g. "rename a label in one file") → triage says `trivial`, skips council + full TDD, but still does a verify and lands on a branch (reversible).
2. **risk-surface** (e.g. "tweak the login token check") → triage **auto-escalates to `risky`** despite being small; full flow runs.
3. **standard** (e.g. "add a CSV export to an existing report") → light `lean-plan` + one batched review, **not** per-step review.
4. **override** → say "go higher" on a trivial task; confirm it re-scales.
5. **token check** → note that the trivial run used far fewer tokens / subagent calls than a full flow would.

Record the observed result of each in the spec's §10 (or a short note) — do not claim acceptance without it. If any misbehaves, loop back to the relevant task.

- [ ] **Step 3: Commit any spec note**

```bash
git add docs/superpowers/specs/2026-07-21-adaptive-ceremony-design.md
git commit -m "docs: record v0.3 behavioral acceptance results"
```

---

## Self-review (plan author)

**Spec coverage:** §2 ownership (L2) → Tasks 2/3/4 (owned skills) + Task 6 (demotion). §3 tiers + §4 triage → Task 1 + Task 5. §5 floor → Task 5 (floor block). §6 tier→phase table → Task 5. §7 lean plan → Task 2. §8 own-spine + Superpowers optional → Tasks 2/3/4/5/6. §9 components → Tasks 5/6/7 (+ new skills 1–4). §10 verify → Task 8 (manual) + per-task validate. §11 out-of-scope (no config, no fork) → respected (no config file; skills adapt ideas only). §12 risks → mitigated in triage.md (bias up, risk surfaces) + floor in Task 5. No gaps.

**Placeholder scan:** none — every new/edited file has its full content or an exact find-and-replace target. The only "fill at runtime" is the triage OUTPUT the AI emits per task, which is by design (it's a template, documented).

**Name consistency:** skill names `lean-plan` / `adaptive-verify` / `light-finish` are spelled identically in their frontmatter, the `feature` delegation table, CHANGELOG, and CONTRIBUTING. `triage.md` path (`skills/feature/sections/triage.md`) matches the `${CLAUDE_PLUGIN_ROOT}` reference in the `feature` rewrite. Version `0.3.0` consistent across both manifests + CHANGELOG.
