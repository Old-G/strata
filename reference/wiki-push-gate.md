# Wiring the wiki push gate (A2b)

`scripts/pre-commit/check_wiki_push.sh` refuses a push whose new commits change code
(`STRATA_PUSH_GATE_LINES`, default 20 lines outside `wiki/ raw/ docs/`) and never touch
`wiki/log.md`. It is a **git** hook, not a Claude Code one: it catches commits made by another
agent, an editor or by hand, which the Stop gate never sees. Install it only where the repo has
`wiki/log.md`.

## Wire it as `pre-push` — into what the repo already uses

Detect in this order and use the first that applies. **Chain, never replace:** an existing
`pre-push` (tests, lint) keeps running; add ours after it.

- **`core.hooksPath` is set** → in that directory, create `pre-push` with the wrapper below, or
  add ours to the existing one after its own checks, keeping their exit status (an `exec <check>`
  line becomes `<check> || exit $?`, or ours would never run).
- **The pre-commit framework** (`.pre-commit-config.yaml`) → add a local hook and make new clones
  install the type:

  ```yaml
  default_install_hook_types: [pre-commit, pre-push]   # keep any types already listed
  repos:
    - repo: local
      hooks:
        - id: strata-wiki-push-gate
          name: Wiki push gate
          entry: bash scripts/pre-commit/check_wiki_push.sh
          language: system
          stages: [pre-push]
          pass_filenames: false
          always_run: true
  ```

  If the config has no `default_stages`, add `default_stages: [pre-commit]` (and keep any stages
  already there) — otherwise every hook without `stages` also runs at push time. Then
  `pre-commit install --hook-type pre-push` — only that type.
- **husky** (`.husky/`) → `.husky/pre-push` with the wrapper body.
- **Nothing** → `.git/hooks/pre-push` with the wrapper (per clone, untracked — say so).

The wrapper — a missing script must never block a push:

```bash
#!/usr/bin/env bash
s="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/pre-commit/check_wiki_push.sh"
[ -f "$s" ] || exit 0
exec bash "$s" "$@"
```

## Verify

1. `bash scripts/strata_upgrade_check.sh <templates> scripts | grep 'UNWIRED  git pre-push'` prints
   nothing.
2. `git push --dry-run` runs the hook (git runs `pre-push` on a dry run too): on a branch whose
   unpushed commits carry code but no `wiki/log.md` line it is refused, otherwise it passes.
3. Escape for one push: `STRATA_SKIP_WIKI=1 git push` (or `--no-verify`).
