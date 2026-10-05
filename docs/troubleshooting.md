---
title: Troubleshooting
nav_order: 5
---

# Troubleshooting
{: .no_toc }

When the loop can't finish a ticket, it stops and leaves that ticket's worktree and PR exactly as they are, so you can see what happened. The final report says which step stopped and why.

1. TOC
{:toc}

## "docs/agents/shipping.md is missing"

The default branch on the remote doesn't have the file. Run `/setup-ship-tickets` and merge the PR it opens. A copy on your local branch doesn't count: the loop reads the remote default branch.

## "No ticket is ready"

Every ticket left in the set has an open blocker. The report names them. Ship or close the blockers, or include them in the set.

## Workers would load a different `tdd` or `code-review`

The check before the first ticket found that the implement worker's agent would load a `tdd` or `code-review` that isn't from [mattpocock/skills](https://github.com/mattpocock/skills). The report names the skill and its path.

- **Claude Code:** install the plugin from Matt's marketplace (`/plugin marketplace add mattpocock/skills`, then `/plugin install mattpocock-skills@mattpocock`) or from the official one (`/plugin install mattpocock-skills@claude-plugins-official`).
- **OpenCode:** it doesn't read Claude Code plugins. Run `npx skills add mattpocock/skills`. If OpenCode finds two skills with the same name, remove the one that isn't Matt's, because OpenCode may load either.

If the skills came from a `git clone` or another place with no install record, the check can only compare their content, so it asks you to confirm the paths before the loop goes on.

If an implement worker loaded a different copy than the check found, the loop stops at that ticket and reports both paths. A plugin update during the run moves the Claude Code skills to a new versioned folder and also stops the loop this way. If both paths are Matt's, run the skill again.

## A worker failed

A worker settled as failed, or its result didn't pass the coordinator's check (no commits, a dirty working tree, a PR without `Closes #<n>`).

1. Open the worktree in Orca and read the worker's terminal.
2. Finish the ticket by hand, or fix what blocked the worker (an unclear ticket, a broken test setup) and remove the worktree with `orca worktree rm`.
3. Run the skill again for the tickets that are left.

## CI is still red after two fixes

Two fix workers couldn't get CI green. The PR stays open with the last attempt. Read the failing run (`gh pr checks <pr>`, then `gh run view <run-id> --log-failed`), fix it on the branch, and merge by hand or close the PR.

## CI never starts

If no checks run on PRs in this repo, set `CI: none` in `shipping.md` (see the [reference](shipping-md#why-ci-none-exists)). Otherwise, check that your workflows trigger on `pull_request` for the base branch.

## A worker couldn't be started

`worker-start` failed. The coordinator follows Orca's recovery guide and doesn't launch a duplicate. Check that Orca is running and that the session is in an Orca terminal, then run the skill again.

## You chose Stop

The PR stays open as it is, and the loop ends. Merge or close it yourself, then run the skill again for the tickets that are left.
