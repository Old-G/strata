# Product-ready architecture — two levels

> Stack-agnostic. Read by `strata-eng-review` on every plan. The goal is a codebase someone else could
> pick up and run for themselves — another team, another company, a future SaaS tenant — **without
> building SaaS in advance**. Do now only what is cheap now and expensive to retrofit later.

## Which level applies

| Level | Applies to | How it is chosen |
|---|---|---|
| **1 — base** | every project | always |
| **2 — product** | a project its owner has named a product candidate | `.strata/profile` contains the word `product` |

Mark a project: `echo product > .strata/profile` and commit it. Remove the file to go back to level 1.

Asking for level 2 in a project without the marker is itself a finding: over-engineering
(essential vs. accidental complexity). An internal tool for one team does not need tenancy.

## Level 1 — always

| # | Rule | Why | Reviewer flags |
|---|---|---|---|
| 1.1 | **Nothing owner-specific in code.** People's names, chat/channel/user ids, absolute paths, project names, account emails, keys live in config or `.env`, with an `.env.example` entry. | The first thing that stops someone else from running it, and a common secret leak. | A literal id, personal path, name or address in source that decides behaviour. Test fixtures are fine. |
| 1.2 | **One external service, one module.** All calls to a given vendor (chat, tracker, mail, payments, an LLM API) go through one module; the rest of the code calls that module's functions. | Swapping or adding a vendor touches one place; tests can fake one seam. | The vendor's SDK or base URL imported or called from more than one module. |
| 1.3 | **Data goes through one place.** Reads and writes of a store go through a repository / storage layer, not ad-hoc queries scattered across handlers. | Adding an owner/tenant scope later is a change in one layer instead of every query. | New raw queries or file writes outside the storage layer. |
| 1.4 | **Modules by domain, small files.** A folder per domain concept with a clear entry point; a file has one reason to change. | Others find their way; changes stay local. | A grab-bag file (`utils`, `helpers`, `misc`) or a domain split across unrelated folders. |
| 1.5 | **Runs with one command; README says how.** Setup, config keys and the one command are in the README. | The difference between a project and a personal script. | New config, service or step with no README/`.env.example` change. |
| 1.6 | **No early generalisation.** Extract shared code on the third repetition, not the second; no plugin system for one plugin. | Premature abstraction is the most common way "reusable" code becomes unusable. | An interface/registry/factory with a single implementation and no second caller in sight. |

## Level 2 — product candidates only

| # | Rule | Why | Reviewer flags |
|---|---|---|---|
| 2.1 | **Every record has an owner scope** (workspace / tenant / organisation id), set at creation and filtered on every read. No process-wide singletons holding one owner's state. | The single most expensive thing to retrofit; leaks between customers are the worst bug class. | A new table, collection or file store without the scope column/key; a read without the scope filter; a global cache keyed without it. |
| 2.2 | **Config and secrets per scope.** Credentials, integrations and settings are looked up by scope, not read from one global env var. | Two customers never share a token. | A new integration reading a single global credential. |
| 2.3 | **A user exists in the model** even while there is one user: actions record who did them; permission checks have a place to live. | Audit and access control without a migration of every table. | New write paths that record no actor. |
| 2.4 | **Module boundaries are enforced by a tool** (import-boundary lint, package exports, architecture tests), not by convention. | Conventions erode under deadline; a failing check does not. | A cross-module import of internals; a new module with no declared public entry. |
| 2.5 | **Data can be exported and deleted per scope.** | A customer leaving, and privacy law. | A new store with no path to export or delete one scope's data. |

## What is deliberately not here

Billing, sign-up, multi-region, sharding, SSO, rate plans. They come with the first real customer,
not before. If a plan builds any of them for a project without a paying second user, flag it as
accidental complexity.
