#!/usr/bin/env bash
# Behavioural test for the P1 enforcement layer (A1 Stop gate, A2 commit gate,
# A3 SessionStart injection) and the shared marker-retirement rule.
#
# Builds a throwaway git repo, installs the template scripts into it exactly as
# init/adopt would, and drives each gate through its real interface. No mocks —
# the scripts under test are the ones that ship.
#
# Usage: bash scripts/test_p1_gates.sh          (exit 0 = all green)

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

git init -q .
git config user.email test@strata.local
git config user.name "Strata Test"
mkdir -p docs raw wiki src scripts/lib scripts/hooks scripts/pre-commit
cp "$TPL/lib/pending_ingest.sh"                 scripts/lib/
cp "$TPL/lib/tree_snapshot.sh" scripts/lib/
cp "$TPL/hooks/strata_session_start.sh"         scripts/hooks/
cp "$TPL/hooks/strata_stop_gate.sh"             scripts/hooks/
cp "$TPL/pre-commit/check_wiki_fresh.sh"        scripts/pre-commit/
cp "$TPL/sync_raw_mirror.sh"                    scripts/
printf 'seed\n' > seed.txt
: > wiki/log.md
printf '.strata/\n' > .gitignore
git add -A >/dev/null && git commit -qm seed

GATE=scripts/hooks/strata_stop_gate.sh
START=scripts/hooks/strata_session_start.sh
COMMITGATE=scripts/pre-commit/check_wiki_fresh.sh

new_session() { rm -rf .strata; echo "{\"session_id\":\"$1\"}" | bash "$START" >/dev/null 2>&1; }
stop_gate()   { echo "{\"session_id\":\"$1\"${2:-}}" | bash "$GATE" 2>/dev/null; }
# "blocked" / "clear" — never inspect the JSON text, only the decision.
verdict() {
  local out; out="$(stop_gate "$1" "${2:-}")"
  [ -z "$out" ] && { echo clear; return; }
  printf '%s' "$out" | python3 -c "
import json,sys
try: print('blocked' if json.load(sys.stdin).get('decision')=='block' else 'clear')
except Exception: print('malformed')
"
}

echo "== marker retirement rule (D1) =="
printf -- '- pending_ingest: docs/a.md (mirrored)\n' > wiki/log.md
check "open marker counts as outstanding" "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "1"
echo '[ts] ingest raw/a.md → created: sources/a.md' >> wiki/log.md
check "later ingest line retires it" "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "0"
printf -- '- pending_ingest: docs/a.md (mirrored)\n' >> wiki/log.md
check "re-edit after ingest reopens it" "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "1"
printf 'prose mentioning pending_ingest: docs/b.md mid-sentence\n' >> wiki/log.md
check "prose mentioning the token is ignored" "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "1"
# Upstreamed from app-b (found 2026-09-05: 32 reported outstanding, 31 real):
# a marker whose value is not a docs/*.md path is prose, and nothing could ever retire it.
printf -- '- pending_ingest: all 28 raw/*.md await the first ingest\n' >> wiki/log.md
check "a non-doc marker value is not a path (no phantom)" "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "1"

: > wiki/log.md
printf -- '- pending_ingest: docs/c.md (mirrored)\n- pending_ingest: docs/d.md (mirrored)\n' > wiki/log.md
echo '[ts] ingest raw/c.md, raw/d.md -> created: sources/c.md, sources/d.md; updated: index.md.' >> wiki/log.md
check "a multi-path ingest line retires every listed path, not just the first" \
  "$(bash scripts/lib/pending_ingest.sh | wc -l | tr -d ' ')" "0"

echo "== A3 SessionStart injection =="
: > wiki/log.md
printf -- '- pending_ingest: docs/a.md (mirrored)\n' > wiki/log.md
printf '| [[thing]] | a thing |\n' > wiki/index.md
new_session s-a3
out="$(echo '{"session_id":"s-a3"}' | bash "$START")"
check "context block stays within the 50-line budget" \
  "$([ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -le 50 ] && echo yes || echo no)" "yes"
check "names the branch"        "$(printf '%s' "$out" | grep -c '^Branch:')" "1"
check "lists the pending doc"   "$(printf '%s' "$out" | grep -c '^  - docs/a.md$')" "1"
check "carries the wiki-first rule" "$(printf '%s' "$out" | grep -c 'wiki/index.md first')" "1"
check "writes the session stamp" "$([ -f .strata/sessions/s-a3.start ] && echo yes || echo no)" "yes"
check "session_id cannot escape the directory" \
  "$(echo '{"session_id":"../../pwned"}' | bash "$START" >/dev/null 2>&1; [ -f ../../pwned.start ] && echo escaped || echo contained)" "contained"

echo "== A1 Stop gate — loop safety =="
new_session s1
check "stop_hook_active=true exits without blocking" "$(verdict s1 ',"stop_hook_active":true')" "clear"
rm -rf .strata
check "no session stamp fails open" "$(verdict s1)" "clear"

echo "== A1 Stop gate — trigger (a): markers from THIS session =="
: > wiki/log.md; new_session s2
printf -- '- pending_ingest: docs/new.md (mirrored)\n' >> wiki/log.md
check "blocks on a marker created this session" "$(verdict s2)" "blocked"
check "never blocks twice in one session"       "$(verdict s2)" "clear"

printf -- '- pending_ingest: docs/old.md (mirrored)\n' > wiki/log.md
new_session s3   # stamp taken AFTER the marker exists
check "ignores markers older than the session (ADR #4)" "$(verdict s3)" "clear"
# The commit gate has no session scope — the same marker the Stop gate waved
# through must still stop the commit. It judges the STAGED log, so stage it.
git add wiki/log.md >/dev/null
check "commit gate still catches that old marker" \
  "$(bash "$COMMITGATE" >/dev/null 2>&1; echo $?)" "1"

echo "== A1 Stop gate — trigger (b): code-only drift =="
: > wiki/log.md; new_session s4
python3 -c "print('x = 1\n' * 120, end='')" > src/big.py
check "blocks a big code-only change with a silent wiki" "$(verdict s4)" "blocked"
new_session s5
echo 'no-wiki-impact: generated fixture' >> wiki/log.md
check "one wiki/log.md line satisfies it"   "$(verdict s5)" "clear"
new_session s6
check "STRATA_STOP_GATE_LINES=0 disables the trigger" \
  "$(echo '{"session_id":"s6"}' | STRATA_STOP_GATE_LINES=0 bash "$GATE" 2>/dev/null | grep -c . | tr -d ' ')" "0"
rm -f src/big.py; new_session s7
check "small changes stay below the threshold" "$(verdict s7)" "clear"
# v0.16.4: the default threshold is 20 lines (was 50 — a 40-line fix left no trace).
new_session s7b
python3 -c "print('t = 1\n' * 25, end='')" > src/mid.py
check "25 changed lines → blocked (default threshold 20)" "$(verdict s7b)" "blocked"
rm -f src/mid.py; new_session s7c
python3 -c "print('t = 1\n' * 10, end='')" > src/tiny.py
check "10 changed lines → clear (below the default)" "$(verdict s7c)" "clear"
rm -f src/tiny.py

# (b) is about THIS session's code. Uncommitted work that was already in the tree
# when the session started is not this session's change (seen in P5: a fresh
# headless session was blocked for a ~36k-line diff it never touched).
: > wiki/log.md
python3 -c "print('y = 2\n' * 120, end='')" > src/old.py
new_session s9
check "pre-existing uncommitted code → not this session's (clear)" "$(verdict s9)" "clear"
new_session s10
python3 -c "print('y = 2\n' * 180, end='')" > src/old.py
check "a pre-existing file edited again this session → counted (blocked)" "$(verdict s10)" "blocked"
new_session s11
python3 -c "print('z = 3\n' * 120, end='')" > src/new.py
check "pre-existing dirt + a new big file this session → blocked" "$(verdict s11)" "blocked"
rm -f src/new.py; new_session s12
rm -f .strata/sessions/s12.dirty
check "no start snapshot (older SessionStart) → whole-tree fallback (blocked)" "$(verdict s12)" "blocked"
rm -f src/old.py

# Review round 2. A file dirty before the session and touched again is billed for
# the CHANGE to its diff, not the whole diff (else the 36k-line case comes back
# the moment the session edits one of those files).
python3 -c "print('w = 4\n' * 3000, end='')" > src/old.py   # 3000 lines, pre-existing, uncommitted
new_session s13
python3 -c "print('w = 4\n' * 2999 + 'w = 5\n', end='')" > src/old.py
check "pre-dirty file, 1-line re-edit → billed the delta (clear)" "$(verdict s13)" "clear"
rm -f src/old.py

# Non-ASCII paths (git quotes them by default — core.quotePath).
python3 -c "print('u = 1\n' * 120, end='')" > "src/ünï file.py"
new_session s14
check "pre-existing non-ASCII file → clear"            "$(verdict s14)" "clear"
new_session s15
python3 -c "print('u = 1\n' * 240, end='')" > "src/ünï file.py"
check "non-ASCII file grown this session → blocked"    "$(verdict s15)" "blocked"
rm -f "src/ünï file.py"

# Thousands of pre-existing untracked files: the Stop gate must stay fast
# (BSD grep -f is quadratic — measured 9 s at 5k lines).
mkdir -p src/many && for i in $(seq 1 3000); do echo "$i" > "src/many/f$i.txt"; done
new_session s16
t0=$(date +%s%N); v="$(verdict s16)"; t1=$(date +%s%N)
check "3000 pre-existing dirty files: clear, Stop < 1500 ms ($(( (t1 - t0) / 1000000 )) ms)" \
  "$v:$([ $(( (t1 - t0) / 1000000 )) -lt 1500 ] && echo fast || echo slow)" "clear:fast"
# Past STRATA_SNAPSHOT_MAX dirty files the snapshot is skipped and (b) fails OPEN
# for that session rather than billing it for the whole tree.
: > wiki/log.md
STRATA_SNAPSHOT_MAX=100 bash -c "rm -rf .strata; echo '{\"session_id\":\"s17\"}' | bash '$START'" >/dev/null 2>&1
check "over STRATA_SNAPSHOT_MAX → (b) fails open (clear)" "$(verdict s17)" "clear"
rm -rf src/many

# v0.16.3: an agent that COMMITS its code before it stops leaves a clean tree —
# (b) used to see 0 lines exactly when it mattered. Committed lines count too:
# commits in <start HEAD>..HEAD, no merges, committer time >= session start.
# Own fixture repo, outside the main one: these tests make commits, and the
# A2/e2e checks below count the main fixture's commits.
echo "== A1 Stop gate — trigger (b): code committed this session =="
WORK_C="$(mktemp -d)"
trap 'rm -rf "$WORK" "$WORK_C"' EXIT
cd "$WORK_C" || exit 1
git init -q . && git config user.email test@strata.local && git config user.name "Strata Test"
mkdir -p src docs wiki scripts/lib scripts/hooks
cp "$TPL/lib/pending_ingest.sh" "$TPL/lib/tree_snapshot.sh" scripts/lib/
cp "$TPL/hooks/strata_session_start.sh" "$TPL/hooks/strata_stop_gate.sh" scripts/hooks/
printf 'seed\n' > seed.txt; : > wiki/log.md; printf '.strata/\n' > .gitignore
git add -A >/dev/null && git commit -qm seed
lines() { python3 -c "print('$2\n' * $3, end='')" > "$1"; }
commit_all() { git add -A >/dev/null && git commit -q --no-verify -m "$1" >/dev/null 2>&1; }

new_session c0
check "the session stamp records the starting commit" \
  "$(grep -c "^HEAD=$(git rev-parse HEAD)$" .strata/sessions/c0.start)" "1"

new_session c1
lines src/feat.py 'a = 1' 120; commit_all "feat"
check "code committed this session, tree clean, wiki silent → blocked" "$(verdict c1)" "blocked"

new_session c2
lines src/feat2.py 'b = 2' 120; echo 'feat2: what changed and why' >> wiki/log.md; commit_all "feat2"
check "committed code + a committed wiki/log.md line → clear" "$(verdict c2)" "clear"

new_session c3
lines src/half.py 'c = 3' 30; commit_all "half"
lines src/other.py 'c = 4' 30
check "committed + uncommitted lines are summed (30+30 → blocked)" "$(verdict c3)" "blocked"
commit_all "other"

new_session c4
lines src/theirs.py 'd = 4' 120
git add -A >/dev/null
GIT_AUTHOR_DATE='2001-01-01T00:00:00Z' GIT_COMMITTER_DATE='2001-01-01T00:00:00Z' \
  git commit -q --no-verify -m "pulled from someone else" >/dev/null 2>&1
check "a commit dated before the session (pulled in) is not billed → clear" "$(verdict c4)" "clear"

new_session c5
lines docs/guide.md 'prose' 120; commit_all "docs only"
check "committed docs/ lines are excluded like uncommitted ones → clear" "$(verdict c5)" "clear"

new_session c6
git checkout -q -b side HEAD~1
lines src/side.py 'e = 5' 120; commit_all "side"
check "start HEAD not an ancestor of HEAD (branch switch) → committed part skipped (clear)" "$(verdict c6)" "clear"
git checkout -q -

new_session c7
grep -v '^HEAD=' .strata/sessions/c7.start > .strata/sessions/c7.tmp && mv .strata/sessions/c7.tmp .strata/sessions/c7.start
lines src/legacy.py 'f = 6' 120; commit_all "legacy"
check "stamp without HEAD= (older SessionStart) → committed part skipped (clear)" "$(verdict c7)" "clear"

# The gate reads HEAD with builtins on the plain layout; packed refs and linked
# worktrees take the other paths and must reach the same verdict.
new_session c8
lines src/packed.py 'g = 7' 120; commit_all "packed"; git pack-refs --all --prune
check "HEAD's ref only in packed-refs → still counted (blocked)" "$(verdict c8)" "blocked"
git worktree add -q -b wt-branch "$WORK_C/wt" >/dev/null 2>&1
cd "$WORK_C/wt" || exit 1
new_session c9
lines src/in_worktree.py 'h = 8' 120; commit_all "in a worktree"
check "code committed in a linked worktree → blocked" "$(verdict c9)" "blocked"

# v0.16.4 trigger (e): the session wrote the wiki but left it uncommitted while its
# code is committed (or there is no code left to commit). mtime decides what this
# session touched, so each case waits a second past its stamp.
echo "== A1 Stop gate — trigger (e): wiki left uncommitted =="
cd "$WORK_C" || exit 1
git worktree remove --force "$WORK_C/wt" >/dev/null 2>&1
mkdir -p wiki/entities
new_session e1; sleep 1
lines src/e1.py 'i = 1' 5; commit_all "small code"
echo 'e1: what changed' >> wiki/log.md; echo '# page' > wiki/entities/e1.md
check "code committed, wiki written but uncommitted → blocked" "$(verdict e1)" "blocked"
commit_all "wiki for e1"

new_session e2; sleep 1
lines src/e2.py 'j = 1' 5
echo 'e2: work in progress' >> wiki/log.md
check "wiki and code both uncommitted (work in progress) → clear" "$(verdict e2)" "clear"
commit_all "e2"

new_session e3; sleep 1
echo 'e3: wiki-only session' >> wiki/log.md
check "wiki-only session, nothing committed, no code dirty → blocked" "$(verdict e3)" "blocked"
commit_all "e3"

new_session e4; sleep 1
lines src/e4.py 'k = 1' 5; echo 'e4: committed together' >> wiki/log.md; commit_all "e4 code + wiki"
check "code and wiki committed together → clear" "$(verdict e4)" "clear"

echo '# old notes' > wiki/entities/old.md; sleep 1
new_session e5; sleep 1
lines src/e5.py 'l = 1' 5; echo 'e5: line' >> wiki/log.md; commit_all "e5"
git rm -q --cached wiki/entities/old.md >/dev/null 2>&1
check "wiki dirt older than the session is not its debt → clear" "$(verdict e5)" "clear"
rm -f wiki/entities/old.md

new_session e6
lines src/e6.py 'm = 1' 5; commit_all "e6 code, wiki untouched"
check "log not written this session → (e) stays out of it (clear)" "$(verdict e6)" "clear"

echo "== A2b push gate =="
WORK_P="$(mktemp -d)"
trap 'rm -rf "$WORK" "$WORK_C" "$WORK_P"' EXIT
git init -q --bare "$WORK_P/remote.git"
git clone -q "$WORK_P/remote.git" "$WORK_P/clone" 2>/dev/null
cd "$WORK_P/clone" || exit 1
git config user.email test@strata.local && git config user.name "Strata Test"
mkdir -p src wiki scripts/pre-commit
cp "$TPL/pre-commit/check_wiki_push.sh" scripts/pre-commit/
cp "$ROOT/.githooks/pre-push" .git/hooks/pre-push && chmod +x .git/hooks/pre-push
echo 'seed' > wiki/log.md; git add -A >/dev/null && git commit -qm seed && git push -q origin HEAD:main 2>/dev/null
git branch -q -u origin/main 2>/dev/null
remote_head() { git --git-dir="$WORK_P/remote.git" rev-parse "${1:-main}" 2>/dev/null; }
push_ok() { git push -q origin "${1:-HEAD:main}" >/dev/null 2>&1 && echo pushed || echo refused; }

lines src/p1.py 'n = 1' 30; git add -A >/dev/null; git commit -qm "code only"
check "30 lines of code, no wiki/log.md in the pushed commits → refused" "$(push_ok)" "refused"
check "the remote did not move" "$(remote_head)" "$(git rev-parse HEAD~1)"
check "the refusal names the line count" \
  "$(git push origin HEAD:main 2>&1 | grep -c 'carries ~30 lines of code')" "1"
echo 'p1: what changed' >> wiki/log.md; git add -A >/dev/null; git commit -qm "wiki"
check "a pushed commit touching wiki/log.md satisfies it → pushed" "$(push_ok)" "pushed"
lines src/p2.py 'o = 1' 30; git add -A >/dev/null; git commit -qm "code again"
check "STRATA_SKIP_WIKI=1 bypasses it" \
  "$(STRATA_SKIP_WIKI=1 git push -q origin HEAD:main >/dev/null 2>&1 && echo pushed || echo refused)" "pushed"
lines src/p3.py 'p = 1' 10; git add -A >/dev/null; git commit -qm "small"
check "10 lines → below the default threshold → pushed" "$(push_ok)" "pushed"
lines src/p4.py 'q = 1' 30; git add -A >/dev/null; git commit -qm "big"
check "STRATA_PUSH_GATE_LINES=0 disables it" \
  "$(STRATA_PUSH_GATE_LINES=0 git push -q origin HEAD:main >/dev/null 2>&1 && echo pushed || echo refused)" "pushed"
git checkout -q -b feature
lines src/p5.py 'r = 1' 30; git add -A >/dev/null; git commit -qm "feature code"
check "a new branch (remote sha all zeros) is judged too → refused" "$(push_ok feature)" "refused"
git tag v-test
check "a tag push passes" "$(push_ok v-test)" "pushed"
check "pre-commit framework env (FROM/TO refs) → refused" \
  "$(PRE_COMMIT_FROM_REF="$(git rev-parse main)" PRE_COMMIT_TO_REF="$(git rev-parse HEAD)" \
     bash scripts/pre-commit/check_wiki_push.sh >/dev/null 2>&1; echo $?)" "1"
check "upgrade check: a wired pre-push is not reported" \
  "$(bash "$TPL/strata_upgrade_check.sh" "$TPL" scripts 2>/dev/null | grep -c '^UNWIRED  git pre-push')" "0"
mv .git/hooks/pre-push .git/hooks/pre-push.off
check "upgrade check: an unwired push gate is reported" \
  "$(bash "$TPL/strata_upgrade_check.sh" "$TPL" scripts 2>/dev/null | grep -c '^UNWIRED  git pre-push')" "1"
mv .git/hooks/pre-push.off .git/hooks/pre-push
rm -f wiki/log.md
check "a repo without wiki/log.md is out of scope" \
  "$(bash scripts/pre-commit/check_wiki_push.sh origin </dev/null >/dev/null 2>&1; echo $?)" "0"
cd "$WORK" || exit 1

echo "== A1 Stop gate — performance =="
: > wiki/log.md; new_session s8
# Best-of-N, not the mean: the question is whether this code path CAN clear
# 100ms, and a single stolen timeslice should not turn CI red. A mean over 5
# runs was observed failing ~1 in 6 at 113ms on an otherwise idle machine.
best=999999
for _ in 1 2 3 4 5 6 7; do
  t0=$(date +%s%N); stop_gate s8 >/dev/null; t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 ))
  [ "$ms" -lt "$best" ] && best="$ms"
done
check "clean-state fast path stays under 100ms (best of 7: ${best}ms)" \
  "$([ "$best" -lt 100 ] && echo yes || echo no)" "yes"

echo "== A2 commit gate =="
: > wiki/log.md
printf -- '- pending_ingest: docs/c.md (mirrored)\n' > wiki/log.md
git add -A >/dev/null
check "fails the commit while a marker is outstanding" "$(bash "$COMMITGATE" >/dev/null 2>&1; echo $?)" "1"
check "names the file to ingest" "$(bash "$COMMITGATE" 2>/dev/null | grep -c 'wiki-ingest raw/c.md')" "1"
check "STRATA_SKIP_WIKI=1 is an escape hatch" \
  "$(STRATA_SKIP_WIKI=1 bash "$COMMITGATE" >/dev/null 2>&1; echo $?)" "0"
echo '[ts] ingest raw/c.md → created: sources/c.md' >> wiki/log.md
check "ingesting without staging wiki/ still fails" "$(bash "$COMMITGATE" >/dev/null 2>&1; echo $?)" "1"
git add wiki/log.md
check "ingesting AND staging passes"                "$(bash "$COMMITGATE" >/dev/null 2>&1; echo $?)" "0"

echo "== end-to-end: a real commit is blocked, then allowed =="
cp "$ROOT/.githooks/pre-commit" .git/hooks/pre-commit 2>/dev/null && chmod +x .git/hooks/pre-commit
printf '# doc\n' > docs/e2e.md
bash scripts/sync_raw_mirror.sh docs/e2e.md >/dev/null 2>&1
git add -A >/dev/null
git commit -qm "should be blocked" >/dev/null 2>&1
check "git commit refused while the wiki is behind" "$(git log --oneline | wc -l | tr -d ' ')" "1"
echo '[ts] ingest raw/e2e.md → created: sources/e2e.md' >> wiki/log.md
git add -A >/dev/null
git commit -qm "should land" >/dev/null 2>&1
check "git commit lands once the ingest is recorded" "$(git log --oneline | wc -l | tr -d ' ')" "2"

echo
echo "P1 gates: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
