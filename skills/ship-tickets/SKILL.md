---
name: ship-tickets
description: Ship GitHub tickets one at a time with Orca workers (implement, PR, CI) and merge each PR as soon as CI is green.
argument-hint: "[issue numbers…] (default: every open ready-for-agent issue)"
disable-model-invocation: true
---

# Ship tickets

Run the loop in `shared/ship-tickets-loop.md` for the tickets in the arguments. That file sits two levels above this skill's base directory. Read it in full before your first command.

**Step 6, Merge:** merge as soon as CI is green, with the merge method from `docs/agents/shipping.md` (`gh pr merge <pr> --<method>`).
