#!/usr/bin/env bash
# Strata P5 — Agent-Session commit trailer (a prepare-commit-msg hook).
#
# Appends `Agent-Session: <id>` to every commit made from inside a Claude Code
# session, so `git blame` → commit → trailer → session transcript can later answer
# "why does this code exist" with evidence (scripts/strata_why.sh walks that chain).
# Borrowed from devdotfast/whiteboard's trace capture, minus its hosted store: the
# transcript never leaves this machine — the trailer is only a pointer to it.
#
# Where the id comes from: Claude Code exports CLAUDE_CODE_SESSION_ID to every Bash
# tool call, and git hooks inherit the environment. No variable → the commit was
# not made by an agent session → no trailer. That is the whole attribution rule;
# there is no "active sessions" file to go stale.
#
# Rules (docs/superpowers/specs/2026-09-26-p5-provenance.md):
#   D2  never blocks a commit — exit 0 on every path
#   D3  the id is validated, never "cleaned" into something that looks real
#   D4  replays keep their original provenance: no trailer during a rebase or a
#       cherry-pick (git runs this hook for every replayed pick); merge, revert
#       and amend are new work by this session and do get one
#   D1  STRATA_SKIP_TRAILER=1 skips one commit
#
# Install: as the repo's prepare-commit-msg hook (core.hooksPath dir, the
# pre-commit framework's prepare-commit-msg stage, husky, or .git/hooks) — it takes
# git's own arguments: <message-file> [<source> [<sha>]].

msg_file="${1:-}"
[ -n "$msg_file" ] && [ -f "$msg_file" ] && [ -w "$msg_file" ] || exit 0
[ "${STRATA_SKIP_TRAILER:-}" = "1" ] && exit 0

id="${CLAUDE_CODE_SESSION_ID:-}"
# D3 — whole-value match; a newline anywhere fails it (grep would match per line).
case "$id" in
  "" | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) exit 0 ;;
esac
[ "${#id}" -le 128 ] || exit 0

# An empty message must still abort the commit. The trailer would make it non-empty
# and git would commit a message that is nothing but "Agent-Session: …". Cut at the
# `git commit -v` scissors line, then drop comment lines (stripspace honours
# core.commentChar).
if [ -z "$(sed '/^. -\{24\} >8 -\{24\}$/,$d' "$msg_file" | git stripspace --strip-comments 2>/dev/null)" ]; then
  exit 0
fi

# D4 — git-path resolves per worktree.
for marker in rebase-merge rebase-apply CHERRY_PICK_HEAD; do
  p="$(git rev-parse --git-path "$marker" 2>/dev/null)" || exit 0
  [ -e "$p" ] && exit 0
done

git interpret-trailers --in-place --if-exists addIfDifferent \
  --trailer "Agent-Session: $id" "$msg_file" >/dev/null 2>&1 || true
exit 0
