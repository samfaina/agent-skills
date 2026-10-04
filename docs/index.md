---
title: Home
layout: home
nav_order: 1
---

# agent-skills

A Claude Code plugin that ships GitHub tickets for you, one at a time. For each ticket it opens an Orca worktree, has one agent build it test-first and another open the PR, waits for CI, and merges. The next ticket starts from the branch the last one merged into, so it builds on the code before it.

[Get started](getting-started){: .btn .btn-primary } [View on GitHub](https://github.com/samfaina/agent-skills){: .btn }

## The skills

| Skill | When to run it |
| --- | --- |
| `/setup-ship-tickets` | Once per repo. Checks the repo is ready and opens a PR with `docs/agents/shipping.md`, the file the loop reads. |
| `/ship-tickets-reviewed [#n…]` | To ship tickets and approve each merge yourself, or ask for changes first. |
| `/ship-tickets [#n…]` | To ship tickets and merge each PR as soon as its CI is green. |

With no issue numbers, the shipping skills take every open issue labelled `ready-for-agent`.

## Who does what

Your Claude Code session is the **coordinator**. It picks the order, waits for CI and merges. The coding happens in **workers**: fresh Orca agents, each started for one job in the ticket's worktree, with a written spec of what to do and how the coordinator will check it.

| Worker | Job | The coordinator accepts it when |
| --- | --- | --- |
| Implement | Builds the ticket test-first, reviews its own diff, commits. | The branch has commits and a clean working tree. |
| PR | Pushes the branch and opens the PR in your repo's format. | The PR exists on the ticket's branch and its body says `Closes #<n>`. |
| Fix | Fixes a red CI run, or the changes you asked for in review. | The fix is pushed. |

Each worker starts with an empty context, so the PR worker writes from the commits and the ticket, not from the implementer's reasoning.

## Next

- [Getting started](getting-started): requirements, install, and setting up a repo.
- [How the loop works](how-it-works): every step, from picking a ticket to cleaning up.
- [shipping.md reference](shipping-md): the per-repo settings file.
- [Troubleshooting](troubleshooting): why the loop stops and what to do.
