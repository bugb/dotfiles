---
description: Two-vendor plan consensus — codex and claude must agree before any code is written
---

Produce a plan for $ARGUMENTS that both vendors independently ratify.

## Round 1 — independent, parallel

Dispatch `plan-codex` and `plan-claude` in the **same** `tasks[]` batch so they
plan concurrently and neither sees the other's answer. Give both the identical
brief: the goal, the constraints, the invariants, the non-goals, and the exact
area of the codebase involved. Do not hint at a preferred approach — a steered
consensus is worth nothing.

## Round 2 — cross-critique

Write each plan to `local://plan-codex.md` and `local://plan-claude.md`. Dispatch
both agents again, in parallel, each given the peer's plan and asked to return
`AGREE` or `DISAGREE` with evidence-backed `disagreements`.

## Round 3 — converge

- **Both AGREE** → the plan is settled. Proceed.
- **One disagrees** → you adjudicate. Check the objection against the code
  yourself; do not take either model's word. Fold the correct points into a
  merged plan and re-run round 2 on the merged version.
- **Both disagree with each other** → the task is underspecified. Say what is
  ambiguous and ask the user, rather than picking a side and discovering the
  problem during implementation.

Cap at three convergence rounds. If they still disagree, the disagreement is the
finding: report both positions with their evidence and let the user decide.

## After consensus

Write the settled plan to `local://plan.md` and build a todo list from it, one
item per slice plus its verification. Then implement with `implementer` and
peer-review with `astra-high-review` — the vendor that did not write the code
reviews it.

Never skip straight from a single model's plan to implementation. The whole point
is that the two vendors fail differently.
