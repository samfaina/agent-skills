---
name: ship-tickets-reviewed
description: Ship GitHub tickets one at a time with Orca workers (implement, PR, CI), pausing for your approval before each merge.
argument-hint: "[issue numbers…] (default: every open ready-for-agent issue)"
disable-model-invocation: true
---

# Ship tickets, reviewed

Run the loop in `shared/ship-tickets-loop.md` for the tickets in the arguments. That file sits two levels above this skill's base directory. Read it in full before your first command.

**Step 6, Merge:** once CI is green, show the user the PR URL, its title and its size (`gh pr view <pr> --json additions,deletions,changedFiles`), then ask with AskUserQuestion:

- **Merge** → `gh pr merge <pr> --<method>`, with the merge method from `docs/agents/shipping.md`.
- **Request changes** → take the user's notes as the reason for a fix worker, then run steps 5 and 6 again. Review rounds are unlimited; the cap of 2 counts CI fixes only.
- **Stop** → leave the PR open and end the loop.
