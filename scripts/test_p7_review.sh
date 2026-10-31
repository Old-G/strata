#!/usr/bin/env bash
# Behavioural test for P7 — REVIEW.md and the review loop (v0.18.0):
#   templates/core/REVIEW.md.tmpl              (the owner's 5–15 lines)
#   scripts/lib/line_origin.sh <base> <loc>... (Pre-existing comes from git blame, not a guess)
#   scripts/lib/state_tools.py review-round    (three rounds, then "reconsider the approach")
#   the reviewers / light-finish / adopt / init text that wires them in
#
# Same discipline as the other test_p*.sh: throwaway git repo, the real shipped
# scripts, no mocks. See docs/superpowers/plans/2026-10-31-review-md-plan.md.
#
# Usage: bash scripts/test_p7_review.sh      (exit 0 = all green)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates/core/scripts"
pass=0; fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has()  { if grep -qF -- "$2" "$1" 2>/dev/null; then echo yes; else echo no; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/.no-claude-config"
unset CLAUDE_PLUGIN_ROOT

echo "== REVIEW.md template — short, and every rule the owner sets =="
T="$ROOT/templates/core/REVIEW.md.tmpl"
check "template exists" "$([ -f "$T" ] && echo y)" "y"
n="$(grep -cv '^[[:space:]]*$' "$T" 2>/dev/null || echo 0)"
check "5–15 non-empty lines (got $n)" "$([ "$n" -ge 5 ] && [ "$n" -le 15 ] && echo y)" "y"
for rule in "Broken here means" "Nits:" "Skip:" "Always a human:" "file:line" "Pre-existing" "Nothing to fix"; do
  check "template states: $rule" "$(has "$T" "$rule")" "yes"
done

echo "== line_origin.sh — who wrote this line: the branch, or the code before it =="
LO="$TPL/lib/line_origin.sh"
check "line_origin.sh is shipped" "$([ -f "$LO" ] && echo y)" "y"
check "this repo's copy matches the template" "$(cmp -s "$LO" "$ROOT/scripts/lib/line_origin.sh" && echo y)" "y"
cd "$WORK" || exit 1
git init -q repo && cd repo || exit 1
git config user.email test@strata.local; git config user.name "Strata Test"
git checkout -q -b main
mkdir -p src
printf 'a = 1\nb = 2\nc = 3\n' > src/app.py
git add -A && git commit -qm base
git checkout -q -b feat
printf 'a = 1\nb = 20\nc = 3\n' > src/app.py
git commit -qam "branch edit"
printf 'a = 1\nb = 20\nc = 30\n' > src/app.py          # uncommitted
base="$(git merge-base main feat)"
first() { printf '%s\n' "$1" | head -1 | awk '{print $1}'; }
check "an untouched line is PRE-EXISTING"      "$(first "$(bash "$LO" "$base" src/app.py:1)")" "PRE-EXISTING"
check "a line the branch committed is BRANCH"  "$(first "$(bash "$LO" "$base" src/app.py:2)")" "BRANCH"
check "a line changed in the tree is UNCOMMITTED" "$(first "$(bash "$LO" "$base" src/app.py:3)")" "UNCOMMITTED"
check "a range is pre-existing only if every line is" "$(first "$(bash "$LO" "$base" src/app.py:1-2)")" "BRANCH"
check "a range of old lines is PRE-EXISTING"   "$(first "$(bash "$LO" "$base" src/app.py:1-1)")" "PRE-EXISTING"
check "no such line → UNKNOWN"                 "$(first "$(bash "$LO" "$base" src/app.py:99)")" "UNKNOWN"
check "no such file → UNKNOWN"                 "$(first "$(bash "$LO" "$base" src/nope.py:1)")" "UNKNOWN"
check "not a line number → UNKNOWN"            "$(first "$(bash "$LO" "$base" src/app.py:x)")" "UNKNOWN"
check "one line out per location"              "$(bash "$LO" "$base" src/app.py:1 src/app.py:2 | wc -l | tr -d ' ')" "2"
check "PRE-EXISTING names the commit"          "$(bash "$LO" "$base" src/app.py:1 | awk '{print $3}')" "$(git rev-parse main)"
check "paths are repo-relative from a subdir"  "$(cd src && first "$(bash "$LO" "$base" src/app.py:1)")" "PRE-EXISTING"
bash "$LO" not-a-commit src/app.py:1 >/dev/null 2>&1; check "a base that is not a commit → exit 1" "$?" "1"
bash "$LO" >/dev/null 2>&1;                          check "no arguments → exit 1"               "$?" "1"
# A moved line counts as the branch's: a false "branch" costs a look, a false "pre-existing" hides a bug.
git checkout -q -- src/app.py
printf 'c = 3\na = 1\nb = 20\n' > src/app.py && git commit -qam "branch moves a line"
check "a line the branch moved is BRANCH (plain blame, no -M)" "$(first "$(bash "$LO" "$base" src/app.py:1)")" "BRANCH"

echo "== state_tools.py review-round — three rounds, then the human =="
ST="$TPL/lib/state_tools.py"
mkdir -p scripts/lib && cp "$ST" scripts/lib/
printf '.strata/*\n!.strata/state/\n' > .gitignore
S=".strata/state/feat.json"
RR() { python3 scripts/lib/state_tools.py review-round "$@"; }
out="$(RR feat)"; rc=$?
check "round 1 on a branch with no state file" "$rc:$out" "0:ROUND 1/3 SINCE base"
check "asking writes nothing"                  "$([ -f "$S" ] && echo y || echo n)" "n"
out="$(RR feat)"
check "a review that never finished is retried with the same scope" "$out" "ROUND 1/3 SINCE base"
h1="$(git rev-parse HEAD)"
out="$(RR feat --done)"; rc=$?
check "--done records round 1 at HEAD"         "$rc:$out" "0:ROUND 1/3 recorded at $h1"
check "it created a valid state file"          "$(python3 scripts/lib/state_tools.py validate "$S" && echo valid)" "valid"
check "a state file made for the count has no goal (it is not a plan)" "$(python3 -c 'import json,sys; print(repr(json.load(open(sys.argv[1]))["goal"]))' "$S")" "''"
echo x >> .gitignore; git add .gitignore && git commit -qm fix1
out="$(RR feat)"
check "round 2 reviews only what came after round 1" "$out" "ROUND 2/3 SINCE $h1"
RR feat --done >/dev/null; h2="$(git rev-parse HEAD)"
echo y >> .gitignore; git add .gitignore && git commit -qm fix2
check "the fix rounds made real commits" "$([ "$h1" != "$h2" ] && [ "$h2" != "$(git rev-parse HEAD)" ] && echo y)" "y"
out="$(RR feat)"
check "round 3"                                "$out" "ROUND 3/3 SINCE $h2"
RR feat --done >/dev/null
out="$(RR feat)"; rc=$?
check "a 4th round is refused (exit 3)"        "$rc" "3"
check "…and says to reconsider the approach"   "$(printf '%s' "$out" | grep -c 'reconsider the approach')" "1"
RR feat --done >/dev/null; rc=$?
check "--done past the cap is refused too"     "$rc" "3"
check "…without counting it"                   "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["review"]["rounds"])' "$S")" "3"
out="$(RR feat --reset)"
check "--reset after the human reconsiders → round 1, full diff" "$out" "ROUND 1/3 SINCE base"
check "--reset clears the count"               "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["review"]["rounds"])' "$S")" "0"
RR feat --bogus >/dev/null 2>&1;               check "an unknown flag → exit 1" "$?" "1"
python3 scripts/lib/state_tools.py init other --goal "keep this goal" >/dev/null
python3 scripts/lib/state_tools.py review-round other --done >/dev/null
check "an existing state file keeps its goal"  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["goal"])' .strata/state/other.json)" "keep this goal"
python3 - "$S" <<'PY'
import json, sys
o = json.load(open(sys.argv[1])); o["review"] = {"rounds": "two", "head": "x"}
json.dump(o, open(sys.argv[1], "w"))
PY
python3 scripts/lib/state_tools.py validate "$S" 2>/dev/null; check "validate rejects a non-integer rounds" "$?" "1"
python3 - "$S" <<'PY'
import json, sys
o = json.load(open(sys.argv[1])); o["review"] = {"rounds": 1, "head": "x", "extra": 1}
json.dump(o, open(sys.argv[1], "w"))
PY
python3 scripts/lib/state_tools.py validate "$S" 2>/dev/null; check "validate rejects an unknown review key" "$?" "1"
check "this repo's state_tools.py matches the template" "$(cmp -s "$ST" "$ROOT/scripts/lib/state_tools.py" && echo y)" "y"

echo "== the reviewers and the skills carry the rules =="
cd "$ROOT" || exit 1
D=agents/strata-diff-review.md
for s in "REVIEW.md" "line_origin.sh" "Pre-existing" "bug class" "every location" "ROUND" "SINCE" "PREVIOUS" "findings (Important" "Nothing to fix" "Still open" "still open ·" "empty \`goal\` is not a plan" "not counted"; do
  check "diff-review: $s" "$(has "$D" "$s")" "yes"
done
for a in eng cso design; do
  for s in "REVIEW.md" "Pre-existing" "findings (Important" "bug class"; do
    check "$a-review: $s" "$(has "agents/strata-$a-review.md" "$s")" "yes"
  done
done
L=skills/light-finish/SKILL.md
for s in "review-round" "review-round <branch> --done" "reconsider the approach" "## Testing" "## Risk" "## How to revert" "PREVIOUS"; do
  check "light-finish: $s" "$(has "$L" "$s")" "yes"
done
for f in skills/adopt/SKILL.md skills/init/SKILL.md; do
  check "$f drafts REVIEW.md from the template" "$(has "$f" "REVIEW.md.tmpl")" "yes"
  check "$f installs line_origin.sh"           "$(has "$f" "lib/line_origin.sh")" "yes"
done
check "upgrade offers a REVIEW.md draft"       "$(has skills/upgrade/SKILL.md "REVIEW.md")" "yes"
check "Strata has its own REVIEW.md"           "$([ -f REVIEW.md ] && [ "$(grep -cv '^[[:space:]]*$' REVIEW.md)" -le 15 ] && echo y)" "y"

echo
echo "P7 review loop: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
