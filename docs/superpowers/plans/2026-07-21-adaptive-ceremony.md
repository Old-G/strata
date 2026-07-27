# Strata v0.3 — Adaptive Ceremony Implementation Plan

> **For agentic workers:** implement task-by-task; each task ends in a commit. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/strata:feature` auto-classify each task (trivial/standard/risky) and run only the ceremony that fits — behind a floor of real evidence, risk escalation, drift-close and git safety — while *removing* scaffolding that frontier models no longer need.

**Architecture:** A Phase-0 triage rubric drives a tier→phase table in a rewritten `feature` skill, which also sets the per-tier effort level and an evidence cadence (no separate verification skill — Anthropic says that scaffolding causes over-verification). Two small owned skills (`lean-plan`, `light-finish`) replace the Superpowers-wrapped phases. The council becomes risk-triggered and lens-selected instead of a fixed 4-agent panel. `office-hours` gains grill-style questioning.

**Tech Stack:** Claude Code plugin — Markdown skills + `sections/` subfiles; `bash scripts/validate.sh` is the structural check.

**Spec:** [docs/superpowers/specs/2026-07-21-adaptive-ceremony-design.md](../specs/2026-07-21-adaptive-ceremony-design.md)

**Verification note:** these are Markdown skills, so per-task checks are `bash scripts/validate.sh` + grep anchors. The **behavioral** acceptance (does trivial skip the council? does a risk surface escalate? are tokens lower?) is a manual dogfood run in Task 9 — never claim it from `validate.sh`.

**Authoring rule for every file in this plan (dogfood §2 of the spec):** keep skills short, state intent instead of rigid rules, put detail in `sections/`, never repeat an instruction that lives elsewhere, and **never write "double-check / re-verify / add a verification step"** — ask for evidence instead.

---

## File structure

| File | New/Mod | Responsibility |
|---|---|---|
| `skills/feature/sections/triage.md` | new | Rubric: signals → tier, risk surfaces, escalation, output format |
| `skills/lean-plan/SKILL.md` | new | Complete-but-lean plan; high-fidelity references, no invented code |
| `skills/light-finish/SKILL.md` | new | Lean branch integration (green → merge/PR/keep/discard → cleanup) |
| `skills/feature/SKILL.md` | rewrite | Triage → floor → effort → tier→phase table → delegation → evidence cadence |
| `skills/office-hours/SKILL.md` | mod | Grill-style: a recommendation per question; converge on risky |
| `skills/autoplan/SKILL.md` | mod | Lens selection by risk; "report everything, filter after" |
| `BOOTSTRAP.md`, `skills/onboard/SKILL.md` | mod | Superpowers → optional power-up |
| `skills/using-strata/SKILL.md`, `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CHANGELOG.md` | mod | Docs + attribution |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | mod | Bump to `0.3.0` |

Tasks 1–3 must land before Task 4 (the `feature` rewrite references them).

---

## Task 1: Triage rubric

**Files:** Create `skills/feature/sections/triage.md`

- [ ] **Step 1: Create the file**

```markdown
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
```

- [ ] **Step 2: Verify** — Run `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and `grep -q 'Risk surfaces' skills/feature/sections/triage.md && grep -q 'Bias UP' skills/feature/sections/triage.md && echo ANCHORS`. Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit** — `git add skills/feature/sections/triage.md && git commit -m "feat(feature): add triage rubric (tier classifier)"` — end the body with a blank line then `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` (same trailer for every commit in this plan).

---

## Task 2: `lean-plan` skill

**Files:** Create `skills/lean-plan/SKILL.md`

- [ ] **Step 1: Create the file**

```markdown
---
name: lean-plan
description: Use when /strata:feature needs a plan for a standard or risky task, or when the user asks for a lean implementation plan. Produces a complete-but-lean plan — intent, constraints, success criterion — that points at high-fidelity references (a failing test, real code to mirror, a rubric) instead of pasting invented implementation code.
---

# lean-plan — complete, but free of noise

Frontier models do best with the **complete** task specification up front, then left to run. So aim for complete, not minimal — while cutting anything that isn't signal.

## What a plan carries

- **Intent** — what should be true when this is done.
- **Constraints** — stack, ADRs, data, security, compatibility.
- **Success criterion** — how we'll know, in one line.
- **Steps** — what changes, in order.

Do not dictate libraries or frameworks, and do not paste invented implementation code. The implementing model chooses how.

## Prefer high-fidelity references over prose

Where a real artifact can express the requirement, point at it instead of describing it: a failing test that defines the behavior, an existing file or function to mirror, an acceptance rubric. **Point at real artifacts; never invent fake ones.**

## By tier

- **trivial** — no written plan; hold the step list inline.
- **standard** — a short bullet plan in the conversation.
- **risky** — a dated file at `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`, same shape, short enough to hold in context.

Return the plan (or its path) to `/strata:feature`.
```

- [ ] **Step 2: Verify** — `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and `grep -q 'name: lean-plan' skills/lean-plan/SKILL.md && grep -q 'never invent fake ones' skills/lean-plan/SKILL.md && echo ANCHORS`. Expected: `OK` (validate lists `✓ skills/lean-plan/SKILL.md`) and `ANCHORS`.

- [ ] **Step 3: Commit** — `git add skills/lean-plan/SKILL.md && git commit -m "feat: add lean-plan skill (complete-but-lean, reference-first)"`

---

## Task 3: `light-finish` skill

**Files:** Create `skills/light-finish/SKILL.md`

- [ ] **Step 1: Create the file**

```markdown
---
name: light-finish
description: Use when a /strata:feature change is implemented and needs integrating, or when the user asks to wrap up a branch. Confirms the build is green, offers merge / PR / keep / discard, does the chosen one, and cleans up.
---

# light-finish — integrate the work, minimally

1. **Green?** Run the project's test/build command. If it fails, stop and report — never integrate broken work.
2. **Ask once:** merge to base locally · push + open a PR · keep the branch · discard.
3. **Do it.** Git safety holds: never a silent write to the default branch; keep commits reversible; if on the default branch, branch first.
4. **Clean up** the branch after a merge or discard.

If the project's release rule requires a version bump or changelog entry (see `CONTRIBUTING.md`), do that as part of finishing; otherwise skip it.
```

- [ ] **Step 2: Verify** — `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and `grep -q 'name: light-finish' skills/light-finish/SKILL.md && grep -q 'never integrate broken work' skills/light-finish/SKILL.md && echo ANCHORS`. Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit** — `git add skills/light-finish/SKILL.md && git commit -m "feat: add light-finish skill (lean branch integration)"`

---

## Task 4: Rewrite `feature` around adaptive ceremony

**Files:** Modify (full body rewrite) `skills/feature/SKILL.md`

- [ ] **Step 1: Overwrite the file with exactly this**

```markdown
---
name: feature
description: Use when someone wants to build a feature or change end-to-end and wants the process to fit the task — says "build X", "ship X properly", "run the flow", or has a design doc to carry to a merged change. Classifies the task (trivial/standard/risky) and runs only the ceremony that fits, behind a floor of evidence, risk escalation, drift-close and git safety.
---

# Feature — adaptive-ceremony feature flow

Strata's PROCESS spine: trivial work goes fast, risky work gets real guardrails, and the framework decides — not the human. Built for frontier models, so it deliberately carries **less** scaffolding than classic pipelines: state intent, then let the model work.

## Phase 0 — Triage (always, cheap)

Classify the request with `${CLAUDE_PLUGIN_ROOT}/skills/feature/sections/triage.md`. Emit **tier + one-line why + what you'll skip + the effort level**, then proceed — no confirmation gate. The user may say "go higher / lower" at any time; re-scale immediately. Bias **up** on doubt.

## The floor — always, every tier

1. **Evidence** — show that the change works: run the real test or command and report its output. Ask for proof, not reassurance.
2. **Risk escalation** — a risk surface (see the rubric) makes the task `risky`, however small it looks.
3. **Drift-close** — if docs or a documented fact changed, run `/strata:wiki-ingest` on them; otherwise nothing to do.
4. **Git safety** — work on a branch, keep commits reversible, never write silently to the default branch.

## Effort per tier

`trivial` → low · `standard` → medium · `risky` → high (xhigh for demanding agentic or multi-file work). Effort is the main cost lever; prefer thinking on at low effort over turning thinking off.

## Tier → phases

| Phase | trivial | standard | risky |
|---|---|---|---|
| Think | restate the ask in one line | light grill via `/strata:office-hours` (intent + success criterion) | `/strata:office-hours` — grill to convergence, design doc |
| Plan | none | `lean-plan`, short | `lean-plan`, complete-but-lean |
| Council | none | none by default | 1–2 risk-matched lenses (below) |
| Build | implement, then evidence | implement, evidence on the core | implement, evidence per meaningful step |
| Finish | `light-finish` | `light-finish` | `light-finish` + an explicit gate |
| Drift-close | floor #3 | `/strata:wiki-ingest` + scoped mini-`/strata:audit` | `/strata:wiki-ingest` + mini-audit |

## The council — risk-triggered, lens-selected

Only on `risky`, and only the lenses the risk actually calls for: security or PII → `strata-cso-review` · frontend or UX → `strata-design-review` · architecture or complexity → `strata-eng-review` · scope or "is this the right problem" → `strata-ceo-review`. Use the full panel only when several of those risks genuinely coincide; `/strata:autoplan` can drive it. Its job is an **independent adversarial read of a risky surface** — not routine double-checking of ordinary work. Surface reviewer disagreements to the user rather than averaging them away.

## Delegation

Think → `/strata:office-hours` · Plan → `lean-plan` · Council → `/strata:autoplan` or the `strata-*-review` agents in parallel · Finish → `light-finish` · Knowledge → `/strata:wiki-ingest`, `/strata:audit`.

**Superpowers is optional.** If `superpowers:*` skills are installed you may use them as accelerators on `risky` work. Absent — the native path above is complete; nothing degrades.

## Never

Skip the floor. Treat a risk-surface task as trivial. Run the council on trivial or standard work by default. Claim something works without showing its evidence.
```

- [ ] **Step 2: Verify**

Run:
```bash
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q 'Phase 0 — Triage' skills/feature/SKILL.md && grep -q 'The floor' skills/feature/SKILL.md && grep -q 'Effort per tier' skills/feature/SKILL.md && grep -q 'lens-selected' skills/feature/SKILL.md && grep -q 'lean-plan' skills/feature/SKILL.md && grep -q 'light-finish' skills/feature/SKILL.md && echo ANCHORS
grep -ciE 'double-check|re-verify|verification step' skills/feature/SKILL.md
```
Expected: `OK`, `ANCHORS`, and the scaffolding-grep count is `0`.

- [ ] **Step 3: Commit** — `git add skills/feature/SKILL.md && git commit -m "feat(feature): adaptive ceremony — triage, floor, effort, lens-selected council"`

---

## Task 5: Grill-style questioning in `office-hours`

**Files:** Modify `skills/office-hours/SKILL.md`

- [ ] **Step 1: Read the file**, then in "Phase 2 — The six forcing questions", find the sentence `Ask these **ONE AT A TIME** using \`AskUserQuestion\`. NEVER batch them.` and insert immediately after it:

```markdown
**Give your own recommended answer with every question.** State what you'd choose and why, so the user can confirm or redirect rather than invent from scratch — the decision stays theirs, so wait for their answer. Work out anything you can determine yourself (read the code, the wiki, the docs) instead of asking.
```

- [ ] **Step 2:** After the Phase 2 `**verify:**` line, add:

```markdown
**Depth scales with the task.** For a risky or ambiguous idea, keep grilling branch by branch — one dependency at a time — until the possibility space collapses to a single, clearly-specified idea; the six questions are the floor, not the ceiling. For a bounded `standard` task, a short recommend-and-confirm pass on intent plus the success criterion is enough. Build nothing until the user confirms you understand each other.
```

- [ ] **Step 3: Verify** — `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and `grep -q 'recommended answer with every question' skills/office-hours/SKILL.md && grep -q 'Depth scales with the task' skills/office-hours/SKILL.md && echo ANCHORS`. Expected: `OK` and `ANCHORS`.

- [ ] **Step 4: Commit** — `git add skills/office-hours/SKILL.md && git commit -m "feat(office-hours): grill-style questioning (recommend per question, converge by tier)"`

---

## Task 6: Lens selection in `autoplan`

**Files:** Modify `skills/autoplan/SKILL.md`

- [ ] **Step 1: Read the file**, then insert this section immediately before the section that spawns/lists the reviewers (the first place the `strata-*-review` agents are enumerated):

```markdown
## Pick the lenses the risk calls for

Do not run a fixed panel by default. Choose the reviewers whose lens matches the plan's actual risk: security, secrets, or PII → `strata-cso-review` · frontend or UX surface → `strata-design-review` · architecture, complexity, or reversibility → `strata-eng-review` · scope or "is this the right problem" → `strata-ceo-review`. One or two is the norm; use the full panel only when several of those risks genuinely coincide. Skip the council entirely for trivial or routine changes — it exists for an independent adversarial read of a risky surface, not to double-check ordinary work.

When you brief a reviewer, ask it to **report everything it finds and let the synthesis step filter**. Telling a reviewer to "only report high-severity issues" or "be conservative" makes it report less.
```

- [ ] **Step 2: Verify** — `bash scripts/validate.sh >/dev/null 2>&1 && echo OK` and `grep -q 'Pick the lenses' skills/autoplan/SKILL.md && grep -q 'report everything' skills/autoplan/SKILL.md && echo ANCHORS`. Expected: `OK` and `ANCHORS`.

- [ ] **Step 3: Commit** — `git add skills/autoplan/SKILL.md && git commit -m "feat(autoplan): risk-matched lens selection instead of a fixed panel"`

---

## Task 7: Demote Superpowers in onboarding

**Files:** Modify `BOOTSTRAP.md`, `skills/onboard/SKILL.md`

- [ ] **Step 1: BOOTSTRAP.md** — Read it; replace the whole bullet that begins `- **Superpowers** — *strongly recommended*.` with:

```markdown
- **Superpowers** — *optional power-up*. Are `superpowers:*` skills available? Strata's feature flow is native and complete without it; installed, it can add heavier discipline on `risky` work for teams that want it. Not required — don't push installing it.
```

Also remove the paragraph in Step 2 that begins `If your Step 1 scan found **Superpowers missing**, have them install it in the **same batch**` (Superpowers is no longer part of the install batch).

- [ ] **Step 2: onboard** — Read `skills/onboard/SKILL.md`; in the prerequisite table replace the Superpowers row with:

```markdown
| **Superpowers** — optional power-up | are `superpowers:*` skills available? | `/plugin install superpowers@claude-plugins-official` (only if you want the heavier discipline) | Strata's flow is native and complete without it; installed, it can add extra plan/review rigor on `risky` work. Not required. |
```

and change the sentence recommending Superpowers before `/strata:feature` to `Superpowers is optional — the native flow needs nothing installed.`

- [ ] **Step 3: Verify** — Run:
```bash
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q 'optional power-up' BOOTSTRAP.md && grep -q 'optional power-up' skills/onboard/SKILL.md && echo ANCHORS
grep -ci 'strongly recommend' BOOTSTRAP.md skills/onboard/SKILL.md
```
Expected: `OK`, `ANCHORS`, and `0` for both files in the last grep.

- [ ] **Step 4: Commit** — `git add BOOTSTRAP.md skills/onboard/SKILL.md && git commit -m "feat(onboarding): Superpowers is an optional power-up, not a prerequisite"`

---

## Task 8: Docs, attribution, version bump

**Files:** Modify `skills/using-strata/SKILL.md`, `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, both manifests

- [ ] **Step 1: using-strata** — Read it; in the `/strata:feature` row, set the "What it does" cell to: `Adaptive-ceremony feature flow — classifies the task (trivial/standard/risky) and runs only the ceremony that fits, behind a safety floor`.

- [ ] **Step 2: README** — Read it; in the Commands table, set the `/strata:feature` Purpose cell to: `Adaptive feature flow: triage → (grill) → lean plan → risk-matched council → build with evidence → finish → wiki+audit`. In "The four layers", change the Process row's "Owns" cell to end with `— scaled to the task (adaptive ceremony)`.

- [ ] **Step 3: CLAUDE.md** — Read it; add after the onboarding row of the Phase/status table:
```markdown
| Adaptive ceremony in /strata:feature (triage + tiers + effort + lens-selected council) | 🔄 building |
```
Confirm the file is still ≤ 200 lines.

- [ ] **Step 4: CONTRIBUTING** — Read it; in "Attribution" add: `The lean process skills (lean-plan, light-finish) and the grill-style questioning in office-hours adapt *ideas* from Superpowers, gstack, and grill-me — no vendored code.`

- [ ] **Step 5: CHANGELOG** — Read it; insert directly under `## [Unreleased]`:
```markdown
## [0.3.0] — 2026-07-21

### Changed
- **`/strata:feature` is now adaptive-ceremony.** A cheap Phase-0 triage classifies each task
  (trivial / standard / risky) and runs only the ceremony that fits, behind a floor of evidence,
  risk auto-escalation, drift-close and git safety. Adds a per-tier **effort** policy (low/medium/high)
  as the main token lever.
- **The council is risk-triggered and lens-selected.** Instead of a fixed four-agent panel on every
  plan, 1–2 reviewers are chosen to match the actual risk, and only on `risky` work — an independent
  adversarial read of a risky surface, not routine double-checking.
- **Removed verification scaffolding.** Per Anthropic's Opus 5 guidance (frontier models verify their
  own work; explicit verification instructions cause over-verification), the flow asks for *evidence*
  — run the test, show the output — instead of instructing re-checks.
- **Strata owns a lean process spine:** new `lean-plan` (complete-but-lean, reference-first) and
  `light-finish` (lean branch integration). **Superpowers is now an optional power-up, not a
  prerequisite** — the native flow is complete without it.
- **`office-hours` grills better:** every question comes with a recommended answer, and depth scales
  with the task (converge branch-by-branch on risky work).
```

- [ ] **Step 6: Bump** — Read both manifests; change `"version": "0.2.2"` to `"version": "0.3.0"` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

- [ ] **Step 7: Verify** — Run:
```bash
grep '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
awk 'END{print "CLAUDE.md lines:", NR}' CLAUDE.md
bash scripts/validate.sh >/dev/null 2>&1 && echo OK
grep -q '0.3.0' CHANGELOG.md && grep -q 'grill-me' CONTRIBUTING.md && echo DOCS
```
Expected: both `0.3.0`; CLAUDE.md ≤ 200; `OK`; `DOCS`.

- [ ] **Step 8: Commit** — `git add skills/using-strata/SKILL.md README.md CLAUDE.md CONTRIBUTING.md CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json && git commit -m "release: 0.3.0 — adaptive ceremony, lean spine, lens-selected council"`

---

## Task 9: Acceptance — automated sweep + manual dogfood

**Files:** none (verification only)

- [ ] **Step 1: Automated** — Run `bash scripts/validate.sh` (expect `✅ Strata plugin validation PASSED`) and the anti-scaffolding sweep:
```bash
grep -rniE 'double-check|re-verify|verification step|verify your own work' skills/ | grep -v sections/triage.md
```
Expected: no hits (spec §12.6). If a hit is a legitimate evidence requirement, reword it to ask for evidence.

- [ ] **Step 2: Manual behavioral runs** (spec §12 — cannot be automated). With 0.3.0 loaded, run `/strata:feature` and record the observed outcome of each:
1. **trivial** ("rename a label in one file") → tier `trivial`, no council, no plan file, still shows evidence, lands on a branch.
2. **risk surface** ("tweak the login token check") → **auto-escalates to `risky`** though tiny; the `cso` lens runs.
3. **standard** ("add CSV export to an existing report") → short plan, **no council**.
4. **lens selection** → on a security task, only the matching lens(es) run, not all four.
5. **override** → "go higher" on a trivial task re-scales the flow.
6. **tokens** → note that the trivial run cost far less than the old fixed flow.

- [ ] **Step 3: Record + commit** — Append the observed results to the spec's §12 and commit: `git add docs/superpowers/specs/2026-07-21-adaptive-ceremony-design.md && git commit -m "docs: record v0.3 behavioral acceptance results"`

---

## Self-review (plan author)

**Spec coverage:** §2 frontier constraints → the authoring rule + Task 9.1 sweep · §3 decisions → Tasks 1–8 · §4 tiers/triage → Tasks 1, 4 · §5 floor → Task 4 · §6 effort → Task 4 · §7 tier→phases + council lenses → Tasks 4, 6 · §8 grill → Task 5 · §9 lean plan → Task 2 · §10 Superpowers optional → Tasks 4, 7 · §11 components → Tasks 1–8 · §12 verify → Task 9 · §13 out-of-scope respected (no verify skill, no grill skill, no config, no fork) · §14 risks → mitigated in triage.md + the floor.

**Placeholder scan:** none — every new file has complete content; every edit names an exact find-and-replace target.

**Name consistency:** `lean-plan` / `light-finish` spelled identically in frontmatter, the `feature` table, CHANGELOG and CONTRIBUTING. `skills/feature/sections/triage.md` matches the `${CLAUDE_PLUGIN_ROOT}` reference in Task 4. Council agent ids (`strata-cso-review`, `strata-design-review`, `strata-eng-review`, `strata-ceo-review`) match `agents/`. Version `0.3.0` consistent across both manifests and the CHANGELOG.
