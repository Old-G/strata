---
title: LLM-behaviour evidence (evals, not runs)
type: entity
created: 2026-09-30
updated: 2026-09-30
links: [ablate, diff-review, friction-capture, behaviour-specs, agent-session-trailer]
---

# LLM-behaviour evidence (evals, not runs)

## TLDR

When a change alters what a model does — a prompt, a skill, a tool description, the model or
effort, the harness feeding them — the evidence floor asks for the same eval before and after on a
held-out split, not one good run. Tooling is delegated: `/claude-api build-eval` · `hillclimb` for
Claude-backed apps, the project's own harness otherwise. Method: `reference/llm-evals.md`.

## Role

Strata's floor #1 ("run the real test and show its output") assumed deterministic code. A
stochastic system passes or fails the same input on different runs, so a single green run proves
nothing and a tweak tuned on the failures you looked at usually overfits them. The owner's AI
projects change prompts and models routinely; before 0.15.0 Strata had no rule for what counts as
proof there.

## Current solutions

**Shipped in v0.15.0**, after Anthropic's "Automating eval design and hillclimbing" (claude.dev).

- **feature, floor #1:** an LLM-behaviour change is proven by an eval before/after on a held-out
  split; train-up/test-flat is reverted; no eval → build one or record `no-eval: <reason>` and
  call the evidence what it is. Not a new tier or risk surface — the ceremony stays adaptive, the
  bar for *proof* changes.
- **strata-diff-review, compliance pass:** such a change with neither an eval result nor a
  `no-eval:` line = Important; a prompt or description that now carries a failing case or the
  missed phrase verbatim = Important. It runs even on a branch with no plan — a one-line prompt
  tweak is the commonest case and is usually trivial-tier.
- **Where the result goes:** before/after scores in the commit message or `wiki/log.md` (or a
  pointer to `.claude/hillclimb/<flow>/summary.json`). In a repo whose product is instructions —
  Strata itself — every skill edit is in scope, and the honest default until it has an eval is a
  `no-eval:` line with the reason.
- **reference/llm-evals.md:** case sources (production transcripts first, never "cases today's
  model fails"), graders (programmatic first; judge on a rubric, graded twice), noise (infra
  failures apart from misses; noise floor before optimising), the loop (a random train/test split, one
  structural change per round, never paste failure content), tooling table, "paid runs are the owner's call".
- **Tooling, verified 2026-09-30:** Claude Code 2.1.283's bundled `claude-api` skill carries
  `build-eval`, `hillclimb`, `prompt-audit`, `cost-optimize`; results under
  `.claude/hillclimb/<flow>/`. The owner's AI apps mostly call other providers, and the skill
  steers away from non-Claude code when it self-triggers — so the project's own harness is the
  default there, and the method, not the tool, is the rule.
- **Also fed:** [[ablate]] gains its measuring method; `CLAUDE.md` gains "fix a misroute at its
  cause, never by appending the missed phrase" — the no-paste rule applied to routing.

Deliberately not built: any eval harness inside Strata. Its own routing evals (v0.7.0) were
removed the day they shipped — noise the harness could not separate, one finding for the cost.

## Related

[[ablate]] · [[diff-review]] · [[friction-capture]] (where production cases come from) ·
[[behaviour-specs]] (a scenario's `test:` is a programmatic grader) · [[agent-session-trailer]]

## Sources

`reference/llm-evals.md` · [claude.dev — Automating eval design and hillclimbing](https://claude.dev/blog/automating-eval-design-and-hillclimbing/) · `wiki/log.md` 2026-09-02 (routing evals removed)
