#!/usr/bin/env bash
# Behavioural test for P3 / A5 — the PreToolUse guard and its toggle lifecycle:
#   scripts/hooks/strata_pre_tool_guard.sh   (rule a: raw/ mirror; rule b: tests read-only mid-fix)
#   SessionStart warning when .strata/guard-tests is left behind
#
# Same discipline as test_p1_gates.sh / test_p2_state.sh: throwaway git repo,
# the real shipped scripts, no mocks. Branch name pinned (CI runners default to
# master; a mismatch here is a silent miss, not an error).
# See docs/superpowers/specs/2026-09-01-sdlc-right-side.md, D2.
#
# Usage: bash scripts/test_p3_guards.sh          (exit 0 = all green)

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
git checkout -q -b main
mkdir -p docs raw wiki src tests scripts/lib scripts/hooks
cp "$TPL/lib/pending_ingest.sh"          scripts/lib/
cp "$TPL/lib/state_tools.py"             scripts/lib/
cp "$TPL/hooks/strata_session_start.sh"  scripts/hooks/
cp "$TPL/hooks/strata_pre_tool_guard.sh" scripts/hooks/
printf 'seed\n' > seed.txt
: > wiki/log.md
printf '.strata/*\n!.strata/state/\n' > .gitignore
git add -A >/dev/null && git commit -qm seed

GUARD=scripts/hooks/strata_pre_tool_guard.sh
START=scripts/hooks/strata_session_start.sh

# exit code of the guard for a synthetic PreToolUse payload
guard() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" | bash "$GUARD" 2>/dev/null; echo $?; }
reason(){ printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" | bash "$GUARD" 2>&1 >/dev/null; }

echo "== rule (a): raw/ is a mirror =="
check "Edit under raw/ is refused (exit 2)"        "$(guard Edit raw/x.md)" "2"
check "Write under nested raw/ is refused"          "$(guard Write raw/deep/y.md)" "2"
check "absolute path under raw/ is refused"         "$(guard Edit "$WORK/raw/z.md")" "2"
check "the refusal names the escape hatch"          "$(reason Edit raw/x.md | grep -c STRATA_ALLOW_RAW_EDIT)" "1"
check "STRATA_ALLOW_RAW_EDIT=1 lets it through"     "$(STRATA_ALLOW_RAW_EDIT=1 guard Edit raw/x.md)" "0"
check "docs/ edit is allowed"                       "$(guard Edit docs/x.md)" "0"
check "a file merely named raw-notes.md is allowed" "$(guard Edit docs/raw-notes.md)" "0"

echo "== rule (b): tests read-only while .strata/guard-tests exists =="
check "test file, no toggle: allowed"               "$(guard Edit tests/test_a.py)" "0"
mkdir -p .strata && : > .strata/guard-tests
check "tests/ dir, toggle set: refused"             "$(guard Edit tests/test_a.py)" "2"
check "*.spec.ts, toggle set: refused"              "$(guard Write src/thing.spec.ts)" "2"
check "*_test.go, toggle set: refused"              "$(guard Edit pkg/thing_test.go)" "2"
check "*_test.dart (spec's *_test.* pattern), toggle set: refused" "$(guard Edit lib/widget_test.dart)" "2"
check "*_test.ts, toggle set: refused"              "$(guard Write src/mod_test.ts)" "2"
check "the refusal tells how to clear the toggle"   "$(reason Edit tests/test_a.py | grep -c 'rm .strata/guard-tests')" "1"
check "source file, toggle set: allowed"            "$(guard Edit src/a.py)" "0"
check "Read of a test file, toggle set: allowed"    "$(guard Read tests/test_a.py)" "0"
rm -f .strata/guard-tests
check "toggle removed: test file allowed again"     "$(guard Edit tests/test_a.py)" "0"

echo "== fail-open =="
check "unparseable payload exits 0"                 "$(printf 'garbage' | bash "$GUARD" 2>/dev/null; echo $?)" "0"
check "payload without file_path exits 0"           "$(printf '{"tool_name":"Edit","tool_input":{}}' | bash "$GUARD" 2>/dev/null; echo $?)" "0"
check "empty stdin exits 0"                         "$(bash "$GUARD" </dev/null 2>/dev/null; echo $?)" "0"

echo "== performance =="
best=999999
for _ in 1 2 3 4 5 6 7; do
  t0=$(date +%s%N); guard Edit src/a.py >/dev/null; t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 )); [ "$ms" -lt "$best" ] && best="$ms"
done
check "allow path stays under 100ms (best of 7: ${best}ms)" "$([ "$best" -lt 100 ] && echo yes || echo no)" "yes"

echo "== SessionStart: stale toggle warning =="
printf '| [[thing]] | a thing |\n' > wiki/index.md
rm -rf .strata/sessions
out="$(echo '{"session_id":"g1"}' | bash "$START")"
check "no toggle: no warning"                       "$(printf '%s' "$out" | grep -c 'guard-tests')" "0"
: > .strata/guard-tests
rm -rf .strata/sessions
out="$(echo '{"session_id":"g2"}' | bash "$START")"
check "toggle left behind: one warning line"        "$(printf '%s' "$out" | grep -c 'Stale test-file guard')" "1"
check "still within the 50-line budget"             "$([ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -le 50 ] && echo yes || echo no)" "yes"
rm -f .strata/guard-tests

echo
echo "P3 guards: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
