#!/usr/bin/env sh
# Strata installer — registers the Strata marketplace and enables the plugin by
# merging two keys into your Claude Code settings.json. Idempotent and
# non-destructive: existing keys are preserved, a timestamped backup is taken,
# and the write is aborted if the existing file is not valid JSON.
#
#   curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
#
# Target: ~/.claude/settings.json  (override with STRATA_SETTINGS=/path, used by tests)
set -eu

SETTINGS="${STRATA_SETTINGS:-$HOME/.claude/settings.json}"
MARKETPLACE_URL="https://github.com/Old-G/strata.git"

command -v python3 >/dev/null 2>&1 || {
  echo "✗ python3 is required but was not found on PATH." >&2
  exit 1
}

SETTINGS="$SETTINGS" MARKETPLACE_URL="$MARKETPLACE_URL" python3 - <<'PY'
import json, os, sys, time, shutil

path = os.environ["SETTINGS"]
url  = os.environ["MARKETPLACE_URL"]
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

data = {}
if os.path.exists(path):
    raw = open(path, encoding="utf-8").read()
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"✗ {path} is not valid JSON ({e}); refusing to touch it.", file=sys.stderr)
            sys.exit(1)
        backup = f"{path}.strata-bak.{int(time.time())}"
        shutil.copy2(path, backup)
        print(f"  backup: {backup}")

if not isinstance(data, dict):
    print(f"✗ {path} top-level JSON is not an object; refusing to touch it.", file=sys.stderr)
    sys.exit(1)

data.setdefault("extraKnownMarketplaces", {})["strata"] = {
    "source": {"source": "git", "url": url}
}
data.setdefault("enabledPlugins", {})["strata@strata"] = True

tmp = f"{path}.strata-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"✓ Strata registered in {path}")
PY

cat <<'EOF'

✅ Strata is in your config. Two steps left:
  1. Run  /reload-plugins   (or restart Claude Code).
  2. Send  /strata:onboard

If /strata:onboard isn't found, run  /plugin marketplace add Old-G/strata
and  /plugin install strata@strata  first, then  /strata:onboard.
EOF
