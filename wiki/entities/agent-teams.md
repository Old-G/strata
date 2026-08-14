---
title: Agent Teams / council v2
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [hq-mode]
---

# Agent Teams / council v2

## TLDR

Claude Code's native multi-agent primitive — teammates as full independent instances with a
shared task list and peer-to-peer mailboxes — and the council upgrade it unlocks: reviewers who
argue with each other *before* synthesis.

## Role

Today's Strata council spawns Task-tool subagents that report only to the parent, so reviewers
first meet each other's opinions at the synthesis step. Agent Teams changes the topology.

## Current solutions

Watch-and-adopt, P3. Experimental since Claude Code v2.1.32 / Opus 4.6 (Feb 2026), enabled by
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`: one session is the team lead, teammates have isolated
contexts, a shared task list with file locking, and p2p messaging; `TeammateIdle` /
`TaskCompleted` hook events integrate. Known rough edges: session resumption and shutdown.

Planned use: risk tier ≥ *risky* spawns reviewers as teammates who must exchange at least one
challenge/response before issuing verdicts; the lead synthesizes. Falls back to Task-tool
subagents when the env var is off — a capability check, never a hard dependency. Bonus pattern:
builder + shadow-reviewer teammate running concurrently on CRITICAL work.

Council upgrades queued alongside it, mined from Anthropic's RH-campaign volume: verdict-first
structured reports with a prescribed enum (`VIABLE / EMPTY / PARTIAL`), **negative controls** (a
deliberately broken variant the review must catch — a review that passes it is itself broken),
hostile blind referees each handed a specific suspected weakness and an attack plan, and blind
re-derivation of the critical piece from the spec alone. Which lands first is OQ#7.

## Related

[[hq-mode]] · [[session-reflector]]

## Sources

[[vnext-brief]] §8, §11.1, §12.4
