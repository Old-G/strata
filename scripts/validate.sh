#!/usr/bin/env bash
# Validate the Strata plugin structure. Run locally or in CI.
# Exit non-zero on any failure. No external deps beyond bash + python3.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
err() { echo "  ✗ $1"; fail=1; }
ok()  { echo "  ✓ $1"; }

echo "== 1. JSON manifests parse =="
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json templates/core/claude-settings-hook.json; do
  if python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then ok "$f"; else err "$f is not valid JSON"; fi
done

echo "== 2. plugin.json has required 'name' =="
python3 -c "import json; assert json.load(open('.claude-plugin/plugin.json')).get('name'), 'missing name'" 2>/dev/null \
  && ok "plugin.json name present" || err "plugin.json missing 'name'"

echo "== 2b. plugin.json skills/agents component fields are well-formed =="
# A folder reference MUST be a string ("./agents/"). An array is only for listing
# individual files; an array containing a folder path (["./agents/"]) is REJECTED by
# the Claude Code validator. Catch that regression here.
python3 - <<'PY' && ok "skills/agents fields well-formed" || err "plugin.json skills/agents field is malformed (folder must be a string, not an array)"
import json, sys
m = json.load(open(".claude-plugin/plugin.json"))
bad = False
for key in ("skills", "agents", "commands"):
    v = m.get(key)
    if v is None:
        continue
    if isinstance(v, list):
        for item in v:
            if isinstance(item, str) and item.rstrip().endswith("/"):
                print(f"  {key}: array contains a folder path {item!r} — use a string instead", file=sys.stderr)
                bad = True
sys.exit(1 if bad else 0)
PY

echo "== 3. every skill has name + description frontmatter =="
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  grep -q '^name:' "$f"        || err "$f missing 'name:'"
  grep -q '^description:' "$f" || err "$f missing 'description:'"
  grep -q '^name:' "$f" && grep -q '^description:' "$f" && ok "$f"
done

echo "== 4. every council agent has name + description + tools =="
for f in agents/*.md; do
  [ -f "$f" ] || continue
  grep -q '^name:' "$f" && grep -q '^description:' "$f" && grep -q '^tools:' "$f" \
    && ok "$f" || err "$f missing name/description/tools frontmatter"
done

echo "== 5. shell templates pass 'bash -n' =="
for f in $(find templates -name '*.sh'); do
  bash -n "$f" 2>/dev/null && ok "$f" || err "$f has a shell syntax error"
done

echo "== 6. python templates parse =="
for f in $(find templates -name '*.py'); do
  python3 -c "import ast; ast.parse(open('$f').read())" 2>/dev/null && ok "$f" || err "$f has a syntax error"
done

echo "== 7. no private/internal markers leaked into shipped files =="
if git grep -niE 'levhaolam|lh_ai_brain|46\.51\.161|/home/(andrey|gleb)|/opt/lh|analytics_priority' \
     -- skills agents templates 2>/dev/null | grep -q .; then
  err "private marker found in skills/agents/templates (run the grep to see)"
else
  ok "no private markers in skills/agents/templates"
fi

echo
if [ "$fail" -eq 0 ]; then echo "✅ Strata plugin validation PASSED"; else echo "❌ validation FAILED"; fi
exit "$fail"
