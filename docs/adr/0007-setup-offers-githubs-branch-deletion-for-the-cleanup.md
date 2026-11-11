# Setup offers GitHub's branch deletion, instead of approving the cleanup

Claude Code's auto mode refused the loop's post-merge `git push origin --delete <branch>` under its `[Git Destructive]` rule (samfaina/gikli#106, agent-skills 0.6.0, Claude Code 2.1.322). The command ran chained after two `gh` commands in the PowerShell tool, so it is unknown whether the rule also fires for the command on its own in the Bash tool. The loop now handles the refusal as it handles a refused `orca worktree rm`: it runs the **After merge** step as a command of its own, with the Bash tool where there is one, and on a refusal it carries on and gives the user the command in the final report. A deletion that fails because the branch is already gone counts as done.

To make the step rarely needed, `setup-ship-tickets` asks whether to turn on GitHub's "Automatically delete head branches" when it finds the setting off. On **Yes** it runs `gh repo edit --delete-branch-on-merge` and writes **After merge** "nothing". The user's answer is the authorization: setup changes the setting only if they pick it. If the change fails or is refused, or the user picks **No**, setup writes the deletion step as before.

## Considered options

- **Extend the merge hook, or add an allow rule, to approve `git push origin --delete`.** The hook from ADR 0006 checks a PR with `gh` before it approves a merge. A branch deletion has nothing comparable to check: the hook would have to confirm the branch belongs to a merged PR, and any slip would approve deleting a branch someone still works on. It would also be one more command the repo approves for every Claude Code session, not only the loop.
- **Merge with `gh pr merge --delete-branch`.** It deletes the branch in the same command as the merge, but the merge hook returns `ask` for any form other than the plain merge, so `auto` would ask before every merge.
- **Turn the setting on without asking.** It changes how every PR in the repo merges, a human's included, so it is the user's call.
- **Only handle the refusal.** The ticket still ships, but with Merge approval `auto` every ticket would leave a branch behind and a command in the report.

## Consequences

This is the first time setup changes a repo setting on GitHub. Unlike the merge hook, the change isn't in the setup PR, so nobody reviews it there: setup says what it does before asking, and the report says whether the setting was turned on, left off, or couldn't be changed. It takes effect at once, before the setup PR merges, and needs admin access to the repo. GitHub then deletes the head branch of every PR merged in the repo, not only the loop's, but not a fork's branch. A deleted branch can be restored from its PR.

Setup asks only when it gathers **After merge**, so a repo set up before this with the setting off doesn't get the offer on an update. Its user learns of the setting from the loop's final report after a refused cleanup. #68 tracks asking on an update too.

The loop runs the cleanup with the Bash tool by analogy with the merge in ADR 0005, where the classifier refused merges from the PowerShell tool that the Bash tool ran under the same allow rule. No rule covers the deletion, and the difference between the tools hasn't been measured for `git push --delete`. The release test's `auto-mode` run checks that the coordinator ran the deletion on its own with the Bash tool, and passes whether auto mode deletes the branch or refuses and the report gives the command.
