---
title: Behaviour specs (Requirements + Behaviour delta)
type: entity
created: 2026-09-28
updated: 2026-09-28
links: [executable-wiki, diff-review, branch-state, stop-gate, commit-gate]
---

# Behaviour specs (Requirements + Behaviour delta)

## TLDR

An entity page may say what the component **must do** — `## Requirements`, each a WHEN/THEN
scenario pointing at a test — and a plan changes that only through a `## Behaviour delta` that
`light-finish` applies on the branch before integrating. OpenSpec's delta → archive, on Strata's
own wiki and gates ([[p6-behaviour-specs]]).

## Role

The wiki answered "how does X work"; dated plans answered "what did we intend"; nothing answered
"what must X do right now" in a form a script can check. A requirement with a scenario and a
`test:` pointer is a promise that names its own evidence — so a promise whose test disappears is a
finding, not a silent lie. It is the first shipped slice of [[executable-wiki]].

## Current solutions

**Shipped in v0.14.0.** Format once, in `WIKI.md` "Requirements and behaviour deltas".

- **Where it lives:** inside `wiki/entities/<slug>.md`, after `## Current solutions`; optional per
  page, reserved heading (a `## Requirements` with no `###` is ignored). Never a second tree.
- **How it changes:** `lean-plan` adds a `## Behaviour delta` (`### ADDED|MODIFIED|REMOVED [[slug]]`
  → `#### <title>` → full body) when specified behaviour changes — then the plan is a file even on
  the standard tier, named `<date>-<last-branch-segment>-plan.md`.
- **When it merges:** never at ingest (the plan is ingested before the behaviour exists);
  `light-finish` step 1b, on the branch, after green, before the diff review — so merge, PR and keep
  carry it and discard throws it away.
- **The checker:** `scripts/lib/requirements.py` — `check [--strict]` (a requirement without a
  scenario, WHEN/THEN missing, zero or two pointers, a `test:` path or `::needle` that does not
  resolve, pytest ids included; `manual:` counted), `owed` (delta vs pages; exit 1 while owed or
  malformed; never writes `wiki_debt`). Plan lookup: `state_tools.py plan <branch>` — the one rule,
  shared with [[diff-review]] and light-finish.
- **Who reads it:** [[diff-review]] (script output = Important; judges whether the test asserts
  the THEN, and behaviour changed without a delta), `audit` Phase 2 step 7 (`check` only),
  `validate.sh` §17 (`check --strict` on this repo).

Proved to **resolve**, not to pass: running the tests is the floor's and CI's job.

## Related

[[executable-wiki]] · [[diff-review]] · [[branch-state]] · [[stop-gate]] · [[commit-gate]]

## Sources

[[p6-behaviour-specs]]
