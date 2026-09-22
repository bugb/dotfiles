---
description: Have codex review the current change (uncommitted diff, or $ARGUMENTS)
---

Dispatch the `codex-review` agent over the work in progress.

Scope, in order of preference:

1. If `$ARGUMENTS` is given, review exactly that: a path, a commit range like
   `main...HEAD`, or a PR number.
2. Otherwise review the uncommitted change: `git diff HEAD` plus untracked files
   that are not ignored.
3. If the tree is clean, review the last commit: `git show HEAD`.

Before dispatching, work out the scope yourself and put it in the task prompt:
name the exact files and symbols that changed, and state anything that is
deliberately out of scope so the reviewer does not relitigate settled ground.
A reviewer that has to guess the scope wastes a round trip.

Give the agent:

- the concrete file list and what each change is trying to achieve
- the invariants that must hold (what would make this change wrong)
- any constraint already agreed in this session
- explicit non-goals and known pre-existing issues

Then act on the result:

- `APPROVE` with no findings → report it and continue.
- `CHANGES_REQUIRED` → fix every finding, then dispatch a fresh `codex-review`
  on the fixed state. Repeat until it approves. Do not argue with a finding you
  have not first verified in the code; if it is genuinely wrong, say why with
  evidence and move on.

Never mark the work done on an unreviewed fix: the last change you make is the
one nobody has looked at.
