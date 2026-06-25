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

echo "== 2b. plugin.json component fields match the manifest schema =="
# Convention (verified against every official plugin): the standard dirs
# skills/, agents/, commands/, hooks/hooks.json are AUTO-DISCOVERED — so the
# manifest needs NO component-path fields at all. If you DO add them, the schema
# is strict: `agents` entries must be .md FILE paths (not a directory), `skills`
# entries are directory paths starting with "./". A folder string in `agents`
# (e.g. "./agents/") is rejected with "agents: Invalid input".
python3 - <<'PY' && ok "component fields valid (or absent — auto-discovered)" || err "plugin.json component field violates the manifest schema"
import json, sys
m = json.load(open(".claude-plugin/plugin.json"))
bad = False
def entries(v):
    return v if isinstance(v, list) else ([v] if isinstance(v, str) else [])
for item in entries(m.get("agents")):
    if not item.endswith(".md"):
        print(f"  agents: {item!r} must be a .md FILE path, not a directory "
              f"(remove the field — agents/ is auto-discovered)", file=sys.stderr); bad = True
for key in ("skills", "commands"):
    for item in entries(m.get(key)):
        if not item.startswith("./"):
            print(f"  {key}: {item!r} must start with './'", file=sys.stderr); bad = True
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

echo "== 5b. root install.sh parses =="
if [ -f install.sh ]; then
  sh -n install.sh 2>/dev/null && ok "install.sh" || err "install.sh has a shell syntax error"
fi

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
