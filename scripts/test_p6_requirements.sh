#!/usr/bin/env bash
# Behavioural test for P6 / T1 — the behaviour-spec checker:
#   scripts/lib/requirements.py check [--strict]   (Requirements sections in wiki/entities/)
#   scripts/lib/requirements.py owed              (the branch plan's Behaviour delta vs the wiki)
#   scripts/lib/state_tools.py  plan <branch>      (the one plan lookup)
#
# Same discipline as the other test_p*.sh: throwaway git repo, the real shipped
# scripts, no mocks. Branch pinned to main.
# See docs/superpowers/specs/2026-09-28-p6-behaviour-specs.md, D2–D5.
#
# Usage: bash scripts/test_p6_requirements.sh      (exit 0 = all green)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates/core/scripts"
pass=0; fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has()  { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_CONFIG_DIR="$WORK/.no-claude-config"
unset CLAUDE_PLUGIN_ROOT
cd "$WORK" || exit 1

git init -q .
git config user.email test@strata.local
git config user.name "Strata Test"
git checkout -q -b main
mkdir -p scripts/lib wiki/entities tests docs/superpowers/plans
cp "$TPL/lib/state_tools.py"   scripts/lib/
cp "$TPL/lib/requirements.py"  scripts/lib/ 2>/dev/null || true
printf 'check "blocks once" x\ncheck "escape hatch works" y\n' > tests/test_gate.sh
printf '.strata/*\n!.strata/state/\n' > .gitignore

RQ=scripts/lib/requirements.py
ST=scripts/lib/state_tools.py
run_check(){ python3 "$RQ" check "$@" 2>&1; }
code_check(){ python3 "$RQ" check "$@" >/dev/null 2>&1; echo $?; }

page(){ # page <slug> <requirements-body>
  { printf -- '---\ntitle: %s\ntype: entity\n---\n\n# %s\n\n## TLDR\n\nx\n\n## Current solutions\n\ny\n\n' "$1" "$1"
    printf '%s\n' "$2"
    printf '\n## Related\n\n- none\n'; } > "wiki/entities/$1.md"
}

GOOD='## Requirements

### Blocks at most once
The gate never forces a second continuation.

- Scenario: second stop — WHEN the gate already blocked THEN the next stop exits 0 ·
  `test: tests/test_gate.sh::blocks once`'

page gate "$GOOD"
git add -A >/dev/null && git commit -qm seed

echo "P6 / T1 — requirements.py check"

if [ -f "$RQ" ] && python3 -m py_compile "$RQ" 2>/dev/null; then ok "requirements.py present and compiles"; else bad "requirements.py missing or does not compile"; fi

out="$(run_check)"
check "clean page → no findings"            "$(printf '%s' "$out" | grep -c '^ERROR')" "0"
check "  exit 0"                            "$(code_check --strict)" "0"

page gate '## Requirements

### No scenario here
Just a statement.'
out="$(run_check)"
check "requirement without a scenario → reported"   "$(has "$out" 'no scenario')" yes
check "  names the page and the title"              "$(has "$out" 'gate.md')$(has "$out" 'No scenario here')" yesyes
check "  --strict exits 1"                          "$(code_check --strict)" "1"
check "  default exits 0"                           "$(code_check)" "0"

page gate '## Requirements

### Vague
Something.

- Scenario: vague — it works · `test: tests/test_gate.sh::blocks once`'
check "scenario without WHEN/THEN → reported"  "$(has "$(run_check)" 'WHEN')" yes

page gate '## Requirements

### Unproven
Something.

- Scenario: s — WHEN a THEN b'
check "scenario with no pointer → reported"    "$(has "$(run_check)" 'no evidence pointer')" yes

page gate '## Requirements

### Double
Something.

- Scenario: s — WHEN a THEN b · `test: tests/test_gate.sh` · `manual: also by hand`'
check "scenario with two pointers → reported"  "$(has "$(run_check)" 'more than one evidence pointer')" yes

page gate '## Requirements

### Missing test
Something.

- Scenario: s — WHEN a THEN b · `test: tests/nope.sh::blocks once`'
check "test: path missing → reported"          "$(has "$(run_check)" 'tests/nope.sh')" yes

page gate '## Requirements

### Wrong needle
Something.

- Scenario: s — WHEN a THEN b · `test: tests/test_gate.sh::never written`'
check "::needle absent → reported"             "$(has "$(run_check)" 'never written')" yes

page gate '## Requirements

### Twice
One.

- Scenario: s — WHEN a THEN b · `test: tests/test_gate.sh`

### Twice
Two.

- Scenario: s — WHEN a THEN b · `test: tests/test_gate.sh`'
check "duplicate titles → reported"            "$(has "$(run_check)" 'duplicate')" yes

page gate '## Requirements

### Live only
Only a real session shows it.

- Scenario: s — WHEN a live session stops THEN the prompt appears · `manual: needs a live Claude Code session`'
out="$(run_check)"
check "manual: → counted, not an error"        "$(printf '%s' "$out" | grep -c '^ERROR')" "0"
check "  summary counts it"                    "$(has "$out" '1 manual')" yes
check "  --strict still exits 0"               "$(code_check --strict)" "0"

page gate '## Requirements

Format example, not a requirement:

```markdown
### Inside a fence
- Scenario: nothing — no pointer
```'
check "a fenced example is not parsed"         "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

page gate '## Requirements

### Other spans are text
The escape hatch lets a commit through.

- Scenario: s — WHEN `STRATA_SKIP_WIKI=1` is set THEN the commit passes ·
  `test: tests/test_gate.sh::escape hatch works`'
check "a non-pointer code span is not a pointer"   "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

page gate '## Requirements

### Wrapped pointer
x.

- Scenario: s — WHEN a THEN b · `test: tests/test_gate.sh::escape
  hatch works`'
check "a pointer wrapped across lines resolves"    "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

printf 'class TestA:\n    def test_b(self): pass\n' > tests/test_x.py
page gate '## Requirements

### Pytest id
x.

- Scenario: s — WHEN a THEN b · `test: tests/test_x.py::TestA::test_b`'
check "a pytest-style a::b needle resolves"        "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

page gate '## Requirements

````markdown
```markdown
### Nested
- Scenario: none
```
### Still nested
````'
check "a nested 4-backtick fence is skipped"       "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

page gate '## Requirements

You need python3 and git on PATH.'
check "Requirements prose with no ### is ignored"  "$(run_check)" ""

page gate ''
check "page without Requirements → nothing"    "$(printf '%s' "$(run_check)" | grep -c '^ERROR')" "0"

# --- plan lookup --------------------------------------------------------------
echo "P6 / T1 — state_tools.py plan"
PL=docs/superpowers/plans
touch "$PL/2026-09-01-spec-it-v2-plan.md"
check "no exact match → exit 1"                     "$(python3 "$ST" plan feature/spec-it >/dev/null 2>&1; echo $?)" "1"
touch "$PL/2026-09-10-spec-it-plan.md" "$PL/2026-09-28-spec-it-plan.md"
check "exact *-<segment>-plan.md, newest date wins" "$(python3 "$ST" plan feature/spec-it 2>/dev/null)" "$PL/2026-09-28-spec-it-plan.md"
check "  several matches → noted on stderr"         "$(has "$(python3 "$ST" plan feature/spec-it 2>&1 >/dev/null)" '2026-09-10-spec-it-plan.md')" yes
touch "$PL/spec-it-plan.md"
check "an undated <segment>-plan.md is not a plan"  "$(python3 "$ST" plan feature/spec-it 2>/dev/null)" "$PL/2026-09-28-spec-it-plan.md"
rm -f "$PL"/*.md

# --- owed -----------------------------------------------------------------------
echo "P6 / T1 — requirements.py owed"
page gate "$GOOD"
git add -A >/dev/null && git commit -qm "good page" >/dev/null
owed(){ python3 "$RQ" owed 2>/dev/null; }
owed_rc(){ python3 "$RQ" owed >/dev/null 2>&1; echo $?; }

git checkout -q -b feature/no-plan
err="$(python3 "$RQ" owed 2>&1 >/dev/null)"; out="$(owed)"; rc="$(owed_rc)"
check "no plan → stderr says so"               "$(has "$err" 'no plan for')" yes
check "  stdout empty, exit 0"                 "${out}:$rc" ":0"
git checkout -q main

git checkout -q -b feature/spec-it
python3 "$ST" init feature/spec-it --goal "spec it" >/dev/null
STATE="$(python3 "$ST" path feature/spec-it)"
PLAN=docs/superpowers/plans/2026-09-28-spec-it-plan.md
printf '# plan\n\n## T1\n\nstuff\n' > "$PLAN"
check "plan without a delta → silent, exit 0"  "$(owed):$(owed_rc)" ":0"

cat > "$PLAN" <<'EOF'
# plan

## Behaviour delta

### ADDED [[gate]]
#### Honours the escape hatch
The gate lets a commit through when asked to.

- Scenario: escape — WHEN `STRATA_SKIP_WIKI=1` THEN the commit passes ·
  `test: tests/test_gate.sh::escape hatch works`

#### Names the file
It names the file to ingest.

- Scenario: s — WHEN a THEN b · `manual: fixture`

### ADDED [[brand-new]]
#### Exists
It exists.

- Scenario: s — WHEN a THEN b · `manual: fixture`

### MODIFIED [[gate]]
#### Blocks at most once
The gate never forces a second continuation, per session.

- Scenario: second stop — WHEN the gate already blocked THEN the next stop exits 0 ·
  `test: tests/test_gate.sh::blocks once`

### REMOVED [[gate]]
#### Something old
Why: fixture.
EOF
out="$(owed)"
check "ADDED not in the page → owed"           "$(has "$out" 'Honours the escape hatch')" yes
check "  second #### under the same verb too"  "$(has "$out" 'Names the file')" yes
check "  exit 1 while something is owed"       "$(owed_rc)" "1"
check "ADDED to a missing page → create"       "$(has "$out" 'create wiki/entities/brand-new.md')" yes
check "MODIFIED with a different body → owed"  "$(printf '%s\n' "$out" | grep -c 'MODIFIED.*Blocks at most once')" "1"
check "REMOVED title absent → not owed"        "$(has "$out" 'Something old')" no
check "never touches wiki_debt"                "$(python3 "$ST" debt "$STATE" | grep -c .)" "0"

# apply the delta the way light-finish would — with different line wrapping
page gate '## Requirements

### Blocks at most once
The gate never forces a second continuation,
per session.

- Scenario: second stop — WHEN the gate already blocked THEN the next stop exits 0 · `test: tests/test_gate.sh::blocks once`

### Honours the escape hatch
The gate lets a commit through when asked to.

- Scenario: escape — WHEN `STRATA_SKIP_WIKI=1` THEN the commit passes · `test: tests/test_gate.sh::escape hatch works`

### Names the file
It names the file to ingest.

- Scenario: s — WHEN a THEN b · `manual: fixture`

### Something old
Still here.

- Scenario: s — WHEN a THEN b · `manual: fixture`'
page brand-new '## Requirements

### Exists
It exists.

- Scenario: s — WHEN a THEN b · `manual: fixture`'
out="$(owed)"
check "equal body, different wrapping → not owed" "$(has "$out" 'Blocks at most once')$(has "$out" 'escape hatch')" nono
check "REMOVED title still present → owed"        "$(has "$out" 'Something old')" yes
sed -i.bak '/^### Something old$/,/manual: fixture`$/d' wiki/entities/gate.md && rm -f wiki/entities/gate.md.bak
check "delta fully applied → silent, exit 0"      "$(owed):$(owed_rc)" ":0"

# a typo must never read as "no delta"
cp "$PLAN" "$WORK/plan.good"
sed -i.bak 's/^## Behaviour delta$/## Behavior delta/' "$PLAN" && rm -f "$PLAN.bak"
check "## Behavior delta (US spelling) → still parsed" "$(owed):$(owed_rc)" ":0"
printf '\n### ADDED [[brand-new]]\n#### Not yet\nx.\n\n- Scenario: s — WHEN a THEN b · `manual: x`\n' >> "$PLAN"
check "  and still finds what is owed"                 "$(has "$(owed)" 'Not yet')" yes
sed -i.bak 's/^## Behavior delta$/## Behaviour delta (gates)/' "$PLAN" && rm -f "$PLAN.bak"
check "## Behaviour delta (gates) → still parsed"      "$(has "$(owed)" 'Not yet')" yes
cp "$WORK/plan.good" "$PLAN"
for bad_head in '### Added [[gate]]' '### ADDED gate' '### RENAMED [[gate]]'; do
  cp "$WORK/plan.good" "$PLAN"; printf '\n%s\n#### X\nx.\n' "$bad_head" >> "$PLAN"
  check "malformed '$bad_head' → error, exit 1" "$(has "$(owed)" 'malformed')$(owed_rc)" yes1
done
cp "$WORK/plan.good" "$PLAN"; printf '\n### REMOVED [[gate]]\n\nnothing under it\n' >> "$PLAN"
check "a verb block with no #### → error"      "$(has "$(owed)" 'no ####')" yes
cp "$WORK/plan.good" "$PLAN"; printf '\n### ADDED [[gate]]\n#### Names the file\nagain.\n' >> "$PLAN"
check "the same (page, title) twice → error"   "$(has "$(owed)" 'twice')" yes
cp "$WORK/plan.good" "$PLAN"

check "unknown subcommand → exit 2"             "$(python3 "$RQ" frobnicate >/dev/null 2>&1; echo $?)" "2"
check "owed takes no argument → exit 2"         "$(python3 "$RQ" owed main >/dev/null 2>&1; echo $?)" "2"

echo
if [ "$fail" -eq 0 ]; then echo "P6 requirements: $pass/$pass passed"; exit 0; fi
echo "P6 requirements: $fail failed, $pass passed"; exit 1
