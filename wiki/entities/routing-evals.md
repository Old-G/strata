---
title: Routing evals (E1)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [native-invocation, enforcement-layer]
---

# Routing evals (E1)

## TLDR

`evals/routing-cases.json` + `scripts/test_routing_evals.sh` — the first test of Strata's
*probabilistic* half: does a trigger phrase actually fire the skill it belongs to? 34 cases,
threshold 1.0, run on every change to the routing surface.

## Role

[[native-invocation]] made skill descriptions the whole routing surface (ADR #2) and the README
said plainly that routing is probabilistic "which is exactly why the hooks below are not". The
deterministic layer had ~80 behavioural assertions; the layer that decides *which skill runs at
all* had zero — `validate.sh` §8 only checked that descriptions *contain* EN+RU phrases. The
playbook's "continuous evals in CI on any change to CLAUDE.md, skills or hooks" is the missing
gate.

## Current solutions

**Shipped in v0.7.0.**

- **Cases are generated, not typed** (`evals/routing_cases.py`): for each of the 13 skills, the
  first EN `'…'` and first RU `«…»` phrase of its own `description`, verbatim — the eval tests the
  routing surface as written and cannot drift from it. Plus eight hand-written borderline prompts
  for the four confusable pairs (`feature`/`refactor`, `office-hours`/`lean-plan`,
  `wiki-ingest`/`using-strata`, `upgrade`/`adopt`), each naming the neighbour that must not fire.
- **Mechanism:** `claude plugin eval` is in early access on this CLI (both `init` and the run
  path say so and create nothing), so each case runs headless — `claude -p "<prompt>"
  --plugin-dir <root> --allowedTools Skill --max-turns 1 --output-format stream-json` from an
  empty temp dir (no project settings can bias the route) — and the first `Skill` call's `skill`
  must equal `strata:<expect>`. The JSON is shaped to convert to native eval cases unchanged.
  Recorded as a D1 amendment in the shipping branch's state.
- **Three outcomes per run, kept apart:** ✓ expected skill fired · ✗ routing miss (wrong or no
  skill with a healthy API, exit 1) · ! inconclusive (rate limit / overload / network after
  retries with backoff, exit 2). The first RUNS=3 pass reported 13 cases at 0.00 with nothing
  fired; every one routed correctly alone — an 8-wide queue had hit a rate limit and the runner
  recorded it as a routing failure. An eval that cannot tell "the model chose wrong" from "the
  API said no" is worse than none, so the two are now separate verdicts and every non-✓ row
  prints what the CLI actually said.
- **Safety:** the [[diff-review]] dogfood run caught prompts being spliced into a `bash -c`
  script via `xargs -I{}` — a `$(…)` in a case prompt executed. Prompts are repo-controlled,
  but CI runs this on every PR touching `skills/**`; they are now passed as an argument
  (`bash -c '… "$1"' _ {}`), never interpolated. Per-run spend cap `--max-budget-usd` (default
  0.10) when the CLI has the flag.
- **Gate:** `validate.sh` §11 (free, offline) asserts the case file is current against the
  descriptions and covers every skill — so a skill added without cases, or a trigger phrase
  edited without regenerating, fails in normal CI. The eval **run** is deliberately NOT in CI:
  it costs API calls, and a paid job that only the repo owner can make green is a gate nobody
  can satisfy. It is a local command, run when the routing surface changes:
  `RUNS=3 bash scripts/test_routing_evals.sh`. (A CI workflow shipped in the first cut of
  v0.7.0 and was removed the same day — it went red on a missing `ANTHROPIC_API_KEY` secret,
  which is the honest behaviour for a skipped eval but a bad default for a solo repo.)
- First run: 34/34 at 1.0 (RUNS=1), including all eight negatives.

## Related

[[native-invocation]] · [[enforcement-layer]] · [[diff-review]] · [[pre-tool-guard]]

## Sources

[[sdlc-right-side]] D1 · playbook play "Continuous evals in CI"
