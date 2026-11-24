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

## An older version of the loop runs

The harness loads the copy of the skills you installed, and that copy keeps its version until you update it, so two repos can run different versions of the same `/ship-tickets`. Before the first ticket, the coordinator compares its version with the latest release. When it is older, it shows both versions and the update command, such as `claude plugin update agent-skills@samfaina --scope user`, and asks whether to go on or stop. Pick **Stop**, run the command, start a new session, and run the skill again. In a run where no one can answer, the loop stops there.

The final report names the version that ran, and `/setup-ship-tickets` reports an older version as a preflight failure. A copy from `npx skills add` has no `plugin.json` to read, so the coordinator says the version is unknown and goes on.

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

A worker settled as failed, or its result didn't pass the coordinator's check (no commits, a dirty working tree, a PR without `Closes #<n>`, or a PR that is already merged or closed because an earlier branch had the same name).

1. Open the worktree in Orca and read the worker's terminal.
2. Finish the ticket by hand, or fix what blocked the worker (an unclear ticket, a broken test setup) and remove the worktree with `orca worktree rm`.
3. Run the skill again for the tickets that are left.

## CI is still red after two fixes

Two fix workers couldn't get CI green. The PR stays open with the last attempt. Read the failing run (`gh pr checks <pr>`, then `gh run view <run-id> --log-failed`), fix it on the branch, and merge by hand or close the PR.

## CI never starts

No check started within 10 minutes of a push to the PR. If no checks run on PRs in this repo, set `CI: none` in `shipping.md` (see the [reference](shipping-md#why-ci-none-exists)). Otherwise, check that your workflows trigger on `pull_request` for the base branch.

## The base branch is red before the first ticket

The Base CI runs on the base branch's last commit failed before the loop started, so every ticket would build on a red base, and its failures would be hard to tell from new ones. The coordinator shows the failed jobs and the run links and asks whether to go on or stop, even with Merge approval `auto`. In a run where no one can answer, it stops there.

Pick **Stop** to fix the base branch first, then run the skill again. Pick **Go on** to ship anyway: the failed jobs become known failures, which don't stop the loop after a merge while they keep failing. A ticket that breaks one of those jobs in a new way goes unnoticed, and the final report says so.

## The loop stopped after a merge turned the base branch red

The PR's checks were green, but the push runs of its merge commit failed on a job that wasn't already failing, as when the repo runs a wider set of jobs on the base branch than on PRs. The PR stays merged and the ticket closed. The final report gives the failed jobs and the run links. Read the failure (`gh run view <run-id> --log-failed`), then fix the base branch or revert the merge, and run the skill again for the tickets that are left.

## The loop waits 2 minutes after each merge

**Base CI** is `wait`, which is also what a `shipping.md` without the field gets, and no CI ran on push to the base branch, so the coordinator waited for a run that never came. The final report marks the merge **no run**. If the repo runs no CI on push, set `Base CI: none` in `shipping.md`, or run `/setup-ship-tickets` again, which sets it from your workflows' `push` triggers. If the run was only filtered by `paths`, the wait is expected.

## A worker couldn't be started

`worker-start` failed. The coordinator follows Orca's recovery guide and doesn't launch a duplicate. Check that Orca is running, that the session is in an Orca terminal, and that the agent id in **Workers** is one `orca orchestration worker-start --help` lists. Then run the skill again.

## A worker's spec arrives cut short

On Windows, `orca` resolved to `orca.cmd`, which cuts a multi-line spec at its first newline. The coordinator should call `orca.exe` instead; if it didn't, put the folder holding `orca.exe` ahead on your `PATH`. In PowerShell older than 7.3 the spec also loses its double quotes, so use PowerShell 7.3 or later. See [Shell](harnesses#shell).

## The loop asks before every merge

**Merge approval** is `ask`, which is also what a `shipping.md` without the field gets. To merge as soon as the PR's checks are green, set `Merge approval: auto` in `shipping.md`, or run `/ship-tickets auto` for one run.

## The loop asks before a merge with Merge approval `auto`

The coordinator runs in Claude Code's auto mode, which refused the merge because no human approved it. The coordinator tells you so and asks you instead. Pick **Merge** to merge that PR. To merge without asking, add the [merge hook](shipping-md#the-merge-hook-for-claude-codes-auto-mode): run `/setup-ship-tickets`, pick **Add**, merge its PR and pull it into your checkout.

If the repo already has the hook, check that your checkout has it, and that `sh` runs on your machine: on Windows, the hook needs Git Bash. If the repo has the older allow rule, check which tool ran the merge: from Claude Code's PowerShell tool, auto mode sends the merge to the classifier even when the rule matches. Pick **Replace** in `/setup-ship-tickets` to move to the hook.

## Claude Code asks you to confirm a merge

The [merge hook](shipping-md#the-merge-hook-for-claude-codes-auto-mode) didn't approve it, and the prompt says why:

- **External PR.** The PR comes from a fork or belongs to another repo. Review it first. If `origin` is your fork, every PR counts as external.
- **Not the plain command.** The command has a flag such as `--admin`, or something chained to it. The loop never runs these, so check what ran it.
- **Could not check.** `gh` failed, and the error is in the prompt. A network failure would stop the merge too.

Pick **Yes** to merge that one PR. Pick **No** to stop the turn and tell the coordinator what to do instead. In a `claude -p` run nobody can answer, so Claude Code refuses the merge, and the loop stops at that ticket.

## A merged ticket's worktree is still there

The harness refused `orca worktree rm` after the merge. Claude Code's auto mode has done this once, without naming a rule. The ticket is still shipped: the PR is merged and the issue closed. The final report gives the command. Run it yourself, for example with `! orca worktree rm --worktree issue:<n> --json` in Claude Code. If this happens on every run, add to [#54](https://github.com/samfaina/agent-skills/issues/54).

## A merged ticket's remote branch is still there

The harness refused the **After merge** step from `shipping.md`. Claude Code's auto mode has refused `git push origin --delete <branch>` under its `[Git Destructive]` rule. The ticket is still shipped: the PR is merged and the issue closed. The final report gives the command. Run it yourself, for example with `! git push origin --delete <branch>` in Claude Code.

To stop it happening, turn on **Automatically delete head branches**. With Merge approval `auto`, run `/setup-ship-tickets` again and pick **Yes** when it offers to turn the setting on. Otherwise, turn it on in the repo's **Settings** → **General** → **Pull Requests**, or with `gh repo edit --delete-branch-on-merge`, then run `/setup-ship-tickets` again. Either way, setup sets **After merge** to "nothing", so the loop has no cleanup left to refuse.

If the final report shows the deletion failed with another error, its output is in the report.

## The report says `shipping.md` deletes a branch GitHub already deletes

GitHub's **Automatically delete head branches** setting is on, but **After merge** in `shipping.md` still deletes the remote branch. Before each deletion the coordinator checks that the branch still exists, so it found the branch gone, skipped the deletion, and counted the step as done. Nothing failed: the note tells you that the file and the repo setting disagree. Run `/setup-ship-tickets` again: it sets **After merge** to "nothing", and the loop then skips the check too.

## You chose Stop

The PR stays open as it is, and the loop ends. Merge or close it yourself, then run the skill again for the tickets that are left.
