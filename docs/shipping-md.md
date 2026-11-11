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
| **Merge approval** | `ask` (once CI is green, the loop shows you the PR and waits for **Merge**, **Request changes** or **Stop**) or `auto` (the loop merges as soon as CI is green). A file without this field counts as `ask`. `/ship-tickets ask` or `/ship-tickets auto` overrides it for one run. In Claude Code's auto mode, `auto` also needs the [merge hook](#the-merge-hook-for-claude-codes-auto-mode). | Merge |
| **Branch naming** | How to turn a ticket into a worktree name, such as the kebab-case issue title. Note any prefix Orca adds to the branch. | Worktree creation |
| **After merge** | What to do once the PR merges, such as deleting the remote branch with `git push origin --delete <branch>`, or "nothing" when GitHub's "Automatically delete head branches" setting deletes it for you. `/setup-ship-tickets` offers to turn that setting on, which spares the loop a step Claude Code's auto mode may refuse. It offers when it sets this field, and again on each update with Merge approval `auto` while the field deletes the branch. If the harness refuses the step, the ticket still ships and the final report gives you the command ([troubleshooting](troubleshooting#a-merged-tickets-remote-branch-is-still-there)). | Clean up |
| **CI** | `required` (the loop waits for checks to pass) or `none` (no checks run on PRs, so the loop merges without waiting). A file without this field counts as `required`. | CI |
| **Workers** | The Orca agent id each worker starts in, passed to `worker-start --agent`: one id for every role, such as `claude` (all roles), or one per role, such as implement `claude`, PR `opencode`, fix `claude`. A role left out, or a file without this field, gets `claude`. See [Workers](harnesses#workers). | Implement, PR and fix workers |
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

## The merge hook for Claude Code's auto mode

Claude Code's auto mode refuses a `gh pr merge` that no human approved. So with Merge approval `auto`, a coordinator running in that mode stops at the merge and asks you, as if the field said `ask`. The approval you give covers only that one PR.

A `PreToolUse` hook in the repo's `.claude/` lets the merge through, after checking the PR. When you pick `auto`, `/setup-ship-tickets` offers to add it to the same PR as `shipping.md`:

- `.claude/hooks/merge-hook.sh`, a script that needs `sh`, `sed` and `gh`.
- Two entries in `.claude/settings.json` that run the script for `gh pr merge` from the Bash and PowerShell tools.
- A line in `.gitattributes` that keeps the script's line endings LF.

| The command | The hook |
| --- | --- |
| `gh pr merge [selector] [-R repo] --merge\|--squash\|--rebase`, for a PR of this repo with its head branch in this repo | Approves it, so the merge runs without asking. |
| The same, for an External PR: from a fork, a collaborator's fork included, or in another repo | Asks you, naming the PR. |
| The same, when `gh` fails twice | Asks you, with the error from `gh`. |
| Any other form: `--admin`, `--auto`, a chained command, a wrapper such as `timeout` | Asks you, even for a PR of this repo. |

- The hook applies to every Claude Code session in the repo, not only the loop. Any of them may merge the repo's own PRs without asking.
- Claude Code reads `.claude/` from your local checkout. Once the PR merges, pull the default branch into the checkout you run `/ship-tickets` from, and start a new session.
- If the hook can't run, nothing approves the merge, and the coordinator asks you. That is what happens on Windows without Git Bash.
- If `origin` is your fork rather than the repo PRs merge into, every PR the loop opens counts as external, so the coordinator asks before each merge.
- The hook guards `gh pr merge` only. Claude Code's usual checks decide anything else, such as `gh api` or a merge inside `bash -c`.
- To update the script after a new release, run `/setup-ship-tickets` again. It offers **Update** when the script differs.

Without the hook, `auto` still works in every other harness and in Claude Code's other permission modes.

### Upgrading from the merge rule

Before 0.6.0, setup added an allow rule instead: `Bash(gh pr merge * --<method>)` and `PowerShell(gh pr merge * --<method>)` in `permissions.allow`. The rule reads only the text of the command, so any session could merge any PR it matches, an External PR or one with `--admin` included.

To replace it, run `/setup-ship-tickets` and pick **Replace**. It adds the hook and removes the rule in one PR. Merge that PR, pull it into your checkout, and start a new session. With Merge approval `ask`, it offers **Remove** instead, since `ask` doesn't need the rule.

## Why `CI: none` exists

In a repo where no checks run on PRs, waiting for CI never ends well. The loop would wait ten minutes for checks to show up and then stop, because CI is required and none started. `CI: none` skips the wait. The implement worker still runs the full test suite before committing.
