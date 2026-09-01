---
title: Version stamp (which build is loaded)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [upgrade-path, session-start-injection, native-invocation]
---

# Version stamp (which build is loaded)

## TLDR

The running plugin's version is written into `skills/using-strata/SKILL.md` — in the
**description** (so it reaches every session's skill listing with no invocation and no shell) and
in the **body**. `scripts/validate.sh` §2c makes `.claude-plugin/plugin.json` the single source
and checks every other claim against it, in both directions: a stamp may not go stale, and it may
not go missing.

## Role

A session could not say which Strata build it had loaded. The question is not academic — it is
the first thing anyone asks after `/plugin update`: *did it actually update, and is the new one
what this chat is using?*

What existed answered a **different** question. `.strata/version` is the *repo* stamp — the
version of the `scripts/**` copied in at adoption time — and [[session-start-injection]] compares
it against `$CLAUDE_PLUGIN_ROOT`'s `plugin.json`, printing one line **only on a mismatch**. So
silence from that hook is not evidence: it is equally what you get when the versions agree, when
`.strata/version` does not exist (repo never adopted Strata), and when `CLAUDE_PLUGIN_ROOT` is
unset. Three different states, one indistinguishable quiet.

Off to the side, the version *was* recoverable on disk — but only by comparing what the cached
release directories contain. On 2026-09-01 the running build was pinned as 0.5.0 by the fact that
`skills/upgrade/` exists in `cache/strata/strata/0.5.0` and in neither 0.3.1 nor 0.4.0. That
works exactly once: the next release that ships no new skill is indistinguishable from its
predecessor by that method.

## Current solutions

**The description is the carrier.** It is the one plugin-side surface that reaches context
unconditionally — before any skill is invoked, in any repo, adopted or not. It also picks up the
matching triggers (`'which Strata version is running'`, «какая версия страты», «страта
обновилась?»), so the question routes to the page that answers it — consistent with
[[native-invocation]]'s rule that the description is the entire routing surface.

**The guard is what keeps it true.** A stamp that can drift is worse than none, because it is
believed. `validate.sh` §2c reads `plugin.json` and checks four claims against it:
`marketplace.json`, the `using-strata` description, the `using-strata` body, and `CLAUDE.md`'s
status line. It compares **every** `vX.Y.Z` token in those files, not the first one, so a
half-updated file fails rather than passing on its one correct mention — and it fails on a
*missing* stamp too, which is the failure mode a value-comparison alone would sleep through.

Bumping a release therefore touches: `plugin.json` · `marketplace.json` · `CLAUDE.md` ·
`using-strata` (×2) · `CHANGELOG.md`. Four of the five files are mechanically enforced; the
changelog is not, deliberately — prose about what shipped is not a version claim.

**Evidence.** 5 mutations, 5 killed: source bumped (all four dependents red at once) · stale
stamp in the description · deleted stamp in the body · lagging `marketplace.json` · `CLAUDE.md`
stripped of its version. Each mutation was verified present in the file before the run and each
restore diffed against the pre-mutation backup. Positive control: on the RED run — markers absent
— the guard named exactly the two missing stamps and stayed silent about `marketplace.json` and
`CLAUDE.md`, which already agreed.

## Related

[[upgrade-path]] · [[session-start-injection]] · [[native-invocation]]
