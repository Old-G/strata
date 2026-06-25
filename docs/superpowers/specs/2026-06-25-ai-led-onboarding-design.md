# Design — AI-led one-line onboarding for Strata

**Date:** 2026-06-25
**Status:** Approved (design); pending implementation plan
**Topic:** Turn Strata install + setup into a single line you drop into an AI agent, after which the AI itself drives the whole framework adoption — installing the plugin, then conducting `init`/`adopt`/`audit` conversationally.

---

## 1. Problem & goal

Today, getting Strata into a project is a multi-step manual ritual the human must learn and remember:

```
/plugin marketplace add Old-G/strata
/plugin install strata@strata
/reload-plugins
/strata:using-strata        # then figure out init vs adopt vs audit yourself
```

That is slow, easy to get wrong, and pushes the cognitive load (which command, in what order, what does each do) onto the human.

**Goal:** one line, dropped into a fresh AI session (or run in a terminal), after which **the AI leads everything** — it installs Strata, then conducts the full setup conversationally: detects new-vs-existing repo, checks prerequisites, proposes a plan, runs `init` or `adopt` to completion, runs the first `audit`, and hands off — asking questions one at a time and calling the commands itself.

**Verify (acceptance):** a person who knows nothing about Strata's commands can paste one line, answer a few questions, do exactly one manual action (reload), and end with a structured, green, self-describing repo — without ever typing a `/strata:*` command by hand.

---

## 2. Key constraint that shapes the design

Verified against Claude Code plugin mechanics (claude-code-guide research + local `~/.claude` inspection):

- A plugin **can** be installed non-interactively by writing two keys to a `settings.json`:
  - `extraKnownMarketplaces.strata = { "source": { "source": "git", "url": "https://github.com/Old-G/strata.git" } }`
  - `enabledPlugins["strata@strata"] = true`
- **But** newly-installed plugin skills (`/strata:*`) only activate after a **session restart or `/reload-plugins`**, and **the assistant cannot trigger that reload itself** — it is a user action.
- There is **no** native "fetch a remote instruction file on launch" mechanism.

**Consequence:** a fully seamless "one line → plugin installs → AI immediately uses `/strata:*`" in a single session is not possible. There is an unavoidable one-restart seam. The design's job is to make that seam a single, clearly-instructed human action with a ready-to-paste continuation prompt — not dead air.

**#1 implementation risk (must be verified during build):** whether writing `extraKnownMarketplaces` alone triggers an automatic git-clone of the marketplace on `/reload-plugins`, or whether the clone only happens via the interactive `/plugin marketplace add`. The bridge instruction therefore **always** includes the canonical `/plugin marketplace add` + `/plugin install` commands as a fallback, so the human never gets stuck even if config-only auto-clone does not fire.

---

## 3. Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Entry medium | Both — chat-prompt is the headline, `install.sh` is the alternative | Chat matches the "AI leads in this chat" vision; shell serves terminal-first users |
| Install model | Clean install via config + exactly one restart; AI emits a precise continuation prompt + breadcrumb | User-chosen; honest about the restart constraint |
| Config location | **Global** `~/.claude/settings.json` | Matches "set up all my projects"; plugin is inert until invoked; Strata ships **no** global hooks (mirror hook is per-project via init/adopt), so unrelated repos are untouched |
| `onboard` shape | **Thin conductor** that delegates to `/strata:init` or `/strata:adopt` | Strata's hard rule: thin glue, do not reimplement. init/adopt already own the logic + their own verifies |
| Session-2 scope | Drive through to the **first `/strata:audit`**, then suggest `refactor`/`feature` | User-chosen; audit is read-only so auto-running it is safe |

---

## 4. End-to-end flow

```
SESSION 1 — one line in chat  (or: run install.sh in terminal)
   │
   ├─ chat path: AI WebFetches BOOTSTRAP.md and EXECUTES it:
   │     step 0  idempotency: are /strata:* already available? → skip to onboard
   │     step 1  prereq scan (report-only): Superpowers, claude-mem, RTK
   │     step 2  write install config into ~/.claude/settings.json (idempotent merge) + VERIFY
   │     step 3  drop breadcrumb .strata/onboard.json (project type, prereqs, ts)
   │     step 4  print the BRIDGE block (exact human steps + continuation prompt + fallback)
   │
   └─ shell path: install.sh does step 2 (+ backup/validate) and prints the same bridge

[ HUMAN: /reload-plugins  (or restart Claude Code) ]   ← the single manual action

SESSION 2 — human pastes:  /strata:onboard
   └─ onboard (thin conductor):
        reads breadcrumb (resume context) → detect new|existing → re-check prereqs
        → propose plan as step→verify, get approval
        → DELEGATE to /strata:init  OR  /strata:adopt  (runs to completion, their verifies)
        → run /strata:audit (read-only first drift report)
        → hand off: "next: /strata:refactor for findings, or /strata:feature to build"
```

---

## 5. Components

### 5.1 `BOOTSTRAP.md` (repo root; fetched by raw URL)

An instruction document **addressed to the AI**, written so the AI *executes* it (not just summarizes it). Goal-driven (`step → verify`). Contents:

- **Header**: "You are bootstrapping Strata. Execute these steps in order; do not skip verifies."
- **Step 0 — idempotency.** If `/strata:*` skills are already available (plugin already loaded), skip install and go straight to invoking `strata:onboard`. Handles re-runs and already-installed machines.
- **Step 1 — prereq scan (report-only).** Detect Superpowers / claude-mem (recommended) and RTK (optional). Report present/missing; never hard-fail. (Reference: `reference/tool-integration.md`.)
- **Step 2 — write install config (idempotent merge).** Merge the two keys into `~/.claude/settings.json`. Must: create the file if absent; never clobber existing keys; produce valid JSON. **Verify:** read the file back, assert both keys present and JSON parses.
- **Step 3 — breadcrumb.** Write `.strata/onboard.json` in the project: `{ installedAt, projectType: "new"|"existing", prereqs: {...}, configLocation: "global" }`. Ensure `.strata/` is gitignored (append to `.gitignore`, merge-safe). This lets session 2 resume with context instead of cold-starting.
- **Step 4 — bridge.** Print the exact continuation block (see §6).

BOOTSTRAP.md works **pre-install** because it only requires the AI to read a doc, run bash, and write files — no plugin needed yet.

### 5.2 `skills/onboard/SKILL.md` (NEW skill — the session-2 conductor)

The active "AI leads everything" wizard. Thin conductor; delegates real work.

- **Frontmatter `description`** must trigger on: "continue Strata setup", "onboard this repo", post-bootstrap resume, and direct `/strata:onboard`.
- **Resume:** read `.strata/onboard.json` if present; use it to avoid re-asking what bootstrap already determined.
- **Detect new vs existing:** empty / near-empty dir & no substantial git history → `init` path; real code/history → `adopt` path. Confirm with the user (one question).
- **Prereq report:** re-check in the new session (session changed); surface what's missing and what it costs (e.g., "no Superpowers → the feature/TDD flow is degraded").
- **Plan:** state the chosen path as `step → verify`, get approval (honors Strata's plan-mode rule).
- **Delegate:** invoke `/strata:init` or `/strata:adopt` and let it run to completion with its own verifies. `onboard` does NOT duplicate their logic.
- **First audit:** run `/strata:audit` (read-only) and present the ranked drift report.
- **Hand off:** suggest `/strata:refactor` (for findings) and `/strata:feature` (to build the first feature). Do not auto-run those.
- `using-strata` (the existing router) gains one line pointing at `onboard` as the active entry; `onboard` references `using-strata` for the conceptual model.

### 5.3 `install.sh` (repo root; curl-able) — shell alternative

- Idempotent JSON merge (python3) of the two keys into `~/.claude/settings.json`.
- Safety: parse the existing file *before* touching anything — if it is not valid JSON (or its top level is not an object), abort with a non-zero exit and leave the file byte-for-byte untouched (the error path never writes, so there is nothing to restore). On the change path, take a timestamped backup, then write atomically (temp file + replace).
- Idempotent: when both keys are already present with the same values, the installer makes no change at all — no backup, no rewrite.
- Prints the same bridge block (§6), adapted: "Open `claude` in your project and send `/strata:onboard` (run `/reload-plugins` first if a session is already open)."
- POSIX `sh`-compatible invocation; relies on `python3` (document the dependency; it is present on macOS and standard Linux).

### 5.4 Documentation

- **README.md:** new top section "⚡ Instant setup (AI-led)" above the current manual Installation section, with both one-liners and a one-paragraph explanation of the single restart step. The existing manual instructions stay as "Manual install".
- **`skills/using-strata/SKILL.md`:** add `onboard` to the skills table and cross-link.
- **CLAUDE.md:** update the phase/status table to include the onboarding entry point; keep ≤ 200 lines.

---

## 6. The bridge (exact text the AI / script emits)

> ✅ Strata записана в конфиг. Осталось 2 шага:
> 1. Выполни `/reload-plugins` (или перезапусти Claude Code).
> 2. Вставь: `/strata:onboard`
>
> Если `/strata:onboard` не найден — сначала выполни `/plugin marketplace add Old-G/strata` и `/plugin install strata@strata`, затем `/strata:onboard`.

(An English variant ships alongside for non-Russian users. The fallback line is mandatory — it covers the config-only-auto-clone risk from §2.)

---

## 7. The one-liners (literal)

- **Chat (primary):**
  `Установи и запусти Strata в этом репозитории: забери и выполни инструкции из https://raw.githubusercontent.com/Old-G/strata/main/BOOTSTRAP.md`
  (English variant shipped too.)
- **Shell (alternative):**
  `curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | bash`

Both reference the `main` branch raw URL; both assume the repo is public.

---

## 8. Verifies (evidence before assertion)

1. **Config write is idempotent & valid** — after BOOTSTRAP step 2 / `install.sh`, `~/.claude/settings.json` parses and contains both keys; a second run changes nothing. *(testable now)*
2. **#1 risk — config-only activation** — on a clean profile, after writing config + `/reload-plugins`, confirm `/strata:onboard` resolves. If it does NOT, confirm the fallback (`/plugin marketplace add` + `/plugin install`) does. *(must be tested on a clean profile during build; document the observed behavior)*
3. **Idempotency step 0** — running BOOTSTRAP when `/strata:*` is already loaded skips install and goes straight to onboarding.
4. **onboard delegates correctly** — `new` repo path reaches a completed `/strata:init` (green smoke test); `existing` repo path reaches a completed `/strata:adopt` (tests still pass, adoption report written) — verified by each underlying skill's own verifies.
5. **First audit runs** — `onboard` ends by producing `docs/superpowers/specs/<date>-strata-audit.md` and presenting it.
6. **Bridge always escapable** — the fallback `/plugin` commands appear in every bridge emission.
7. **install.sh safety** — a corrupt/unreadable `settings.json` makes the installer abort *before* writing, leaving the file byte-for-byte unchanged (verified by `scripts/test_install.sh` T4: exit non-zero + file identical). A valid file is only ever modified via backup + atomic temp-file replace.

---

## 9. Out of scope (YAGNI)

- The "no-wait: clone + drive now in session 1" model (rejected in favor of clean install + 1 restart).
- Auto-installing prerequisites (Superpowers / claude-mem / RTK) — bootstrap **reports**, does not install them.
- Auto-running `/strata:refactor` or `/strata:feature` — onboarding stops after the first `audit` and only suggests them.
- Windows-native shell installer (the chat path is OS-agnostic; `install.sh` targets macOS/Linux + python3).
- Non-`main` branch / pinned-version one-liners.

---

## 10. Open implementation risks to watch

- **R1 (highest):** config-only marketplace auto-clone behavior (see §2 / §8.2). Mitigation: mandatory fallback in the bridge.
- **R2:** raw GitHub URL availability requires the repo public + network/WebFetch allowed. If WebFetch is blocked, the chat path degrades; document the shell path as the offline-ish fallback.
- **R3:** breadcrumb staleness — if a user runs bootstrap, abandons, and returns much later. Mitigation: `onboard` treats the breadcrumb as a hint and re-detects, never as ground truth.
