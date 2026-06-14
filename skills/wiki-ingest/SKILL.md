---
name: wiki-ingest
description: Use when ingesting a docs/raw file into the wiki, querying the project knowledge base ("query <question>", "what does X do?"), or linting the wiki for drift — runs the docs→raw→wiki protocol from WIKI.md.
---

# Wiki Ingest / Query / Lint

You are the executable companion to `wiki/WIKI.md` (read it if present — it is the
canonical protocol). The knowledge base follows the three-layer split:

```
docs/  ──cp──>  raw/  ──ingest──>  wiki/  ──query/lint──>  AI answers
(people)        (AI reads)         (AI owns)
```

`docs/` is the human source-of-truth. `raw/` is a read-only script mirror — **never
edit it**. `wiki/` is AI-owned and derived. The AI queries `wiki/` FIRST, before
grepping the repo.

This skill handles three sub-operations the user triggers in prose. Pick the branch
that matches the request.

This skill is also invoked by **/strata:adopt** (to bulk-ingest existing docs on
adoption) and by **/strata:feature** (post-merge, to ingest docs that changed).

---

## INGEST — `ingest <raw-file>`

Trigger: "ingest raw/<file>.md", "проингестим X", or a caller handing you a changed
doc. Goal verify: every entity the source names has an `entities/` page, and `index.md`
+ `log.md` both show the new entry.

1. Read `raw/<file>.md` **in full**. (If only `docs/<file>.md` changed, first mirror it:
   `cp -p docs/<file>.md raw/<file>.md`.)
2. Create/update `wiki/sources/<slug>.md` — a **3–7 paragraph summary**, never a copy:
   what it is, key claims, entities it touches, decisions it anchors, open questions.
   Add frontmatter (`type: source`, `source: raw/<file>.md`, `created`, `updated`).
3. Extract **entities** (components, technologies, roles, patterns). For each, create or
   update `wiki/entities/<slug>.md` with these sections:
   - **TLDR** — one or two sentences.
   - **Role** — what it does / why it exists.
   - **Current solutions** — how it is implemented right now.
   - **Related** — `[[wiki-links]]` to neighbouring entities.
   - **Sources** — backlinks to the `sources/` pages that mention it.
   If the entity exists, add/refine a section and append the new source backlink — do
   not clobber prior knowledge.
4. If the source anchors a decision, create/update `wiki/decisions/adr-<n>-<slug>.md`
   (ADR number + title + context + decision + consequences).
5. Augment `wiki/glossary.md` with any new terms (short definitions; pin facts at risk
   of drift to their source-of-truth).
6. Update `wiki/overview.md` if the source changes the big picture (phase, layers,
   component map).
7. Add a one-line TLDR entry for every new/changed page to `wiki/index.md`.
8. Append to `wiki/log.md`:
   `[YYYY-MM-DDTHH:MM:SSZ] ingest raw/<file>.md → created/updated: <list>`.

**Cascade is expected**: one source can touch 5–15 wiki pages. That is correct, not
over-eager.

---

## QUERY — `query <question>`

Trigger: any question about the project ("how does X work?", "which components are
required for phase 0?"). Goal verify: the answer is sourced from `wiki/` pages you can
name, not from a fresh repo grep.

1. **Read `wiki/index.md` FIRST.** Match the question against the one-line TLDRs.
2. Follow the index to the relevant `entities/`, `decisions/`, `sources/`, and
   `overview.md` pages and read them.
3. Answer from `wiki/`, citing the pages you used (`[[entity]]`, `[ADR #N](decisions/...)`).
4. **Fallback rule**: only if the wiki genuinely lacks the detail, read the specific
   `raw/<file>.md`. When you do, **flag that ingest is incomplete** for that source and
   suggest re-ingesting it — a query fallback is a signal the wiki has a gap.
5. Optional (ask the user first): save a substantial answer as
   `wiki/entities/analysis-<slug>.md` (`type: analysis`) and add it to `index.md`.

Do NOT grep the codebase before consulting the wiki — that defeats the knowledge layer.

---

## LINT — `lint`

Trigger: explicit "lint", or every ~10th ingest. Goal verify: a fresh findings section
appears in `wiki/log.md`. **NEVER auto-fix — report only; the user decides.**

Run the mechanical helper first if it exists:

```bash
python3 wiki/scripts/lint.py
```

Then read across `wiki/` and report:

- **Contradictions** — page A says X, page B says ¬X.
- **Orphan pages** — no incoming `[[links]]` (candidate to linkify or delete).
- **Outdated refs** — links to entities that no longer exist; overview numbers that
  disagree with current sources.
- **Missing cross-links** — an entity named in prose without a `[[link]]`.
- **Drift** — `docs/` ↔ `raw/` ↔ `wiki/` mismatch (a `docs/` file newer than its `raw/`
  mirror, or a `raw/` file with no `sources/` page = un-ingested).

Write findings as a dated section in `wiki/log.md`:
`[YYYY-MM-DDTHH:MM:SSZ] lint → <N> findings: <summary>`. List each finding with the
pages involved so the user can act. Do not change any wiki page during a lint.

---

## Rules (from WIKI.md — do not contradict)

- No embeddings / vectorstores — `index.md` + structural reading is enough until
  hundreds of pages.
- `sources/` pages are **summaries**, not copies; full text stays in `raw/`.
- Never edit `raw/` by hand. Change `docs/` → mirror → ingest.
- Don't record ephemera (in-progress task state) — that lives in the plan, not the wiki.
