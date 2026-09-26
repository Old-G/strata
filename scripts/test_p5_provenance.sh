#!/usr/bin/env bash
# Behavioural test for P5 — provenance:
#   scripts/git-hooks/strata_commit_trailer.sh   (prepare-commit-msg: Agent-Session trailer)
#   scripts/strata_why.sh                    (blame → commit → trailer → local transcript)
#
# Same discipline as test_p1_gates.sh / test_p3_guards.sh: throwaway git repo,
# the real shipped scripts, no mocks. Branch name pinned (CI runners default to
# master; a mismatch here is a silent miss, not an error).
# See docs/superpowers/specs/2026-09-26-p5-provenance.md.
#
# Usage: bash scripts/test_p5_provenance.sh      (exit 0 = all green)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates/core/scripts"
pass=0; fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Isolation from THIS machine's Claude Code: since v0.9.0 SessionStart resolves the
# installed Strata plugin from ~/.claude/plugins and auto-syncs from it — a test
# fixture must never see the real plugin (it did, the day 0.9.0 was installed).
export CLAUDE_CONFIG_DIR="$WORK/.no-claude-config"
unset CLAUDE_PLUGIN_ROOT
cd "$WORK" || exit 1

# The test must not inherit the session it runs in — every case sets its own id.
unset CLAUDE_CODE_SESSION_ID STRATA_SKIP_TRAILER

A="aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa"
B="bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb"

git init -q repo && cd repo || exit 1
git config user.email test@strata.local
git config user.name "Strata Test"
git config core.hooksPath .githooks
git checkout -q -b main
mkdir -p scripts/git-hooks .githooks
cp "$TPL/git-hooks/strata_commit_trailer.sh" scripts/git-hooks/ 2>/dev/null
[ -f "$TPL/strata_why.sh" ] && cp "$TPL/strata_why.sh" scripts/
cp "$ROOT/.githooks/prepare-commit-msg" .githooks/prepare-commit-msg
chmod +x .githooks/prepare-commit-msg
git add -A && git commit -qm scaffolding

# trailer values on a revision, comma-joined, in message order
trailers() { git log -1 --format='%(trailers:key=Agent-Session,valueonly,separator=%x2C)' "${1:-HEAD}"; }
n_trailers() { git log -1 --format=%B "${1:-HEAD}" | grep -c '^Agent-Session:' || true; }
commit_as() { # <session-id|-> <file> <msg>
  local sid="$1"; shift
  echo "$RANDOM" >> "$1"; git add "$1"
  if [ "$sid" = "-" ]; then git commit -qm "$2"; else CLAUDE_CODE_SESSION_ID="$sid" git commit -qm "$2"; fi
}

echo "== T1: Agent-Session trailer =="
commit_as "$A" a.txt "from session A"
check "commit inside a session carries its id"         "$(trailers)" "$A"
check "…exactly once"                                   "$(n_trailers)" "1"

commit_as - h.txt "human commit"
check "commit outside a session carries nothing"        "$(n_trailers)" "0"

echo x >> h.txt; git add h.txt
CLAUDE_CODE_SESSION_ID="$A" STRATA_SKIP_TRAILER=1 git commit -qm "skipped"
check "STRATA_SKIP_TRAILER=1 skips the trailer"         "$(n_trailers)" "0"

commit_as "$A" a.txt "A again"
CLAUDE_CODE_SESSION_ID="$A" git commit -q --amend --no-edit
check "amend in the same session keeps one trailer"     "$(n_trailers)" "1"
CLAUDE_CODE_SESSION_ID="$B" git commit -q --amend --no-edit
check "amend from a second session adds its id"         "$(trailers)" "$A,$B"

echo y >> a.txt; git add a.txt
CLAUDE_CODE_SESSION_ID="$A" git commit -q -F - <<'MSG'
subject

Co-Authored-By: Someone <s@example.com>
MSG
check "joins an existing trailer block"                 "$(git log -1 --format='%(trailers:only,unfold)' | grep -c .)" "2"

for evil in 'x;touch pwned' 'a b' $'a\nAgent-Session: forged' '../../etc' '..' '-x' ''; do
  echo z >> a.txt; git add a.txt
  CLAUDE_CODE_SESSION_ID="$evil" git commit -qm "evil" 2>/dev/null
  rc=$?
  check "malformed id $(printf '%q' "$evil") → commit ok, no trailer" "$rc:$(n_trailers)" "0:0"
done
[ -e pwned ] && bad "an id was executed" || ok "no id was ever executed"
long="$(printf 'a%.0s' $(seq 1 129))"
echo z >> a.txt; git add a.txt
CLAUDE_CODE_SESSION_ID="$long" git commit -qm "long"
check "129-char id → no trailer"                        "$(n_trailers)" "0"

# Replays keep the ORIGINAL provenance: a rebase or cherry-pick run from session B
# must not stamp B onto commits that session A wrote.
git checkout -q -b feat
commit_as "$A" f1.txt "feat 1"
commit_as "$A" f2.txt "feat 2"
git checkout -q main
commit_as - m.txt "main moves"
git checkout -q feat
CLAUDE_CODE_SESSION_ID="$B" git rebase -q main 2>/dev/null
check "rebase from B: HEAD keeps A only"                "$(trailers HEAD)" "$A"
check "rebase from B: HEAD~1 keeps A only"              "$(trailers HEAD~1)" "$A"
git checkout -q main
CLAUDE_CODE_SESSION_ID="$B" git cherry-pick feat >/dev/null 2>&1
check "cherry-pick from B keeps A only"                 "$(trailers)" "$A"
git reset -q --hard HEAD~1
CLAUDE_CODE_SESSION_ID="$B" git merge -q --no-ff feat -m "merge feat" 2>/dev/null
check "merge from B is B's work"                        "$(trailers)" "$B"
CLAUDE_CODE_SESSION_ID="$B" git revert --no-edit HEAD~1 >/dev/null 2>&1 \
  || CLAUDE_CODE_SESSION_ID="$B" git revert --no-edit -m 1 HEAD >/dev/null 2>&1
check "revert from B is B's work"                       "$(trailers)" "$B"

git checkout -q main
echo v >> a.txt; git add a.txt
before="$(git rev-parse HEAD)"
CLAUDE_CODE_SESSION_ID="$A" GIT_EDITOR=true git commit -q 2>/dev/null
check "empty editor message still aborts (trailer does not rescue it)" "$(git rev-parse HEAD)" "$before"
CLAUDE_CODE_SESSION_ID="$A" GIT_EDITOR=true git commit -q -v 2>/dev/null
check "…also with -v (diff below the scissors)"         "$(git rev-parse HEAD)" "$before"
git commit -qm "human, then amended by the agent through the editor"
CLAUDE_CODE_SESSION_ID="$A" GIT_EDITOR=true git commit -q --amend
check "amend without -m (source=commit) gets the trailer" "$(trailers)" "$A"

git checkout -q -b multi
commit_as "$A" p1.txt "pick 1"
commit_as "$A" p2.txt "pick 2"
git checkout -q main
CLAUDE_CODE_SESSION_ID="$B" git cherry-pick multi~1 multi >/dev/null 2>&1
check "multi-pick from B: both keep A only"             "$(trailers HEAD~1)|$(trailers HEAD)" "$A|$A"

git worktree add -q "$WORK/wt" -b wt-branch main~2 2>/dev/null
(
  cd "$WORK/wt" || exit 1
  CLAUDE_CODE_SESSION_ID="$B" git cherry-pick multi >/dev/null 2>&1
  printf '%s' "$(git log -1 --format='%(trailers:key=Agent-Session,valueonly,separator=%x2C)')" > "$WORK/wt.out"
  echo q >> q.txt; git add q.txt; CLAUDE_CODE_SESSION_ID="$B" git commit -qm "B in a worktree"
  printf '|%s' "$(git log -1 --format='%(trailers:key=Agent-Session,valueonly,separator=%x2C)')" >> "$WORK/wt.out"
)
check "worktree: cherry-pick detected, plain commit stamped" "$(cat "$WORK/wt.out")" "$A|$B"

check "unwritable message file → exit 0" \
  "$(CLAUDE_CODE_SESSION_ID="$A" bash scripts/git-hooks/strata_commit_trailer.sh /nonexistent/msg message; echo $?)" "0"
check "no message-file argument → exit 0" \
  "$(CLAUDE_CODE_SESSION_ID="$A" bash scripts/git-hooks/strata_commit_trailer.sh; echo $?)" "0"

mv scripts/git-hooks/strata_commit_trailer.sh "$WORK/parked.sh"
echo w >> a.txt; git add a.txt
CLAUDE_CODE_SESSION_ID="$A" git commit -qm "hook script missing" 2>/dev/null
check "script absent → the wrapper still lets the commit through" "$?" "0"
mv "$WORK/parked.sh" scripts/git-hooks/strata_commit_trailer.sh

echo "== T2: strata_why.sh — blame → commit → trailer → transcript =="
cd "$WORK" || exit 1
git init -q why && cd why || exit 1
git config user.email test@strata.local
git config user.name "Strata Test"
git config core.hooksPath .githooks
git checkout -q -b main
mkdir -p scripts/git-hooks .githooks
cp "$TPL/git-hooks/strata_commit_trailer.sh" scripts/git-hooks/
cp "$TPL/strata_why.sh" scripts/ 2>/dev/null
cp "$ROOT/.githooks/prepare-commit-msg" .githooks/prepare-commit-msg
chmod +x .githooks/prepare-commit-msg

git add -A && git commit -qm scaffolding
export CLAUDE_CONFIG_DIR="$WORK/claude-home"
# Claude Code names a project dir after the session's cwd, every non-alnum → '-'.
SLUG="$(pwd -P | sed 's/[^A-Za-z0-9]/-/g')"
C="cccccccc-3333-4333-8333-cccccccccccc"
mkdir -p "$CLAUDE_CONFIG_DIR/projects/$SLUG/$A/subagents" "$CLAUDE_CONFIG_DIR/projects/-other-project"
HERE="$(pwd -P)"
printf '{"type":"queue-operation"}\n{"type":"user","cwd":"%s/sub"}\n' "$HERE" > "$CLAUDE_CONFIG_DIR/projects/$SLUG/$A.jsonl"
printf '{"type":"user","cwd":"%s"}\n' "$HERE" > "$CLAUDE_CONFIG_DIR/projects/$SLUG/$A/subagents/agent-1.jsonl"
# C ran in a SIBLING directory whose name merely starts with this repo's name.
printf '{"type":"user","cwd":"%s-sibling"}\n' "$HERE" > "$CLAUDE_CONFIG_DIR/projects/-other-project/$C.jsonl"

printf 'one\ntwo\n' > code.txt; git add code.txt
CLAUDE_CODE_SESSION_ID="$A" git commit -qm "agent writes lines 1-2"
sha_a="$(git rev-parse --short=12 HEAD)"
printf 'three\n' >> code.txt; git add code.txt
git commit -qm "human writes line 3"
sha_h="$(git rev-parse --short=12 HEAD)"
printf 'four\n' >> code.txt; git add code.txt
CLAUDE_CODE_SESSION_ID="$B" git commit -qm "agent B, transcript elsewhere"
sha_b="$(git rev-parse --short=12 HEAD)"
printf 'x\n' > other.txt; git add other.txt
CLAUDE_CODE_SESSION_ID="$C" git commit -qm "agent C, a session run from another project"
printf 'five\n' >> code.txt   # uncommitted

WHY=scripts/strata_why.sh
out="$(bash "$WHY" code.txt 2>&1)"
check "names the agent commit"                          "$(printf '%s' "$out" | grep -c "^commit $sha_a")" "1"
check "names the human commit"                          "$(printf '%s' "$out" | grep -c "^commit $sha_h")" "1"
check "session A resolves to its transcript"           "$(printf '%s' "$out" | grep -c "session $A · transcript $CLAUDE_CONFIG_DIR/projects/$SLUG/$A.jsonl")" "1"
check "…and names its subagent transcripts"            "$(printf '%s' "$out" | grep -c "subagents $CLAUDE_CONFIG_DIR/projects/$SLUG/$A/subagents")" "1"
check "session B: not on this machine"                 "$(printf '%s' "$out" | grep -c "session $B · transcript: not on this machine")" "1"
check "human commit: no Agent-Session"                 "$(printf '%s' "$out" | grep -A2 "^commit $sha_h" | grep -c 'no Agent-Session trailer')" "1"
check "uncommitted line is reported as such"            "$(printf '%s' "$out" | grep -c 'not committed yet')" "1"

out="$(bash "$WHY" other.txt 2>&1)"
check "a session from another project is named, not opened" "$(printf '%s' "$out" | grep -c "session $C · transcript: another project (-other-project) — not opened")" "1"
check "…and its path is never printed"                 "$(printf '%s' "$out" | grep -c "$C.jsonl")" "0"

out="$(bash "$WHY" code.txt -L 1,2 2>&1)"
check "-L 1,2 → only the agent commit"                  "$(printf '%s' "$out" | grep -c '^commit ')" "1"
check "-L 1,2 → it is A's"                              "$(printf '%s' "$out" | grep -c "^commit $sha_a")" "1"

git add code.txt; git commit -qm "line 5"
printf 'one\ntwo\n' > code.txt; git add code.txt; git commit -qm "drop 3-5"
out="$(bash "$WHY" code.txt 2>&1)"
check "blame alone no longer sees B's commit"           "$(printf '%s' "$out" | grep -c "^commit $sha_b")" "0"
out="$(bash "$WHY" code.txt --history 2>&1)"
check "--history finds B's commit again"                "$(printf '%s' "$out" | grep -c "^commit $sha_b")" "1"

git commit -q --allow-empty -m "forged" -m "Agent-Session: ../../../etc/passwd"
git mv code.txt moved.txt; git commit -qm "rename" -m "Agent-Session: ../../../etc/passwd"
out="$(bash "$WHY" moved.txt --history 2>&1)"
check "a forged trailer is reported, never resolved"   "$(printf '%s' "$out" | grep -c 'invalid Agent-Session value')" "1"
check "--history follows the rename to A's commit"     "$(printf '%s' "$out" | grep -c "^commit $sha_a")" "1"

git checkout -q -b sq
printf 'x\n' > sq.txt; git add sq.txt; CLAUDE_CODE_SESSION_ID="$A" git commit -qm "on a branch, by A"
git checkout -q main
git merge -q --squash sq >/dev/null 2>&1; git commit -q --no-edit
out="$(bash "$WHY" sq.txt 2>&1)"
check "squash merge by a human: A found in the body"    "$(printf '%s' "$out" | grep -c "session (from message body — squashed?) $A · transcript ")" "1"
check "…and not called a human commit"                  "$(printf '%s' "$out" | grep -c 'no Agent-Session trailer')" "0"

printf 'y\n' > prose.txt; git add prose.txt
git commit -qm "docs: explain the Agent-Session: trailer in prose"
out="$(bash "$WHY" prose.txt 2>&1)"
check "prose mention of 'Agent-Session:' mid-line → still reported as no trailer" "$(printf '%s' "$out" | grep -c 'no Agent-Session trailer')" "1"

bash "$WHY" nope.txt >/dev/null 2>&1; check "missing file → exit 2" "$?" "2"
bash "$WHY" >/dev/null 2>&1;          check "no args → exit 2"      "$?" "2"
check "read-only: the work tree is untouched"           "$(git status --porcelain | grep -c .)" "0"
unset CLAUDE_CONFIG_DIR

echo
echo "P5 provenance: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
