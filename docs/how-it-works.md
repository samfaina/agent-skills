---
title: How the loop works
nav_order: 3
---

# How the loop works
{: .no_toc }

Both shipping skills run the same loop, written for the agent in [`shared/ship-tickets-loop.md`](https://github.com/samfaina/agent-skills/blob/main/shared/ship-tickets-loop.md). They differ only at the merge step. This page explains the loop for people. When the two disagree, the loop file is what runs.

1. TOC
{:toc}

```mermaid
flowchart TD
    start([Start]) --> pick[1. Pick the next ready ticket]
    pick -->|none left| report([Final report])
    pick --> wt[2. Create the ticket's worktree]
    wt --> impl[3. Implement worker]
    impl --> pr[4. PR worker]
    pr --> ci{5. CI}
    ci -->|green, or CI: none| merge[6. Merge]
    ci -->|red, up to 2 times| fix[Fix worker]
    fix --> ci
    merge -->|reviewed: request changes| fix
    merge --> clean[7. Clean up]
    clean --> pick
```

## Before the first ticket

The coordinator:

- loads Orca's orchestration guide, the source of truth for every worker command;
- reads `docs/agents/shipping.md` from the remote default branch and stops if it isn't there;
- turns your arguments, or every open `ready-for-agent` issue, into the **ticket set**;
- opens one Orca run for the whole session, which every worker belongs to.

## 1. Pick

A ticket is **ready** when it is open and none of its blockers is: GitHub reports no open blocking issues, and every issue in a `Blocked by:` line of its body is closed. The coordinator takes the lowest-numbered ready ticket.

If tickets are left but none is ready, the loop stops and tells you which open blockers hold them.

## 2. Worktree

The coordinator fetches and creates an Orca worktree for the issue, branched from the base branch on the remote. The branch name follows the naming rule in `shipping.md`.

Because tickets ship one at a time, each worktree starts from a base that already has the previous ticket merged.

## 3. Implement

A fresh agent gets the implement spec. It reads the issue and anything it links, builds test-first with the `tdd` skill, runs the full test suite, reviews its own diff against the issue with `code-review`, fixes what that finds, and commits. It doesn't push.

If the worker has a question, it asks the coordinator. The coordinator answers from the ticket and the repo when it can, and otherwise asks you and passes your answer on.

The coordinator accepts the work only when the branch has new commits and the working tree is clean.

## 4. PR

A second fresh agent, in the same worktree, pushes the branch and opens the PR with the title and body format from `shipping.md`, working from the commits, the diff and the issue. The body ends with `Closes #<n>`.

The coordinator checks the PR is on the ticket's branch and that `Closes #<n>` is in its body.

## 5. CI

The coordinator waits in the background until GitHub lists checks for the PR, which can take a few minutes after a push, and then until they finish.

- **Green:** go to the merge.
- **Red:** a fix worker reads the failing logs, reproduces the failure locally, fixes it and pushes, then CI runs again. A ticket gets at most two fix workers for CI. The third red run stops the loop.

With `CI: none` in `shipping.md`, this step is skipped.

## 6. Merge

| Skill | What happens |
| --- | --- |
| `/ship-tickets` | Merges right away, with the merge method from `shipping.md`. |
| `/ship-tickets-reviewed` | Shows you the PR and asks: **Merge**, **Request changes** or **Stop**. Requested changes go to a fix worker, then back through CI and this question. Review rounds have no limit. |

After the merge, the coordinator checks the issue closed, and closes it with a comment pointing at the PR if it didn't.

## 7. Clean up

The coordinator runs the after-merge step from `shipping.md` (deleting the remote branch, for example), removes the worktree, and checks that no worker from the run is left behind. Then it picks the next ticket.

## Workers and specs

Every worker gets a written spec with the same five parts: **Target**, **Change**, **Constraints**, **Ownership** and **Observable acceptance**. The last one is the check the coordinator runs before accepting the work. A worker reporting success isn't enough on its own.

Workers in the same worktree don't share context. Each one starts empty, reads the issue, the repo and its spec, and settles with a single result.
