# A hook in the repo approves the merge, instead of an allow rule

The allow rule from ADR 0005 reads only the text of a command, so it let any Claude Code session in the repo merge any PR, including an External PR that the PR's own content manipulated an agent into merging. `setup-ship-tickets` now offers a `PreToolUse` hook, committed in the repo's `.claude/` by the setup PR, and removes the rule. The hook returns `allow` only for the plain command, `gh pr merge [selector] [-R repo] --<method>`, when `gh` confirms the PR is not an External PR. For an External PR, any other form of `gh pr merge`, or a `gh` failure after one retry, it returns `ask`. Nothing else in the repo approves the merge, so if the hook can't run, the merge goes to Claude Code's usual checks and the loop's fallback to `ask`.

Measured in a trusted clone with a fake `gh`, on Claude Code 2.1.319, with the instruction to merge read from a file. Merges that ran in auto mode:

| Setup | Bash tool | PowerShell tool |
| --- | --- | --- |
| No rule, no hook | 0 of 6 | 0 of 6 |
| Allow rule | 6 of 6 | 0 of 6 |
| Hook that returns `allow`, no rule | 6 of 6 | 6 of 6 |

In default mode, with no classifier in the way, the `Bash(...)` rule matched `--admin` before the method, `--auto`, a URL or `-R` for another repo, `; echo`, `&& echo`, `cd x &&` and `timeout 30`. It didn't match `--admin` after the method, a merge with no selector, or `GH_REPO=x`. The `PowerShell(...)` rule matched none of the commands tried, the plain merge included. In an interactive auto mode session, a hook's `ask` showed the prompt despite a matching allow rule, and the merge ran only after the approval. The docs promise this for a hook that exits 2, not for `ask`.

## Considered options

- **Keep the rule and have the hook step in only for an External PR.** The hook would then be all that stands between the rule and any PR: if it failed to start or timed out, Claude Code would carry on and the rule would approve the merge. `onFailure: "block"` closes that, but it also blocks a merge the user approved. The hook would have to catch every form the rule matches, and the PowerShell tool would stay refused.
- **Block an External PR with exit 2.** A retry after the user's approval would be blocked again, so the loop's fallback to `ask` couldn't work.
- **Ship the hook in the plugin.** It would update itself and need no setup. But it would approve merges in every repo where the plugin is enabled, whether or not the repo chose Merge approval `auto`, and a session without the plugin would have no hook.
- **A `.ps1` beside the `sh` script.** Claude Code runs the same `sh` command for both tools wherever Git Bash exists, and without Git Bash the hook fails to start, which approves nothing. That one case loses unattended merges, not safety.

## Consequences

This reverses ADR 0005. Its reason against a plugin mod that approves the merge was that the plugin would switch off a safety rule on its own; this hook is offered and reviewed in the setup PR, and it covers less than the rule did. Its other reason stands: this is more code than a settings entry.

`setup-ship-tickets` copies the script, so a new version reaches a repo only through a new setup run. The script needs `sh`, `sed` and `gh`, and `.gitattributes` keeps it LF. Changing **Merge method** no longer needs a setup run.

In a clone whose `origin` is the user's fork, every PR the loop opens is an External PR, so `auto` behaves as `ask`. The hook guards only `gh pr merge`: `gh api`, `curl` or a merge inside `bash -c "..."` get no approval from it, so Claude Code's usual checks decide them, as they would with no hook. A branch that changes `.claude/` takes effect once it is checked out, as with any project setting, so don't check out an External PR's branch in a session you trust with that repo. In a `-p` run in a folder nobody has trusted, project hooks run where project allow rules don't, so the hook can approve there; a project hook can already run anything in that case.
