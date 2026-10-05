# Release testing

Run this checklist before each release. It ships real tickets in a throwaway sandbox repo with each supported harness as the coordinator and as the workers.

For each release, open an issue titled `Release test: <version>`, paste this checklist into it, and tick it off there. Every failure gets its own issue, linked from that one.

## The sandbox

`testing/sandbox/` is a small Node library with a CI workflow and a `docs/agents/shipping.md`. `testing/tickets/` holds its four tickets. `testing/sandbox.sh` turns them into a private GitHub repo, and resets that repo between runs.

- Ticket #2 is blocked by #3, so a full run ships them in the order #1, #3, #2, #4.
- CI has two checks, `test` and `changelog`. `changelog` fails any PR that adds no line to `CHANGELOG.md`. The sandbox's `AGENTS.md` doesn't mention it, so a PR usually goes red the first time and a fix worker has to add the line.

Run the script in bash (Git Bash on Windows), from this repo, with `gh` logged in. Below, `<sandbox>` is the repo you create, such as `<you>/ship-tickets-sandbox`.

**Create** the sandbox at the start of each release test. The repo must not exist yet: the script creates it, pushes the fixture as `main`, tags it `baseline`, allows only squash merges, and opens tickets #1 to #4 labelled `ready-for-agent`.

```bash
bash testing/sandbox.sh create <sandbox>
```

**Reset** before every run. It closes open PRs, force-pushes `main` back to `baseline`, deletes every other branch, and reopens the four tickets as they were, comments deleted.

```bash
bash testing/sandbox.sh reset <sandbox> [--workers '<value>'] [--no-shipping-md]
```

`--workers` writes its value into the **Workers** field of `shipping.md` for that run. `--no-shipping-md` removes the file, to test setup from scratch. After a reset, remove the Orca worktrees the last run left, and reset your clone to `origin/main`. The script prints both commands.

To change the fixture or the tickets, edit `testing/` in this repo. The next `create` picks the change up. A new ticket is a file `tickets/<n>.md`, numbered after the last one, whose first line is `# <title>` and whose body starts on the third line.

## Before you start

Once per machine:

- [ ] The sandbox is created (above) and added to Orca as a repo. Every coordinator below runs in an Orca terminal in its clone.
- [ ] `gh` is logged in with admin access to the sandbox.
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

## 1. Setup

### 1.1 Fresh setup in Claude Code

Reset with `--no-shipping-md`. Run `/setup-ship-tickets` in Claude Code.

- [ ] All four preflight checks pass, each with its evidence.
- [ ] Merge method is settled as `squash` without a question, because it's the only method the repo allows.
- [ ] It asks about the unsettled fields with `AskUserQuestion`, offering the inferred value first: Merge approval, Branch naming if it has fewer than three PRs to infer from, and Workers in two rounds (same agent for every role, then the agent id).
- [ ] The provenance check passes for the implement worker's agent and names the `tdd` and `code-review` folders.
- [ ] It shows the file and waits for your go-ahead before committing.
- [ ] It opens a PR from `agents/shipping-config` adding `docs/agents/shipping.md`. The file follows `shipping-template.md`, and the PR body lists each value and where it came from.
- [ ] `git worktree list` shows no worktree left by the setup.

Close the PR without merging.

### 1.2 Fresh setup in OpenCode

Reset with `--no-shipping-md`. Run `/setup-ship-tickets` in OpenCode.

- [ ] Same as 1.1, but the questions come through OpenCode's `question` tool.

Close the PR without merging.

### 1.3 Setup with nothing to change

Reset. Run `/setup-ship-tickets` in either harness.

- [ ] It reports that `shipping.md` is up to date and opens no PR ([#24](https://github.com/samfaina/agent-skills/issues/24)).

## 2. Preflight failures

Each item breaks one thing, runs a skill, and restores the thing afterwards. Reset first.

- [ ] **Missing label.** `gh label delete ready-for-agent --repo <sandbox> --yes`, then `/setup-ship-tickets`: the label check fails, and setup offers to create the label. Accept, and confirm it exists again.
- [ ] **Outside Orca.** Run `/setup-ship-tickets` in a terminal that Orca didn't open: the Orca terminal check fails with the fix, and setup carries on.
- [ ] **No `shipping.md`.** Reset with `--no-shipping-md`, then `/ship-tickets`: it stops before the first ticket and tells you to run `setup-ship-tickets`.
- [ ] **Matt's skills missing in Claude Code.** `claude plugin disable mattpocock-skills@claude-plugins-official`, then `/ship-tickets`: the provenance check fails before the first ticket and names the missing plugin. Re-enable it with `claude plugin enable`.
- [ ] **Two copies of `tdd` in OpenCode.** Reset with ``--workers '`opencode` (all roles)'``. Put a second `tdd/SKILL.md` in a folder OpenCode loads skills from, such as `~/.claude/skills/tdd/`, and confirm that `opencode debug skill` lists it. Then `/ship-tickets`: the provenance check fails and names both paths. Delete the copy.
- [ ] **Blocked ticket.** Reset, then `/ship-tickets 2`: it stops before starting a worker and reports that #3 holds #2.

## 3. The loop

One run per row of the harness matrix. Each run ships all four tickets unless the row says otherwise.

| Run | Reset with | Coordinator | Command |
| --- | --- | --- | --- |
| 3.1 | ``--workers '`opencode` (all roles)'`` | Claude Code | `/ship-tickets` |
| 3.2 | (no options) | OpenCode | `/ship-tickets auto` |
| 3.3 | ``--workers 'implement `claude`, PR `opencode`, fix `opencode`'`` | Claude Code or OpenCode | `/ship-tickets auto` |
| 3.4 | (no options) | OpenCode on Windows, `SHELL` unset, so it runs `pwsh` | `/ship-tickets auto 3 2` |

If 3.2 runs on Windows with `SHELL` unset, it covers 3.4 too.

### Every run

- [ ] Before the first ticket: the provenance check passes for the implement agent, and one Run is bound.
- [ ] Tickets ship in the order #1, #3, #2, #4 (#3, #2 in run 3.4). #2 waits until #3 is closed.
- [ ] Each worktree's name follows Branch naming in `shipping.md`.
- [ ] Each worker starts in the harness its role names in Workers. Check the agent of each worker terminal in Orca.
- [ ] The implement worker's `worker_done` summary names the `tdd` and `code-review` folders, and the coordinator accepts them as matching the provenance check.
- [ ] Each PR's title is the issue title, and its body has Summary, Testing and `Closes #<n>`.
- [ ] The coordinator waits for the checks to appear, then until they finish. In Claude Code the watch runs in the background. In OpenCode it runs in the foreground and reruns after a timeout.
- [ ] A red `changelog` check starts a fix worker (task title `#<n> fix`). It adds a `CHANGELOG.md` line, pushes, and CI goes green.
- [ ] After each merge: the PR is squash-merged, the issue is closed, the remote branch is deleted, the worktree is removed, and `worker-list --terminal-state reclaimable` returns no rows.
- [ ] The final report lists each ticket as merged, with its PR link. In run 3.1, the ticket you stopped is listed as stopped.

### Run 3.1 only: Merge approval `ask`

- [ ] Before each merge, `AskUserQuestion` shows the PR URL, title and size and offers Merge, Request changes and Stop.
- [ ] On one ticket, pick **Request changes** with a note (such as "add a test for an empty string"). A fix worker applies it, CI runs again, and the coordinator asks again.
- [ ] On the last ticket, pick **Stop**. The PR stays open, and the final report lists that ticket as stopped.

### Runs 3.2 to 3.4 only: Merge approval `auto`

- [ ] No merge question: each PR merges as soon as CI is green.

### Run 3.4 only: `pwsh`

- [ ] The coordinator runs its commands in `pwsh` and passes each spec as a single-quoted here-string.
- [ ] The spec reaches the worker intact, backticks and quotes included. Compare the start of a worker's terminal with the implement spec in `skills/ship-tickets/ship-tickets-loop.md`.
- [ ] Every `orca` command calls `orca.exe`.

### If no PR went red

If the implement worker added a `CHANGELOG.md` line in every ticket of a run, the fix worker for CI never ran. Reset, run `/ship-tickets 4`, and as soon as the PR is open, push a commit to its branch that removes the `CHANGELOG.md` line:

- [ ] The `changelog` check fails, and a fix worker restores the line and gets CI green.

## When you're done

- [ ] Every failure has its own issue, linked from the release test issue.
- [ ] `docs/harnesses.md` lists the versions from the table above and the date.
- [ ] Delete the sandbox with `gh repo delete <sandbox> --yes`. It needs the `delete_repo` scope: `gh auth refresh -s delete_repo`.
