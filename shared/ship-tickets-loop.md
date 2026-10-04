# Ship tickets: the loop

Shared by `/ship-tickets` and `/ship-tickets-reviewed`. They differ only at step 6, **Merge**, and each skill says what to do there.

You are the **coordinator**: you own the ticket order, the CI wait and the merge. **Workers** are fresh Orca agents. Each does one job in the ticket's worktree and settles with `worker_done`. Tickets ship **one at a time**, so each one starts from the base branch the previous one merged into.

## Before the first ticket

1. Load Orca's orchestration guide with `orca skills get orchestration`, resolving the executable as the `orchestration` skill says. The guide is the source of truth for every `orca orchestration` command below and for its safety floor: an empty or timed-out wait is a checkpoint, and only an accepted `worker_done` authorizes `worker-release`. Before any stop, abandon or retry, load its `references/recovery-and-cleanup.md`.
2. Read `docs/agents/shipping.md` as the remote default branch holds it, so the loop runs the same from any worktree: `git fetch origin`, then `git show origin/<default>:docs/agents/shipping.md`, where `<default>` comes from `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. It sets the base branch, merge method, branch naming, CI, PR format and post-merge cleanup. If the default branch lacks the file, stop and tell the user to run `/setup-ship-tickets` and merge the PR it opens.
3. Resolve the **ticket set**: the issue numbers the user passed or, with none, every open issue labelled `ready-for-agent`.
4. Bind one Run for the whole session: `orca orchestration run-create --objective "Ship tickets #a, #b, …" --json`.

Done when the guide is loaded, `shipping.md` is read, the ticket set is a list of numbers, and a Run is bound.

## For each ticket

### 1. Pick

A ticket is **ready** when it is open and none of its blockers is open: `gh api repos/{owner}/{repo}/issues/<n> --jq .issue_dependencies_summary.blocked_by` returns `0`, and every issue in a `Blocked by:` line of its body is closed. Take the lowest-numbered ready ticket in the set.

Tickets left but none ready: stop and report which open blockers hold them.

### 2. Worktree

```bash
git fetch origin
orca worktree create --name <slug> --issue <n> --base-branch origin/<base> --json
```

`<slug>` follows the branch naming in `shipping.md`. Record the worktree path and branch from the result. Address the worktree as `issue:<n>` from here on.

### 3. Implement worker

```bash
orca orchestration worker-start --worktree issue:<n> --agent claude --task-title "#<n> implement" --spec "$(cat <<'SPEC'
<implement spec>
SPEC
)" --json
```

Then wait as the guide says (`check --wait --types worker_done,escalation,question`). Pass every spec through a quoted heredoc like this one, so its backticks and `$` reach the worker unchanged.

Answer each worker `question` with `reply`. Answer from the ticket and the repo when they hold the answer, otherwise ask the user and relay what they say.

Accept `--outcome succeeded` when `git -C <path> log origin/<base>..HEAD --oneline` lists commits and `git -C <path> status --porcelain` is empty. Then `worker-release` and ack.

### 4. PR worker

A fresh agent in the same worktree: `worker-start --worktree issue:<n> --agent claude --task-title "#<n> PR"` with the PR spec. On an existing worktree Orca opens a new terminal, so this agent starts with an empty context.

Accept when the `worker_done` summary names a PR, `gh pr view <pr> --json headRefName,body` shows the ticket's branch, and the body contains `Closes #<n>`. Release and ack.

### 5. CI

If `shipping.md` sets **CI** to `none`, go to step 6. A file without the field means `required`. Otherwise run this as a background command, so you are notified when it exits:

```bash
for i in $(seq 1 40); do
  [ "$(gh pr view <pr> --json statusCheckRollup --jq '.statusCheckRollup | length')" -gt 0 ] && break
  sleep 15
done
gh pr checks <pr> --watch --fail-fast --interval 30
```

The loop covers the first minutes after a push, when GitHub lists no checks yet.

- **Exit 0 (green)** → step 6.
- **Non-zero (red)** → start a **fix worker** (spec below) in the same worktree with the CI failure as its reason, accept it when it reports the fix pushed, then run step 5 again. A ticket gets at most **2** fix workers for CI. After the third red run, stop the loop.

### 6. Merge

Do what the running skill says. Then confirm the merge closed the ticket: `gh issue view <n> --json state`. If it is still open, `gh issue close <n> --comment "Shipped in #<pr>"`.

### 7. Clean up

1. Apply the post-merge cleanup from `shipping.md` (for example deleting the remote branch).
2. `orca worktree rm --worktree issue:<n> --json`. This also deletes the local branch once Orca can prove it merged.
3. `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json` returns no rows.

Done when the PR is merged, the ticket is closed, the worktree is removed and no worker is left reclaimable. Then go back to step 1.

## Stopping

Stop the loop and leave the ticket's worktree and PR exactly as they are when:

- a worker settles with `--outcome failed`, or its result fails the acceptance check of its step;
- CI is red after 2 fix workers;
- `worker-start` exits non-zero (follow its receipt and the recovery reference, and launch no duplicate);
- the running skill's merge step says to stop.

## Final report

Per ticket in the set: **merged** (PR link), **stopped** (step, evidence, what the user needs to do), or **not started** (the blockers holding it).

## Specs

Each spec meets Orca's task-spec contract: Target, Change, Constraints, Ownership, Observable acceptance. Fill the `<placeholders>` and send the rest as written.

### Implement spec

```text
Target: GitHub issue #<n> in <owner>/<repo>, worked in this worktree on branch <branch>.

Change: build what the ticket asks. Read it first with `gh issue view <n> --comments`, plus any spec or parent issue it links. Then:
- Build test-first with the `mattpocock-skills:tdd` skill, at the seams the ticket or its spec names.
- Run typechecking and single test files as you go, and the full test suite once at the end.
- Review your diff with the `mattpocock-skills:code-review` skill against `origin/<base>`, with issue #<n> as the spec, and fix what it finds.
- Commit to the current branch.

Constraints: follow the repo's CLAUDE.md / AGENTS.md and the docs they point to. Keep the commits local: another worker pushes the branch and opens the PR.

Ownership: this worktree and its branch.

Observable acceptance: every acceptance criterion in #<n> is met, the full test suite passes, and the work is committed with a clean working tree.
```

### PR spec

```text
Target: branch <branch> in this worktree, which implements issue #<n>.

Change: push the branch with `git push -u origin HEAD` and open a PR against <base> with `gh pr create`. Write the title and body as docs/agents/shipping.md describes, working from the commits (`git log origin/<base>..HEAD`), the diff and issue #<n>. The body ends with `Closes #<n>`.

Constraints: publish the code exactly as committed.

Ownership: the branch on the remote and its PR.

Observable acceptance: the PR is open against <base>. Put its URL in the worker_done summary.
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
