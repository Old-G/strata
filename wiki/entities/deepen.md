---
title: Deepen
type: entity
created: 2026-10-22
updated: 2026-10-22
links: [native-invocation, diff-review]
---

# Deepen

## TLDR

`/strata:deepen` (v0.17.0) rewrites an ask before it is planned, so the plan aims at the result
instead of the task. `/strata:feature` runs it by itself on `standard` and `risky` tiers, between
Think and Plan; the user can also ask for it ("go deeper", «глубже»).

- **Why.** An agent does what the prompt names and stops; nothing in the prompt says what the task
  is for. A role prompt ("act as a senior X") changes the tone, not the work.
- **The pass:** altitude (the outcome behind the ask) · depth (what the best practitioner would add,
  the material they start from, their methods and tools, proof outside the model) · ambition (a
  target tweaking cannot reach, inside the scope) · range (2-4 fields as sequential subagents, only
  on risky work that faces people) · outside judge (a model that did not build it; risky only, on
  the diff before light-finish).
- **Resources first.** Without the signal, the context and a place to reproduce, the pass cannot be
  met — the skill names what is missing and says plainly when proof is unavailable.
- **Output:** a short Deeper ask block that `lean-plan` copies as intent + success criterion. Items
  that add a feature, spend money or touch production stay options for the user.
- **Not on** trivial work, questions, or an exact spec the user wants as written.
- **Reaching it.** A skill description alone does not fire on a plain "add X" (measured 0/3); the
  opt-in `bin/strata-deepen-gate` UserPromptSubmit hook makes it the first tool call (2/2) —
  `reference/deepen-gate.md`.
- **Once per ask.** A pass the gate already ran is reused by `feature`, not repeated (range
  subagents included). The gate runs in every project, so its note also names the skill file — where
  the plugin is off, the model follows the pass by hand (the context gate does the same).

Related: [[native-invocation]] (how it is reached without a command), [[diff-review]] (the other
outside read, at branch close). Source: Felix Rieseberg's altitude / depth / range framing.
