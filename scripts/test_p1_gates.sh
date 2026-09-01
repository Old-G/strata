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
cd "$WORK" || exit 1

git init -q .
git config user.email test@strata.local
git config user.name "Strata Test"
mkdir -p docs raw wiki src scripts/lib scripts/hooks scripts/pre-commit
cp "$TPL/lib/pending_ingest.sh"                 scripts/lib/
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
