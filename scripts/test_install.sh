#!/usr/bin/env bash
# Behavioral tests for install.sh — runs it against a temp settings file
# (STRATA_SETTINGS override) and asserts the resulting JSON. bash + python3 only.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
fail=0
err() { echo "  ✗ $1"; fail=1; }
ok()  { echo "  ✓ $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

has_strata() {
  python3 -c "
import json
d=json.load(open('$1'))
assert d.get('extraKnownMarketplaces',{}).get('strata',{}).get('source',{}).get('url')=='https://github.com/Old-G/strata.git', 'marketplace missing'
assert d.get('enabledPlugins',{}).get('strata@strata') is True, 'plugin not enabled'
" 2>/dev/null
}

echo "== T1: fresh file (does not exist) =="
S="$TMP/fresh.json"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
{ [ -f "$S" ] && has_strata "$S"; } && ok "fresh install writes both keys" || err "fresh install failed"

echo "== T2: preserves existing keys =="
S="$TMP/existing.json"
printf '{"env":{"FOO":"bar"},"enabledPlugins":{"other@x":true}}' > "$S"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
python3 -c "
import json
d=json.load(open('$S'))
assert d['env']['FOO']=='bar'
assert d['enabledPlugins']['other@x'] is True
assert d['enabledPlugins']['strata@strata'] is True
" 2>/dev/null && ok "existing keys preserved + strata added" || err "merge clobbered existing keys"

echo "== T3: idempotent =="
S="$TMP/idem.json"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
A="$(python3 -c "import json;print(json.dumps(json.load(open('$S')),sort_keys=True))")"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
B="$(python3 -c "import json;print(json.dumps(json.load(open('$S')),sort_keys=True))")"
[ "$A" = "$B" ] && ok "second run is a no-op" || err "not idempotent"

echo "== T4: refuses corrupt JSON, leaves file unchanged =="
S="$TMP/corrupt.json"
printf '{ this is not json ' > "$S"
before="$(cat "$S")"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
rc=$?
after="$(cat "$S")"
{ [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; } && ok "aborts on corrupt JSON, file untouched" || err "did not protect corrupt file"

echo "== T5: no-op re-run creates no new backup =="
D="$TMP/backups"
mkdir -p "$D"
S="$D/settings.json"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
n1="$(find "$D" -name '*.strata-bak.*' | wc -l | tr -d ' ')"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
n2="$(find "$D" -name '*.strata-bak.*' | wc -l | tr -d ' ')"
[ "$n1" = "$n2" ] && ok "no-op re-run took no backup ($n1 == $n2)" || err "backup proliferated on no-op ($n1 -> $n2)"

echo
if [ "$fail" -eq 0 ]; then echo "✅ install.sh tests PASSED"; else echo "❌ install.sh tests FAILED"; fi
exit "$fail"
