---
title: "ADR #5 — Branch state is git-tracked and branch-scoped, not session-scoped"
type: decision
created: 2026-09-01
updated: 2026-09-01
status: accepted
---

# ADR #5 — Branch state is git-tracked and branch-scoped, not session-scoped

## Context

Designing [[branch-state]] (the P2 episodic layer), two shapes were plausible: a file per
*session* (matching the existing `.strata/sessions/<id>.start` stamps, gitignored, ephemeral), or
a file per *branch* (surviving across sessions on that branch). And separately: gitignored, like
the rest of `.strata/`, or committed.

Session-scoped and gitignored is what the existing enforcement layer already does for gate
cadence — reusing that shape would have been the path of least resistance.

## Decision

**Branch-scoped, one file per branch, committed.** `.strata/state/<branch-slug>.json` persists
across sessions on the same branch and is tracked in git; `.strata/sessions/` and
`.strata/version` stay exactly what they are — ephemeral, gitignored bookkeeping.
`.gitignore`/`gitignore.tmpl` change from a blanket `.strata/` to `.strata/*` +
`!.strata/state/`.

Rationale: the whole point of the layer is to survive the boundary that currently loses
knowledge — a `/clear`, a context compaction, a different machine, a different person picking up
the same branch. A gitignored file cannot do any of that. The content (goal, decisions with
`why`, open questions, gotchas, wiki debt) is small structured JSON, not secrets, so committing it
costs nothing and buys durability across exactly the boundary that matters. Session-scoping would
have thrown the state away at the one moment it's most needed — the next session picking up
yesterday's work.

## Consequences

- A completed branch would leave a permanent scratch file behind if nothing retired it —
  `light-finish` folds its content into `wiki/log.md` and deletes it on close; `audit` flags any
  file whose branch no longer exists as an orphan, so abandoned ones don't silently accumulate.
- The `.gitignore` carve-out (`.strata/*` + `!.strata/state/`) is a real gotcha: a plain
  `.strata/` line blocks git from descending into the directory at all, so `!.strata/state/`
  would silently have no effect — verified with `git check-ignore` on both sub-paths before
  shipping.
- `/strata:upgrade`'s own version stamp (`.strata/version`) deliberately stays **outside** the
  tracked exception — it's per-machine bookkeeping (which plugin build last touched this
  checkout), not project knowledge, and committing it would just create merge noise across
  contributors upgrading at different times.
- This diverges from claude-mem's model (automatic, machine-local, episodic) on purpose: `wiki/`
  and now `.strata/state/` are both *reviewed, project-scoped, in-git* truth; claude-mem stays
  the machine-local working memory. Never store the same fact in both (the existing
  knowledge-layer rule in `skills/using-strata/SKILL.md`, extended here to cover branch state).

## Sources

[[episodic-state-layer]] · [[branch-state]] · resolved 2026-09-01
