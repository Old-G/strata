# P1 — Enforce + Route (Feature A1–A4, Feature C1–C4)

**Status:** plan, awaiting approval **Date:** 2026-08-15 **Tier:** risky
**Source:** [v-next brief](../specs/2026-08-14-vnext-brief.md) §2, §6 · [[vnext-brief]]

---

## Intent

When this is done, a Strata project cannot let its wiki silently drift, and Strata can be
driven end-to-end in Russian without typing a single `/strata:` command.

Concretely: an outstanding `pending_ingest` marker blocks both the end of the turn (once) and
the commit; every session opens with branch + pending list + wiki index head already in
context; and every skill's `description` matches the words a Russian-speaking user actually
types.

## Constraints

- **No global plugin hooks.** Scripts ship under `templates/core/scripts/{hooks,pre-commit,lib}/`;
  `init` / `adopt` install them into the *target* project's `.claude/settings.json`, exactly as
  `sync_raw_mirror.sh` is installed today. This repo dogfoods them on itself.
- **Bash only, no new dependencies.** No `jq`, no `yq`, no pre-commit framework. `python3` is
  already used by `sync_raw_mirror.sh` for JSON parsing and may be used the same way.
- **Loop safety is part of the spec, not polish** — see A1.
- Scope is P1 only: brief §2 (A1–A4) and §6 (C1–C4). §3, §7–8, §10–15 are context. Open
  questions #2–4 and #6–14 stay open.
- Decided: OQ#1 → [ADR #4](../../../wiki/decisions/adr-4-stop-gate-session-scope.md);
  OQ#5 → [ADR #2](../../../wiki/decisions/adr-2-native-invocation.md).
- `CLAUDE.md` ≤ 200 lines here and in every template.
- Release rule: adding skills/behaviour requires a version bump in **both**
  `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## Success criterion

`bash scripts/test_p1_gates.sh` is green, and in a fresh session on a fixture repo a Russian
feature request runs start-to-finish with zero slash commands while a planted `pending_ingest`
marker blocks both turn-end and commit.

---

## Shared design decisions (settled here, once)

**D1 — Marker retirement rule.** A `pending_ingest: <src>` line in `wiki/log.md` is *outstanding*
unless a **later** line in the same file matches `ingest raw/<mirror-of-src>`. Both gates use this
rule, implemented once in `scripts/lib/pending_ingest.sh` and sourced by both — never
reimplemented per gate.
*Found by dogfooding:* a naive `grep -c pending_ingest:` also counts prose that mentions the
token; the retirement rule must be pairing-based, and log prose must avoid writing the literal
marker string.

**D2 — Session boundary.** A3 writes `.strata/sessions/<session_id>.start` (epoch) on
`SessionStart`. A1 reads it to scope markers to the current session. If the file is absent (A3
not installed, or the session predates install) A1 **fails open** — exits 0 silently. A gate
that cannot know the boundary must not guess. `.strata/` is gitignored.

**D3 — Routing map lives in exactly one place.** C2 puts it in `CLAUDE.md`, which is already in
context every session; A3 does **not** duplicate it, only points at it. Single source of truth,
and the injection budget stays spent on state the model cannot otherwise see.

**D4 — Block channel.** A1 emits `{"decision":"block","reason":"…"}` on stdout and exits 0
(documented, explicit) rather than relying on exit-code-2 stderr semantics.

---

## Steps

Order is fixed: **A3 → A2 → A1 → A4 → C2 → C1 → C3 → finish.** A3 first because A1 depends on
its session stamp (D2), and A2 before A1 because the commit gate is the safe, non-interactive
half of the same marker logic.

### Step 1 — A3: SessionStart injection

**Changes**
- new `templates/core/scripts/lib/pending_ingest.sh` — prints outstanding markers, one per line,
  implementing D1. Exit 0 always.
- new `templates/core/scripts/hooks/strata_session_start.sh` — prints the ≤50-line context block
  (brief §2 A3: branch · last 3 `wiki/log.md` lines · pending list or "none" · first ~20 TLDR
  lines of `wiki/index.md` · the wiki-first rule) and writes the session stamp per D2.
- `templates/core/claude-settings-hook.json` — add the `SessionStart` entry; keep the
  `_strata_note` merge instructions accurate.
- `skills/init/SKILL.md` §4 and `skills/adopt/SKILL.md` §4 — install the two new scripts
  alongside `sync_raw_mirror.sh`.
- dogfood: `scripts/lib/`, `scripts/hooks/`, `.claude/settings.json`, `.gitignore += .strata/`.

**Verify**
```bash
echo '{"session_id":"t1"}' | bash scripts/hooks/strata_session_start.sh | tee /tmp/a3.out
test "$(wc -l < /tmp/a3.out)" -le 50 && grep -q '^Branch:' /tmp/a3.out
grep -q '2026-06-25-ai-led-onboarding-design' /tmp/a3.out   # the 4 real un-ingested sources
test -f .strata/sessions/t1.start
bash scripts/validate.sh
```

### Step 2 — A2: commit gate

**Changes**
- new `templates/core/scripts/pre-commit/check_wiki_fresh.sh` — sources the D1 helper; exits 1
  listing every outstanding marker with a runnable `/strata:wiki-ingest <file>` line per file;
  honours `STRATA_SKIP_WIKI=1`. Mirrors the style of the existing `check_raw_mirror.sh`.
- `skills/init/SKILL.md` §8 + `skills/adopt/SKILL.md` — add it to the installed pre-commit set.
- dogfood: `scripts/pre-commit/check_wiki_fresh.sh` + an untracked `.git/hooks/pre-commit` shim
  (no pre-commit framework — that would be a new dependency).

**Verify** — fixture-based, in `scripts/test_p1_gates.sh`:
outstanding marker → exit 1 and the remediation line names the file; `STRATA_SKIP_WIKI=1` →
exit 0; a paired `ingest raw/…` line later in the log → exit 0.

### Step 3 — A1: Stop gate

**Changes**
- new `templates/core/scripts/hooks/strata_stop_gate.sh`.
- `templates/core/claude-settings-hook.json` — add the `Stop` entry; init/adopt install lines.
- dogfood install.

Behaviour, in order:
1. Read `stop_hook_active` from stdin JSON — if true, `exit 0`. **First thing, unconditionally.**
2. No session stamp → `exit 0` (D2 fail-open).
3. Already blocked once this session (`.strata/sessions/<id>.blocked`) → `exit 0`. Hard cap: one
   forced continuation per session.
4. Outstanding markers newer than the session stamp (D1 + ADR #4) → block per D4, naming the
   files and the exact remediation; touch the `.blocked` marker.
5. Otherwise → `exit 0`.

**Verify** — in `scripts/test_p1_gates.sh`: block fires exactly once; `stop_hook_active=true`
returns immediately with no output; clean state exits 0 **in under 100 ms** (measured, asserted).

### Step 4 — A4: `light-finish` gains drift-close

**Changes** — `skills/light-finish/SKILL.md`: a numbered step between "Do it" and "Clean up" —
ingest every `docs/*.md` the branch touched; if only code changed, append a one-line summary to
`wiki/log.md` and update affected `entities/` pages. Not optional.

**Verify** — `bash scripts/validate.sh` (new check: `light-finish` mentions `wiki-ingest`), and
the step sits between steps 3 and 4 of the file.

### Step 5 — C2: routing map

**Changes** — `templates/core/CLAUDE.md.tmpl` gains the 6–8 line intent table from brief §6 C2,
in the Workflow section; the same table is added to this repo's `CLAUDE.md`. Nothing else grows.

**Verify** — both files ≤200 lines; table present; `bash scripts/validate.sh`.

### Step 6 — C1: 12 descriptions as bilingual trigger specs

**Changes** — every `skills/*/SKILL.md` frontmatter `description` rewritten as *use when the
user says X*, with concrete EN **and** RU phrases inline (ADR #2), plus a `## Do NOT use when`
section in the body of each.

**Verify** — new `validate.sh` checks, run over all 12: description present and ≤1024 chars;
contains at least one Cyrillic trigger phrase; body contains `## Do NOT use when`.

### Step 7 — C3: `using-strata` as coordinator

**Changes** — its `description` recast as a dispatcher (broad intent, loads early, routes, never
does the work), and an explicit "route, don't execute" operating rule in the body. The existing
skills table stays as the routing target.

**Verify** — `validate.sh` green; manual routing check folded into step 8.

### Step 8 — Finish: docs, release, end-to-end

**Changes**
- new `scripts/test_p1_gates.sh` — the staged fixture test covering steps 1–3; wired into
  `scripts/validate.sh` and `.github/workflows/ci.yml`.
- `README.md` — a hooks section (what each gate does, how to bypass, that nothing is global) and
  an auto-invocation section (no slash commands needed; how routing works).
- `CHANGELOG.md` — 0.4.0 entry.
- version bump to **0.4.0** in `.claude-plugin/plugin.json` **and** `.claude-plugin/marketplace.json`.
- mirror the touched `docs/` files to `raw/` and ingest, closing this plan's own markers.

**Verify (the brief's own verify for A and C)**
1. `bash scripts/test_p1_gates.sh && bash scripts/validate.sh` — green.
2. Staged test: with a planted marker, the turn cannot end and `git commit` fails; after ingest,
   both pass.
3. Fresh session shows the injected context block.
4. Manual, user-run: a feature driven start-to-finish in Russian with zero slash commands —
   "добавь X" → feature, "как у нас работает Y" → wiki query, "заканчиваем" → light-finish —
   with the correct skills observed loading and the wiki updated without being asked.

---

## Open decisions for approval

**Q1 — A1's second trigger (code-only changes).** The brief's A1 also blocks on "substantive
changes with no matching wiki log entry this session". Marker-based blocking alone satisfies the
brief's stated verify, but leaves code-only sessions unguarded — the exact gap §1 complains
about. Proposal: ship it, threshold `STRATA_STOP_GATE_LINES` (default 50, `0` disables),
counting changed lines in tracked files outside `wiki/ raw/ docs/`. Still capped at one block per
session. **Default ON or OFF?**

**Q2 — dogfooding A2 in this repo.** Plain `.git/hooks/pre-commit` shim (machine-local,
untracked, zero deps) vs a committed `.pre-commit-config.yaml` (needs the `pre-commit` tool =
new dependency). Proposal: the shim.

## Out of scope (named, not forgotten)

A5 `FileChanged` migration · A6 session distiller · all of Feature B · §7 `ablate` · §8 council
upgrades · §11–15. The 4 sources already mirrored into `raw/` but not yet ingested stay a
tracked backlog line in `wiki/index.md`.
