# Ship tickets: the loop

You are the **coordinator**: you own the ticket order, the CI wait and the merge. **Workers** are fresh Orca agents. Each does one job in the ticket's worktree and settles with `worker_done`. Tickets ship **one at a time**, so each one starts from the base branch the previous one merged into.

## Before the first ticket

1. Resolve `orca` on `PATH` (`command -v orca` in POSIX shells, `(Get-Command orca).Source` in PowerShell) and load Orca's orchestration guide with `orca skills get orchestration`. On Windows it must resolve to `orca.exe`: `orca.cmd` runs arguments through `cmd.exe`, which cuts a multi-line spec at its first newline. If it resolves to `orca.cmd`, call the `orca.exe` beside it by its full path. Use this executable for every `orca` command in the run. The guide is the source of truth for every `orca orchestration` command below and for its safety floor: an empty or timed-out wait is a checkpoint, and only an accepted `worker_done` authorizes `worker-release`. Before any stop, abandon or retry, load its `references/recovery-and-cleanup.md`.
2. Read `docs/agents/shipping.md` as the remote default branch holds it, so the loop runs the same from any worktree: `git fetch origin`, then `git show origin/<default>:docs/agents/shipping.md`, where `<default>` comes from `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. It sets the base branch, merge method, merge approval, branch naming, CI, workers, PR format and post-merge cleanup. If the default branch lacks the file, stop and tell the user to run `setup-ship-tickets` and merge the PR it opens.
3. Resolve the **ticket set**: the issue numbers from the arguments or, with none, every open issue labelled `ready-for-agent`.
4. Resolve the **merge approval**, `ask` or `auto`: the override from the arguments when the user gave one, otherwise the **Merge approval** field in `shipping.md`. A file without the field means `ask`.
5. Resolve the **worker agents** from the **Workers** field in `shipping.md`: one Orca agent id for each role: implement, PR and fix. A single id applies to all three roles, and a role the field leaves out gets `claude`. A file without the field means `claude` for all roles.
6. Check that the implement agent will load Matt Pocock's `tdd` and `code-review`: run the provenance check in `skill-provenance.md`, in this skill's own folder, for that agent. On a fail, stop before the first ticket and report the skill and its path. Keep the resolved folders: each ticket's step 3 (Implement worker) compares the worker's report with them.
7. Bind one Run for the whole session: `orca orchestration run-create --objective "Ship tickets #a, #b, …" --json`.

Done when the guide is loaded, `shipping.md` is read, the ticket set is a list of numbers, the merge approval is `ask` or `auto`, each worker role has an agent id, `tdd` and `code-review` each have a resolved folder, and a Run is bound.

## For each ticket

### 1. Pick

A ticket is **ready** when it is open and none of its blockers is open: `gh api 'repos/{owner}/{repo}/issues/<n>' --jq .issue_dependencies_summary.blocked_by` returns `0` (keep the quotes: PowerShell reads bare braces as a script block), and every issue in a `Blocked by:` line of its body is closed. Take the lowest-numbered ready ticket in the set.

Tickets left but none ready: stop and report which open blockers hold them.

### 2. Worktree

```text
git fetch origin
orca worktree create --name <slug> --issue <n> --base-branch origin/<base> --json
```

`<slug>` follows the branch naming in `shipping.md`. Record the worktree path and branch from the result. Address the worktree as `issue:<n>` from here on.

### 3. Implement worker

Orca takes a spec only as the literal text of `--spec`, so pass it as one argument whose backticks, quotes and `$` reach the worker unchanged. Load it into `spec` with your shell's literal multi-line form, then pass `"$spec"`. Run both lines as one command, so the variable survives to `worker-start`.

In bash, a quoted heredoc. `read` exits 1 at the end of the heredoc, so keep `worker-start` on its own line rather than after `&&`:

```bash
IFS= read -r -d '' spec <<'SPEC'
<implement spec>
SPEC
orca orchestration worker-start --worktree issue:<n> --agent <implement agent> --task-title "#<n> implement" --spec "$spec" --json
```

In PowerShell 7.3 or later, a single-quoted here-string; older versions strip the double quotes from the argument. The closing `'@` starts its own line:

```powershell
$spec = @'
<implement spec>
'@
orca orchestration worker-start --worktree issue:<n> --agent <implement agent> --task-title "#<n> implement" --spec "$spec" --json
```

Pass every spec this way. Then wait as the guide says (`check --wait --types worker_done,escalation,question`).

Answer each worker `question` with `reply`. Answer from the ticket and the repo when they hold the answer, otherwise ask the user and relay what they say.

Accept `--outcome succeeded` when:

- `git -C <path> log origin/<base>..HEAD --oneline` lists commits;
- `git -C <path> status --porcelain` is empty;
- the summary's `tdd:` and `code-review:` lines give the base directory of each skill the worker loaded, and the realpath of each matches the resolved folder from "Before the first ticket" (realpaths as `skill-provenance.md` defines them). On a mismatch, stop the loop and report both paths: the worker built or reviewed with a different skill.

Some workers write those lines only after they settle. If the summary lacks them, look further before you release the worker: give it up to two minutes to go idle, then read its output with `orca orchestration worker-read --dispatch <dispatch_id> --limit 3000 --json` and take the lines from a later `worker_done` or from its terminal. Stop the loop only if they are in neither place, and say in the final report which tickets' lines came from the worker's output.

Then `worker-release` and ack.

### 4. PR worker

A fresh agent in the same worktree: `worker-start --worktree issue:<n> --agent <PR agent> --task-title "#<n> PR"` with the PR spec, passed as in step 3. On an existing worktree Orca opens a new terminal, so this agent starts with an empty context.

Accept when the `worker_done` summary names a PR, `git -C <path> status --porcelain` is empty, and `gh pr view <pr> --json state,headRefName,body` shows it `OPEN`, on the ticket's branch, with `Closes #<n>` in the body. A merged or closed PR is one an earlier branch with the same name left behind, not this ticket's. Release and ack.

Then compare the PR's title and body with the PR format in `shipping.md` (`gh pr view <pr> --json title,body`). If the title differs or the body lacks a section, fix them with `gh pr edit <pr> --title <title> --body-file <file>`, writing <file> with your file-writing tool outside the repo, and say what you changed in the merge question and the final report.

### 5. CI

If `shipping.md` sets **CI** to `none`, go to step 6. A file without the field means `required`. Otherwise wait for the checks in two parts:

1. **Checks listed.** For the first minutes after a push GitHub lists no checks yet. Run `gh pr view <pr> --json statusCheckRollup --jq '.statusCheckRollup | length'` about every 30 seconds until it prints a number above 0. If it still prints 0 after 10 minutes, stop the loop: CI is `required` but no check started.
2. **Checks settled.** Run `gh pr checks <pr> --watch --fail-fast --interval 30`. This can run for many minutes. If your harness notifies you when a background command exits, run it in the background: in Claude Code, with the Bash tool's `run_in_background`, then wait for the notification that it exited. Otherwise run it in the foreground, and if it times out, run it again until it exits with a result; it is safe to rerun.

- **Exit 0 (green)** → step 6.
- **Non-zero (red)** → start a **fix worker** in the same worktree: `worker-start --worktree issue:<n> --agent <fix agent> --task-title "#<n> fix"` with the fix spec and the CI failure as its reason. Accept it when it reports the fix pushed, then run step 5 again. A ticket gets at most **2** fix workers for CI. After the third red run, stop the loop.

### 6. Merge

Merge with the merge method from `shipping.md`: `gh pr merge <pr> --<method>`. The merge approval from "Before the first ticket" decides whether the user approves it first:

- **`auto`** → merge now.
- **`ask`** → show the user the PR URL, its title and its size (`gh pr view <pr> --json url,title,additions,deletions,changedFiles`), then ask them to pick one and wait for the answer; if your harness has a structured question tool, use it:
  - **Merge** → merge.
  - **Request changes** → start a fix worker as in step 5, with the user's notes as its reason, then run steps 5 and 6 again. Review rounds are unlimited; the cap of 2 counts CI fixes only.
  - **Stop** → leave the PR open and end the loop.

Once merged, confirm the merge closed the ticket: `gh issue view <n> --json state`. If it is still open, `gh issue close <n> --comment "Shipped in #<pr>"`.

### 7. Clean up

1. Apply the post-merge cleanup from `shipping.md` (for example deleting the remote branch).
2. `orca worktree rm --worktree issue:<n> --json`. This also deletes the local branch once Orca can prove it merged.
3. `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json` returns no rows.

Done when the PR is merged, the ticket is closed, the worktree is removed and no worker is left reclaimable. Then go back to step 1.

## Stopping

Stop the loop and leave the ticket's worktree and PR exactly as they are when:

- a worker settles with `--outcome failed`, or its result fails the acceptance check of its step;
- CI is red after 2 fix workers, or no check starts within 10 minutes;
- `worker-start` exits non-zero (follow its receipt and the recovery reference, and launch no duplicate);
- the user picks **Stop** at step 6.

## Final report

Per ticket in the set: **merged** (PR link), **stopped** (step, evidence, what the user needs to do), or **not started** (the blockers holding it, or the failed provenance check).

## Specs

Each spec meets Orca's task-spec contract: Target, Change, Constraints, Ownership, Observable acceptance. Fill the `<placeholders>` and send the rest as written.

<!-- Maintainers: this spec copies the steps of Matt Pocock's implement skill, which workers can't load. When you edit it, read https://github.com/samfaina/agent-skills/blob/main/docs/adr/0004-the-implement-spec-copies-matts-implement-skill.md -->

### Implement spec

```text
Target: GitHub issue #<n> in <owner>/<repo>, worked in this worktree on branch <branch>.

Change: build what the ticket asks. Read it first with `gh issue view <n> --comments`, plus any spec or parent issue it links. Then:
- Build test-first: call the Skill tool with `tdd` (in Claude Code, `mattpocock-skills:tdd`), at the seams the ticket or its spec names.
- Run typechecking and single test files as you go, and the full test suite once at the end.
- Review your diff: call the Skill tool with `code-review` (in Claude Code, `mattpocock-skills:code-review`, not its built-in `code-review`), against `origin/<base>` with issue #<n> as the spec, and fix what it finds.
- Commit to the current branch.
- Settle with `worker_done`. End its summary with two lines: `tdd:` followed by the folder that holds the SKILL.md of the `tdd` you loaded, and `code-review:` followed by that of the `code-review`. Give each folder as your harness reported it when the skill loaded, or else the folder of the SKILL.md you read.

If `tdd` or `code-review` is not available to you, stop, and settle with `--outcome failed`, naming the missing skill.

Constraints: follow the repo's agent instruction files (AGENTS.md, CLAUDE.md and the like) and the docs they point to. Keep the commits local: another worker pushes the branch and opens the PR.

Ownership: this worktree and its branch.

Observable acceptance: every acceptance criterion in #<n> is met, the full test suite passes, and the work is committed with a clean working tree. The worker_done summary ends with the `tdd:` and `code-review:` lines.
```

### PR spec

```text
Target: branch <branch> in this worktree, which implements issue #<n>.

Change: push the branch with `git push -u origin HEAD` and open a new PR against <base> with `gh pr create --body-file .pr-body.md`. Write the title and body as docs/agents/shipping.md describes, working from the commits (`git log origin/<base>..HEAD`), the diff and issue #<n>. The body ends with `Closes #<n>`. Write the body to `.pr-body.md` at the root of this worktree with your file-writing tool, so that no shell rewrites its backticks, quotes or `$`, and delete it once `gh pr create` has run. Never commit it.

Constraints: publish the code exactly as committed. Open the PR even if `gh pr view` or `gh pr list` finds one for this branch: a merged or closed PR from an earlier branch with the same name is not this ticket's. Take the URL from the output of `gh pr create`.

Ownership: the branch on the remote and its PR.

Observable acceptance: the PR is open against <base>, `.pr-body.md` is deleted, and the working tree is clean. Put the PR's URL in the worker_done summary.
```

### Fix spec

```text
Target: PR #<pr> (branch <branch>, issue #<n>) in this worktree.

Reason: <reason>

Change: fix what the reason describes, run the checks it concerns locally, commit, and push. For a CI failure, find it with `gh pr checks <pr>` and `gh run view <run-id> --log-failed`, and reproduce it with the commands in the repo's CI workflow.

Constraints: stay within the scope of issue #<n>.

Ownership: this branch.

Observable acceptance: the checks named in the reason pass locally and the fix is pushed.
```
