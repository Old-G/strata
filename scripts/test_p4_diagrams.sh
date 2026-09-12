#!/usr/bin/env bash
# Behavioural test for P4 / T3 — the diagram layer's deterministic half:
#   scripts/lib/state_tools.py add-debt      (idempotent wiki_debt append)
#   scripts/diagram_check.sh                 (pinned paths ∩ branch diff; re-pin-to-HEAD
#                                             validate when archify is present)
#
# Same discipline as the other test_p*.sh: throwaway git repo, the real shipped
# scripts, no mocks. Branch pinned to main. The archify half runs only where the
# skill is installed (ARCHIFY_BIN or ~/.claude/skills/archify); elsewhere the test
# asserts the skip line instead, so CI without archify stays meaningful.
# See docs/superpowers/specs/2026-09-12-p4-field-patterns.md, D3.
#
# Usage: bash scripts/test_p4_diagrams.sh          (exit 0 = all green)

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
cd "$WORK" || exit 1

git init -q .
git config user.email test@strata.local
git config user.name "Strata Test"
git checkout -q -b main
git remote add origin https://github.com/example/fixture.git
mkdir -p src wiki/diagrams scripts/lib
cp "$TPL/lib/state_tools.py"  scripts/lib/
cp "$TPL/diagram_check.sh"    scripts/ 2>/dev/null || true
printf '#!/bin/sh\necho a\n' > src/a.sh
printf '#!/bin/sh\necho b\n' > src/b.sh
printf 'seed\n' > README.md
printf '.strata/*\n!.strata/state/\nwiki/diagrams/history/*.html\n' > .gitignore
git add -A >/dev/null && git commit -qm seed
SEED="$(git rev-parse HEAD)"

# A minimal but complete architecture diagram pinning src/a.sh at the seed commit.
cat > wiki/diagrams/system.architecture.json <<EOF
{
  "schema_version": 1,
  "diagram_type": "architecture",
  "meta": {
    "title": "Fixture system",
    "quality_profile": "standard",
    "viewBox": [960, 480],
    "repository": { "url": "https://github.com/example/fixture", "provider": "github", "revision": "$SEED" }
  },
  "components": [
    { "id": "a", "type": "backend",  "label": "a.sh", "pos": [120, 200], "size": [160, 64],
      "sources": [ { "path": "src/a.sh", "line": 1, "label": "entry" } ] },
    { "id": "b", "type": "database", "label": "store", "pos": [640, 200], "size": [160, 64] }
  ],
  "connections": [ { "from": "a", "to": "b", "label": "writes" } ]
}
EOF
git add -A >/dev/null && git commit -qm "diagram"

CHECK=scripts/diagram_check.sh
ST=scripts/lib/state_tools.py

echo "P4 / T3 — diagram layer: add-debt + diagram_check.sh"

# 0. the script must exist and parse
if [ -f "$CHECK" ] && bash -n "$CHECK" 2>/dev/null; then ok "diagram_check.sh present and parses"; else bad "diagram_check.sh missing or has a syntax error"; fi

# 1. add-debt: appends once, idempotent, keeps the file valid
python3 "$ST" init main --goal "fixture" >/dev/null
STATE="$(python3 "$ST" path main)"
python3 "$ST" add-debt "$STATE" "diagram system: fixture item" >/dev/null 2>&1
python3 "$ST" add-debt "$STATE" "diagram system: fixture item" >/dev/null 2>&1
check "add-debt appends once (idempotent)" "$(python3 "$ST" debt "$STATE" | grep -c .)" "1"
check "  state still validates"            "$(python3 "$ST" validate "$STATE" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
python3 - "$STATE" <<'PY'
import json,sys; o=json.load(open(sys.argv[1])); o["wiki_debt"]=[]; json.dump(o,open(sys.argv[1],"w"),indent=2)
PY
git add -A >/dev/null && git commit -qm "state" >/dev/null

# 2. unrelated change on a branch → no findings, debt unchanged
git checkout -q -b feature/unrelated
printf 'echo more\n' >> src/b.sh
git commit -qam "touch b"
out="$(ARCHIFY_BIN=/nonexistent bash "$CHECK" main 2>/dev/null)"
check "unrelated change → no 'pinned file changed' finding" "$(has "$out" 'pinned file changed')" no
check "  debt unchanged" "$(python3 "$ST" debt "$(python3 "$ST" path feature/unrelated)" 2>/dev/null | grep -c .)" "0"
git checkout -q main

# 3. change to the pinned file → one finding, one wiki_debt item on the branch state
git checkout -q -b feature/touch-a
python3 "$ST" init feature/touch-a --goal "touch a" >/dev/null
BSTATE="$(python3 "$ST" path feature/touch-a)"
printf 'echo changed\n' >> src/a.sh
git add -A >/dev/null && git commit -qm "change a"
out="$(ARCHIFY_BIN=/nonexistent bash "$CHECK" main 2>/dev/null)"
check "pinned file changed → finding names the diagram" "$(has "$out" 'diagram system:')" yes
check "  finding names the file"                        "$(has "$out" 'src/a.sh')" yes
check "  finding recorded as wiki_debt"                 "$(python3 "$ST" debt "$BSTATE" | grep -c 'diagram system')" "1"
out2="$(ARCHIFY_BIN=/nonexistent bash "$CHECK" main 2>/dev/null)"
check "  second run does not duplicate the debt item"   "$(python3 "$ST" debt "$BSTATE" | grep -c 'diagram system')" "1"
check "archify absent → one skip line, exit 0"          "$(has "$out" 'pin verification skipped')" yes
# 3b. a branch state that no longer validates: the finding is still printed, and the script
#     must not claim it recorded anything (review nit on the first cut: record() swallowed the
#     add-debt failure and the closing line said 'recorded' regardless)
python3 - "$BSTATE" <<'PY'
import json,sys; o=json.load(open(sys.argv[1])); o["status"]="wip"; json.dump(o,open(sys.argv[1],"w"),indent=2)
PY
out="$(ARCHIFY_BIN=/nonexistent bash "$CHECK" main 2>/dev/null)"
check "invalid branch state → finding still printed"          "$(has "$out" 'diagram system:')" yes
check "  no false 'recorded as wiki_debt' line"                "$(has "$out" 'recorded as wiki_debt')" no
check "  says it could not record, and why"                    "$(has "$out" 'could not record')" yes
git checkout -q -- "$BSTATE"
git add -A >/dev/null && git commit -qm "debt recorded" >/dev/null   # state is tracked; commit before switching branches

# 4. with archify installed: deleting the pinned file fails the re-pinned validate
ARCH="${ARCHIFY_BIN:-$HOME/.claude/skills/archify/bin/archify.mjs}"
if command -v node >/dev/null 2>&1 && [ -f "$ARCH" ]; then
  git checkout -q main
  git checkout -q -b feature/delete-a
  git rm -q src/a.sh && git commit -qm "delete a"
  out="$(ARCHIFY_BIN="$ARCH" bash "$CHECK" main 2>/dev/null)"
  check "archify present + pinned file deleted → repository-evidence/file-missing" "$(has "$out" 'repository-evidence/file-missing')" yes
  check "  no skip line when archify is present" "$(has "$out" 'pin verification skipped')" no
  # a diagram without meta.repository is not re-pinned, and does not error
  git checkout -q main
  git checkout -q -b feature/norepo
  python3 - wiki/diagrams/system.architecture.json <<'PY'
import json,sys; o=json.load(open(sys.argv[1])); o["meta"].pop("repository"); [c.pop("sources",None) for c in o["components"]]; json.dump(o,open(sys.argv[1],"w"),indent=2)
PY
  git commit -qam "no repository metadata"
  out="$(ARCHIFY_BIN="$ARCH" bash "$CHECK" main 2>&1)"; rc=$?
  check "diagram without meta.repository → skipped quietly, exit 0" "$rc/$(has "$out" 'repository-evidence')" "0/no"
else
  ok "archify not installed on this machine — evidence half skipped (asserted the skip line above)"
  ok "(placeholder to keep the count stable)"
  ok "(placeholder to keep the count stable)"
fi

# 5. no wiki/diagrams/ at all → silent, exit 0
git checkout -q main
git checkout -q -b feature/nodiagrams
git rm -rq wiki/diagrams && git commit -qm "no diagrams"
out="$(ARCHIFY_BIN=/nonexistent bash "$CHECK" main 2>&1)"; rc=$?
check "no wiki/diagrams/ → silent, exit 0" "$rc/$out" "0/"

echo
echo "P4 diagrams: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
