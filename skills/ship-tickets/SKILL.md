---
name: ship-tickets
description: Ship GitHub tickets one at a time with Orca workers (implement, PR, CI, merge), merging each PR on your approval or as soon as CI is green.
argument-hint: "[ask|auto] [issue numbers…] (default: Merge approval from shipping.md, every open ready-for-agent issue)"
disable-model-invocation: true
---

# Ship tickets

Run the loop in `ship-tickets-loop.md`, in this skill's own folder, with the arguments below. Read it in full before your first command.

## Arguments

Whatever the user wrote after the skill name, read as words separated by spaces. Every argument is optional:

- **Merge approval override:** a first word of `ask` or `auto` sets the merge approval for this run, over the **Merge approval** field in `docs/agents/shipping.md`.
- **Issue numbers:** the remaining words, with or without a leading `#`. With none, the ticket set is every open issue labelled `ready-for-agent`.

So `ship-tickets auto 41 42 43` ships #41, #42 and #43 and merges each one without asking, and `ship-tickets` alone ships every ready ticket with the approval `shipping.md` sets.
