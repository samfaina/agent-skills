---
name: setup-ship-tickets
description: Check that a repo is ready for the ship-tickets skill and open a PR with its docs/agents/shipping.md, filled from the repo's settings and history.
disable-model-invocation: true
---

# Set up ship tickets

Run this skill only when the user invoked it by name. If you reached it any other way, stop and tell the user to run `setup-ship-tickets` themselves.

Prepares the current repo for the `ship-tickets` skill. The loop reads `docs/agents/shipping.md` from the remote default branch, so setup ends with a PR that adds or updates that file, unless nothing in that file needs to change.

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
| After merge | `deleteBranchOnMerge: true` → "nothing"; otherwise delete the remote branch |
| CI | `pull_request` triggers in `.github/workflows/`, plus `gh pr view <recent-pr> --json statusCheckRollup` on two or three recent PRs to catch external checks. Checks found → `required`; none → `none` |
| PR title and body | `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE/`) if present; otherwise the sections the last merged PRs share (`gh pr view <n> --json title,body`) |
| Workers | no repo setting covers it, so it stays unsettled; the inferred value is `claude` for all roles |

A field is **settled** when one source gives one clear answer. Collect the unsettled ones, plus any inference resting on fewer than three examples, and ask the user about them, each question offering the inferred value first. Wait for the answers; if your harness has a structured question tool, use it.

Ask about Workers in two rounds. First ask whether every worker role uses the same agent or each role gets its own. Then ask for the Orca agent id: one question for all roles, or one per role. `orca orchestration worker-start --help` lists the ids Orca knows, such as `codex` and `opencode`.

Once Workers is settled, run the provenance check for the implement worker's agent and record its result alongside the preflight checks. The check is `skill-provenance.md` in the `ship-tickets` skill's folder, which sits beside this skill's folder (`../ship-tickets/`).

On an update, work out the file step 3 would write from the template and the values gathered here. If it is the same as the one on the default branch, nothing needs to change: skip step 3, create no worktree and open no PR, and go to **Report**.

Done when every field in the template holds a value, the user has confirmed each unsettled one, the provenance check has a recorded result, and on an update you know whether the file changes.

## 3. Open the PR

Work in a separate worktree, so the user's checkout stays as it is:

```text
git worktree add <tmp-dir> -b agents/shipping-config origin/<default>
```

Write `docs/agents/shipping.md` there, and nowhere else: setup writes nothing in the user's checkout. Follow the template with its placeholder text replaced by the values from step 2:

- Keep the line saying which skill reads the file, taken from the template, and on an update replace an older one with it.
- Drop the paragraph after it, about running setup or copying the file by hand.
- Every field holds its value from step 2, in the form the template gives, such as `<id>` (all roles) for Workers. **Body** lists the confirmed sections in order, each with what it holds.

Before showing the file, compare it with the template line by line: no placeholder text, such as "the sections, in order, and what each holds" or "e.g.", is left. Then show the user the file (or the diff, on an update) and wait for their go-ahead.

Then commit, `git push -u origin agents/shipping-config`, and `gh pr create --base <default> --body-file <file>` with a body listing each value and where it came from. Write the body to <file> with your file-writing tool, outside the worktree and the user's checkout, so that no shell rewrites its backticks, quotes or `$`. Remove the worktree with `git worktree remove <tmp-dir>`, and the body file.

Done when the PR is open, the worktree and the body file are removed, and `git status --porcelain` in the user's checkout lists no file that setup wrote.

## Report

- The PR URL. `ship-tickets` can run once it merges. If step 3 was skipped, say instead that `shipping.md` is up to date and `ship-tickets` can run now, or once the preflight failures below are fixed.
- Each preflight failure still open, with the fix the user needs. A failed provenance check names the skill and the path the worker would load it from.
