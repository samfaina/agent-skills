# Helpers that run.sh and verify.sh share. Source it, don't run it.

# Evaluates a JavaScript expression over the JSON on stdin, as `d`, with the
# remaining arguments as `a`. Arrays print one item per line. The script stays
# on one line: Windows shims for node, such as Volta's, cut an argument at its
# first newline. MSYS_NO_PATHCONV stops Git Bash rewriting a /regex/ as a path.
js() {
  local script='let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => { const d = JSON.parse(s); const a = process.argv.slice(1); const r = eval(a[0]); if (r !== undefined && r !== null) console.log(Array.isArray(r) ? r.join("\n") : String(r)); });'
  MSYS_NO_PATHCONV=1 node -e "$script" -- "$@"
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
