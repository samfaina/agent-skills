---
name: setup-ship-tickets
description: Check that a repo is ready for the ship-tickets skill and open a PR with its docs/agents/shipping.md, filled from the repo's settings and history.
disable-model-invocation: true
---

# Set up ship tickets

Run this skill only when the user invoked it by name. If you reached it any other way, stop and tell the user to run `setup-ship-tickets` themselves.

Prepares the current repo for the `ship-tickets` skill. The loop reads `docs/agents/shipping.md` from the remote default branch, so setup ends with a PR that adds or updates that file, plus the Claude Code merge hook from step 2 when the user wants it, unless nothing needs to change.

The format is `shipping-template.md`, in this skill's own folder. Read it before step 2: every field it lists gets a value, and the file you write keeps its structure.

## 1. Preflight

Run each check and record pass or fail with the evidence:

| Check | How |
| --- | --- |
| `gh` is authenticated and the repo resolves | `gh repo view --json nameWithOwner,defaultBranchRef,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed,deleteBranchOnMerge` |
| `orca` resolves on `PATH` and serves Orca's orchestration guide | `command -v orca` in POSIX shells, `(Get-Command orca).Source` in PowerShell; on Windows it must be `orca.exe`, not `orca.cmd`. Then `orca skills get orchestration` prints the guide |
| This session runs inside an Orca terminal | `ORCA_TERMINAL_HANDLE` is set |
| The `ready-for-agent` label exists | `ready-for-agent` is an exact line of `gh label list --search ready-for-agent --json name --jq '.[].name'` (the search is fuzzy) |

A missing label is the one failure you fix here: offer to create it with `gh label create ready-for-agent`. Report the other failures with the fix the user needs; they block the loop, not this setup, so carry on.

Done when every check has a recorded result. Whether workers will load Matt Pocock's `tdd` and `code-review` depends on **Workers**, so step 2 checks it.

## 2. Gather

`git fetch origin`, then `git show origin/<default>:docs/agents/shipping.md`. If the file exists, this is an **update**: keep every value it sets and gather only the fields it lacks or that contradict the repo settings from step 1.

For each field, take the value from the first source that settles it:

| Field | Source |
| --- | --- |
| Base branch | `defaultBranchRef` |
| Merge method | the one method `mergeCommitAllowed` / `squashMergeAllowed` / `rebaseMergeAllowed` allows; with several allowed, it stays unsettled |
| Merge approval | no repo setting covers it, so it stays unsettled; the inferred value is `ask` |
| Branch naming | the pattern in `gh pr list --state all --limit 30 --json headRefName` |
| After merge | `deleteBranchOnMerge: true` → "nothing"; otherwise the branch-deletion question below settles it |
| CI | `pull_request` triggers in `.github/workflows/`, plus `gh pr view <recent-pr> --json statusCheckRollup` on two or three recent PRs to catch external checks. Checks found → `required`; none → `none` |
| PR title and body | `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE/`) if present; otherwise the sections the last merged PRs share (`gh pr view <n> --json title,body`) |
| Workers | no repo setting covers it, so it stays unsettled; the inferred value is `claude` for all roles |

A field is **settled** when one source gives one clear answer. Collect the unsettled ones, plus any inference resting on fewer than three examples, and ask the user about them, each question offering the inferred value first. Wait for the answers; if your harness has a structured question tool, use it.

Ask about Workers in two rounds. First ask whether every worker role uses the same agent or each role gets its own. Then ask for the Orca agent id: one question for all roles, or one per role. `orca orchestration worker-start --help` lists the ids Orca knows, such as `codex` and `opencode`.

Settle **After merge** once Merge approval is settled, since the question depends on it. When `deleteBranchOnMerge` is `false` and this run gathers the field (a fresh setup, a file without it, or a file whose "nothing" contradicts the setting), ask whether to turn on GitHub's "Automatically delete head branches" setting, offering **Yes** first. Say why: GitHub then deletes each branch when its PR merges, so the loop needs no post-merge cleanup, which Claude Code's auto mode may refuse. With Merge approval `auto`, add that such a refusal would leave a remote branch behind on every ticket. The user's answer is the authorization: change the repo setting only if they pick **Yes**.

- **Yes**: run `gh repo edit --delete-branch-on-merge` as a command of its own, with nothing chained before or after it. If it succeeds, After merge is "nothing". If it fails (for example, the user isn't an admin of the repo) or the harness's permission check refuses it, After merge is "delete the remote branch with `git push origin --delete <branch>`", and the report gives the command and the setting, for the user to change themselves.
- **No**: After merge is "delete the remote branch with `git push origin --delete <branch>`".

On an update, a file whose After merge deletes the branch while `deleteBranchOnMerge` is `true` contradicts the repo settings: GitHub deletes the branch first, so the step would fail. Gather the field again: it is "nothing", and the report says why it changed.

Once Workers is settled, run the provenance check for the implement worker's agent and record its result alongside the preflight checks. The check is `skill-provenance.md` in the `ship-tickets` skill's folder, which sits beside this skill's folder (`../ship-tickets/`).

Then settle the **merge hook**. Claude Code's auto mode refuses a `gh pr merge` that no human approved, so without the hook a coordinator in Claude Code asks before each merge whatever `shipping.md` says. The hook is a `PreToolUse` hook in the repo's `.claude/`, made of three parts:

- the script `merge-hook.sh`, in this skill's own folder, copied to `.claude/hooks/merge-hook.sh`;
- these two entries in `hooks.PreToolUse` of `.claude/settings.json`:

  ```json
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "if": "Bash(*gh pr merge*)",
        "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/hooks/merge-hook.sh\"",
        "timeout": 30
      }
    ]
  },
  {
    "matcher": "PowerShell",
    "hooks": [
      {
        "type": "command",
        "if": "PowerShell(*gh pr merge*)",
        "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/hooks/merge-hook.sh\"",
        "timeout": 30
      }
    ]
  }
  ```

- this line in `.gitattributes`, because Git Bash tolerates CRLF line endings but other shells break on them: `.claude/hooks/*.sh text eol=lf`, unless a line there already forces LF on that path.

An older setup wrote the **merge rule** instead: `Bash(gh pr merge * --<method>)` and `PowerShell(gh pr merge * --<method>)` in `permissions.allow`, for any method. It approves any PR, so the hook replaces it.

Read `.claude/settings.json`, `.claude/hooks/merge-hook.sh` and `.gitattributes` with `git show "$(git rev-parse origin/<default>):<path>"`, which takes `<path>` from the repo root and works the same in Git Bash and PowerShell. Don't shorten it to `origin/<default>:<path>`: Git Bash rewrites that argument as a path when `<path>` starts with a dot, and the read fails. Don't set `MSYS_NO_PATHCONV` to get past it either: with it, git and Git Bash can resolve step 3's worktree path to two different folders. When the default branch doesn't have the file, the read fails with an error that starts `fatal: path '<path>'`: that file is absent. Compare the script with this skill's copy, ignoring line endings. Then pick the row that fits and ask the user, offering the action first. The user's answer is the authorization: change these files only if they pick it.

| Merge approval | What the default branch holds | Offer | On a decline, say |
| --- | --- | --- | --- |
| `auto` | No hook, no rule | **Add** | A coordinator in Claude Code's auto mode will ask before each merge. |
| `auto` | The rule, no hook | **Replace**: add the hook, remove the rule's entries | The rule stays, so any session may merge any PR the rule matches without asking, an External PR or one with `--admin` included. |
| `auto` | The hook with a part missing or a script that differs from this skill's | **Update** | The hook stays as it is. |
| `auto` | The whole hook, and the rule too | **Replace**: remove the rule's entries | The rule stays, and approves the merge if the hook can't run. |
| `auto` | The whole hook, no rule | Nothing: it's settled | |
| `ask` | The rule | **Remove** the rule's entries. `ask` doesn't need them | The rule stays, as in the **Replace** row. |
| `ask` | Anything else | Nothing, and a hook already there stays | |

When you offer **Add**, **Replace** or **Update**, say what the hook does:

- Any Claude Code session in this repo, not only the loop, may then run `gh pr merge [selector] [-R repo] --merge|--squash|--rebase` without asking, if `gh` confirms the PR belongs to this repo and so does its head branch.
- It asks a human about an External PR (a fork's PR, a collaborator's fork included, or a PR in another repo), about any other form of `gh pr merge` such as `--admin`, and when `gh` fails.
- If the hook can't run, nothing approves the merge and the coordinator asks. That is what happens on Windows without Git Bash.
- If `origin` is the user's fork rather than the repo PRs merge into, every PR the loop opens counts as external, so the coordinator asks before each merge.

On an update, work out the files step 3 would write: `shipping.md` from the template and the values gathered here, plus the hook's files and the rule's removal if the user chose them. If `shipping.md` is the same as the one on the default branch and no hook or rule file changes, nothing needs to change: skip step 3, create no worktree and open no PR, and go to **Report**.

Done when every field in the template holds a value, the user has confirmed each unsettled one, the branch-deletion question is answered and acted on when it was asked, the provenance check has a recorded result, the merge hook is settled, changed or declined, and on an update you know whether any file changes.

## 3. Open the PR

Work in a separate worktree, so the user's checkout stays as it is:

```text
git worktree add <tmp-dir> -b agents/shipping-config origin/<default>
```

`<tmp-dir>` is a new folder outside the user's checkout, given as a native absolute path, so that git, the shell and your file-writing tool all reach the same folder. On macOS and Linux, `mktemp -d` gives one. On Windows it's a drive-letter path such as `C:/Users/<you>/AppData/Local/Temp/tmp.abc123`: in Git Bash, take it from `cygpath -m "$(mktemp -d)"`, and in PowerShell, from a new folder under `$env:TEMP`. Never use a POSIX path like `/tmp/...` on Windows: git and Git Bash can resolve it to two different folders.

Before the first write, check that you're in the worktree, from the shell you'll write from:

```text
cd <tmp-dir> && git rev-parse --abbrev-ref HEAD
```

It must print `agents/shipping-config`. Git checks a branch out in one worktree at a time, so this can't pass in the user's checkout. Checking only that `<tmp-dir>` exists isn't enough: git can see a worktree the shell can't reach. If the `cd` fails or the output is anything else, the worktree check fails. Stop: write nothing, run `git worktree remove --force <tmp-dir>` and `git branch -D agents/shipping-config` from the user's checkout, and go to **Report**.

Write every file there, and nowhere else: setup writes nothing in the user's checkout. Write files by their absolute path under `<tmp-dir>`, and start each shell command that writes there with `cd <tmp-dir> &&`, so a failed `cd` stops it. Write `docs/agents/shipping.md` following the template, with its placeholder text replaced by the values from step 2:

- Keep the line saying which skill reads the file, taken from the template, and on an update replace an older one with it.
- Drop the paragraph after it, about running setup or copying the file by hand.
- Every field holds its value from step 2, in the form the template gives, such as `<id>` (all roles) for Workers. **Body** lists the confirmed sections in order, each with what it holds.

Before showing `shipping.md`, compare it with the template line by line: no placeholder text, such as "the sections, in order, and what each holds" or "e.g.", is left.

Apply what the user chose in step 2, in the same worktree:

- **Add**, **Update**, or **Replace** without the hook: copy `merge-hook.sh` to `.claude/hooks/merge-hook.sh` with LF line endings. Append the two entries to `hooks.PreToolUse` in `.claude/settings.json`, unless an entry already runs that script, and add the line to `.gitattributes` if the file doesn't force LF on that path. Create either file if it's missing.
- **Replace** or **Remove**: delete the rule's entries from `permissions.allow`, then any `allow` list or `permissions` object that leaves empty.

Keep every other key and entry those files have. Check that `.claude/settings.json` parses as JSON.

Show the user each file you wrote (or the diff, on an update) and wait for their go-ahead.

Then commit, `git push -u origin agents/shipping-config`, and `gh pr create --base <default> --body-file <file>` with a body listing each value and where it came from, and, when the PR changes them, the merge hook with what it does and the rule with why it goes. Write the body to <file> with your file-writing tool, outside the worktree and the user's checkout, so that no shell rewrites its backticks, quotes or `$`. Remove the worktree with `git worktree remove <tmp-dir>`, run from the user's checkout: on Windows, git can't delete a folder a shell is still in. Then remove the body file.

Done when either the PR is open and the worktree and the body file are removed, or the worktree check failed and the worktree and its branch are removed; and in both cases `git status --porcelain` in the user's checkout lists no file that setup wrote.

## Report

- The PR URL. `ship-tickets` can run once it merges. If step 3 was skipped, say instead that `shipping.md` is up to date and `ship-tickets` can run now, or once the preflight failures below are fixed. If the worktree check failed, say so instead: give `<tmp-dir>` and what the check printed, and say that setup wrote nothing and opened no PR.
- If the PR changes the merge hook or the rule: Claude Code reads `.claude/` from the local checkout, not the remote, so pull the default branch into the checkout the coordinator runs in once the PR merges, then start the coordinator in a new session. Until then, that checkout keeps what it had.
- What happened to GitHub's "Automatically delete head branches" setting: turned on, already on, left off, or couldn't be changed. When it couldn't, give the error or the refusal, the command `gh repo edit --delete-branch-on-merge`, and the setting under **Settings** → **General** → **Pull Requests**, for the user to change themselves. When an update changed After merge to "nothing" because the setting is on, say so.
- Each preflight failure still open, with the fix the user needs. A failed provenance check names the skill and the path the worker would load it from.
