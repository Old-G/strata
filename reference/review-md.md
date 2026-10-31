# REVIEW.md and the review loop

After Anthropic's "How the Claude Code team does code review". The reviewer does what the code owner
says matters in that part of the code, keeps what a change broke apart from what was already
broken, stops after three rounds, and every PR says how it was tested, what it risks and how to undo
it.

## REVIEW.md — the owner writes it

5–15 lines at the repo root (`templates/core/REVIEW.md.tmpl`); a `REVIEW.md` in a subdirectory adds
rules for the files under it, and the closer one wins on a conflict. `adopt` and `init` draft it from
what is in the repo and show it to the owner; `upgrade` offers a draft where none exists. Nobody
writes it unasked.

| Line | What goes in it | Examples |
|---|---|---|
| Broken here means | what failure looks like for what this repo holds, 1–3 | docs: they say what the code does not do · config: it points somewhere wrong · API/library: a caller breaks · migration: data is lost or locked · auth/payments: the wrong person gets in or is charged |
| Nits | the cap per review; the rest is a count | `at most 5` |
| Skip | paths the review does not read | lockfiles, `dist/`, `vendor/`, snapshots, `raw/` |
| Always a human | paths a person signs off whatever the review says | migrations, auth, payments, deploy and CI config, the public API |
| Evidence | every finding cites the `file:line` it read | no finding from a function's name |
| Pre-existing | what the branch did not write goes in its own list | checked with `git blame` |
| Summary | opens with the count; says "Nothing to fix" when so | `0 findings — Nothing to fix.` |

Read by `strata-diff-review` (branch close) and `strata-eng/cso/design-review` (the council).

## Labels

- **Important** — breaks behaviour, leaks data, breaches a policy, matches what REVIEW.md calls
  broken, or the plan and the code disagree with nothing recording why.
- **Nit** — style, naming, a comment. Shown up to the cap, then counted.
- **Pre-existing** — in a line the branch did not write. Decided by `scripts/lib/line_origin.sh
  <merge-base> <file>:<line>` — plain `git blame` plus `git merge-base --is-ancestor`; a moved or
  reindented line counts as the branch's, because a false "pre-existing" hides a bug and a false
  "branch" costs one look. Never Important, never counted in the first line, listed apart.

One row per **bug class** with every location; no finding twice — not across passes, not across
rounds.

## Three rounds

`light-finish` asks `state_tools.py review-round <branch>` which round is next before each review
(it writes nothing) and records it with `--done` once the report is in, so an interrupted review is
retried with the same scope. Round 1 reads the whole branch, rounds 2 and 3 only what was committed
after the previous round (`SINCE`), and check the previous findings as `Fixed` / `Still open`; a
still-open Important keeps the verdict off `CLEAN`. Past round 3 both calls exit 3: the human is
asked to reconsider the approach instead; a new approach starts again with `--reset`. The count
lives in the branch state (`review: {rounds, head}`), so it survives a new session, and goes when
the branch closes. A state file made only for the count has an empty goal, and an empty goal is
not a plan.

## PR description

`light-finish` drafts three sections for a PR or MR from the evidence of the run — **Testing** (the
commands and their results), **Risk** (what breaks if this is wrong, always-human paths touched,
Important findings left open), **How to revert** (the concrete undo and what it cannot undo) — and
the human confirms or edits them before it is opened. The agent drafts; the person signs off.
