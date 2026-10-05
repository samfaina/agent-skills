# Skill provenance check

Implement workers build with Matt Pocock's `tdd` and review with his `code-review`. A different skill with the same name breaks the loop and nobody notices. Claude Code has a built-in `code-review`, and when two skills share a name OpenCode picks one of them and leaves only a WARN log line. This check finds the folder each worker harness will load both skills from and confirms it comes from `mattpocock/skills`.

Run it for the harness of every worker role whose spec calls these skills. Today that is the implement role only. Run each command from the repo root. Each harness ends with one of three results:

- **pass**: record the **resolved folder** of `tdd` and of `code-review`, the realpath of the folder that holds each `SKILL.md`;
- **fail**: name the skill, the path the harness would load it from, and what is wrong;
- **warn**: there is no install record to check, so the result rests on the content check below.

**Realpath** of a folder: `realpath <dir>` in POSIX shells, `(Get-Item <dir>).ResolveLinkTarget($true)?.FullName ?? <dir>` in PowerShell 7. The `skills` installer links each agent's skill folder to one copy under `.agents/skills`, so compare realpaths and never the raw paths. On Windows, compare them case-insensitively.

## Claude Code (`claude`)

1. `claude plugin list --json` has an entry whose `id` is `mattpocock-skills@<marketplace>` with `enabled: true`. Without one, fail: the plugin is not installed.
2. `claude plugin marketplace list --json` gives `<marketplace>`'s `repo` or `url`. It passes if that is `mattpocock/skills`. Otherwise read `.claude-plugin/marketplace.json` under the marketplace's `installLocation`: it passes if the `mattpocock-skills` entry's `source` points at `github.com/mattpocock/skills` (Anthropic's `claude-plugins-official` does this). Anything else fails, naming the marketplace and the source it gives.
3. The resolved folders are the `tdd` and `code-review` folders listed in `skills` in `<installPath>/.claude-plugin/plugin.json`, taken from the plugin entry. If `plugin.json` lists no skills, search for `tdd/SKILL.md` and `code-review/SKILL.md` under `<installPath>/skills`.

Workers call them as `mattpocock-skills:tdd` and `mattpocock-skills:code-review`, so the built-in `code-review` cannot shadow them.

## OpenCode (`opencode`)

OpenCode does not read Claude Code plugin skills, so a plugin-only install fails here. The fix is `npx skills add mattpocock/skills`.

1. Run `opencode debug skill --print-logs --log-level WARN 2> <log-file>`. Stdout is a JSON array with one entry per skill: `name`, `location` (the `SKILL.md` path) and the skill's full `content`. Read only `name` and `location`, because the content runs long.
2. `tdd` and `code-review` each have an entry. If one is missing, fail and give the fix above.
3. For each of them, the log file may hold `duplicate skill name` lines with `name=<skill>`. Every `existing` and `duplicate` path on those lines must have the same realpath as the listed `location`. Otherwise fail, naming both paths: OpenCode may load either copy.
4. Take the realpath of the folder holding `location`:
   - `<repo>/.agents/skills/<skill>`, and the repo's `skills-lock.json` records `<skill>` with `source` `mattpocock/skills`: pass.
   - `~/.agents/skills/<skill>`, and `~/.agents/.skill-lock.json` records `<skill>` with `source` `mattpocock/skills`: pass.
   - A lock file records `<skill>` with another source: fail, naming that source.
   - No lock file records it (a `git clone`, say): warn, and run the content check on `location`.

## Any other harness

This skill has no tested check for it. Find where the harness loads `tdd` and `code-review` from (its docs say where it looks; `~/.agents/skills` and `<repo>/.agents/skills` are common), run the content check on those files, and warn.

## Content check

A fallback, and so a warning at best:

- `tdd/SKILL.md` has the H1 `# Test-Driven Development`;
- `code-review/SKILL.md` mentions `/setup-matt-pocock-skills`.

If either does not match, fail and name the file. If both match, show the user the paths and wait for them to confirm before going on.
