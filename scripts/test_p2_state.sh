#!/usr/bin/env bash
# Behavioural test for P2 — the episodic state layer:
#   scripts/lib/state_tools.py     (schema + validator)
#   Stop-gate trigger (c)          (extends A1, same one-block-per-session cap)
#   SessionStart state summary + version nudge
#   strata_upgrade_check.sh        (backs /strata:upgrade)
#
# Same discipline as test_p1_gates.sh: a throwaway git repo, the real shipped
# scripts, no mocks. See docs/superpowers/specs/2026-09-01-episodic-state-layer.md.
#
# Usage: bash scripts/test_p2_state.sh          (exit 0 = all green)

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
# Pin the branch name — do NOT rely on the runner's `init.defaultBranch`
# default (main locally, master on GitHub's ubuntu runners). The fixture
# below hardcodes "main" as the branch under test, and the Stop gate reads
# the REAL current branch via `git rev-parse --abbrev-ref HEAD`; a mismatch
# there is silent (state lookup for a branch that doesn't exist just misses),
# so it must be pinned, not assumed. Caught via a real CI failure.
git checkout -q -b main
mkdir -p docs raw wiki src scripts/lib scripts/hooks scripts/pre-commit
cp "$TPL/lib/pending_ingest.sh"          scripts/lib/
cp "$TPL/lib/state_tools.py"             scripts/lib/
cp "$TPL/hooks/strata_session_start.sh"  scripts/hooks/
cp "$TPL/hooks/strata_stop_gate.sh"      scripts/hooks/
printf 'seed\n' > seed.txt
: > wiki/log.md
printf '.strata/*\n!.strata/state/\n' > .gitignore
git add -A >/dev/null && git commit -qm seed

STATE_TOOLS=scripts/lib/state_tools.py
START=scripts/hooks/strata_session_start.sh
GATE=scripts/hooks/strata_stop_gate.sh

# Only resets session-cadence bookkeeping — .strata/state/ must survive across
# simulated session boundaries on the same branch, exactly as it must in
# production (that's the entire point of the layer).
new_session() { rm -rf .strata/sessions; echo "{\"session_id\":\"$1\"}" | bash "$START" >/dev/null 2>&1; }
verdict() {
  local out; out="$(echo "{\"session_id\":\"$1\"}" | bash "$GATE" 2>/dev/null)"
  [ -z "$out" ] && { echo clear; return; }
  printf '%s' "$out" | python3 -c "
import json,sys
try: print('blocked' if json.load(sys.stdin).get('decision')=='block' else 'clear')
except Exception: print('malformed')
"
}

echo "== state_tools.py — schema + validator =="
python3 "$STATE_TOOLS" init main --goal "ship it" --verify "pytest -q" >/dev/null
STATE_PATH="$(python3 "$STATE_TOOLS" path main)"
check "init produces a valid file"          "$(python3 "$STATE_TOOLS" validate "$STATE_PATH" >/dev/null 2>&1; echo $?)" "0"

echo '{not json' > bad_json.json
check "rejects invalid JSON"                "$(python3 "$STATE_TOOLS" validate bad_json.json >/dev/null 2>&1; echo $?)" "1"

python3 -c "import json; json.dump({'status':'active','branch':'x','updated':'t'}, open('missing_key.json','w'))"
check "rejects a missing required key"      "$(python3 "$STATE_TOOLS" validate missing_key.json >/dev/null 2>&1; echo $?)" "1"
check "names the missing key"               "$(python3 "$STATE_TOOLS" validate missing_key.json 2>&1 | grep -c 'goal')" "1"

python3 -c "import json; json.dump({'goal':'g','status':'active','branch':'x','updated':'t','bogus':1}, open('unknown_key.json','w'))"
check "rejects an unknown top-level key"    "$(python3 "$STATE_TOOLS" validate unknown_key.json >/dev/null 2>&1; echo $?)" "1"

python3 -c "
import json
json.dump({'goal':'g','status':'active','branch':'x','updated':'t',
           'decisions':[{'what':'a','why':'b','trust':'yolo'}]}, open('bad_trust.json','w'))
"
check "rejects a trust value outside the enum" "$(python3 "$STATE_TOOLS" validate bad_trust.json >/dev/null 2>&1; echo $?)" "1"

python3 -c "
import json
json.dump({'goal':'g','status':'active','branch':'x','updated':'t',
           'wiki_debt':['decision: X because Y']}, open('debt.json','w'))
"
check "debt lists wiki_debt entries"        "$(python3 "$STATE_TOOLS" debt debt.json | wc -l | tr -d ' ')" "1"
check "debt is silent (not an error) on a missing file" "$(python3 "$STATE_TOOLS" debt no_such_file.json; echo exit=$?)" "exit=0"

echo "== A1 Stop gate — trigger (c): branch state =="
new_session c1
check "no wiki_debt yet: clear" "$(verdict c1)" "clear"

new_session c2
python3 -c "
import json
p='$WORK/.strata/state/main.json'
o=json.load(open(p)); o['wiki_debt']=['x']; json.dump(o, open(p,'w'))
"
check "non-empty wiki_debt: blocked"        "$(verdict c2)" "blocked"
check "never blocks twice in one session"   "$(verdict c2)" "clear"

new_session c3
python3 -c "
import json
p='$WORK/.strata/state/main.json'
o=json.load(open(p)); o['wiki_debt']=[]; json.dump(o, open(p,'w'))
"
check "wiki_debt cleared: clear again"      "$(verdict c3)" "clear"

new_session c4
echo '{bad json' > .strata/state/main.json
check "invalid state file: blocked"         "$(verdict c4)" "blocked"

rm -rf .strata/state
new_session c5
check "missing state file entirely: clear (layer stays incremental)" "$(verdict c5)" "clear"

echo "== SessionStart — state summary + version nudge =="
: > wiki/log.md
python3 "$STATE_TOOLS" init main --goal "summarised goal" >/dev/null
new_session s1
out="$(echo '{"session_id":"s1"}' | bash "$START")"
check "prints the branch-state summary"     "$(printf '%s' "$out" | grep -c 'Branch state:.*summarised goal')" "1"
check "stays within the 50-line budget"     "$([ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -le 50 ] && echo yes || echo no)" "yes"

rm -rf .strata/state
new_session s2
out="$(echo '{"session_id":"s2"}' | bash "$START")"
check "silent about state when file absent" "$(printf '%s' "$out" | grep -c '^Branch state:')" "0"

mkdir -p fake_plugin_root/.claude-plugin
echo '{"version":"9.9.9"}' > fake_plugin_root/.claude-plugin/plugin.json
echo "0.0.1" > .strata/version
new_session s3
out="$(CLAUDE_PLUGIN_ROOT="$WORK/fake_plugin_root" bash -c "echo '{\"session_id\":\"s3\"}' | bash '$START'")"
check "nudges /strata:upgrade on a version mismatch" "$(printf '%s' "$out" | grep -c '/strata:upgrade')" "1"

mkdir -p fake_plugin_root/.claude-plugin
echo '{"version":"0.0.1"}' > fake_plugin_root/.claude-plugin/plugin.json
echo "0.0.1" > .strata/version
new_session s4
out="$(CLAUDE_PLUGIN_ROOT="$WORK/fake_plugin_root" bash -c "echo '{\"session_id\":\"s4\"}' | bash '$START'")"
check "silent when version matches"         "$(printf '%s' "$out" | grep -c '/strata:upgrade')" "0"
rm -rf fake_plugin_root .strata/version

echo "== strata_upgrade_check.sh — diff reporter =="
mkdir -p tpl_fixture/hooks tpl_fixture/lib installed_fixture/hooks installed_fixture/lib
printf 'echo one\n' > tpl_fixture/hooks/a.sh
printf 'echo two\n' > tpl_fixture/lib/b.sh
cp -r tpl_fixture/. installed_fixture/
check "reports clean when identical"        "$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture >/dev/null 2>&1; echo $?)" "0"

printf 'echo one-changed\n' > tpl_fixture/hooks/a.sh
rm installed_fixture/lib/b.sh
out="$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture)"
check "reports the exit code as drifted"    "$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture >/dev/null 2>&1; echo $?)" "1"
check "names the stale file"                "$(printf '%s' "$out" | grep -c '^STALE    hooks/a.sh$')" "1"
check "names the missing file"              "$(printf '%s' "$out" | grep -c '^MISSING  lib/b.sh$')" "1"

# A file can differ in TWO opposite directions, and one word for both is a trap:
# the template may have moved ahead (re-sync is the fix), or the INSTALLED file
# may have — a project bolting real guards onto a shipped script. Copying over
# the second case DELETES those guards. Measured on a real repo: HorOS's
# check_secrets.sh is the template plus 59 lines (a guest-phone PII guard, an
# AWS-placeholder exception), reported as STALE every run, so the check's exit
# code was permanently 1 and therefore worthless as a gate.
mkdir -p tpl_fixture/pre-commit installed_fixture/pre-commit
printf 'echo base\n' > tpl_fixture/pre-commit/c.sh
printf 'echo base\necho local guard\n' > installed_fixture/pre-commit/c.sh
out="$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture)"
check "installed-ahead is AHEAD, not STALE" "$(printf '%s' "$out" | grep -c '^AHEAD    pre-commit/c.sh$')" "1"

# Positive control on the direction: the SAME file, with the template also
# carrying a line the installed one lacks, must stay STALE — otherwise AHEAD
# would swallow genuine template evolution and the repo would never re-sync.
printf 'echo base\necho template evolved\n' > tpl_fixture/pre-commit/c.sh
out="$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture)"
check "both-diverged stays STALE"           "$(printf '%s' "$out" | grep -c '^STALE    pre-commit/c.sh$')" "1"

# AHEAD alone is not drift: nothing to copy, so the gate must go green. This is
# the whole point — a check that can never exit 0 gets ignored.
rm -rf tpl_fixture installed_fixture
mkdir -p tpl_fixture/pre-commit installed_fixture/pre-commit
printf 'echo base\n' > tpl_fixture/pre-commit/c.sh
printf 'echo base\necho local guard\n' > installed_fixture/pre-commit/c.sh
check "AHEAD alone exits clean"             "$(bash "$TPL/strata_upgrade_check.sh" tpl_fixture installed_fixture >/dev/null 2>&1; echo $?)" "0"

echo "== .gitignore carve-out =="
touch .strata/sessions/probe.start 2>/dev/null || mkdir -p .strata/sessions && touch .strata/sessions/probe.start
mkdir -p .strata/state && touch .strata/state/probe.json
check "sessions/ stays ignored"             "$(git check-ignore -q .strata/sessions/probe.start; echo $?)" "0"
check "state/ is tracked"                   "$(git check-ignore -q .strata/state/probe.json; echo $?)" "1"

echo
echo "P2 state layer: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
