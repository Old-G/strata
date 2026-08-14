---
title: "AI-led one-line onboarding — design"
type: source
source: raw/superpowers/specs/2026-06-25-ai-led-onboarding-design.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — AI-led one-line onboarding (design, 2026-06-25)

Approved design for turning Strata's install-and-setup ritual into a single line dropped into an
AI session, after which the AI conducts the whole adoption conversationally. Shipped in v0.2.0 and
confirmed by a real end-to-end human run.

## The constraint that shaped everything

A plugin *can* be enabled non-interactively by writing `extraKnownMarketplaces` and
`enabledPlugins` into `~/.claude/settings.json` — but newly-installed skills only activate after
`/reload-plugins` or a restart, and **the assistant cannot trigger that reload itself**. There is
no "fetch remote instructions on launch" mechanism either. So a seamless single-session install is
impossible; the design's job is to make the seam one clearly-instructed human action with a
ready-to-paste continuation prompt.

A live run then surfaced a second, sharper constraint: in auto permission mode Claude Code
**auto-denies the assistant writing `~/.claude/settings.json`** to register an external
marketplace — flagged as self-modification. This is correct behaviour, and the design accepts it as
a rule: enabling an external plugin is intrinsically a user action. The assistant must never route
around the guard; a denied write falls back to the user running `/plugin install strata@strata`, or
`install.sh` in their own terminal, which sits outside the in-session guard.

## Shape

Session 1 is `BOOTSTRAP.md` — an instruction document addressed to the AI, written to be *executed*:
idempotency check (skills already loaded → skip to onboarding), a report-only prerequisite scan
(Superpowers / claude-mem / RTK — never installs them), the user-run enable step, a
`.strata/onboard.json` breadcrumb, and a printed bridge block. `install.sh` is the terminal
alternative: an idempotent, backup-then-atomic-replace JSON merge that aborts untouched if the
existing settings file is not valid JSON, and makes literally no change on a true no-op re-run.

Session 2 is `/strata:onboard`, deliberately a **thin conductor**: it reads the breadcrumb, detects
new-vs-existing, re-checks prerequisites, proposes a `step → verify` plan, then **delegates** to
`init` or `adopt` and lets their own verifies run. It ends by running the first (read-only) `audit`
and handing off. It never duplicates their logic — Strata's thin-glue rule applied to its own
onboarding.

## Why it matters now

The bridge always carries a fallback `/plugin` command, because the open risk (R1) — whether
config-only registration triggers a marketplace clone on reload — was never fully resolved; it was
made harmless instead. Two further risks were accepted with mitigations: WebFetch may be blocked
(shell path is the fallback), and the breadcrumb may be stale (`onboard` treats it as a hint and
re-detects, never as ground truth).

Related: [[enforcement-layer]] — the hooks `init`/`adopt` now install as part of the same setup
path this design defined.
