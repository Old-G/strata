# Diataxis Doc-Coverage Map

`/strata:audit` uses the **Diataxis** model to check whether a repo's
documentation is *complete and fresh* — not just present. Diataxis says good
docs split into four distinct kinds, each serving a different user need. Mixing
them (a tutorial that drifts into reference, an explanation pretending to be a
how-to) is the most common doc failure. The audit maps repo artifacts to the
four quadrants and flags any that are **missing** or **stale**.

## The two axes

Diataxis organizes docs along two axes:

- **Action vs. Cognition** — is the reader *doing* something, or *understanding*
  something?
- **Acquisition vs. Application** — are they *learning* (new to it), or *at work*
  (already competent, need help now)?

Crossing them gives four quadrants:

|                | **Action** (doing) | **Cognition** (understanding) |
|----------------|--------------------|-------------------------------|
| **Acquisition** (learning) | **Tutorial** | **Explanation** |
| **Application** (working)  | **How-to guide** | **Reference** |

## The four quadrants

### 1. Tutorial — *learning-oriented, doing*
A guided lesson that takes a newcomer from nothing to a first success. It holds
their hand; it does not explain every why. Goal: "I did it once and it worked."
- **Repo artifacts that map here:** `README` getting-started section, a
  `docs/tutorial.md` / `getting-started.md`, `examples/` walkthroughs, a
  quickstart in the top-level README.

### 2. How-to guide — *task-oriented, doing*
A recipe for a competent user solving a specific real problem ("how to deploy,"
"how to rotate the key," "how to add a migration"). Assumes context; gets to the
point.
- **Repo artifacts that map here:** `docs/how-to/*`, runbooks
  (`docs/runbooks/*`), `CONTRIBUTING.md` task sections, deploy/ops guides,
  `Makefile`/script comments that document a procedure.

### 3. Reference — *information-oriented, understanding-while-working*
Dry, accurate, exhaustive description of the machinery: APIs, CLI flags, config
keys, schemas, env vars. The user looks something up; doesn't read it cover to
cover.
- **Repo artifacts that map here:** API docs, generated docstrings, OpenAPI/
  schema files, `.env.example`, config reference, CLI `--help` output,
  data-model / schema docs.

### 4. Explanation — *understanding-oriented, learning*
The "why" — design rationale, tradeoffs, architecture, history. Discursive;
gives the reader a mental model.
- **Repo artifacts that map here:** ADRs (`docs/adr/*`), `ARCHITECTURE.md`,
  design docs, `SCALABLE_ARCHITECTURE_REFERENCE.md`, the wiki's explanatory
  entities, "why we chose X" sections.

## How /strata:audit uses the map

For the repo under audit, the auditor:

1. **Maps existing docs** to the four quadrants by location and content (a file
   can serve more than one, but the audit notes when one file is straining to be
   two — a smell worth flagging).
2. **Flags MISSING quadrants.** Coverage gaps are reported by quadrant:
   - *No Tutorial* → newcomers can't get a first win unaided.
   - *No How-to* → common tasks live only in someone's head.
   - *No Reference* → users guess at flags/config/schema.
   - *No Explanation* → no recorded "why," so decisions get re-litigated and
     ADRs drift.
3. **Flags STALE quadrants** by cross-checking docs against the code/structure
   layer: a Reference whose documented config keys no longer exist, a How-to
   pointing at a removed script, a Tutorial whose first command fails, an
   Explanation describing an architecture the code has since outgrown. The
   structure layer (PROJECT_PATTERN + SCALABLE_ARCHITECTURE_REFERENCE) and the
   wiki give the audit a source of truth to diff docs against.
4. **Reports per-quadrant status** — `present / missing / stale` — plus a
   prioritized list of the cheapest high-value gaps to close first (usually a
   missing How-to runbook or a stale Reference).

The point is not to demand all four quadrants for every tiny repo, but to make
the *shape* of the doc coverage visible so gaps are a decision, not an accident.
