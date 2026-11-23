# Release testing

Run this checklist before each release. It ships real tickets in a throwaway sandbox repo with each supported harness as the coordinator and as the workers.

Most of it runs unattended: `testing/run.sh` starts the coordinator, waits for it, and checks the result. You run six cases by hand, the ones where the coordinator asks you questions or the check needs you to read the run: fresh setup in each harness (1.1, 1.2), the version question with an older install (2.1), the question about a red base branch (2.2), the `ask` run of the loop (3.1), and a branch GitHub already deleted (3.5).

For each release, open an issue titled `Release test: <version>`, paste this checklist into it, and tick it off there. Every failure gets its own issue, linked from that one.

## The sandbox

`testing/sandbox/` is a small Node library with a CI workflow and a `docs/agents/shipping.md`. `testing/tickets/` holds its four tickets. `testing/sandbox.sh` turns them into a private GitHub repo, and resets that repo between runs.

- Ticket #2 is blocked by #3, so a full run ships them in the order #1, #3, #2, #4.
- `.claude/` holds the merge hook `/setup-ship-tickets` adds for Merge approval `auto`. `sandbox.sh create` copies its script from `skills/setup-ship-tickets/`.
- CI has two checks on PRs, `test` and `changelog`. `changelog` fails any PR that adds no line to `CHANGELOG.md`. The sandbox's `AGENTS.md` doesn't mention it, but the implement worker's code review usually catches it, so a PR rarely goes red by itself.
- A push to `main` runs CI too, the loop's **Base CI**: `test`, and `push-only`, a job PRs never run. So every loop run waits for a green Base CI before the first ticket and after each merge. `push-only` passes unless the repo variable `BASE_CI_RED` is set: `all` fails every run, and a commit sha fails every run but that commit's.

Run the scripts in bash (Git Bash on Windows), from this repo, with `gh` logged in. Below, `<sandbox>` is the repo you create, such as `<you>/ship-tickets-sandbox`.

**Create** the sandbox at the start of each release test. The repo must not exist yet: the script creates it, pushes the fixture as `main`, tags it `baseline`, allows only squash merges, creates the `needs-triage` label the coordinator gives the follow-ups it opens, and opens tickets #1 to #4 labelled `ready-for-agent`.

```bash
bash testing/sandbox.sh create <sandbox>
```

**Reset** before every run by hand. `run.sh` resets on its own. It closes open PRs, unsets `BASE_CI_RED`, force-pushes `main` back to `baseline`, deletes every other branch, turns off **Automatically delete head branches**, and reopens the four tickets as they were, comments deleted.

```bash
bash testing/sandbox.sh reset <sandbox> [--workers '<value>'] [--no-shipping-md] [--base-ci-red]
```

`--workers` writes its value into the **Workers** field of `shipping.md` for that run. `--no-shipping-md` removes the file and the merge hook, to test setup from scratch. `--base-ci-red` sets `BASE_CI_RED` to `all` and adds an empty commit to `main`, whose push run fails, so the base branch is red before the run. After a reset, remove the Orca worktrees the last run left, and reset your clone to `origin/main`. The script prints both commands.

To change the fixture or the tickets, edit `testing/` in this repo. The next `create` picks the change up. A new ticket is a file `tickets/<n>.md`, numbered after the last one, whose first line is `# <title>` and whose body starts on the third line.

## Before you start

Once per machine:

- [ ] The sandbox is created (above), cloned, and the clone is added to Orca as a repo (`orca repo add --path <clone>`). Every coordinator below runs in an Orca terminal in that clone.
- [ ] `gh` is logged in with admin access to the sandbox.
- [ ] `node` is on `PATH`. The scripts use it to read JSON.
- [ ] **Claude Code:** the `agent-skills` and `mattpocock-skills` plugins are installed and enabled, and `agent-skills` is at the version in `.claude-plugin/plugin.json` on `main` (`claude plugin update agent-skills@samfaina`). An older install stops every `/ship-tickets` run before its first ticket, at the version check.
- [ ] **OpenCode:** both sets of skills are installed with `npx skills add <repo> --agent opencode -g`, and `~/.config/opencode/opencode.json` denies both skills to the model ([Harnesses](docs/harnesses.md#keeping-the-skills-user-invoked)).
- [ ] **OpenCode model:** `model` in `~/.config/opencode/opencode.json` (or `.jsonc`) names one model, such as `openrouter/thinkingmachines/inkling:free`. `run.sh` passes no `-m`, so every OpenCode coordinator and worker uses this model. Don't pick a router such as `openrouter/free`: it picks a different model for each request, so a failure can't be traced to one model. Free models are rate-limited. OpenRouter allows 20 requests a minute, and 50 a day until the account has bought 10 credits, then 1,000. The OpenCode coordinator in 3.2 alone made about 90 requests on 0.4.4. If the model hits its limit or keeps failing during a run, set another model, rerun the case, and write in its result which model it ran on.
- [ ] **Windows:** `pwsh --version` is 7.3 or later.

Write down the versions. They go into `docs/harnesses.md` at the end:

| | Version |
| --- | --- |
| Date | |
| agent-skills (`.claude-plugin/plugin.json`) | |
| Orca | |
| Claude Code (`claude --version`) | |
| OpenCode (`opencode --version`) | |
| OpenCode model (`model` in `opencode.json`) | |
| mattpocock-skills, Claude Code (`claude plugin list`) | |
| mattpocock/skills, OpenCode (`~/.agents/.skill-lock.json`) | |
| OS and shell for each run | |

### OpenCode on a local model

A model served by [Ollama](https://ollama.com/) has no request limit. OpenCode sends about 14k tokens with every request, and a run can reach 80k, so give the model a 128k context in a Modelfile of its own. Ollama's default context is much smaller, and it drops the overflow without saying so:

```bash
printf 'FROM glm-4.7-flash\nPARAMETER num_ctx 131072\n' > Modelfile
ollama create glm-4.7-flash-128k -f Modelfile
```

Then add Ollama as a provider in `opencode.json` and point `model` at it:

```jsonc
"model": "ollama/glm-4.7-flash-128k",
"provider": {
  "ollama": {
    "npm": "@ai-sdk/openai-compatible",
    "options": { "baseURL": "http://localhost:11434/v1" },
    "models": {
      "glm-4.7-flash-128k": { "tools": true, "limit": { "context": 131072, "output": 16384 } }
    }
  }
}
```

Ollama unloads a model after 5 minutes without requests, and a coordinator can wait longer than that for CI. Set `OLLAMA_KEEP_ALIVE=30m` in the environment Ollama starts from, then restart Ollama. Load the model before you start a run, with `curl -s localhost:11434/api/generate -d '{"model":"glm-4.7-flash-128k"}'`, so the coordinator's first step doesn't wait for it: the first load of `glm-4.7-flash` took 5 minutes.

On 0.4.4, on a 16 GB GPU with 62 GB of RAM, five models at Q4 with a 128k context ran two cases. In 3.4 the local model is the OpenCode coordinator. In 3.3 Claude Code coordinates, and the local model is the PR and fix worker. Minutes are for 3.4, then 3.3.

| Model | Loaded | On GPU | 3.4 | 3.3 | Minutes | Lowest free RAM |
| --- | --- | --- | --- | --- | --- | --- |
| `glm-4.7-flash` | 26 GB | 60% | Merged #3 and #2 with a fix worker, but left the #3 PR worker unreleased | **PASS** | 42, 51 | 24 GB |
| `laguna-xs-2.1` | 20 GB | 50% | Merged #3 and #2 without watching CI, over a red check, with no fix worker | Not run | 30 | 17 GB |
| `qwen3.6` | 26 GB | 56% | Stopped once to ask whether to start, and once after the first merge | Merged 2 of 4; the PR worker for #2 ended its turn without opening the PR | 11, 39 | 21 GB |
| `north-mini-code-1.0` | 19 GB | 64% | Ended its turn without a tool call before the first ticket | Not run | 3 | 25 GB |
| `gpt-oss:20b` | 14 GB | 89% | Replied with text in its first step, telling the user to run the command | Not run | 1 | 32 GB |

`glm-4.7-flash` can stand in as the PR and fix worker. None of the five is reliable enough to coordinate. The failures are the models', not the skills': cloud models passed the same cases on 0.4.4 ([#30](https://github.com/samfaina/agent-skills/issues/30)).

## The docs

- [ ] `bash testing/docs-test.sh` passes. Every block a reader can copy from `README.md` and `docs/`, the landing page's copy buttons included, holds at most one slash command: Claude Code takes one command per message, so a pasted pair fails.

## The merge hook

- [ ] `bash testing/merge-hook-test.sh` passes. It runs the hook's script with a fake `gh`, with no network: each selector and each tool, for a PR of the repo, an External PR, a `gh` failure, and the forms of `gh pr merge` the hook asks about.
- [ ] In an interactive session in auto mode, in the sandbox's clone, with `GH_TOKEN` set to an invalid token, ask Claude Code to run `gh pr merge 999999 --admin --squash` with each tool. Each shows a prompt from the hook. Answer **No**.

## Automated runs

```bash
bash testing/run.sh <sandbox> <run> [--coordinator claude|opencode]
```

`run.sh` resets the sandbox, removes its Orca worktrees, and resets the clone, deleting its local branches. Then it starts the coordinator in a new Orca terminal in the clone, waits for it to exit, and ends with the result of `verify.sh`: `PASS`, or `FAIL` and the check that failed. Nothing asks you anything, so the coordinator runs with permission prompts off, in the sandbox's clone only: `claude -p --dangerously-skip-permissions` or `opencode run --auto`. `--coordinator` picks the harness for runs that can use either.

The coordinator runs with `MSYS_NO_PATHCONV=1`, which stops Git Bash rewriting arguments as paths, in every run but `setup-noop` and `outside-orca`. Those two unset it, so setup runs as it would in a user's Git Bash ([#64](https://github.com/samfaina/agent-skills/issues/64)). They don't catch a setup that sets the variable itself: check that by hand in 1.1.

The coordinator's output goes to `testing/logs/`: the JSON event log, `<run>-<time>.said.txt` with what the coordinator wrote, `<run>-<time>.report.txt` with its last message, and `<run>-<time>.ran.txt` with the commands it ran. Read them when a run fails.

For a loop run, `verify.sh` checks that:

- the tickets merged in order, each PR squash-merged on top of the one before;
- each PR's title is the issue title, its body has Summary and Testing and ends with `Closes #<n>`, and its branch starts with `<n>-`;
- each ticket is closed and its remote branch deleted, or, in `auto-mode` only, the harness refused the deletion and the last message gives `git push origin --delete <branch>` and names `setup-ship-tickets`;
- one PR's `changelog` check failed and then passed, so a fix worker ran;
- the run opened no issue besides the sandbox's tickets, and posted no comment on an issue but the loop's `Shipped in #<pr>`: the coordinator opens or folds a follow-up only on your answer, and an unattended run has no one to give it;
- no Orca worktree is left for the sandbox, and the run left no reclaimable worker;
- the coordinator's last message links each merged PR as `/pull/<n>`, in any language; a link in an earlier message doesn't count;
- in a run that stops on a red Base CI (`red-base` and `red-after-merge`), the commit it stopped on has a failed push run, the last message links each one as `/actions/runs/<id>` and names the `push-only` job, and, after a merge, the run opened no PR for the next ticket.

So that a fix worker always runs, `run.sh` forces one PR red: once the first ticket's PR opens, it pushes a commit that drops the PR's `CHANGELOG.md` line.

A run that has to stop before its first ticket passes when no PR and no worktree exist, and the coordinator's output names what stopped it: `#3`, `shipping.md`, `ORCA_TERMINAL_HANDLE`, a skill, a path, a version or a command. The checks match these names, never words, so they hold in any language.

You can also run `verify.sh` on its own after a run, with the tickets in the order they must merge: `bash testing/verify.sh <sandbox> 1 3 2 4`. It checks the last message only with `--report <run>-<time>.report.txt`.

`bash testing/report-test.sh` tests how `run.sh` and `verify.sh` read the coordinator's output, with no network: the said, ran and report files from a Claude Code and an OpenCode event log, the check that the report links each PR, the check that it gives a refused cleanup's command, the checks that the run opened no issue and posted no comment on one, the regex `run.sh` matches the version of the loop against, and how `verify.sh` picks the failed Base CI runs of a commit.

## 1. Setup

### 1.1 Fresh setup in Claude Code

Reset with `--no-shipping-md`, then delete the label: `gh label delete ready-for-agent --repo <sandbox> --yes`. Run `/setup-ship-tickets` in Claude Code, on Windows with its shell set to Git Bash and `MSYS_NO_PATHCONV` unset.

- [ ] The label check fails, and setup offers to create the label. Accept, and confirm it exists again.
- [ ] The other three preflight checks pass, each with its evidence.
- [ ] Merge method is settled as `squash` without a question, because it's the only method the repo allows.
- [ ] It asks about the unsettled fields with `AskUserQuestion`, offering the inferred value first: Merge approval, Branch naming if it has fewer than three PRs to infer from, and Workers in two rounds (same agent for every role, then the agent id).
- [ ] The provenance check passes for the implement worker's agent and names the `tdd` and `code-review` folders.
- [ ] Pick `auto` for Merge approval. Setup offers the merge hook with **Add** first, and says what it approves and what it asks about. Pick **Add**.
- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first, and says the loop then needs no post-merge cleanup, which auto mode may refuse, leaving a branch behind on every ticket. Pick **Yes**. It runs `gh repo edit --delete-branch-on-merge` on its own, `gh repo view <sandbox> --json deleteBranchOnMerge` then shows `true`, and **After merge** is "nothing".
- [ ] On Windows: it reads the merge hook's files from `origin/main` with no retry, reports the ones the reset removed as absent, never sets `MSYS_NO_PATHCONV`, creates its worktree at a drive-letter path, and prints `agents/shipping-config` from it before writing.
- [ ] It shows the files and waits for your go-ahead before committing. `.claude/hooks/merge-hook.sh` is the same as the skill's copy, `.claude/settings.json` holds the two hook entries and nothing else, and `.gitattributes` keeps the script LF.
- [ ] It opens a PR from `agents/shipping-config` adding `docs/agents/shipping.md` and the merge hook's files. `shipping.md` follows `shipping-template.md`: it opens with the single "Read by" line, no placeholder text is left, and **Body** lists the sections you confirmed. The PR body lists each value and where it came from, and the merge hook with what it does.
- [ ] The report says to pull the default branch into the coordinator's checkout once the PR merges, and that the branch-deletion setting was turned on.
- [ ] `git worktree list` shows no worktree left by the setup, and `git status --porcelain` in the clone prints nothing.

Close the PR without merging.

### 1.2 Fresh setup in OpenCode

Reset with `--no-shipping-md`, then delete the label as in 1.1. Run `/setup-ship-tickets` in OpenCode.

- [ ] Same as 1.1, but the questions come through OpenCode's `question` tool, and at the branch-deletion question pick **No**: the setting stays off, **After merge** deletes the remote branch with `git push origin --delete <branch>`, and the report says the setting was left off.

Close the PR without merging.

### 1.3 Setup with nothing to change

- [ ] `bash testing/run.sh <sandbox> setup-noop`: setup reports that `shipping.md` is up to date and opens no PR ([#24](https://github.com/samfaina/agent-skills/issues/24)).

### 1.4 The merge hook on a repo already set up

Each state below goes on `main` of a reset sandbox, and takes a run of `/setup-ship-tickets` in Claude Code. Close each PR without merging.

**Replace.** Set Merge approval to `auto`, delete `.claude/hooks/` and `.gitattributes`'s hook line if it has one, and put only `{"permissions": {"allow": ["Bash(gh pr merge * --squash)", "PowerShell(gh pr merge * --squash)"]}}` in `.claude/settings.json`.

- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first. Pick **No**.
- [ ] With nothing else to change in `shipping.md`, setup still offers **Replace** first, and says what the hook does and what the rule keeps allowing if you decline.
- [ ] Pick **Replace**. The PR adds the hook's files and removes the rule's entries, leaving no empty `permissions`.

**Update.** Set Merge approval to `auto`, and change a line of `.claude/hooks/merge-hook.sh`.

- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first. Pick **No**.
- [ ] With nothing else to change in `shipping.md`, setup offers **Update** first, and says what the hook does.
- [ ] Pick **Update**. The PR puts back the skill's copy of the script and changes nothing else.

**Remove.** Leave Merge approval at `ask`, and put the same rule in `.claude/settings.json`, with no hook.

- [ ] Setup offers **Remove** first, and doesn't offer the hook.
- [ ] Pick **Remove**. The PR removes the rule's entries and adds no hook.

**After merge contradicts the repo.** Leave `shipping.md` as the reset put it, with After merge deleting the branch, and turn the setting on: `gh repo edit <sandbox> --delete-branch-on-merge`.

- [ ] Setup asks no branch-deletion question, and the PR changes only After merge, to "nothing". The report says After merge changed because the setting is on.

**Nothing to do.** Set Merge approval to `auto`, and leave the hook as the reset put it.

- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first. Pick **No**.
- [ ] Setup says the hook is settled, reports that `shipping.md` is up to date, and opens no PR. The report says the branch-deletion setting was left off.

**Branch deletion on an update.** Set Merge approval to `auto`, and leave the rest as the reset put it.

- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first. Pick **Yes**. It runs `gh repo edit --delete-branch-on-merge` on its own, and `gh repo view <sandbox> --json deleteBranchOnMerge` then shows `true`.
- [ ] The PR changes only After merge, to "nothing". The report says the setting was turned on.

**A No keeps After merge's wording.** Set Merge approval to `auto`, and set After merge to `run git push origin --delete <branch> once the PR merges`, which deletes the branch in other words than setup writes.

- [ ] Setup asks whether to turn on **Automatically delete head branches**, offering **Yes** first. Pick **No**.
- [ ] Setup reports that `shipping.md` is up to date and opens no PR: After merge keeps your wording. The report says the setting was left off.

## 2. Preflight failures

Each run breaks one thing, runs a skill in Claude Code, and restores the thing afterwards.

- [ ] **Outside Orca.** `bash testing/run.sh <sandbox> outside-orca` runs `/setup-ship-tickets` outside an Orca terminal: the Orca terminal check fails with the fix, and setup carries on.
- [ ] **No `shipping.md`.** `bash testing/run.sh <sandbox> no-shipping-md`: `/ship-tickets` stops before the first ticket and tells you to run `setup-ship-tickets`.
- [ ] **Matt's skills missing in Claude Code.** `bash testing/run.sh <sandbox> no-matt-skills` disables the `mattpocock-skills` plugin while `/ship-tickets` runs: the provenance check fails before the first ticket and names the missing plugin. Other Claude Code sessions you start meanwhile don't get the plugin either.
- [ ] **Two copies of `tdd` in OpenCode.** `bash testing/run.sh <sandbox> two-tdd` sets Workers to `opencode` and copies `tdd/SKILL.md` to `~/.claude/skills/tdd/`, which OpenCode also loads: the provenance check fails and names both paths. The script refuses to run if that folder already exists.
- [ ] **An older install.** `bash testing/run.sh <sandbox> old-install` copies this checkout's skills to a temporary folder as the plugin `agent-skills-old` with version `0.0.1`, adds that folder as the marketplace `ship-tickets-test`, installs the plugin from it at local scope in the clone, and runs `/agent-skills-old:ship-tickets auto`. The installed `agent-skills` stays as it is. Nobody can answer whether to go on with the older version, so the coordinator stops before the first ticket, even with Merge approval `auto`. It names `0.0.1`, the latest release's version from `.claude-plugin/plugin.json` on `main`, and the update command `claude plugin update agent-skills-old@ship-tickets-test --scope local`. When the run ends, `run.sh` uninstalls the plugin, removes the marketplace and its copy in the plugin cache, and puts back the clone's `.claude/settings.local.json` as it was.
- [ ] **An older copy no install manages.** `bash testing/run.sh <sandbox> old-plugin-dir` loads the same copy with `claude --plugin-dir` instead, for the run's session only. The coordinator stops the same way and names both versions. `claude plugin list` has no entry for that copy, so there is no update command to give: the coordinator says to update the copy at the plugin root instead.
- [ ] **Blocked ticket.** `bash testing/run.sh <sandbox> blocked` runs `/ship-tickets auto 2`: it stops before starting a worker and reports that #3 holds #2.
- [ ] **A red base branch.** `bash testing/run.sh <sandbox> red-base` resets with `--base-ci-red`, so `main`'s push run fails on `push-only`, waits until GitHub lists that run, and runs `/ship-tickets auto`. Nobody can answer whether to go on, so the coordinator stops before the first ticket, even with Merge approval `auto`, after reading the push runs with `gh run list --commit`, and its last message names `push-only` and links the failed run. When the run ends, `run.sh` unsets `BASE_CI_RED`.

### 2.1 by hand: the version question

With nobody to answer, the runs above only show that the coordinator stops. This case answers the question. Reset the sandbox, then install the older release in the clone:

```bash
bash testing/sandbox.sh old-install <sandbox>
```

In a new Claude Code session in the clone, in an Orca terminal, run `/agent-skills-old:ship-tickets auto`.

- [ ] Before it creates a worktree or binds a Run, the coordinator asks with `AskUserQuestion`. The question shows `0.0.1`, the latest release and `claude plugin update agent-skills-old@ship-tickets-test --scope local`, and offers **Stop** first. Merge approval `auto` doesn't skip it.
- [ ] Pick **Stop**. The coordinator stops before the first ticket: `orca worktree list` shows no worktree for the sandbox, and no PR is open.

Run `/agent-skills-old:ship-tickets` again, without `auto`.

- [ ] It asks the same question. Pick **Go on**. The provenance check runs, a Run is bound, and the first ticket's implement worker starts.
- [ ] At the merge question, pick **Stop**. The final report starts with `0.0.1`, the latest release and the update command, then lists the ticket as stopped.

Close the PR without merging. Then remove the older release:

```bash
bash testing/sandbox.sh old-install <sandbox> --remove
```

- [ ] `claude plugin list` in the clone shows no `agent-skills-old`, and `git status --porcelain` in the clone prints nothing.

### 2.2 by hand: Go on with a red base branch

`red-base` only shows that the coordinator stops. This case answers its question and ships on top of a known failure. Reset with `--base-ci-red`, then run `/ship-tickets auto 1 3` in Claude Code, in an Orca terminal in the clone.

- [ ] Before it binds a Run, the coordinator asks with `AskUserQuestion`. The question names `push-only`, links the failed run, and offers **Stop** first. Merge approval `auto` doesn't skip it.
- [ ] Pick **Go on**. #1 and #3 ship. After each merge the coordinator waits for the merge commit's push runs, `push-only` fails again, and the loop goes on: it is a known failure.
- [ ] The final report gives the red check before the first ticket and your **Go on** next to the version, gives each merged ticket's Base CI result as red on the known failure `push-only` with its run link, and says that `push-only` was already failing before the first ticket and that a ticket's new breakage of that job can't be told apart from it.

Reset the sandbox afterwards, which unsets `BASE_CI_RED`.

## 3. The loop

One run per row of the harness matrix. Each run ships all four tickets unless the row says otherwise.

| Run | Workers | Coordinator | Command | How |
| --- | --- | --- | --- | --- |
| 3.1 | `` `opencode` (all roles) `` | Claude Code | `/ship-tickets` | By hand |
| 3.2 | `claude` (all roles) | OpenCode | `/ship-tickets auto` | `bash testing/run.sh <sandbox> 3.2` |
| 3.3 | ``implement `claude`, PR `opencode`, fix `opencode` `` | Claude Code, or OpenCode with `--coordinator opencode` | `/ship-tickets auto` | `bash testing/run.sh <sandbox> 3.3` |
| 3.4 | `claude` (all roles) | OpenCode on Windows, `SHELL` unset, so it runs `pwsh` | `/ship-tickets auto 3 2` | `bash testing/run.sh <sandbox> 3.4` |

- [ ] 3.2 passes.
- [ ] 3.3 passes.
- [ ] 3.4 passes.
- [ ] `bash testing/run.sh <sandbox> auto-mode` passes. It runs `/ship-tickets auto 1` in Claude Code with permission checks on (`--permission-mode auto`), where every other Claude Code run skips them. Auto mode refuses a merge no human approved, and the sandbox has no allow rule, so the run merges only if the merge hook approves it, which needs the plain command run on its own. `run.sh` checks that the coordinator ran it with the Bash tool, as the loop says, and ran the **After merge** step `git push origin --delete <branch>` on its own with the Bash tool too. The sandbox has **Automatically delete head branches** off, so the branch check before it exits 0 and the deletion runs. Auto mode may refuse that deletion. The run passes either way: with the branch deleted, or with the branch left and the last message giving the command and naming `setup-ship-tickets`. Write in the case's result which one happened.
- [ ] `bash testing/run.sh <sandbox> red-after-merge` passes. It sets `BASE_CI_RED` to `main`'s head, so the check before the first ticket sees `main` green and every later push run fails, and runs `/ship-tickets auto 1 3`. #1's PR checks pass, since PRs never run `push-only`, but its merge turns `main` red. The coordinator stops before #3 starts: #1 stays merged and closed, no PR closes #3, and the last message names `push-only` and links the failed run. When the run ends, `run.sh` unsets `BASE_CI_RED`.
- [ ] `bash testing/run.sh <sandbox> order` passes. It runs `/ship-tickets auto 2 3 1` in Claude Code, or in OpenCode with `--coordinator opencode`, and the tickets must merge in the order #3, #2, #1: the numbers set the order, #2 waits until #3 is closed, and then it ships ahead of #1. Lowest-numbered first would merge #1, #3, #2.

Besides `verify.sh`'s checks, `run.sh` checks the commands each coordinator ran: it bound a Run, read a commit's push runs with `gh run list --commit` for Base CI, checked that a merged ticket's branch still exists with `git ls-remote --exit-code origin refs/heads/<branch>` before the **After merge** step, and started workers with the agents Workers names (`--agent claude`, plus `--agent opencode` in 3.3). In a run whose coordinator is Claude Code, the last message must also name the version of the `agent-skills` plugin `claude plugin list --json` shows enabled, as the version of the loop that ran. An OpenCode coordinator's copy, from `npx skills add`, has no `plugin.json`, so its version is unknown and the run doesn't check it. In 3.4 it also checks that the coordinator resolved `orca` with `Get-Command`, which finds `orca.exe` before `orca.cmd`, and passed the specs as single-quoted here-strings: the two things that get a spec to a worker intact on Windows.

### 3.1 by hand: Merge approval `ask`

Reset with ``--workers '`opencode` (all roles)'``, and run `/ship-tickets` in Claude Code.

- [ ] Before the first ticket: the coordinator says in one line which version of the loop runs, such as `ship-tickets 0.9.0`, and in another that Base CI on `main` is green, without asking anything, the provenance check passes for the implement agent, and one Run is bound.
- [ ] Tickets ship in the order #1, #3, #2, #4. #2 waits until #3 is closed.
- [ ] Each worktree's name follows Branch naming in `shipping.md`.
- [ ] Each worker starts in OpenCode. Check the agent of each worker terminal in Orca.
- [ ] The implement worker's `worker_done` summary names the `tdd` and `code-review` folders, and the coordinator accepts them as matching the provenance check.
- [ ] Each PR's title is the issue title, and its body has Summary, Testing and `Closes #<n>`.
- [ ] The coordinator waits for the checks to appear, then runs the watch in the background until they finish.
- [ ] Before each merge, `AskUserQuestion` shows the PR URL, title and size and offers Merge, Request changes and Stop.
- [ ] On one ticket, pick **Request changes** with a note that also asks for two things clearly out of its scope (such as "add a test for an empty string, add a `reverse(text)` function to `src/index.js`, and add a `capitalize(text)` function to `src/index.js`"). A fix worker (task title `#<n> fix`) applies the part in scope, adds no `reverse` and no `capitalize`, CI runs again, and the coordinator asks again.
- [ ] After each merge: the PR is squash-merged, the issue is closed, the remote branch is deleted, the worktree is removed, `worker-list --terminal-state reclaimable` returns no rows, and the coordinator waits for the merge commit's push runs before the next ticket.
- [ ] On the last ticket, pick **Stop**. The PR stays open, and the final report starts with the version of the loop that ran, then lists each ticket as merged with its PR link, and the last one as stopped.
- [ ] The fix worker's out-of-scope requests aren't sent back to it, even though they name `src/index.js`, a file every branch but #2's changes: the coordinator checks only the implement workers' follow-ups.
- [ ] If an implement worker reports a follow-up that names a file its branch changed, or no file, the coordinator sends it back with `orca orchestration send` before releasing the worker, waits for its new `worker_done`, and the final report says whether the follow-up was fixed or kept as pre-existing, with the worker's reason. Write in the case's result whether a follow-up was sent back.
- [ ] After the final report, the coordinator shows the follow-ups as a numbered list, the two out-of-scope requests among them as two entries with the ticket they came from, and asks with `AskUserQuestion` offering **All**, **None** and **Choose**. It opens no issue and posts no comment before you answer.
- [ ] Each out-of-scope entry shows #1, #3 and #4, whose bodies name `src/index.js`, each once and with its state: as "same code as", or as a possible duplicate if the coordinator judged it one. It says this code has a chain of issues and suggests one issue about its contract.
- [ ] Pick **Choose** and give both entries' numbers. For each, the coordinator asks whether to open it or fold it into an open same-code match, #4 among them, since **Stop** left it open. Open `reverse`, and fold `capitalize` into #4.
- [ ] The coordinator links the issue it opened for `reverse`, which has the `needs-triage` label, not `ready-for-agent`, and whose body has a `## What happened` and a `## Where` section, no section that sets the fix or its scope, and ends with `Found while shipping #<n> (PR #<pr>)`.
- [ ] It links the comment it posted on #4 for `capitalize`, written the same way, and opened no issue for it. The body and labels of #4 are as they were (`gh issue view 4 --json body,labels`).
- [ ] Its message with the links says, for the ticket the requests came from, `reverse` opened as #x and `capitalize` folded into #4.

### 3.5 by hand: GitHub already deleted the branch

`shipping.md` still deletes the remote branch after each merge, but GitHub deletes it first. Reset the sandbox, keep its **After merge** step `git push origin --delete <branch>`, and turn the setting on:

```bash
gh repo edit <sandbox> --delete-branch-on-merge
```

Then run `/ship-tickets auto 1 3` in Claude Code, in an Orca terminal in the clone.

- [ ] After each merge, step 7 runs `git ls-remote --exit-code origin refs/heads/<branch>` on its own, it exits 2, and the coordinator runs no `git push origin --delete`.
- [ ] The run shows no failed tool call for the cleanup.
- [ ] #1 and #3 are merged and closed, and `gh api repos/<sandbox>/branches --jq '.[].name'` prints only `main`: both branches are gone.
- [ ] The final report says exactly once, not once per ticket, that `shipping.md`'s **After merge** deletes a branch GitHub's "Automatically delete head branches" already deletes, and names `setup-ship-tickets` as the fix.

Reset the sandbox afterwards, which turns the setting off.

## When you're done

- [ ] Every failure has its own issue, linked from the release test issue.
- [ ] `docs/harnesses.md` lists the versions from the table above and the date.
- [ ] If every case passed, tag the commit next to the agent-skills version in the table above, and push the tag: `git tag v<version> <commit> && git push origin v<version>`. A version whose test failed gets no tag.
- [ ] Delete the sandbox with `gh repo delete <sandbox> --yes`. It needs the `delete_repo` scope: `gh auth refresh -s delete_repo`.
