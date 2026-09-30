# LLM-behaviour evidence — evals, not runs

Read by `/strata:feature` (floor #1) and `strata-diff-review` whenever a change alters what a
model does: a system or task prompt, a skill, a tool description, the model or effort level, or
the harness that feeds them. One good-looking run of a stochastic system is an anecdote. The
evidence for such a change is **the same eval run before and after, on cases the change was not
tuned on**. Method after Anthropic's "Automating eval design and hillclimbing" (claude.dev blog);
mechanics are delegated, never rebuilt here (Strata is thin glue).

## Where the cases come from

In this order: production transcripts and logs → bug reports and support escalations → cases a
domain expert writes → synthetic. **Never pick a case because today's model fails it** — that
samples the valleys of one model's jagged capability surface, and the next model makes the eval
meaningless. In a Strata repo, sessions that hurt are already marked: the Stop gate's friction
trigger counts them from the transcript, and `strata_why.sh` leads from a line of code to the
session that wrote it.

## What makes the eval worth trusting

- **Graders:** programmatic first (exact match, schema, a test passing — a `## Requirements`
  scenario with a `test:` pointer is one). LLM-as-judge only for open-ended output, against a
  checkable rubric, never a 1–5 scale; prefer a blind comparison against a baseline output; the
  judge is not the model under test; grade the same output twice — a judge that disagrees with
  itself is noise.
- **Headroom:** the strongest model scores well below 100%, or there is nothing to measure. A
  saturated eval can still climb on cost and latency (a cheaper model or lower effort at the same
  score).
- **Noise:** separate infrastructure failures (timeouts, rate limits, API errors) from wrong
  answers, and report them apart. (Strata's own routing evals died of exactly this: v1 filed rate
  limits as misses, v2 filed misses as API errors.) If run-to-run noise exceeds the smallest
  improvement you care about, add cases before optimising anything.
- **Leaks:** leftover files, git history or fixtures that reveal the answer invalidate a case.

## The loop (hillclimbing)

1. Split once — train / test (random; ≈70/30 is a usual choice). The change is designed on train
   failures only.
2. One **structural** change per round, aimed at a root cause — not a rewording.
3. Accept only when train and test both improve. Train up, test flat → overfit, revert. Any
   regression → revert.
4. **Never paste failure content into the prompt** (a failing input, its expected answer, an
   exact phrase). It fixes the case, not the class.
5. Stalled 2–3 rounds → group failures by cause; a case that never moves is usually a broken case
   or grader, not a hard one.

## Tooling

| The app calls | Build / improve the eval with |
|---|---|
| the Claude API | `/claude-api build-eval`, then `/claude-api hillclimb` (Claude Code's bundled skill; results under `.claude/hillclimb/<flow>/` — `summary.json`, `trajectory/scores.tsv`, the split in `_state.json`) |
| another provider | the project's own eval harness if it has one; otherwise the runner scaffold `/claude-api build-eval` writes (`runCase` is yours to fill, so it is provider-agnostic). The skill steers away from non-Claude apps when it triggers on its own — invoke it by name. |

**Paid runs are the owner's call.** No eval runs in CI or on a schedule unless the owner decided
it; a skipped eval must never look green.

## Where the result goes

The before/after scores (and the split) in the commit message or a `wiki/log.md` line — the branch
review reads git, not the session. With `/claude-api hillclimb`, pointing at
`.claude/hillclimb/<flow>/summary.json` is enough.

**In a repo whose product is instructions** (a plugin like Strata, a skills library) every skill
edit is in scope. Until such a repo has an eval, the honest default is a `no-eval:` line with the
reason — it keeps "unmeasured" visible instead of letting "validate passed" stand in for it.

## When there is no eval yet

Either build one (the change is worth it) or say so: record `no-eval: <reason>` in the branch
state's `decisions` or the commit message, and present the evidence as what it is — "N outputs
checked by hand", never "works". `strata-diff-review` treats an LLM-behaviour change with
neither an eval result nor a `no-eval:` line as Important.
