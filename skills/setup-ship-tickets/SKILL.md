---
name: setup-ship-tickets
description: Check that a repo is ready for /ship-tickets and open a PR with its docs/agents/shipping.md, filled from the repo's settings and history.
disable-model-invocation: true
---

# Set up ship tickets

Prepares the current repo for `/ship-tickets`. The loop reads `docs/agents/shipping.md` from the remote default branch, so setup ends with a PR that adds or updates that file.

The format is `shipping-template.md`, in this skill's own folder. Read it before step 2: every field it lists gets a value, and the file you write keeps its structure.

## 1. Preflight

Run each check and record pass or fail with the evidence:

| Check | How |
| --- | --- |
| `gh` is authenticated and the repo resolves | `gh repo view --json nameWithOwner,defaultBranchRef,mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed,deleteBranchOnMerge` |
| `orca` resolves | as the `orchestration` skill says |
| This session runs inside an Orca terminal | `ORCA_TERMINAL_HANDLE` is set |
| Workers can use `tdd` and `code-review` | `mattpocock-skills:tdd` and `mattpocock-skills:code-review` are in your skill list |
| The `ready-for-agent` label exists | `ready-for-agent` is an exact line of `gh label list --search ready-for-agent --json name --jq '.[].name'` (the search is fuzzy) |

A missing label is the one failure you fix here: offer to create it with `gh label create ready-for-agent`. Report the other failures with the fix the user needs; they block the loop, not this setup, so carry on.

Done when every check has a recorded result.

## 2. Gather

`git fetch origin`, then `git show origin/<default>:docs/agents/shipping.md`. If the file exists, this is an **update**: keep every value it sets and gather only the fields it lacks or that contradict the repo settings from step 1.

For each field, take the value from the first source that settles it:

| Field | Source |
| --- | --- |
| Base branch | `defaultBranchRef` |
| Merge method | the one method `mergeCommitAllowed` / `squashMergeAllowed` / `rebaseMergeAllowed` allows; with several allowed, it stays unsettled |
| Merge approval | no repo setting covers it, so it stays unsettled; the inferred value is `ask` |
| Branch naming | the pattern in `gh pr list --state all --limit 30 --json headRefName` |
| After merge | `deleteBranchOnMerge: true` → "nothing"; otherwise delete the remote branch |
| CI | `pull_request` triggers in `.github/workflows/`, plus `gh pr view <recent-pr> --json statusCheckRollup` on two or three recent PRs to catch external checks. Checks found → `required`; none → `none` |
| PR title and body | `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE/`) if present; otherwise the sections the last merged PRs share (`gh pr view <n> --json title,body`) |
| Workers | no repo setting covers it, so it stays unsettled; the inferred value is `claude` for all roles |

A field is **settled** when one source gives one clear answer. Collect the unsettled ones, plus any inference resting on fewer than three examples, and ask about them with AskUserQuestion (four questions per call at most), each question offering the inferred value first.

Ask about Workers in two rounds. First ask whether every worker role uses the same agent or each role gets its own. Then ask for the Orca agent id: one question for all roles, or one per role. `orca orchestration worker-start --help` lists the ids Orca knows, such as `codex` and `opencode`.

Done when every field in the template holds a value and the user has confirmed each unsettled one.

## 3. Open the PR

Work in a separate worktree, so the user's checkout stays as it is:

```bash
git worktree add <tmp-dir> -b agents/shipping-config origin/<default>
```

Write `docs/agents/shipping.md` there, following the template with its placeholder text replaced by the values from step 2. Drop the template's opening paragraph about copying the file, and take the line saying which skill reads it from the template, replacing an older one on an update. Show the user the file (or the diff, on an update) and wait for their go-ahead.

Then commit, `git push -u origin agents/shipping-config`, and `gh pr create --base <default>` with a body listing each value and where it came from. Remove the worktree with `git worktree remove <tmp-dir>`.

Done when the PR is open and the worktree is removed.

## Report

- The PR URL. `/ship-tickets` can run once it merges.
- Each preflight failure still open, with the fix the user needs.
