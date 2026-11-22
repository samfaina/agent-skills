# Helpers for the release test scripts. Source it, don't run it.

# Evaluates a JavaScript expression over the JSON on stdin, as `d`, with the
# remaining arguments as `a`. Arrays print one item per line. The script stays
# on one line: Windows shims for node, such as Volta's, cut an argument at its
# first newline. MSYS_NO_PATHCONV stops Git Bash rewriting a /regex/ as a path.
js() {
  local script='let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => { const d = JSON.parse(s); const a = process.argv.slice(1); const r = eval(a[0]); if (r !== undefined && r !== null) console.log(Array.isArray(r) ? r.join("\n") : String(r)); });'
  MSYS_NO_PATHCONV=1 node -e "$script" -- "$@"
}

# Splits the coordinator's JSON event log on stdin, from Claude Code or
# OpenCode, into what it wrote (said), the commands it ran (ran), or the text
# of its last message with text (report). A message is one Claude Code message
# id, whose blocks can come in several events, or one OpenCode step, from its
# step_start event on. A Claude Code subagent's messages count as said but
# never as the report.
transcript() {
  local script='let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => { const said = [], ran = []; let id = null, report = []; const addToReport = (m, t) => { if (m !== id) { id = m; report = []; } report.push(t); }; for (const line of s.split("\n")) { let e; try { e = JSON.parse(line); } catch { continue; } if (e.type === "assistant") for (const c of e.message.content) { if (c.type === "text") { said.push(c.text); if (!e.parent_tool_use_id) addToReport(e.message.id, c.text); } if (c.type === "tool_use" && c.input.command) ran.push(c.name + ": " + c.input.command); } if (e.type === "step_start") id = null; if (e.type === "text") { said.push(e.part.text); addToReport(e.part.messageID, e.part.text); } if (e.type === "tool_use" && e.part?.state?.input?.command) ran.push(e.part.state.input.command); } console.log({ said, ran, report }[process.argv[1]].join("\n")); });'
  MSYS_NO_PATHCONV=1 node -e "$script" -- "$1"
}

# Prints each of the PR numbers after <file> that the file doesn't link, as
# /pull/<n> not followed by a digit, one per line.
unlinked_prs() {
  local file=$1 pr
  shift
  for pr in "$@"; do
    grep -Eq -- "/pull/$pr([^0-9]|$)" "$file" || echo "$pr"
  done
}

# Succeeds when <file> gives <command> exactly, not followed by more of a
# branch name, such as a cleanup the harness refused for the user to run. A
# branch name never ends in a dot, so a dot that ends the text or comes before
# anything but a name character ends a sentence.
gives_command() {
  C=$2 awk '
    { s = $0; while ((i = index(s, ENVIRON["C"])) > 0) {
        s = substr(s, i + length(ENVIRON["C"]))
        if (s !~ /^([A-Za-z0-9_\/-]|\.[A-Za-z0-9_\/-])/) { found = 1; exit }
    } }
    END { exit !found }' "$1"
}

# Prints the number of each issue created at or after <since>, one per line,
# from the JSON of `gh issue list --json number,createdAt` on stdin, leaving
# out the issue numbers given as the arguments after <since>.
issues_opened() {
  js 'd.filter((i) => i.createdAt >= a[1] && !a.slice(2).includes(String(i.number))).map((i) => i.number)' "$@"
}

# Prints the number of each issue commented on at or after <since>, once,
# from the JSON of `gh api repos/<repo>/issues/comments --paginate
# --slurp` on stdin: an array of pages, or one array. Comments on PRs, which
# the same API lists, don't count, nor does the loop's `Shipped in #<pr>` on a
# ticket its merge left open.
comments_posted() {
  js 'd.flat().filter((c) => c.created_at >= a[1] && c.html_url.includes("/issues/") && !/^Shipped in #\d+$/.test(c.body.trim())).map((c) => c.issue_url.split("/").pop()).filter((n, i, all) => all.indexOf(n) === i)' "$@"
}

# Prints an extended regex that matches any of the versions given as
# arguments, such as 0.9.0, but not inside a longer version: neither 10.9.0
# nor 0.9.0.1 matches, and a period ending a sentence does.
version_regex() {
  local v alternatives=''
  for v in "$@"; do alternatives+="${alternatives:+|}${v//./\\.}"; done
  printf '(^|[^0-9.])(%s)(\\.?([^0-9.]|$))\n' "$alternatives"
}

# Prints a version_regex of each enabled agent-skills install's version, from
# the JSON of `claude plugin list --json` on stdin. Prints nothing when none
# is enabled.
plugin_version_regex() {
  local versions
  versions=$(js '[...new Set(d.filter((p) => p.id.startsWith("agent-skills@") && p.enabled).map((p) => p.version))]')
  [ -z "$versions" ] || version_regex $versions
}

# Prints the version in .claude-plugin/plugin.json on main of agent-skills:
# the latest release, which a plugin update installs.
latest_release() {
  gh api -H 'Accept: application/vnd.github.raw+json' \
    repos/samfaina/agent-skills/contents/.claude-plugin/plugin.json --jq .version
}

# Prints the id of each failed Base CI run, one per line, from the JSON of
# `gh run list --commit <sha> --event push --json
# databaseId,workflowName,conclusion,status,createdAt` on stdin: a run that
# failed, timed out or couldn't start. Only the latest run of each workflow
# counts: a commit pushed again, as a sandbox reset pushes `baseline`, gets a
# new run, and its result replaces the one before.
failed_runs() {
  js 'Object.values(d.reduce((latest, r) => { const l = latest[r.workflowName]; if (!l || r.createdAt > l.createdAt) latest[r.workflowName] = r; return latest; }, {})).filter((r) => ["failure", "timed_out", "startup_failure"].includes(r.conclusion)).map((r) => r.databaseId)'
}

# Prints <path> as the coordinator's harness takes it: a drive-letter path
# on Windows, where Git Bash's /c/... means nothing to claude.exe.
native_path() {
  case $(uname -s) in MINGW* | MSYS* | CYGWIN*) cygpath -m "$1" ;; *) echo "$1" ;; esac
}

# The older release the old-install runs load: the checkout's skills as the
# plugin agent-skills-old 0.0.1, under a name of its own so the installed
# agent-skills keeps its skills, from a marketplace in a local folder.
old_plugin_id=agent-skills-old@ship-tickets-test

# Writes the older release to the new folder <folder>, which is both the
# plugin and its marketplace, from the checkout <checkout>.
old_plugin_folder() {
  local checkout=$1 folder=$2
  mkdir -p "$folder/.claude-plugin"
  cp -R "$checkout/skills" "$folder/"
  js 'd.name = "agent-skills-old"; d.version = "0.0.1"; JSON.stringify(d, null, 2)' \
    < "$checkout/.claude-plugin/plugin.json" > "$folder/.claude-plugin/plugin.json"
  js 'd.name = a[1]; d.plugins[0].name = "agent-skills-old"; JSON.stringify(d, null, 2)' "${old_plugin_id#*@}" \
    < "$checkout/.claude-plugin/marketplace.json" > "$folder/.claude-plugin/marketplace.json"
}

# Installs the older release from <folder> at local scope in the clone
# <clone>, as a user's repo pins an install. Claude Code then loads its skills
# from <folder>, so keep the folder until old_plugin_remove. The clone's
# .claude/settings.local.json, which the install writes, is kept beside the
# folder to put back.
old_plugin_install() {
  local clone=$1 folder=$2 settings=$1/.claude/settings.local.json
  if [ -e "$settings" ]; then cp "$settings" "$folder.settings.local.json"; fi
  (
    cd "$clone"
    claude plugin marketplace add "$(native_path "$folder")" --scope local >/dev/null
    claude plugin install "$old_plugin_id" --scope local >/dev/null
  )
}

# Undoes old_plugin_install with the same <clone> and <folder>: uninstalls
# the plugin, removes its marketplace and its copy in Claude Code's plugin
# cache, and puts back the clone's .claude/settings.local.json as it was,
# or deletes it.
old_plugin_remove() {
  local clone=$1 folder=$2 settings=$1/.claude/settings.local.json
  (
    cd "$clone"
    claude plugin uninstall "$old_plugin_id" --scope local >/dev/null 2>&1 || true
    claude plugin marketplace remove "${old_plugin_id#*@}" >/dev/null 2>&1 || true
  )
  rm -rf "$HOME/.claude/plugins/cache/${old_plugin_id#*@}"
  if [ -e "$folder.settings.local.json" ]; then
    mv "$folder.settings.local.json" "$settings"
  else
    rm -f "$settings"
  fi
}

# Prints the Orca repo entry of <owner/repo> as JSON, or `null` when the
# sandbox isn't added to Orca.
orca_repo() {
  orca repo list --json | js \
    'JSON.stringify(d.result.repos.find((r) => r.gitRemoteIdentity?.canonicalKey?.toLowerCase() === `github.com/${a[1]}`.toLowerCase()) ?? null)' \
    "$1"
}

# Prints the ids of the Orca repo's worktrees other than its main checkout,
# one per line. An id holds the worktree's path.
orca_worktrees() {
  orca worktree list --repo "id:$1" --json | js \
    'd.result.worktrees.filter((w) => !w.isMainWorktree).map((w) => w.id)'
}
