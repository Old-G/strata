---
title: PreToolUse guard (A5)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [enforcement-layer, raw-mirror-hook, session-start-injection, upgrade-path]
---

# PreToolUse guard (A5)

## TLDR

`scripts/hooks/strata_pre_tool_guard.sh` — a `PreToolUse` hook on `Edit|Write|MultiEdit` that
refuses a write **before it happens**: always under `raw/`, and to test files while a fix is in
progress. Exit 2 with the reason on stderr (the model reads it); exit 0 for everything else.

## Role

Two Strata rules were prose until v0.7.0. "Skills never hand-edit `raw/`" lived in `CLAUDE.md`
plus a pre-commit check that fires *after* the file is already wrong. "Fix the code, not the
test" lived in the TDD skill text. The AI-Native SDLC playbook names the missing piece exactly:
the skill makes violations rare, the hook makes them close to impossible — and build-phase hooks
belong on the action, not on the commit. This is the deterministic half of both rules.

## Current solutions

**Shipped in v0.7.0**, template in `templates/core/scripts/hooks/`, wired by the `PreToolUse`
block in `claude-settings-hook.json`; reaches adopted repos through [[upgrade-path]].

- **Rule (a) — `raw/` is a mirror.** Any write whose path resolves under `raw/` is refused with
  "edit the source under `docs/` instead". Escape for a deliberate one-off repair:
  `STRATA_ALLOW_RAW_EDIT=1`. Absolute paths are resolved physically first (macOS `/var` →
  `/private/var` while git reports the physical root — caught by the test suite, not by
  reasoning).
- **Rule (b) — tests read-only mid-fix.** While `.strata/guard-tests` exists, writes to test
  files (`tests/`, `test/`, `__tests__/`, `spec/`, `test_*.py`, `*_test.*`, `*.spec.*`,
  `*.test.*`, `*_spec.rb`, `*Test.java`, `*Tests.cs`) are refused. The first cut narrowed
  `*_test.*` to `.py`/`.go`; the [[diff-review]] dogfood run found `foo_test.dart`/`.ts`
  slipping through in a fixture and it was widened back to the spec's pattern. `feature`
  and `refactor` create the toggle at "make the failing test pass" and remove it once green;
  [[session-start-injection]] prints one warning line if a stale toggle survives into a new
  session. Escape: `rm .strata/guard-tests`.
- **Fail open, always:** unparseable payload, no `file_path`, a non-write tool, a directory that
  does not exist yet → exit 0. Bash only, `grep`/`sed` parsing — it fires on every write, so the
  Stop gate's no-`python3` rule applies. Measured allow path: 27 ms best-of-7.

Covered by `scripts/test_p3_guards.sh` (24 assertions) as `validate.sh` §12.

## Related

[[enforcement-layer]] · [[raw-mirror-hook]] · [[stop-gate]] · [[session-start-injection]] ·
[[upgrade-path]]

## Sources

[[sdlc-right-side]] D2
