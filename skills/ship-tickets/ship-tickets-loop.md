# Ship tickets: the loop

You are the **coordinator**: you own the ticket order, the CI wait and the merge. **Workers** are fresh Orca agents. Each does one job in the ticket's worktree and settles with `worker_done`. Tickets ship **one at a time**, so each one starts from the base branch the previous one merged into.

## Before the first ticket

1. Resolve `orca` on `PATH` (`command -v orca` in POSIX shells, `(Get-Command orca).Source` in PowerShell) and load Orca's orchestration guide with `orca skills get orchestration`. On Windows it must resolve to `orca.exe`: `orca.cmd` runs arguments through `cmd.exe`, which cuts a multi-line spec at its first newline. If it resolves to `orca.cmd`, call the `orca.exe` beside it by its full path. Use this executable for every `orca` command in the run. The guide is the source of truth for every `orca orchestration` command below and for its safety floor: an empty or timed-out wait is a checkpoint, and only an accepted `worker_done` authorizes `worker-release`. Before any stop, abandon or retry, load its `references/recovery-and-cleanup.md`.
2. Read `docs/agents/shipping.md` as the remote default branch holds it, so the loop runs the same from any worktree: `git fetch origin`, then `git show origin/<default>:docs/agents/shipping.md`, where `<default>` comes from `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. It sets the base branch, merge method, merge approval, branch naming, CI, workers, PR format and post-merge cleanup. If the default branch lacks the file, stop and tell the user to run `setup-ship-tickets` and merge the PR it opens.
3. Resolve the **ticket set**: the issue numbers from the arguments, in the order the user gave them, or, with none, every open issue labelled `ready-for-agent`, lowest number first.
4. Resolve the **merge approval**, `ask` or `auto`: the override from the arguments when the user gave one, otherwise the **Merge approval** field in `shipping.md`. A file without the field means `ask`.
5. Resolve the **worker agents** from the **Workers** field in `shipping.md`: one Orca agent id for each role: implement, PR and fix. A single id applies to all three roles, and a role the field leaves out gets `claude`. A file without the field means `claude` for all roles.
6. Check that the implement agent will load Matt Pocock's `tdd` and `code-review`: run the provenance check in `skill-provenance.md`, in this skill's own folder, for that agent. On a fail, stop before the first ticket and report the skill and its path. Keep the resolved folders: each ticket's step 3 (Implement worker) compares the worker's report with them.
7. Bind one Run for the whole session: `orca orchestration run-create --objective "Ship tickets #a, #b, …" --json`.

Done when the guide is loaded, `shipping.md` is read, the ticket set is an ordered list of numbers, the merge approval is `ask` or `auto`, each worker role has an agent id, `tdd` and `code-review` each have a resolved folder, and a Run is bound.

## For each ticket

### 1. Pick

A ticket is **ready** when it is open and none of its blockers is open: `gh api 'repos/{owner}/{repo}/issues/<n>' --jq .issue_dependencies_summary.blocked_by` returns `0` (keep the quotes: PowerShell reads bare braces as a script block), and every issue in a `Blocked by:` line of its body is closed. Take the first ready ticket in the set's order. A ticket with any open blocker is skipped until its blockers close, and the loop takes the next ready one: with `6 2 3 1` and #6 blocked by #1, the run ships #2, #3, #1, #6.

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

Pass every spec this way.

Orca titles each worker's tab `worker-<task id>`, which doesn't say which ticket or role it is. Give the tab the task title: take the worker's terminal handle from `terminal` in the `worker-start` result, then run `orca terminal rename --terminal <handle> --title "#<n> implement"`. Do the same for every worker you start below, with its own task title. The title only labels the tab, since Orca tracks the worker by its dispatch and handle. If the result has no `terminal` or the rename fails, carry on.

Then wait as the guide says (`check --wait --types worker_done,escalation,question`). Wait the same way on every worker you start below, and handle its questions and escalations as here.

Answer each worker `question` with `reply`. Answer from the ticket and the repo when they hold the answer, otherwise ask the user and relay what they say.

An `escalation` with `stopReason: needs-input` usually means the worker hit a permission prompt that no one was at its terminal to answer, such as the one a file edit made through a shell heredoc raises. Steer it, then keep waiting:

```text
orca orchestration send --to dispatch:<dispatch_id> --subject "Use your file-editing tool" --body "No one can answer a permission prompt in your terminal. If the command that raised it changed a file, redo the change with your file-editing tool (Edit or Write in Claude Code) instead of retrying the shell command. Then carry on with your task."
```

The worker reads the steer once its prompt closes. Sending it doesn't stop the loop, doesn't count as a fix round, and doesn't change the step's acceptance check. This step covers `needs-input` only: handle an escalation with any other `stopReason` as the guide says.

Accept `--outcome succeeded` when:

- `git -C <path> log origin/<base>..HEAD --oneline` lists commits;
- `git -C <path> status --porcelain` is empty;
- the summary's `tdd:` and `code-review:` lines give the base directory of each skill the worker loaded, and the realpath of each matches the resolved folder from "Before the first ticket" (realpaths as `skill-provenance.md` defines them). On a mismatch, stop the loop and report both paths: the worker built or reviewed with a different skill.

Some workers write those lines only after they settle. If the summary lacks them, look further before you release the worker: give it up to two minutes to go idle, then read its output with `orca orchestration worker-read --dispatch <dispatch_id> --limit 3000 --json` and take the lines from a later `worker_done` or from its terminal. Stop the loop only if they are in neither place, and say in the final report which tickets' lines came from the worker's output.

Keep the worker's **follow-ups** with the ticket: each line of the `follow-ups:` block in its summary, or wherever you found the `tdd:` and `code-review:` lines. You offer them after the final report (see "Follow-ups"). A summary without the block has no follow-ups: that never stops the loop or fails the acceptance check.

A follow-up is work that was already wrong on `origin/<base>`. Before you release the worker, check each one against the files the branch changed, `git -C <path> diff --name-only origin/<base>..HEAD`. A follow-up that names a file in that list, or that names no file, may be a problem the diff introduced, so it goes back to the worker. Send all of them in one message, its body passed as you pass a spec:

```text
orca orchestration send --to dispatch:<dispatch_id> --subject "Follow-ups in your diff" --body "$body"
```

```text
These follow-ups name a file your branch changed, or no file. A problem in code your diff introduced is part of #<n>. For each one, either fix it and commit, or say why it was already wrong on origin/<base> before your first commit. Then settle with worker_done again. In its summary, write a `sent-back:` line with one line under it per follow-up, `- <title>: fixed` or `- <title>: pre-existing, <why>`.
<each follow-up sent back, as its `- <title>: <what you saw and where>` line>
```

Orca's guide says a worker that has settled gets a `send` as a follow-up Task and reports on it with a new `worker_done`, as its receipt says. Orca may release a settled worker on its own about two minutes after its `worker_done`, but a `send` reopens a worker it closed. Wait for that `worker_done` as above, and steer a `needs-input` escalation as above. Accept the reply when the first two checks above still pass and its `sent-back:` block has a `fixed` line, or a `pre-existing` line with a reason, for each follow-up you sent. Then drop the fixed ones from the ticket's follow-ups and keep the pre-existing ones as the worker first wrote them, beside the follow-ups that named only files the branch didn't change. For the final report, keep each follow-up you sent back and how it was resolved.

The loop stops at this step, and the final report lists the follow-ups sent back as unresolved, when:

- the `send` receipt says the worker refused the message, as a finished worker on a paired Orca server does;
- the reply settles with `--outcome failed`, or fails its acceptance check;
- an escalation says the worker `exited` or was `lost`.

Silence is not one of them: as for any worker, an empty or timed-out wait is a checkpoint, so keep waiting, and never release a worker whose reply hasn't been accepted.

Then `worker-release`, and release the follow-up Task's dispatch as well if the `send` receipt gave it one of its own. There is nothing to acknowledge: the `check` that returned the `worker_done` already marked it handled.

### 4. PR worker

A fresh agent in the same worktree: `worker-start --worktree issue:<n> --agent <PR agent> --task-title "#<n> PR"` with the PR spec, passed as in step 3. On an existing worktree Orca opens a new terminal, so this agent starts with an empty context.

Accept when the `worker_done` summary names a PR, `git -C <path> status --porcelain` is empty, and `gh pr view <pr> --json state,headRefName,body` shows it `OPEN`, on the ticket's branch, with `Closes #<n>` in the body. A merged or closed PR is one an earlier branch with the same name left behind, not this ticket's. Release it with `worker-release`.

Then compare the PR's title and body with the PR format in `shipping.md` (`gh pr view <pr> --json title,body`). If the title differs or the body lacks a section, fix them with `gh pr edit <pr> --title <title> --body-file <file>`, writing <file> with your file-writing tool outside the repo, and say what you changed in the merge question and the final report.

### 5. CI

If `shipping.md` sets **CI** to `none`, go to step 6. A file without the field means `required`. Otherwise wait for the checks in two parts:

1. **Checks listed.** For the first minutes after a push GitHub lists no checks yet. Run `gh pr view <pr> --json statusCheckRollup --jq '.statusCheckRollup | length'` about every 30 seconds until it prints a number above 0. If it still prints 0 after 10 minutes, stop the loop: CI is `required` but no check started.
2. **Checks settled.** Run `gh pr checks <pr> --watch --fail-fast --interval 30`. This can run for many minutes. If your harness notifies you when a background command exits, run it in the background: in Claude Code, with the Bash tool's `run_in_background`, then wait for the notification that it exited. Otherwise run it in the foreground, and if it times out, run it again until it exits with a result; it is safe to rerun.

- **Exit 0 (green)** → step 6.
- **Non-zero (red)** → start a **fix worker** in the same worktree: `worker-start --worktree issue:<n> --agent <fix agent> --task-title "#<n> fix"` with the fix spec and the CI failure as its reason. Accept it when it reports the fix pushed, keep its follow-ups with the ticket as in step 3, then run step 5 again. A fix worker's follow-ups skip step 3's file check: they include the work its reason asks for outside the ticket, which often names a file the branch changed, so the check can't tell it from a finding the worker should have fixed. The fix spec's own rule covers that case. A ticket gets at most **2** fix workers for CI. After the third red run, stop the loop.

### 6. Merge

Merge with the merge method from `shipping.md`: run `gh pr merge <pr> --<method>` as a command of its own, with nothing chained before or after it. The Claude Code merge hook that `setup-ship-tickets` adds approves only that exact command. If your harness has a Bash tool, run the merge with it, even when you run your other commands in PowerShell: a repo set up before the hook has an allow rule instead, which Claude Code's auto mode honors only for the Bash tool. The merge approval from "Before the first ticket" decides whether the user approves it first:

- **`auto`** → merge now. If the harness's permission check refuses the merge (a permission denial, as opposed to an error from `gh`), handle this ticket as `ask`: the user's answer is then what authorizes the merge. If the harness refuses `gh pr view` too, ask with the URL and title from step 4. Say in the merge question that the harness refused the unattended merge, and in the final report that `setup-ship-tickets` can add the merge hook that lets `auto` merge the repo's own PRs without asking. If the harness refuses the merge again after the user picks **Merge**, stop the loop: the user merges that PR themselves.
- **`ask`** → show the user the PR URL, its title and its size (`gh pr view <pr> --json url,title,additions,deletions,changedFiles`), then ask them to pick one and wait for the answer; if your harness has a structured question tool, use it:
  - **Merge** → merge.
  - **Request changes** → start a fix worker as in step 5, with the user's notes as its reason, then run steps 5 and 6 again. Review rounds are unlimited; the cap of 2 counts CI fixes only.
  - **Stop** → leave the PR open and end the loop.

Once merged, confirm the merge closed the ticket: `gh issue view <n> --json state`. If it is still open, `gh issue close <n> --comment "Shipped in #<pr>"`.

### 7. Clean up

1. Apply the **After merge** step from `shipping.md`, unless it says "nothing": for example `git push origin --delete <branch>` with the branch from step 2. Run it as a command of its own, with nothing chained before or after it. If your harness has a Bash tool, run it with that tool, even when you run your other commands in PowerShell, as for the merge in step 6. Then, by how it ends:
   - **The harness's permission check refuses it** (a permission denial, as opposed to an error from `git`): leave it undone and carry on. Keep the exact command for the final report, for the user to run. A refusal doesn't stop the loop or fail the ticket.
   - **It fails because the remote branch no longer exists** (`git` says the remote ref does not exist): GitHub already deleted it, so the step is done. Report nothing about it.
   - **Any other error**: carry on, since the PR is merged and the ticket closed, and keep the command and its output for the final report.
2. `orca worktree rm --worktree issue:<n> --json`. This also deletes the local branch once Orca can prove it merged. Run it as a command of its own, with nothing chained before or after it, and write out the `orca` executable from "Before the first ticket" rather than a variable that holds it, so the harness's permission check sees what runs. If the harness's permission check refuses it (a permission denial, as opposed to an error from Orca), leave the worktree in place and carry on: keep the exact command for the final report, for the user to run.
3. `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json` returns no rows.

Done when the PR is merged, the ticket is closed, the **After merge** step is done or was refused or failed and kept for the final report, the worktree is removed or its removal was refused, and no worker is left reclaimable. Then go back to step 1.

## Stopping

Stop the loop and leave the ticket's worktree and PR exactly as they are when:

- a worker settles with `--outcome failed`, or its result fails the acceptance check of its step;
- an implement worker can't resolve the follow-ups sent back to it at step 3: it refuses the message, fails, or is gone;
- CI is red after 2 fix workers, or no check starts within 10 minutes;
- `worker-start` exits non-zero (follow its receipt and the recovery reference, and launch no duplicate);
- the user picks **Stop** at step 6;
- the harness refuses a merge the user approved at step 6.

## Final report

Per ticket in the set: **merged** (PR link, whether the user approved a merge the harness refused, the exact **After merge** command for a cleanup the harness refused, the command and its output for a cleanup that failed, and the `worktree rm` command for any removal the harness refused), **stopped** (step, evidence, what the user needs to do), or **not started** (the blockers holding it, or the failed provenance check). For a merged or stopped ticket, also list each follow-up sent back at step 3 and how it was resolved: fixed, kept as pre-existing with the worker's reason, or unresolved because the loop stopped.

If the harness refused a cleanup, also say that turning on GitHub's "Automatically delete head branches" setting and running `setup-ship-tickets` again removes the step: GitHub then deletes the branch on merge, and **After merge** becomes "nothing".

Trouble with the loop itself, such as a worker that failed or a tool the harness refused, goes in this report, never in the follow-ups.

## Follow-ups

After the final report, whether the loop finished or stopped, offer the follow-ups you kept, once for the whole run. With none, skip this section.

1. **Gather.** Merge follow-ups from this run that describe the same work into one, keeping every ticket it came from. Search the open issues for each one, such as `gh issue list --state open --search "<key words of its title>" --json number,title --limit 5`, and mark each issue that looks like the same work as "possible duplicate of #x". Drop none: the user decides.
2. **Offer.** Show a numbered list, one entry per follow-up: its title, what the worker saw and where, the ticket it came from, and its possible duplicates. Ask which to open: all, none, or the numbers. If your harness has a structured question tool, use it with the options **All**, **None** and **Choose**, and on **Choose** ask for the numbers. Open nothing until the user answers, even with Merge approval `auto`: that covers merges only.

   If no one can answer, as in a non-interactive run where a question gets no reply, don't ask: end your last message, the one with the final report, with the numbered list, and open none.
3. **Open.** For each follow-up the user picked, write the issue body with your file-writing tool, outside the repo: what the worker saw, the files or lines it named, and as its last line `Found while shipping #<n> (PR #<pr>)`, or `Found while shipping #<n>` when that ticket stopped before its PR. A follow-up merged from several tickets gets one such line per ticket. Open it with `gh issue create --title "<title>" --body-file <file>`, adding `--label needs-triage` when `gh label list --json name --jq '.[].name'` lists `needs-triage`, and no label otherwise. Never label it `ready-for-agent`: no one has triaged it.
4. **Link.** Give the user the link of each issue you opened.

## Specs

Each spec meets Orca's task-spec contract: Target, Change, Constraints, Ownership, Observable acceptance. Fill the `<placeholders>` and send the rest as written.

<!-- Maintainers: before editing this spec, read https://github.com/samfaina/agent-skills/blob/main/docs/adr/0004-the-implement-spec-copies-matts-implement-skill.md -->

### Implement spec

```text
Target: GitHub issue #<n> in <owner>/<repo>, worked in this worktree on branch <branch>.

Change: build what the ticket asks. Read it first with `gh issue view <n> --comments`, plus any spec or parent issue it links. Then:
- Build test-first: call the Skill tool with `tdd` (in Claude Code, `mattpocock-skills:tdd`), at the seams the ticket or its spec names.
- Run typechecking and single test files as you go, and the full test suite once at the end.
- Review your diff: call the Skill tool with `code-review` (in Claude Code, `mattpocock-skills:code-review`, not its built-in `code-review`), against `origin/<base>` with issue #<n> as the spec, and fix what it finds. A finding about code your diff introduced is part of #<n>, even when the fix changes another file or takes more than the ticket names: fix it before you commit.
- Commit to the current branch.
- Settle with `worker_done`. In its summary, list your follow-ups: work in this repo that was already wrong on `origin/<base>` before your first commit, such as a bug you saw in passing outside #<n>. Follow-ups are pre-existing work only. Write a `follow-ups:` line with one line under it per follow-up, `- <title>: <what you saw and where>`, naming each file involved by its path from the repo root, or write `follow-ups: none`. The coordinator sends back any follow-up that names a file your branch changed. Trouble with your own job, such as a tool that failed, is not a follow-up: report it in the summary as usual. Put the block just before the two lines that end the summary: `tdd:` followed by the folder that holds the SKILL.md of the `tdd` you loaded, and `code-review:` followed by that of the `code-review`. Give each folder as your harness reported it when the skill loaded, or else the folder of the SKILL.md you read.

If `tdd` or `code-review` is not available to you, stop, and settle with `--outcome failed`, naming the missing skill.

Constraints: follow the repo's agent instruction files (AGENTS.md, CLAUDE.md and the like) and the docs they point to. Keep the commits local: another worker pushes the branch and opens the PR. Change files with your file-editing tool (Edit or Write in Claude Code), never with shell scripts, heredocs or redirections: no one is at your terminal to answer the permission prompt those can raise, so it waits, then refuses.

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

Change: fix what the reason describes, run the checks it concerns locally, commit, and push. For a CI failure, find it with `gh pr checks <pr>` and `gh run view <run-id> --log-failed`, and reproduce it with the commands in the repo's CI workflow. A problem you find in code this branch introduced is part of issue #<n>: fix it before you push. Then settle with `worker_done`, and in its summary list your follow-ups: work the reason asks for outside the scope of issue #<n>, and work in this repo that was already wrong on `origin/<base>` before the branch's first commit. Write a `follow-ups:` line with one line under it per follow-up, `- <title>: <what you saw and where>`, naming each file involved by its path from the repo root, or write `follow-ups: none`. Trouble with your own job, such as a tool that failed, is not a follow-up: report it in the summary as usual.

Constraints: stay within the scope of issue #<n>. When the reason, from CI or from the user's notes, asks for something outside that scope, don't do it: report it as a follow-up. Change files with your file-editing tool (Edit or Write in Claude Code), never with shell scripts, heredocs or redirections: no one is at your terminal to answer the permission prompt those can raise, so it waits, then refuses.

Ownership: this branch.

Observable acceptance: the checks named in the reason pass locally and the fix is pushed.
```
