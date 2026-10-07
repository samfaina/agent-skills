# Release testing

Run this checklist before each release. It ships real tickets in a throwaway sandbox repo with each supported harness as the coordinator and as the workers.

Most of it runs unattended: `testing/run.sh` starts the coordinator, waits for it, and checks the result. You run three cases by hand, the ones where the coordinator asks you questions: fresh setup in each harness (1.1, 1.2) and the `ask` run of the loop (3.1).

For each release, open an issue titled `Release test: <version>`, paste this checklist into it, and tick it off there. Every failure gets its own issue, linked from that one.

## The sandbox

`testing/sandbox/` is a small Node library with a CI workflow and a `docs/agents/shipping.md`. `testing/tickets/` holds its four tickets. `testing/sandbox.sh` turns them into a private GitHub repo, and resets that repo between runs.

- Ticket #2 is blocked by #3, so a full run ships them in the order #1, #3, #2, #4.
- CI has two checks, `test` and `changelog`. `changelog` fails any PR that adds no line to `CHANGELOG.md`. The sandbox's `AGENTS.md` doesn't mention it, but the implement worker's code review usually catches it, so a PR rarely goes red by itself.

Run the scripts in bash (Git Bash on Windows), from this repo, with `gh` logged in. Below, `<sandbox>` is the repo you create, such as `<you>/ship-tickets-sandbox`.

**Create** the sandbox at the start of each release test. The repo must not exist yet: the script creates it, pushes the fixture as `main`, tags it `baseline`, allows only squash merges, and opens tickets #1 to #4 labelled `ready-for-agent`.

```bash
bash testing/sandbox.sh create <sandbox>
```

**Reset** before every run by hand. `run.sh` resets on its own. It closes open PRs, force-pushes `main` back to `baseline`, deletes every other branch, and reopens the four tickets as they were, comments deleted.

```bash
bash testing/sandbox.sh reset <sandbox> [--workers '<value>'] [--no-shipping-md]
```

`--workers` writes its value into the **Workers** field of `shipping.md` for that run. `--no-shipping-md` removes the file, to test setup from scratch. After a reset, remove the Orca worktrees the last run left, and reset your clone to `origin/main`. The script prints both commands.

To change the fixture or the tickets, edit `testing/` in this repo. The next `create` picks the change up. A new ticket is a file `tickets/<n>.md`, numbered after the last one, whose first line is `# <title>` and whose body starts on the third line.

## Before you start

Once per machine:

- [ ] The sandbox is created (above), cloned, and the clone is added to Orca as a repo (`orca repo add --path <clone>`). Every coordinator below runs in an Orca terminal in that clone.
- [ ] `gh` is logged in with admin access to the sandbox.
- [ ] `node` is on `PATH`. The scripts use it to read JSON.
- [ ] **Claude Code:** the `agent-skills` and `mattpocock-skills` plugins are installed and enabled.
- [ ] **OpenCode:** both sets of skills are installed with `npx skills add <repo> --agent opencode -g`, and `~/.config/opencode/opencode.json` denies both skills to the model ([Harnesses](docs/harnesses.md#keeping-the-skills-user-invoked)).
- [ ] **Windows:** `pwsh --version` is 7.3 or later.

Write down the versions. They go into `docs/harnesses.md` at the end:

| | Version |
| --- | --- |
| Date | |
| agent-skills (`.claude-plugin/plugin.json`) | |
| Orca | |
| Claude Code (`claude --version`) | |
| OpenCode (`opencode --version`) | |
| mattpocock-skills, Claude Code (`claude plugin list`) | |
| mattpocock/skills, OpenCode (`~/.agents/.skill-lock.json`) | |
| OS and shell for each run | |

## Automated runs

```bash
bash testing/run.sh <sandbox> <run> [--coordinator claude|opencode]
```

`run.sh` resets the sandbox, removes its Orca worktrees, and resets the clone, deleting its local branches. Then it starts the coordinator in a new Orca terminal in the clone, waits for it to exit, and ends with the result of `verify.sh`: `PASS`, or `FAIL` and the check that failed. Nothing asks you anything, so the coordinator runs with permission prompts off, in the sandbox's clone only: `claude -p --dangerously-skip-permissions` or `opencode run --auto`. `--coordinator` picks the harness for runs that can use either.

The coordinator's output goes to `testing/logs/`: the JSON event log, `<run>-<time>.said.txt` with what the coordinator wrote, and `<run>-<time>.ran.txt` with the commands it ran. Read them when a run fails.

For a loop run, `verify.sh` checks that:

- the tickets merged in order, each PR squash-merged on top of the one before;
- each PR's title is the issue title, its body has Summary and Testing and ends with `Closes #<n>`, and its branch starts with `<n>-`;
- each ticket is closed and its remote branch deleted;
- one PR's `changelog` check failed and then passed, so a fix worker ran;
- no Orca worktree is left for the sandbox, and the run left no reclaimable worker.

So that a fix worker always runs, `run.sh` forces one PR red: once the first ticket's PR opens, it pushes a commit that drops the PR's `CHANGELOG.md` line.

A run that has to stop before its first ticket passes when no PR and no worktree exist, and the coordinator's report names the failed check.

You can also run `verify.sh` on its own after a run, with the tickets in the order they must merge: `bash testing/verify.sh <sandbox> 1 3 2 4`.

## 1. Setup

### 1.1 Fresh setup in Claude Code

Reset with `--no-shipping-md`, then delete the label: `gh label delete ready-for-agent --repo <sandbox> --yes`. Run `/setup-ship-tickets` in Claude Code.

- [ ] The label check fails, and setup offers to create the label. Accept, and confirm it exists again.
- [ ] The other three preflight checks pass, each with its evidence.
- [ ] Merge method is settled as `squash` without a question, because it's the only method the repo allows.
- [ ] It asks about the unsettled fields with `AskUserQuestion`, offering the inferred value first: Merge approval, Branch naming if it has fewer than three PRs to infer from, and Workers in two rounds (same agent for every role, then the agent id).
- [ ] The provenance check passes for the implement worker's agent and names the `tdd` and `code-review` folders.
- [ ] It shows the file and waits for your go-ahead before committing.
- [ ] It opens a PR from `agents/shipping-config` adding `docs/agents/shipping.md`. The file follows `shipping-template.md`, and the PR body lists each value and where it came from.
- [ ] `git worktree list` shows no worktree left by the setup.

Close the PR without merging.

### 1.2 Fresh setup in OpenCode

Reset with `--no-shipping-md`, then delete the label as in 1.1. Run `/setup-ship-tickets` in OpenCode.

- [ ] Same as 1.1, but the questions come through OpenCode's `question` tool.

Close the PR without merging.

### 1.3 Setup with nothing to change

- [ ] `bash testing/run.sh <sandbox> setup-noop`: setup reports that `shipping.md` is up to date and opens no PR ([#24](https://github.com/samfaina/agent-skills/issues/24)).

## 2. Preflight failures

Each run breaks one thing, runs a skill in Claude Code, and restores the thing afterwards.

- [ ] **Outside Orca.** `bash testing/run.sh <sandbox> outside-orca` runs `/setup-ship-tickets` outside an Orca terminal: the Orca terminal check fails with the fix, and setup carries on.
- [ ] **No `shipping.md`.** `bash testing/run.sh <sandbox> no-shipping-md`: `/ship-tickets` stops before the first ticket and tells you to run `setup-ship-tickets`.
- [ ] **Matt's skills missing in Claude Code.** `bash testing/run.sh <sandbox> no-matt-skills` disables the `mattpocock-skills` plugin while `/ship-tickets` runs: the provenance check fails before the first ticket and names the missing plugin. Other Claude Code sessions you start meanwhile don't get the plugin either.
- [ ] **Two copies of `tdd` in OpenCode.** `bash testing/run.sh <sandbox> two-tdd` sets Workers to `opencode` and copies `tdd/SKILL.md` to `~/.claude/skills/tdd/`, which OpenCode also loads: the provenance check fails and names both paths. The script refuses to run if that folder already exists.
- [ ] **Blocked ticket.** `bash testing/run.sh <sandbox> blocked` runs `/ship-tickets auto 2`: it stops before starting a worker and reports that #3 holds #2.

## 3. The loop

One run per row of the harness matrix. Each run ships all four tickets unless the row says otherwise.

| Run | Workers | Coordinator | Command | How |
| --- | --- | --- | --- | --- |
| 3.1 | `` `opencode` (all roles) `` | Claude Code | `/ship-tickets` | By hand |
| 3.2 | `claude` (all roles) | OpenCode | `/ship-tickets auto` | `bash testing/run.sh <sandbox> 3.2` |
| 3.3 | ``implement `claude`, PR `opencode`, fix `opencode` `` | Claude Code, or OpenCode with `--coordinator opencode` | `/ship-tickets auto` | `bash testing/run.sh <sandbox> 3.3` |
| 3.4 | `claude` (all roles) | OpenCode on Windows, `SHELL` unset, so it runs `pwsh` | `/ship-tickets auto 3 2` | `bash testing/run.sh <sandbox> 3.4` |

- [ ] 3.2 passes.
- [ ] 3.3 passes. `run.sh` also checks that the coordinator started workers with both `--agent claude` and `--agent opencode`.
- [ ] 3.4 passes. `run.sh` also checks that the coordinator called `orca.exe` and passed specs as single-quoted here-strings. By hand, compare the start of one worker's terminal with the implement spec in `skills/ship-tickets/ship-tickets-loop.md`: the spec must arrive intact, backticks and quotes included.

### 3.1 by hand: Merge approval `ask`

Reset with ``--workers '`opencode` (all roles)'``, and run `/ship-tickets` in Claude Code.

- [ ] Before the first ticket: the provenance check passes for the implement agent, and one Run is bound.
- [ ] Tickets ship in the order #1, #3, #2, #4. #2 waits until #3 is closed.
- [ ] Each worktree's name follows Branch naming in `shipping.md`.
- [ ] Each worker starts in OpenCode. Check the agent of each worker terminal in Orca.
- [ ] The implement worker's `worker_done` summary names the `tdd` and `code-review` folders, and the coordinator accepts them as matching the provenance check.
- [ ] Each PR's title is the issue title, and its body has Summary, Testing and `Closes #<n>`.
- [ ] The coordinator waits for the checks to appear, then runs the watch in the background until they finish.
- [ ] Before each merge, `AskUserQuestion` shows the PR URL, title and size and offers Merge, Request changes and Stop.
- [ ] On one ticket, pick **Request changes** with a note (such as "add a test for an empty string"). A fix worker (task title `#<n> fix`) applies it, CI runs again, and the coordinator asks again.
- [ ] After each merge: the PR is squash-merged, the issue is closed, the remote branch is deleted, the worktree is removed, and `worker-list --terminal-state reclaimable` returns no rows.
- [ ] On the last ticket, pick **Stop**. The PR stays open, and the final report lists each ticket as merged with its PR link, and the last one as stopped.

## When you're done

- [ ] Every failure has its own issue, linked from the release test issue.
- [ ] `docs/harnesses.md` lists the versions from the table above and the date.
- [ ] Delete the sandbox with `gh repo delete <sandbox> --yes`. It needs the `delete_repo` scope: `gh auth refresh -s delete_repo`.
