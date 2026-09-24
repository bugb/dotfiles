---
description: Long-running work: plan, parallel implement, review each slice as it lands, prove it, then ship
---

Run $ARGUMENTS as a long task. You are the driver: you plan, you decide, you
integrate. Subagents do the typing. You do not hand the plan to an agent.

## 1. Own the decomposition

Map the request yourself before spawning anything. Produce:

- the slices that are genuinely independent (different files, no shared state)
- the contracts between them: exact interfaces, schemas, field names, error
  shapes. Decide these now and put them in the batch `context`. Two agents
  negotiating an interface mid-flight will produce two different interfaces.
- the invariants that define "wrong", not just "done"

Create a todo list. One item per slice, plus the verification that proves it.

## 2. Implement in parallel, review in series

Dispatch independent slices as one `tasks[]` batch. Every task instruction must
say: skip formatters, skip linters, skip the project test suite. Agents that
validate mid-flight block on each other's half-finished edits.

dispatch `astra-high-review` on **that slice alone**, while the
other slices are still being written. Reviewing a small change against a fresh
context finds more than reviewing the union at the end, and it finds it while
the decision is still cheap to reverse.

Serialize only the genuinely shared boundary: name one integration owner and let
the others coordinate with it through `hub` before touching the shared file.

## 3. Close the loop on evidence, not opinion

A review verdict is not proof. Before you accept any fix:

- reproduce the failure first, so you know the test can fail
- apply the fix
- confirm the reproduction no longer triggers
- where a plausible future bug would reintroduce it, keep the reproduction as a
  regression test, and verify it fails against the old code

If a reviewer approves something you have not exercised, exercise it. Running
code outranks a careful read. A fix that only passed review is unverified.

## 4. Re-review the fix

The last change you make is the one nobody has looked at. Every time you act on
findings, dispatch a fresh `astra-high-review` on the fixed state. Loop until it
approves with zero findings. Do not carry an open finding past a phase boundary.

## 5. Keep the driver's context clean

Long tasks die from context exhaustion, not difficulty. Push bulk reading into
scouts and let them return compressed findings. Pass large payloads between
agents as `local://` paths, never inline. Keep decisions and invariants in your
own context; keep file dumps out of it.

## 6. Report

State what was built, what was verified and how, what a reviewer flagged and how
it was fixed, and anything left open with the reason. Never claim a verification
you did not run.
