# REVIEW.md and the review loop — plan (v0.18.0)

**Source:** Anthropic, "How the Claude Code team does code review" — the owner-written REVIEW.md,
Important / Nit / Pre-existing labels, the bug class instead of one line, no repeats, three rounds
then "reconsider the approach", diff-only re-review, and a PR template with Testing / Risk / How to
revert that the agent drafts and the person signs off.

**Intent:** the branch review in any Strata repo knows what *broken* means to the owner, keeps what
this branch broke apart from what was there before it, stops after three rounds, and every PR says
how it was tested, what it risks and how to undo it.

**Success criterion:** `bash scripts/test_p7_review.sh` green (red first), `bash scripts/validate.sh`
PASSED; adopt on a throwaway copy of a small repo drafts a REVIEW.md; `strata-diff-review` on a test
branch with a planted old bug prints labels and a summary that opens with the count.

## Tasks

1. **`templates/core/REVIEW.md.tmpl`** — 5–15 lines the owner writes: what broken means here, the
   nit cap, skip paths, always-human paths, `file:line` evidence, the count-first summary.
   verify: test_p7 checks it exists, has each rule, and is ≤ 15 non-empty lines.
2. **`scripts/lib/line_origin.sh`** (template + this repo's copy) — `PRE-EXISTING | BRANCH |
   UNCOMMITTED | UNKNOWN` per `file:line[-end]` from plain `git blame` and `merge-base
   --is-ancestor`. verify: test_p7 fixture repo, each outcome.
3. **`state_tools.py review-round <branch>`** — the round counter in branch state (`review:
   {rounds, head}`), cap 3 (exit 3), `--reset` after the human reconsiders. verify: test_p7.
4. **`strata-diff-review`** — reads REVIEW.md, labels Important / Nit / Pre-existing (line_origin),
   one row per bug class with every location, no repeats across rounds, round ≥ 2 reviews only the
   new diff, output opens with the count. verify: test_p7 structural checks + a live run on a test
   branch.
5. **eng / cso / design reviewers** — the same rules where they apply to a plan. verify: test_p7.
6. **`light-finish`** — round loop through `review-round` (cap → ask "reconsider the approach?"),
   PR body with Testing / Risk / How to revert drafted by the agent, confirmed by the human.
7. **`adopt` / `init`** draft REVIEW.md from the repo and show it for approval; `upgrade` offers a
   draft where none exists; `line_origin.sh` joins the installed scripts.
8. **Docs + release** — README, wiki entity, `reference/review-md.md`, Strata's own REVIEW.md,
   CHANGELOG, version 0.18.0 everywhere, `scripts.history` regenerated.

## Not in scope

- A per-repo round cap or labels beyond the three — the article's numbers stand until a repo asks.
- Auto-writing REVIEW.md into existing projects: it is the owner's file; upgrade only offers.
