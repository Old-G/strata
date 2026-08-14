---
title: Gardener (nightly curator)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [executable-wiki, hq-mode, session-reflector]
---

# Gardener (nightly curator)

## TLDR

A two-tier nightly job that verifies wiki facts for free, then spends one scoped LLM session
tidying what it found — scheduled with anacron semantics so a sleeping laptop still gets
exactly one catch-up run.

## Role

Where [[session-reflector]] grows the knowledge base, the gardener prunes it: dedupe entities,
merge near-duplicates, decay stale TLDRs, keep `index.md` under a token budget, propose
deletions per the Boris Cherny principle (see [[ablate]]).

## Current solutions

Planned for P2/P3. Cost-aware split:

- **Tier 1 — zero tokens.** `wiki_verify_runner.sh` runs every [[executable-wiki]] fact due by
  its freshness window, writes pass/fail to `wiki/.verify-status.json`, flips `stale` flags,
  and commits to branch `gardener/nightly` — never main.
- **Tier 2 — one LLM session**, only if tier 1 found work or it is the weekly slot:
  `claude -p "/strata:gardener" --max-turns 30` fixes what it can prove, merges dupes, and
  writes `morning-digest.md` for a one-click human review.

Scheduling (B6, approved): a launchd `StartCalendarInterval` at 03:33 plus `RunAtLoad=true`,
with the anacron brain in the wrapper — a stamp file enforces "not more than once per ~20h",
a `mkdir` lock prevents wake+login double-fire, and `|| true` keeps one sick repo from
blocking the rest. Battery power → tier 1 only. Same semantics elsewhere: systemd user timer
with `Persistent=true` on Linux, `StartWhenAvailable=true` on Windows. Delivered by a small
`gardener-install` skill with an uninstall verb.

Safety invariants: never pushes to main; never edits `docs/` or `src/` (wiki + status files
only); token budget cap per run; two consecutive runs proposing conflicting changes → stop and
flag for a human.

Runtime options: local launchd (start here), own VPS for true 24/7, or Anthropic cloud
Routines for GitHub-reachable repos like Strata itself.

## Related

[[executable-wiki]] · [[hq-mode]] · [[session-reflector]] · [[ablate]]

## Sources

[[vnext-brief]] §12.5, §14, §15
