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

echo "== 2c. one version, stamped everywhere it is claimed =="
# A version nobody can read is not a version. The entry skill carries the stamp
# so ANY session can answer "which Strata is running" from the skill listing
# alone -- no shell, no invocation, and it works in a repo that never adopted
# Strata (where `.strata/version` does not exist). That is only true while the
# stamps agree, so plugin.json is the single source and every other claim about
# the version is checked against it, in BOTH directions: a stamp may not go
# stale, and it may not go missing.
python3 - <<'PY' && ok "version stamps agree (plugin.json = marketplace.json = using-strata = CLAUDE.md)" || err "version stamp check failed (see above)"
import json, re, sys

bad = False
def fail(msg):
    global bad
    print(f"  {msg}", file=sys.stderr); bad = True

version = json.load(open(".claude-plugin/plugin.json"))["version"]

mk = json.load(open(".claude-plugin/marketplace.json"))["plugins"][0].get("version")
if mk != version:
    fail(f".claude-plugin/marketplace.json: v{mk} != plugin.json v{version}")

SKILL = "skills/using-strata/SKILL.md"
text = open(SKILL, encoding="utf-8").read()
parts = text.split("---", 2)
front, body = (parts[1], parts[2]) if len(parts) == 3 else ("", text)

def stamps(s):
    return re.findall(r"v(\d+\.\d+\.\d+)", s)

for where, chunk in (("description", front), ("body", body)):
    found = stamps(chunk)
    if not found:
        fail(f"{SKILL}: no version stamp in the {where} -- a session cannot tell v{version} from any other build")
    for got in found:
        if got != version:
            fail(f"{SKILL} ({where}): stamped v{got}, plugin.json says v{version}")

claude_md = open("CLAUDE.md", encoding="utf-8").read()
found = stamps(claude_md)
if not found:
    fail(f"CLAUDE.md: no version stamp -- the repo's own status line no longer says which build it describes")
for got in found:
    if got != version:
        fail(f"CLAUDE.md: stamped v{got}, plugin.json says v{version}")

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

echo "== 8. skill descriptions are bilingual trigger specs (C1) =="
# The description is the ENTIRE routing surface at dispatch time: Claude matches
# the user's actual words against it. So every skill must carry concrete trigger
# phrases in BOTH languages the user types (EN + RU, inline — ADR #2), and a
# "Do NOT use when" guard, because over-broad descriptions are the classic
# false-trigger failure mode.
python3 - <<'PY' && ok "all skills carry EN+RU triggers, a length-safe description, and a Do-NOT guard" || err "skill description/guard check failed (see above)"
import glob, re, sys

MAX = 1024
bad = False
for path in sorted(glob.glob("skills/*/SKILL.md")):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^description:[ \t]*(.+?)(?=^\w+:|^---)", text, re.M | re.S)
    desc = " ".join(m.group(1).split()) if m else ""
    if not desc:
        print(f"  {path}: no description", file=sys.stderr); bad = True; continue
    if len(desc) > MAX:
        print(f"  {path}: description is {len(desc)} chars (max {MAX})", file=sys.stderr); bad = True
    if not re.search(r"[Ѐ-ӿ]", desc):
        print(f"  {path}: description has no Russian trigger phrase", file=sys.stderr); bad = True
    if "## Do NOT use when" not in text:
        print(f"  {path}: missing a '## Do NOT use when' section", file=sys.stderr); bad = True
sys.exit(1 if bad else 0)
PY

echo "== 9. P1 enforcement gates behave (A1/A2/A3) =="
# Behavioural, not structural: builds a throwaway repo and drives the real
# scripts through their real interfaces. Structure checks cannot tell you a gate
# blocks when it should, or that it stops blocking after one warning.
if [ -f scripts/test_p1_gates.sh ]; then
  if out="$(bash scripts/test_p1_gates.sh 2>&1)"; then
    ok "$(printf '%s' "$out" | tail -n 1)"
  else
    printf '%s\n' "$out" | grep '✗' >&2
    err "P1 gate tests failed (run: bash scripts/test_p1_gates.sh)"
  fi
else
  err "scripts/test_p1_gates.sh is missing"
fi

echo "== 10. P2 episodic state layer behaves (state_tools.py, Stop-gate trigger c, upgrade check) =="
if [ -f scripts/test_p2_state.sh ]; then
  if out="$(bash scripts/test_p2_state.sh 2>&1)"; then
    ok "$(printf '%s' "$out" | tail -n 1)"
  else
    printf '%s\n' "$out" | grep '✗' >&2
    err "P2 state layer tests failed (run: bash scripts/test_p2_state.sh)"
  fi
else
  err "scripts/test_p2_state.sh is missing"
fi

echo "== 11. P3 PreToolUse guard behaves (A5: raw/ mirror, tests read-only mid-fix) =="
if [ -f scripts/test_p3_guards.sh ]; then
  if out="$(bash scripts/test_p3_guards.sh 2>&1)"; then
    ok "$(printf '%s' "$out" | tail -n 1)"
  else
    printf '%s\n' "$out" | grep '✗' >&2
    err "P3 guard tests failed (run: bash scripts/test_p3_guards.sh)"
  fi
else
  err "scripts/test_p3_guards.sh is missing"
fi

echo
if [ "$fail" -eq 0 ]; then echo "✅ Strata plugin validation PASSED"; else echo "❌ validation FAILED"; fi
exit "$fail"
