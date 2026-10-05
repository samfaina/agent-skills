---
title: Troubleshooting
nav_order: 6
---

# Troubleshooting
{: .no_toc }

When the loop can't finish a ticket, it stops and leaves that ticket's worktree and PR exactly as they are, so you can see what happened. The final report says which step stopped and why.

1. TOC
{:toc}

## The harness doesn't find `/ship-tickets`

The skills aren't installed for the harness you're running. Claude Code loads them from the plugin, and every other harness from `npx skills add samfaina/agent-skills`. OpenCode doesn't read Claude Code plugins, so a plugin install alone leaves it without the skills. See [Install](harnesses#install).

## Every skill shows up twice

The skills are installed twice in the same harness, usually once through the plugin and once through `npx skills add`. Remove one of them: `/plugin uninstall agent-skills@samfaina` in Claude Code, or `npx skills remove` for the skills.sh copy.

## "docs/agents/shipping.md is missing"

The default branch on the remote doesn't have the file. Run `/setup-ship-tickets` and merge the PR it opens. A copy on your local branch doesn't count: the loop reads the remote default branch.

## "No ticket is ready"

Every ticket left in the set has an open blocker. The report names them. Ship or close the blockers, or include them in the set.

## Workers would load a different `tdd` or `code-review`

The provenance check, which `/setup-ship-tickets` runs and `/ship-tickets` runs again before the first ticket, found that the implement worker's harness would load a `tdd` or `code-review` that isn't from [mattpocock/skills](https://github.com/mattpocock/skills). The report names the skill and its path. If an implement worker later loads a different copy than the check found, the loop stops at that ticket and reports both paths.

[When the check fails](harnesses#when-the-check-fails) gives the fix for each case, and [the provenance check](harnesses#the-skill-provenance-check) explains what it looks at in each harness.

## A worker is missing `tdd` or `code-review`

The implement worker couldn't load one of Matt's skills and settled as failed, naming it. Install mattpocock/skills in the harness that **Workers** names for the implement role, as [Install](harnesses#install) shows for each harness, then run the skill again.

## A worker failed

A worker settled as failed, or its result didn't pass the coordinator's check (no commits, a dirty working tree, a PR without `Closes #<n>`).

1. Open the worktree in Orca and read the worker's terminal.
2. Finish the ticket by hand, or fix what blocked the worker (an unclear ticket, a broken test setup) and remove the worktree with `orca worktree rm`.
3. Run the skill again for the tickets that are left.

## CI is still red after two fixes

Two fix workers couldn't get CI green. The PR stays open with the last attempt. Read the failing run (`gh pr checks <pr>`, then `gh run view <run-id> --log-failed`), fix it on the branch, and merge by hand or close the PR.

## CI never starts

No check started within 10 minutes of a push to the PR. If no checks run on PRs in this repo, set `CI: none` in `shipping.md` (see the [reference](shipping-md#why-ci-none-exists)). Otherwise, check that your workflows trigger on `pull_request` for the base branch.

## A worker couldn't be started

`worker-start` failed. The coordinator follows Orca's recovery guide and doesn't launch a duplicate. Check that Orca is running, that the session is in an Orca terminal, and that the agent id in **Workers** is one `orca orchestration worker-start --help` lists. Then run the skill again.

## A worker's spec arrives cut short

On Windows, `orca` resolved to `orca.cmd`, which cuts a multi-line spec at its first newline. The coordinator should call `orca.exe` instead; if it didn't, put the folder holding `orca.exe` ahead on your `PATH`. In PowerShell older than 7.3 the spec also loses its double quotes, so use PowerShell 7.3 or later. See [Shell](harnesses#shell).

## The loop asks before every merge

**Merge approval** is `ask`, which is also what a `shipping.md` without the field gets. To merge as soon as CI is green, set `Merge approval: auto` in `shipping.md`, or run `/ship-tickets auto` for one run.

## You chose Stop

The PR stays open as it is, and the loop ends. Merge or close it yourself, then run the skill again for the tickets that are left.
