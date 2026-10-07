#!/usr/bin/env bash
# Runs one automated case of TESTING.md in the sandbox, unattended.
#
#   run.sh <owner/repo> <run> [--coordinator claude|opencode]
#
# Resets the sandbox, starts the coordinator non-interactively in an Orca
# terminal in the sandbox's clone, waits for it, and ends with verify.sh's
# result. Runs: 3.2 3.3 3.4 no-shipping-md no-matt-skills two-tdd blocked
# setup-noop outside-orca. The coordinator's output goes to testing/logs/.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

usage() {
  echo "usage: run.sh <owner/repo> <run> [--coordinator claude|opencode]" >&2
  echo "runs: 3.2 3.3 3.4 no-shipping-md no-matt-skills two-tdd blocked setup-noop outside-orca" >&2
  exit 2
}

[ $# -ge 2 ] || usage
repo=$1
run=$2
shift 2
coordinator_override=''
while [ $# -gt 0 ]; do
  case $1 in
    --coordinator) [ $# -ge 2 ] || usage; coordinator_override=$2; shift 2 ;;
    *) usage ;;
  esac
done

windows=false
case $(uname -s) in MINGW* | MSYS* | CYGWIN*) windows=true ;; esac

# What each run resets, starts and checks. `tickets` is the merge order a loop
# run must reach; `stopped` runs must stop before their first ticket instead.
# `said` patterns must match what the coordinator wrote, `ran` patterns the
# commands it ran.
reset_args=() coordinator=claude skill=ship-tickets args=auto
tickets=(1 3 2 4) stopped=false said=() ran=() in_orca=true unset_shell=false
case $run in
  3.2) coordinator=opencode ;;
  3.3)
    reset_args=(--workers 'implement `claude`, PR `opencode`, fix `opencode`')
    ran=('--agent claude' '--agent opencode')
    ;;
  3.4)
    $windows || { echo "Run 3.4 needs Windows: OpenCode runs pwsh only there." >&2; exit 2; }
    coordinator=opencode unset_shell=true args='auto 3 2' tickets=(3 2)
    ran=('orca\.exe' "spec = @'")
    ;;
  no-shipping-md) reset_args=(--no-shipping-md) stopped=true said=('setup-ship-tickets') ;;
  no-matt-skills) stopped=true said=('mattpocock-skills') ;;
  two-tdd)
    reset_args=(--workers '`opencode` (all roles)') stopped=true
    said=('\.claude[\/]+skills[\/]+tdd')
    ;;
  blocked) args='auto 2' stopped=true said=('#3' 'block') ;;
  setup-noop)
    skill=setup-ship-tickets args='' stopped=true
    said=('up to date|up-to-date|no change|nothing to change')
    ;;
  outside-orca)
    skill=setup-ship-tickets args='' stopped=true in_orca=false
    said=('ORCA_TERMINAL_HANDLE[^=]*(not|isn.t|unset|missing)')
    ;;
  *) usage ;;
esac
if [ -n "$coordinator_override" ]; then
  case $coordinator_override in claude | opencode) ;; *) usage ;; esac
  [ "$run" != 3.4 ] || { echo "Run 3.4 is OpenCode only." >&2; exit 2; }
  coordinator=$coordinator_override
fi

work=$(mktemp -d)
cleanups=()
cleanup() {
  local c
  for c in ${cleanups[@]+"${cleanups[@]}"}; do eval "$c" || true; done
  rm -rf "$work"
}
trap cleanup EXIT

# Evaluates a JavaScript expression over the JSON on stdin, as `d`, with the
# remaining arguments as `a`. Arrays print one item per line. The script stays
# on one line: Windows shims for node, such as Volta's, cut an argument at its
# first newline. MSYS_NO_PATHCONV stops Git Bash rewriting a /regex/ as a path.
js() {
  local script='let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => { const d = JSON.parse(s); const a = process.argv.slice(1); const r = eval(a[0]); if (r !== undefined && r !== null) console.log(Array.isArray(r) ? r.join("\n") : String(r)); });'
  MSYS_NO_PATHCONV=1 node -e "$script" -- "$@"
}

repo_json=$(orca repo list --json | js \
  'JSON.stringify(d.result.repos.find((r) => r.gitRemoteIdentity?.canonicalKey?.toLowerCase() === `github.com/${a[1]}`.toLowerCase()) ?? null)' \
  "$repo")
[ "$repo_json" != null ] || { echo "$repo isn't added to Orca. Clone it and run: orca repo add --path <clone>" >&2; exit 1; }
repo_id=$(echo "$repo_json" | js 'd.id')
clone=$(echo "$repo_json" | js 'd.path.replace(/\\/g, "/")')

echo "== Run $run: $coordinator coordinator, /$skill${args:+ $args}"
# Drop the reset's closing advice: this script follows it below.
bash "$here/sandbox.sh" reset "$repo" ${reset_args[@]+"${reset_args[@]}"} | sed '/^Done/,$d'

echo "Removing the sandbox's Orca worktrees"
for id in $(orca worktree list --repo "id:$repo_id" --json | js \
  'd.result.worktrees.filter((w) => !w.isMainWorktree).map((w) => w.id)'); do
  orca worktree rm --worktree "id:$id" --force --json >/dev/null
  echo "  removed $id"
done

echo "Resetting the clone at $clone"
git -C "$clone" fetch --quiet origin --prune
git -C "$clone" checkout --quiet main
git -C "$clone" reset --quiet --hard origin/main
git -C "$clone" worktree prune
for branch in $(git -C "$clone" branch --format='%(refname:short)'); do
  [ "$branch" = main ] || git -C "$clone" branch --quiet -D "$branch"
done

case $run in
  no-matt-skills)
    plugin=$(claude plugin list --json | js 'd.filter((p) => p.id.startsWith("mattpocock-skills@") && p.enabled).map((p) => p.id)')
    [ -n "$plugin" ] || { echo "mattpocock-skills isn't installed and enabled in Claude Code." >&2; exit 1; }
    claude plugin disable "$plugin" >/dev/null
    cleanups+=("claude plugin enable '$plugin' >/dev/null && echo 'Re-enabled $plugin'")
    echo "Disabled $plugin"
    ;;
  two-tdd)
    copy=$HOME/.claude/skills/tdd
    [ ! -e "$copy" ] || { echo "$copy already exists. Move it away first." >&2; exit 1; }
    tdd=$(opencode debug skill 2>/dev/null | js 'd.filter((s) => s.name === "tdd").map((s) => s.location)' | head -n 1)
    [ -n "$tdd" ] || { echo "OpenCode lists no tdd skill." >&2; exit 1; }
    mkdir -p "$copy"
    cp "$tdd" "$copy/SKILL.md"
    cleanups+=("rm -rf '$copy' && echo 'Deleted $copy'")
    opencode debug skill --print-logs --log-level WARN 2>&1 >/dev/null | grep -q 'duplicate skill name.*name=tdd' \
      || { echo "OpenCode doesn't report $copy as a duplicate tdd." >&2; exit 1; }
    echo "Copied tdd to $copy"
    ;;
esac

# Forces one PR red, so a fix worker runs: once the first ticket's PR is open,
# push a commit that drops its CHANGELOG.md line. The implement worker's code
# review usually adds that line, so CI rarely goes red by itself.
break_changelog() {
  local n=$1 found pr branch
  while :; do
    [ ! -e "$status" ] || return 0
    found=$(gh pr list --repo "$repo" --state open --search "created:>=$since" \
      --json number,headRefName,closingIssuesReferences \
      --jq "map(select(.closingIssuesReferences | any(.number == $n))) | .[0] // empty | \"\(.number) \(.headRefName)\"" \
      2>/dev/null || true)
    [ -z "$found" ] || break
    sleep 5
  done
  read -r pr branch <<<"$found"
  git clone --quiet --branch "$branch" "https://github.com/$repo.git" "$work/red"
  (
    cd "$work/red"
    git show "$(git merge-base HEAD origin/main):CHANGELOG.md" > CHANGELOG.md
    if git diff --quiet; then
      echo "[run.sh] PR #$pr adds no CHANGELOG.md line, so its changelog check goes red by itself"
    else
      git commit --quiet -am "Drop the CHANGELOG.md line to test the fix worker"
      git push --quiet origin HEAD
      echo "[run.sh] dropped the CHANGELOG.md line from PR #$pr"
    fi
  )
}

stamp=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$here/logs"
log=$here/logs/$run-$stamp.log
status=$here/logs/$run-$stamp.status
since=$(date -u +%FT%TZ)

case $coordinator in
  claude)
    command=(claude -p "/$skill${args:+ $args}" --dangerously-skip-permissions --output-format stream-json --verbose) ;;
  opencode)
    command=(opencode run --command "$skill" --auto --format json)
    [ -z "$args" ] || command+=($args)
    ;;
esac

runner=$work/runner.sh
{
  echo 'export MSYS_NO_PATHCONV=1'
  $unset_shell && echo 'unset SHELL'
  $in_orca || echo 'for v in $(env | grep -o "^ORCA_[A-Z_]*"); do unset "$v"; done'
  echo "cd $(printf %q "$clone")"
  echo "$(printf '%q ' "${command[@]}") > $(printf %q "$log") 2>&1"
  echo "echo \$? > $(printf %q "$status")"
} > "$runner"

breaker=''
if ! $stopped; then
  break_changelog "${tickets[0]}" &
  breaker=$!
  cleanups+=("kill $breaker 2>/dev/null")
fi

echo "Starting the coordinator. Output: $log"
if $in_orca; then
  shell_args=()
  $windows && shell_args=(--shell git-bash)
  handle=$(orca terminal create --worktree "path:$clone" ${shell_args[@]+"${shell_args[@]}"} --title "release test $run" \
    --command "bash $(printf %q "$runner"); exit" --json | js 'd.result.terminal.handle')
  # Loop runs take many minutes: wait in 10-minute chunks, for up to 3 hours.
  for _ in $(seq 18); do
    [ ! -e "$status" ] || break
    orca terminal wait --terminal "$handle" --for exit --timeout-ms 600000 --json >/dev/null 2>&1 || true
  done
else
  bash "$runner"
fi

[ -e "$status" ] || { echo "FAIL  the coordinator didn't finish. Output: $log" >&2; exit 1; }
[ -z "$breaker" ] || wait "$breaker" || true
echo "Coordinator exited with $(cat "$status")"

# Splits the coordinator's JSON event log, from Claude Code or OpenCode, into
# what it wrote (said) or the commands it ran (ran).
transcript() {
  local script='let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => { const want = process.argv[1], out = []; for (const line of s.split("\n")) { let e; try { e = JSON.parse(line); } catch { continue; } if (e.type === "assistant") for (const c of e.message.content) { if (want === "said" && c.type === "text") out.push(c.text); if (want === "ran" && c.type === "tool_use" && c.input.command) out.push(c.input.command); } if (want === "said" && e.type === "text") out.push(e.part.text); if (want === "ran" && e.type === "tool_use" && e.part?.state?.input?.command) out.push(e.part.state.input.command); } console.log(out.join("\n")); });'
  MSYS_NO_PATHCONV=1 node -e "$script" -- "$1" < "$log"
}
transcript said > "${log%.log}.said.txt"
transcript ran > "${log%.log}.ran.txt"

verify_args=(--since "$since" --log "${log%.log}.said.txt")
for regex in ${said[@]+"${said[@]}"}; do verify_args+=(--expect "$regex"); done
verify_args+=(--log "${log%.log}.ran.txt")
for regex in ${ran[@]+"${ran[@]}"}; do verify_args+=(--expect "$regex"); done
if $stopped; then verify_args+=(--stopped); else verify_args+=("${tickets[@]}"); fi
bash "$here/verify.sh" "$repo" "${verify_args[@]}"
