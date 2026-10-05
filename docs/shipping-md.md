---
title: shipping.md reference
nav_order: 4
---

# shipping.md reference
{: .no_toc }

Each repo you ship from has a `docs/agents/shipping.md` with the settings the loop can't guess. `/setup-ship-tickets` writes it. You can also copy [`skills/setup-ship-tickets/shipping-template.md`](https://github.com/samfaina/agent-skills/blob/main/skills/setup-ship-tickets/shipping-template.md) by hand.

The loop reads the file from the remote default branch, so edits take effect once they are merged.

1. TOC
{:toc}

## Fields

| Field | Values | Used in |
| --- | --- | --- |
| **Base branch** | The branch tickets merge into, usually the default branch. | Worktree creation, PR base, CI, merge |
| **Merge method** | `merge`, `squash` or `rebase`, passed to `gh pr merge --<method>`. Use one your repo settings allow. | Merge |
| **Merge approval** | `ask` (once CI is green, the loop shows you the PR and waits for **Merge**, **Request changes** or **Stop**) or `auto` (the loop merges as soon as CI is green). A file without this field counts as `ask`. `/ship-tickets ask` or `/ship-tickets auto` overrides it for one run. | Merge |
| **Branch naming** | How to turn a ticket into a worktree name, such as the kebab-case issue title. Note any prefix Orca adds to the branch. | Worktree creation |
| **After merge** | What to do once the PR merges, such as deleting the remote branch, or "nothing" when GitHub deletes it for you. | Clean up |
| **CI** | `required` (the loop waits for checks to pass) or `none` (no checks run on PRs, so the loop merges without waiting). A file without this field counts as `required`. | CI |
| **Workers** | The Orca agent id each worker starts in, such as `claude` or `opencode`: one id for every role, or one per role (see [below](#workers)). A file without this field counts as `claude` for every role. | Implement, PR and fix workers |
| **PR title** | How the PR worker writes the title, such as the issue title, unchanged. | PR |
| **PR body** | The sections, in order, and what each holds. The loop adds `Closes #<n>` at the end. | PR |

## Example

```markdown
# Shipping

Read by the `ship-tickets` skill (samfaina/agent-skills).

- **Base branch:** `main`
- **Merge method:** `squash`
- **Merge approval:** `ask`
- **Branch naming:** kebab-case issue title, prefixed with the issue number: `42-add-csv-export`.
- **After merge:** nothing (the repo deletes merged branches).
- **CI:** `required`
- **Workers:** `claude` (all roles)

## PR format

- **Title:** the issue title, unchanged.
- **Body:**
  1. **Summary**: what changed and why, in two or three sentences.
  2. **Testing**: the tests added and how to check the change by hand.
  3. `Closes #<n>`
```

## Workers

The loop starts each worker with `orca orchestration worker-start --agent <id>`, so the field takes the agent ids Orca knows. `orca orchestration worker-start --help` lists them. Write one id for every role, or one per role:

```markdown
- **Workers:** `claude` (all roles)
- **Workers:** implement `claude`, PR `opencode`, fix `claude`
```

A role left out gets `claude`. The implement worker's harness has to load Matt Pocock's `tdd` and `code-review`, which the loop checks before the first ticket. [Harnesses](harnesses#workers) covers the check and what each harness needs.

## Why `CI: none` exists

In a repo where no checks run on PRs, waiting for CI never ends well. The loop would wait ten minutes for checks to show up and then stop, because CI is required and none started. `CI: none` skips the wait. The implement worker still runs the full test suite before committing.
