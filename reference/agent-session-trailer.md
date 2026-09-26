# Installing the Agent-Session trailer (P5)

One canonical install procedure, referenced by `init`, `adopt` and `upgrade`. What it is and
why: `docs/superpowers/specs/2026-09-26-p5-provenance.md`.

## 1. Ask first — it is visible in history

One question, before wiring anything: *"Every commit made from inside a Claude Code session
will carry an `Agent-Session: <uuid>` trailer. It lets `strata_why.sh` trace code back to the
session that wrote it; the transcript itself never leaves this machine. The trailer is visible
in git history — in a public repo it shows which commits were agent-made. Wire it?"*
Default yes. On no: still copy the scripts (so `/strata:upgrade` stays clean), do not wire the
hook, run `git config strata.trailer declined` (so `upgrade` never asks this clone again), and
note "trailer declined" in the adoption report. `STRATA_SKIP_TRAILER=1` skips a
single commit either way.

## 2. Copy

From `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/`, preserving the layout, `chmod +x`:
`git-hooks/strata_commit_trailer.sh` → `scripts/git-hooks/strata_commit_trailer.sh`,
`strata_why.sh` → `scripts/strata_why.sh`. The git hook lives in `git-hooks/`, not `hooks/`,
on purpose — `hooks/` holds Claude Code hooks registered in `.claude/settings.json`, and this
one must never be registered there.

## 3. Wire it as `prepare-commit-msg` — into what the repo already uses

Detect, in this order, and use the first that applies. **Chain, never replace:** if a
`prepare-commit-msg` already exists (commitizen, a ticket-number prefixer), keep it and add
ours after it.

- **`core.hooksPath` is set** (`git config core.hooksPath`) → in that directory, create or
  extend `prepare-commit-msg` with the fail-open wrapper below.
- **The pre-commit framework** (`.pre-commit-config.yaml`) → add a local hook, and make new
  clones install that hook type too, or it silently does nothing there:

  ```yaml
  default_install_hook_types: [pre-commit, prepare-commit-msg]
  default_stages: [pre-commit]   # REQUIRED: without it every hook that has no `stages`
                                 # (gitleaks, ruff, …) ALSO runs at prepare-commit-msg — twice per commit
  repos:
    - repo: local
      hooks:
        - id: strata-agent-session-trailer
          name: Agent-Session trailer
          entry: bash -c 'bash scripts/git-hooks/strata_commit_trailer.sh "$@" || true' --
          language: system
          stages: [prepare-commit-msg]
          always_run: true
  ```

  then `pre-commit install --hook-type prepare-commit-msg` — only that type: if the repo's own
  pre-commit gates were never installed, installing them now changes its behaviour; say so, don't.
  If the config already sets `default_stages`, keep it and make sure it does not include
  `prepare-commit-msg`.
- **husky** (`.husky/`) → `.husky/prepare-commit-msg` with the wrapper body.
- **Nothing** → `.git/hooks/prepare-commit-msg` with the wrapper (per clone, untracked — say so).

The wrapper — it must fail open on every path. git does **not** skip `prepare-commit-msg`
under `--no-verify`, so a hook that can abort leaves no escape short of deleting it:

```bash
#!/usr/bin/env bash
s="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/git-hooks/strata_commit_trailer.sh"
[ -f "$s" ] && bash "$s" "$@" || true
exit 0
```

## 4. Verify — with the real session, not a hand-set variable

1. `echo "${CLAUDE_CODE_SESSION_ID:-unset}"` in this session. If `unset`, this Claude Code
   build does not export the id: the hook is inert (no trailers, nothing breaks) — say so
   plainly instead of reporting success.
2. Make the adoption commit from this session, then
   `git log -1 --format='%(trailers:key=Agent-Session,valueonly)'` must print that id.
3. `bash scripts/strata_why.sh <a file from that commit>` names the commit and resolves the
   session to its transcript.
