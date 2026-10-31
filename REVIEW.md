# REVIEW.md — what a reviewer of Strata must know
<!-- The code owner writes this; strata-diff-review and the council read it. Keep it 5–15 lines. -->

- **Broken here means:** a skill or agent tells the agent something untrue, or its description routes the wrong words; a gate blocks when it should pass or passes when it should block; a template carries a private name or path into someone else's repo; a doc says what the code no longer does.
- **Nits:** at most 5 per review; count the rest. Never block on one.
- **Skip:** `raw/` (a mirror of `docs/`), `wiki/diagrams/*.html` (rendered), `templates/core/scripts.history` (generated), `architecture-delta.html`.
- **Always a human:** `.claude-plugin/*.json` (a release), any skill `description:` (the routing surface), `templates/core/scripts/hooks/` (runs in every adopted repo) — the reviewer names them, a person signs off.
- **Evidence:** every finding cites `file:line` it read; nothing guessed from a name. A gate finding names the test case that would go red.
- **Pre-existing:** what this branch did not write (`git blame`) goes in its own list and is never Important.
- **Summary:** opens with the number of findings; with none, it says "Nothing to fix."
