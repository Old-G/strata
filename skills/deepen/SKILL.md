---
name: deepen
description: Use to turn a request into its deeper version before anything is built — 'go deeper', 'do it the way the best expert would', 'what would a pro do here', 'raise the bar', 'make it ambitious', «глубже», «сделай на уровне лучшего специалиста», «что бы сделал профессионал», «подними планку», «углуби задачу». /strata:feature runs it by itself on standard and risky work, between Think and Plan. Restates the ask as its outcome, the methods the best practitioners use, a target tweaking cannot reach and proof from outside the model — deeper, not bigger.
---

# Deepen — ask for the result, not the task

An agent does what the prompt names and stops there: nothing in the prompt says what the task is
*for*, so "done" means "the task ran", not "the result is there". The same model gives ordinary or
excellent work depending on the ask. This pass rewrites the ask before the plan, so the plan aims at
the result. (After Felix Rieseberg's altitude / depth / range framing.)

## When it runs

- **By itself** from `/strata:feature` on `standard` and `risky` tiers, after Think and before Plan,
  and on any build request once the opt-in `bin/strata-deepen-gate` hook is installed
  (`${CLAUDE_PLUGIN_ROOT}/reference/deepen-gate.md`) — a skill alone is not reliably reached from a
  plain "add X".
- **On request**, on any task the user wants raised.
- **Not** on `trivial`, a question, or an exact spec the user wants as written ("just do X").
- Creative work with no single right result: skip Altitude and Ambition, keep Depth and Proof.

## The pass

Read the real code, data and history first — every answer below comes from them, not from the
prompt alone.

1. **Altitude — the outcome behind the ask.** Say in one sentence what the requested thing is for,
   and restate the task as that outcome: "fix this crash" → "the app does not crash"; "build a
   report" → "a report that says why the number lags and what to do about it".
2. **Depth — the best practitioner's version.** A role ("act as a senior X") changes the tone, not
   the work, so ask for the work:
   - What would the best practitioner in this field do here that the ask does not mention?
   - What material do they start from — real data, logs, the existing code, the users' own words?
   - Which concrete methods and tools do they use? Name them. Install or reach a missing tool
     yourself; ask first only when it costs money or touches production.
   - What, other than the model saying so, proves the result right — a test, a measurement, a
     reproduction, a before/after number, a review by someone who did not build it?
3. **Ambition — a target tweaking cannot reach.** State the version that forces a rethink ("feels
   instant", not "faster"). It raises the bar inside the scope; it never widens the scope.
4. **Range — only `risky` work that faces people.** Describe the thing by the verb — what it does
   for people, not what it is — pick 2-4 fields that know that verb best, and run them as
   sequential fresh subagents, each applying its field's methods to what the previous one left.
   Slow and costly: never on `standard`.
5. **Outside judge.** Plan the check by a model that did not build the work: another vendor's CLI
   when installed (e.g. `codex review`), else a non-interactive `claude -p` session on a different
   model, else a fresh `strata-*-review` subagent. The session that built it never grades itself.
   On `standard` the mechanical proof from step 2 is enough; the judge runs on `risky`, before
   `/strata:light-finish`.

## Resources come first

None of this works when the agent cannot see the problem, understand it and try a fix. Name what
is missing — the signal (crash reports, logs, metrics, reachable through an MCP or a CLI), the
context (which build matches which commit) and a place to reproduce and test — and get it before
building. When the proof cannot be had, say so plainly instead of claiming the result.

## Output

A short **Deeper ask** block, shown to the user in 5-8 lines, then proceed — no confirmation gate;
the user may trim it:

- **Outcome** — the result, one line
- **Beyond the ask** — 3-6 things the best practitioner would add
- **Start from** — the material
- **Methods & tools**
- **Target** — the ambitious version
- **Proof** — the evidence outside the model
- **Judge** — who checks it (`risky`)

It becomes the plan's intent and success criterion in `/strata:lean-plan`. An item that adds a
feature, spends money or touches production is listed as an option for the user, not done.

## Do NOT use when

- The task is `trivial` — a typo, a one-line fix, a rename.
- The user asks a question about the project — that is a wiki query.
- The user gave an exact spec and asked for exactly that.
- Whether the thing should exist at all is in doubt — that is `/strata:office-hours`.
