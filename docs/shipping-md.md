---
title: shipping.md reference
nav_order: 4
---

# shipping.md reference
{: .no_toc }

Each repo you ship from has a `docs/agents/shipping.md` with the settings the loop can't guess. `/setup-ship-tickets` writes it. You can also copy [`shared/shipping-template.md`](https://github.com/samfaina/agent-skills/blob/main/shared/shipping-template.md) by hand.

The loop reads the file from the remote default branch, so edits take effect once they are merged.

1. TOC
{:toc}

## Fields

| Field | Values | Used in |
| --- | --- | --- |
| **Base branch** | The branch tickets merge into, usually the default branch. | Worktree creation, PR base, CI, merge |
| **Merge method** | `merge`, `squash` or `rebase`, passed to `gh pr merge --<method>`. Use one your repo settings allow. | Merge |
| **Branch naming** | How to turn a ticket into a worktree name, such as the kebab-case issue title. Note any prefix Orca adds to the branch. | Worktree creation |
| **After merge** | What to do once the PR merges, such as deleting the remote branch, or "nothing" when GitHub deletes it for you. | Clean up |
| **CI** | `required` (the loop waits for checks to pass) or `none` (no checks run on PRs, so the loop merges without waiting). A file without this field counts as `required`. | CI |
| **PR title** | How the PR worker writes the title, such as the issue title, unchanged. | PR |
| **PR body** | The sections, in order, and what each holds. The loop adds `Closes #<n>` at the end. | PR |

## Example

```markdown
# Shipping

Read by `/ship-tickets` and `/ship-tickets-reviewed` (samfaina/agent-skills).

- **Base branch:** `main`
- **Merge method:** `squash`
- **Branch naming:** kebab-case issue title, prefixed with the issue number: `42-add-csv-export`.
- **After merge:** nothing (the repo deletes merged branches).
- **CI:** `required`

## PR format

- **Title:** the issue title, unchanged.
- **Body:**
  1. **Summary**: what changed and why, in two or three sentences.
  2. **Testing**: the tests added and how to check the change by hand.
  3. `Closes #<n>`
```

## Why `CI: none` exists

In a repo where no checks run on PRs, waiting for CI never ends well. The loop would wait ten minutes for checks to show up and then read GitHub's "no checks reported" error as a failure, starting fix workers with nothing to fix. `CI: none` skips the wait. The implement worker still runs the full test suite before committing.
