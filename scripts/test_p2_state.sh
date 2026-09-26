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
cp "$TPL/lib/tree_snapshot.sh" scripts/lib/
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
# the second case DELETES those guards. Measured on a real repo: app-a's
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

echo "== strata_upgrade_check.sh --apply-safe — copy only what cannot lose local lines =="
rm -rf tpl_fixture installed_fixture
mkdir -p tpl_fixture/hooks tpl_fixture/lib tpl_fixture/pre-commit installed_fixture/hooks installed_fixture/pre-commit
printf 'echo new\n' > tpl_fixture/hooks/a.sh;  printf 'echo old\n' > installed_fixture/hooks/a.sh        # an old shipped version
# The plugin ships the hash of every version each template ever had: an installed
# file that matches one was never edited locally, so replacing it loses nothing —
# even though its diff shows lines on both sides (a changed line always does).
printf '%s  hooks/a.sh\n' "$(git hash-object installed_fixture/hooks/a.sh)" > tpl_fixture.history
printf 'echo b\n' > tpl_fixture/lib/b.sh; chmod +x tpl_fixture/lib/b.sh                                  # MISSING
printf 'echo base\necho tpl\n' > tpl_fixture/pre-commit/c.sh
printf 'echo base\necho local\n' > installed_fixture/pre-commit/c.sh                                     # both sides
printf 'echo d\n' > tpl_fixture/pre-commit/d.sh; printf 'echo d\necho guard\n' > installed_fixture/pre-commit/d.sh  # AHEAD
out="$(bash "$TPL/strata_upgrade_check.sh" --apply-safe tpl_fixture installed_fixture)"; rc=$?
check "apply-safe: a conflict left → exit 1"        "$rc" "1"
check "apply-safe: a known old version is synced"               "$(cmp -s tpl_fixture/hooks/a.sh installed_fixture/hooks/a.sh && echo same)" "same"
check "apply-safe: MISSING synced, mode kept"        "$([ -x installed_fixture/lib/b.sh ] && echo x)" "x"
check "apply-safe: both-sides file untouched"        "$(tail -1 installed_fixture/pre-commit/c.sh)" "echo local"
check "apply-safe: AHEAD file untouched"             "$(tail -1 installed_fixture/pre-commit/d.sh)" "echo guard"
check "apply-safe: reports SYNCED / CONFLICT / AHEAD" \
  "$(printf '%s\n' "$out" | grep -cE '^(SYNCED   hooks/a.sh|SYNCED   lib/b.sh|CONFLICT pre-commit/c.sh|AHEAD    pre-commit/d.sh)$')" "4"
rm installed_fixture/pre-commit/c.sh; cp tpl_fixture/pre-commit/c.sh installed_fixture/pre-commit/c.sh
check "apply-safe: nothing left → exit 0"           "$(bash "$TPL/strata_upgrade_check.sh" --apply-safe tpl_fixture installed_fixture >/dev/null; echo $?)" "0"
# A running bash script reads its file as it goes: overwriting it in place (same
# inode) corrupts the run. apply-safe must replace files, not rewrite them.
ino_before="$(ls -i installed_fixture/hooks/a.sh | awk '{print $1}')"
printf '%s  hooks/a.sh\n' "$(git hash-object tpl_fixture/hooks/a.sh)" >> tpl_fixture.history
printf 'echo newer\n' > tpl_fixture/hooks/a.sh
bash "$TPL/strata_upgrade_check.sh" --apply-safe tpl_fixture installed_fixture >/dev/null
check "apply-safe: replaces the file (new inode), never rewrites in place" \
  "$([ "$(ls -i installed_fixture/hooks/a.sh | awk '{print $1}')" != "$ino_before" ] && echo new)" "new"
printf 'echo edited by hand\n' > installed_fixture/hooks/a.sh
printf 'echo newest\n' > tpl_fixture/hooks/a.sh
check "apply-safe: an unknown local edit is a CONFLICT, untouched" \
  "$(bash "$TPL/strata_upgrade_check.sh" --apply-safe tpl_fixture installed_fixture | grep -c '^CONFLICT hooks/a.sh$'):$(cat installed_fixture/hooks/a.sh)" "1:echo edited by hand"
rm -rf tpl_fixture installed_fixture tpl_fixture.history

echo "== SessionStart auto-sync — a newer plugin reaches this repo on its own =="
# fake plugin: its templates carry one extra lib file the repo lacks
FAKE="$WORK/fake_plugin"; mkdir -p "$FAKE/.claude-plugin" "$FAKE/templates/core"
cp -R "$TPL" "$FAKE/templates/core/scripts"
printf '# new in 9.9.9\n' > "$FAKE/templates/core/scripts/lib/brand_new.sh"
echo '{"version":"9.9.9"}' > "$FAKE/.claude-plugin/plugin.json"
echo "0.0.1" > .strata/version
new_session s5
out="$(CLAUDE_PLUGIN_ROOT="$FAKE" bash -c "echo '{\"session_id\":\"s5\"}' | bash '$START'")"
check "auto-sync copies the new file"               "$([ -f scripts/lib/brand_new.sh ] && echo y)" "y"
check "auto-sync stamps the new version"            "$(cat .strata/version)" "9.9.9"
check "auto-sync says so in the session context"    "$(printf '%s' "$out" | grep -c 'auto-synced.*0.0.1 → 9.9.9')" "1"
rm -f scripts/lib/brand_new.sh

echo "0.0.1" > .strata/version
cp scripts/lib/pending_ingest.sh "$WORK/pi.keep"
printf '# local line\n' >> scripts/lib/pending_ingest.sh
printf '# template line\n' >> "$FAKE/templates/core/scripts/lib/pending_ingest.sh"
new_session s6
out="$(CLAUDE_PLUGIN_ROOT="$FAKE" bash -c "echo '{\"session_id\":\"s6\"}' | bash '$START'")"
check "conflict: local lines survive"                "$(tail -1 scripts/lib/pending_ingest.sh)" "# local line"
check "conflict: version NOT stamped"                "$(cat .strata/version)" "0.0.1"
check "conflict: context points at /strata:upgrade"  "$(printf '%s' "$out" | grep -c 'pending_ingest.sh.*/strata:upgrade')" "1"
cp "$WORK/pi.keep" scripts/lib/pending_ingest.sh; rm -f scripts/lib/brand_new.sh
cp "$TPL/lib/pending_ingest.sh" "$FAKE/templates/core/scripts/lib/pending_ingest.sh"

new_session s7
out="$(STRATA_NO_AUTOSYNC=1 CLAUDE_PLUGIN_ROOT="$FAKE" bash -c "echo '{\"session_id\":\"s7\"}' | bash '$START'")"
check "STRATA_NO_AUTOSYNC=1: nothing copied"         "$([ -f scripts/lib/brand_new.sh ] && echo y || echo n)" "n"
check "STRATA_NO_AUTOSYNC=1: still nudges"           "$(printf '%s' "$out" | grep -c '/strata:upgrade')" "1"

echo "9.9.10" > .strata/version
new_session s8
CLAUDE_PLUGIN_ROOT="$FAKE" bash -c "echo '{\"session_id\":\"s8\"}' | bash '$START'" >/dev/null
check "older plugin than the repo: never downgrades" "$([ -f scripts/lib/brand_new.sh ] && echo y || echo n):$(cat .strata/version)" "n:9.9.10"

# No CLAUDE_PLUGIN_ROOT (project hooks may not get it): resolve the plugin from
# Claude Code's own install registry.
echo "0.0.1" > .strata/version
mkdir -p "$WORK/cfg/plugins"
printf '{"version":2,"plugins":{"strata@strata":[{"scope":"user","installPath":"%s","version":"9.9.9"}]}}\n' "$FAKE" > "$WORK/cfg/plugins/installed_plugins.json"
new_session s9
out="$(env -u CLAUDE_PLUGIN_ROOT CLAUDE_CONFIG_DIR="$WORK/cfg" bash -c "echo '{\"session_id\":\"s9\"}' | bash '$START'")"
check "registry resolution: auto-sync without CLAUDE_PLUGIN_ROOT" "$([ -f scripts/lib/brand_new.sh ] && echo y):$(cat .strata/version)" "y:9.9.9"
rm -f scripts/lib/brand_new.sh .strata/version; rm -rf "$FAKE" "$WORK/cfg"

echo "== strata-upgrade-all — every project on the machine, one command =="
UPALL="$ROOT/bin/strata-upgrade-all"
PV="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -1)"
mkrepo() { # <dir> — a Strata repo one file behind the plugin
  mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config user.email t@t && git -C "$1" config user.name t
  cp -R "$TPL" "$1/scripts" && mkdir -p "$1/.strata" && echo "0.0.1" > "$1/.strata/version"
  rm -f "$1/scripts/strata_why.sh"
  git -C "$1" add -A >/dev/null && git -C "$1" commit -qm seed
}
mkrepo "$WORK/fleet/clean"
mkrepo "$WORK/fleet/edited"
sed -i.orig '1s/.*/# edited here/' "$WORK/fleet/edited/scripts/lib/pending_ingest.sh" && rm -f "$WORK/fleet/edited/scripts/lib/pending_ingest.sh.orig"
git -C "$WORK/fleet/clean" worktree add -q "$WORK/fleet/clean-wt" -b wt 2>/dev/null
cp "$WORK/fleet/clean/.strata/version" "$WORK/fleet/clean-wt/.strata/version" 2>/dev/null || { mkdir -p "$WORK/fleet/clean-wt/.strata"; echo 0.0.1 > "$WORK/fleet/clean-wt/.strata/version"; }
mkdir -p "$WORK/cfg2/plugins"
printf '{"version":2,"plugins":{"strata@strata":[{"scope":"local","projectPath":"%s","installPath":"/nowhere"}]}}\n' "$WORK/fleet/clean" > "$WORK/cfg2/plugins/installed_plugins.json"

out="$(CLAUDE_CONFIG_DIR="$WORK/cfg2" bash "$UPALL" --dry-run --scan "$WORK/fleet")"
check "dry run writes nothing"                       "$([ -f "$WORK/fleet/clean/scripts/strata_why.sh" ] && echo y || echo n):$(cat "$WORK/fleet/clean/.strata/version")" "n:0.0.1"
out="$(CLAUDE_CONFIG_DIR="$WORK/cfg2" bash "$UPALL" --scan "$WORK/fleet")"; rc=$?
check "clean repo: synced and stamped"               "$([ -f "$WORK/fleet/clean/scripts/strata_why.sh" ] && echo y):$(cat "$WORK/fleet/clean/.strata/version")" "y:$PV"
check "edited repo: local edit survives"             "$(head -1 "$WORK/fleet/edited/scripts/lib/pending_ingest.sh")" "# edited here"
check "edited repo: named, version not stamped"      "$(printf '%s' "$out" | grep -c 'edited.*lib/pending_ingest.sh.*/strata:upgrade'):$(cat "$WORK/fleet/edited/.strata/version")" "1:0.0.1"
check "a file left over → exit 1"                    "$rc" "1"
check "linked worktree skipped, untouched"           "$(printf '%s' "$out" | grep -c 'clean-wt — linked worktree'):$(cat "$WORK/fleet/clean-wt/.strata/version")" "1:0.0.1"
check "never commits"                                "$(git -C "$WORK/fleet/clean" log --oneline | wc -l | tr -d ' ')" "1"
rm -rf "$WORK/fleet" "$WORK/cfg2"

echo "== .gitignore carve-out =="
touch .strata/sessions/probe.start 2>/dev/null || mkdir -p .strata/sessions && touch .strata/sessions/probe.start
mkdir -p .strata/state && touch .strata/state/probe.json
check "sessions/ stays ignored"             "$(git check-ignore -q .strata/sessions/probe.start; echo $?)" "0"
check "state/ is tracked"                   "$(git check-ignore -q .strata/state/probe.json; echo $?)" "1"

echo
echo "P2 state layer: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
