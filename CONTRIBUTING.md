# Contributing to Strata

Thanks for helping improve Strata. It's a Claude Code plugin — mostly Markdown skills, subagent
personas, and bundled templates — so contributing is light on tooling.

## Develop locally

```bash
git clone https://github.com/Old-G/strata.git
claude --plugin-dir /path/to/strata     # load the plugin from the working tree
/reload-plugins                          # after editing any skill or agent
/strata:using-strata                     # smoke-check the entry skill loads
```

## Project layout

```
.claude-plugin/   plugin.json + marketplace.json  (this repo is its own marketplace)
skills/<name>/SKILL.md   one skill per command, invoked /strata:<name>
agents/*.md       council reviewer subagents (read-only)
templates/core/   stack-neutral assets copied into target projects
templates/stacks/<stack>/   per-stack architecture canon
reference/        human-facing docs (personas, tool integration, Diataxis)
scripts/validate.sh   structure validator (also runs in CI)
```

## Conventions

- **Skills**: frontmatter needs `name:` (matches the directory) and a `description:` that starts with
  "Use when …" and names concrete triggers — that's how Claude decides to auto-invoke. The body is
  imperative, numbered, step-by-step instructions to the executing agent.
- **Skill names have no `strata-` prefix** — the plugin namespace already adds it (`/strata:audit`).
  **Subagents in `agents/` keep the `strata-` prefix** to avoid collisions in target projects.
- **Bundled assets** are referenced at runtime via `${CLAUDE_PLUGIN_ROOT}/...`, never hardcoded paths.
- **No global hooks.** The plugin ships no global hooks; per-project hooks (docs→raw mirror) are
  installed into the target project by `init`/`adopt`.
- **Templates must be generic.** No company names, internal hostnames/IPs, employee names, or
  project-specific service inventories — they get copied into other people's repos. `scripts/validate.sh`
  checks for common leaks.
- **CLAUDE.md ≤ 200 lines**, here and in every template.

## Adding a skill

1. `mkdir skills/<name>` and write `SKILL.md` with the frontmatter above.
2. If it needs heavy detail, put it in `skills/<name>/sections/<topic>.md` and reference it.
3. Wire it into `skills/using-strata/SKILL.md` (the router) if users should discover it there.
4. Run `bash scripts/validate.sh`.
5. **Bump the version** (see [Releasing](#releasing--bump-the-version)) — otherwise the marketplace keeps serving the old build without your skill.

## Adding a stack pack

Copy `templates/stacks/python-fastapi/` to `templates/stacks/<stack>/`, replace the architecture
reference with one for that stack, and keep the two entry points (`init` copies the canon; `audit`
reads its anti-patterns). See that pack's `README.md`.

## Releasing — bump the version

The marketplace serves the plugin by its **`version`** field. If you change a shipped
skill/agent/template and DON'T bump the version, `/plugin install strata@strata` keeps serving the
previously-cached build and consumers never get your change — even though it's on `main`. (We hit
exactly this: `onboard` was on `main` but the marketplace still advertised `0.1.2`, so installs had
no `/strata:onboard`.)

So, as part of any user-facing change:

1. Bump `version` in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (keep
   them identical; SemVer — feature → minor, fix → patch).
2. Move the `CHANGELOG.md` `[Unreleased]` notes into a dated `[x.y.z]` section.
3. After merge, existing installs refresh with `/plugin marketplace update strata` → reinstall →
   `/reload-plugins`.

## Before opening a PR

```bash
bash scripts/validate.sh     # must pass (CI runs the same)
```

Dogfood when you can: run `/strata:audit` on a repo that has Strata adopted and confirm your change
doesn't introduce drift. Keep commits focused; reference the finding or issue they address.

## Attribution

The review-council personas and sprint phases are adapted from
[gstack](https://github.com/garrytan/gstack) (MIT). The wiki pattern follows Andrej Karpathy's
pull-forward knowledge base. The process layer wraps [Superpowers](https://github.com/obra/superpowers).
Keep these credits intact.
