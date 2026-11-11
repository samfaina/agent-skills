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
# branch name, such as a cleanup the harness refused for the user to run.
gives_command() {
  C=$2 awk '
    { s = $0; while ((i = index(s, ENVIRON["C"])) > 0) {
        s = substr(s, i + length(ENVIRON["C"]))
        if (s !~ /^[A-Za-z0-9._\/-]/) { found = 1; exit }
    } }
    END { exit !found }' "$1"
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
