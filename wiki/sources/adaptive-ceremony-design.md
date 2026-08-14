---
title: "Adaptive ceremony for /strata:feature — design"
type: source
source: raw/superpowers/specs/2026-07-21-adaptive-ceremony-design.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — Adaptive ceremony (design, 2026-07-21)

The design behind v0.3.0: scale the feature flow to the size and risk of the task automatically, so
trivial work is fast and cheap while risky work still gets real guardrails. Its defining move is
that it **removes** machinery rather than adding it.

## The bet

Fixed-ceremony workflows run the same spec → plan → per-step TDD → per-step review pipeline on
every task; on frontier models that is over-engineered for small work. (Superpowers' own author
shipped a ~60% cheaper v6 after finding review loops gave no measurable quality gain.) The opposite
pole — vibe-coding — is cheap but unguarded. Nobody auto-calibrates ceremony to the task; every
tool makes the human choose. Strata's bet is to own that empty middle.

## Building for frontier models

The design follows Anthropic's Claude-5/Opus-5 guidance explicitly, and this is why v0.3 deletes
things: don't over-constrain; **don't instruct self-verification** (Opus 5 verifies its own work,
and explicit verification instructions cause over-verification with no quality gain); don't use
subagents to double-check your own work; effort is the primary cost lever; give the complete spec
up front and leave the model alone.

The distinction that keeps Strata's evidence rule alive under that guidance: *telling the model to
double-check itself* is banned scaffolding, while *requiring real evidence* — run the test, show
the output — is ground truth. **Proof, not reminders.** It is also why verification was folded into
`feature` as an evidence-cadence block instead of shipping as its own skill.

## The mechanism

Three tiers — `trivial` / `standard` / `risky` — auto-classified in a cheap Phase 0 that emits tier
+ one-line why + what it skips, then proceeds without a gate (the human can bump anytime). Bias up
on doubt. A list of **risk surfaces** — auth, secrets, PII, money, untrusted input, migrations,
public API, concurrency — forces `risky` however small the change looks.

Beneath every tier sits a four-part floor: evidence, risk auto-escalation, drift-close via
[[pending-ingest-marker]]/`wiki-ingest`, and git safety. Effort per tier (`low`/`medium`/`high`) is
the main token lever. The council became **risk-triggered and lens-selected** — one or two matching
reviewers on risky work, the full panel only when risks genuinely coincide — because its value is
independent adversarial perspective on a risky surface, not routine verification. A prompting note
worth keeping: ask a reviewer to report everything and filter afterwards, since telling it "only
high-severity" makes it literally report less.

Named risks: misclassification (mitigated by the floor plus visible tier and easy override), and
`trivial` eroding into vibe-coding (mitigated by the floor holding at every tier). The drift-close
element of that floor is exactly what P1's [[enforcement-layer]] later made deterministic — this
design named the obligation, but left it as prose.
