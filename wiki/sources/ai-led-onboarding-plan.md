---
title: "AI-led one-line onboarding — implementation plan"
type: source
source: raw/superpowers/plans/2026-06-25-ai-led-onboarding.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — AI-led onboarding (implementation plan, 2026-06-25)

The execution plan for [[ai-led-onboarding-design]]; shipped as v0.2.0. Summarised here at the
level of task structure and outcomes — the rationale lives in the design page, and the literal
file contents live in `raw/`.

Six tasks, in dependency order. **Task 1** built `install.sh` test-first, with the behavioural
suite driving it against a temp settings file via a `STRATA_SETTINGS` override so nothing touches
the real `~/.claude/settings.json`; the installer merges two keys, aborts untouched on invalid
JSON, backs up before a real change, and treats an already-installed re-run as a true no-op —
explicitly so repeat runs stop littering `~/.claude/` with backup files. **Task 2** wrote
`BOOTSTRAP.md` as the session-1 conductor (idempotency → prereq scan → user-run install → breadcrumb
→ bridge). **Task 3** added `skills/onboard/SKILL.md` as the session-2 conductor: resume, detect,
report, plan-and-approve, delegate, first audit, hand off.

**Task 4** wired `scripts/validate.sh` and CI to cover the installer's syntax and behaviour — the
pattern this repo still follows, and which P1 extended with `scripts/test_p1_gates.sh`. **Task 5**
carried the documentation: the README "⚡ Instant setup (AI-led)" section, the `using-strata`
cross-link, and the CLAUDE.md phase table. **Task 6** was a dogfood verify plus a manual
fresh-profile check aimed squarely at risk R1 (whether config-only marketplace registration
triggers a clone on reload).

Two lessons from this plan outlived it. First, the version-bump rule: the marketplace serves the
plugin by its `version` field, and `onboard` sat on `main` while installs still received `0.1.2` —
which is why bumping **both** manifests is now a release requirement. Second, the plan carried a
self-review section by its own author, a habit worth keeping for plans of this size.
