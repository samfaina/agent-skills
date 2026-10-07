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
. "$here/lib.sh"

usage() {
  echo "usage: run.sh <owner/repo> <run> [--coordinator claude|opencode]" >&2
  echo "runs: 3.2 3.3 3.4 no-shipping-md no-matt-skills two-tdd blocked setup-noop outside-orca" >&2
  exit 1
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

work=$(mktemp -d)
cleanups=()
cleanup() {
  local c
  for c in ${cleanups[@]+"${cleanups[@]}"}; do eval "$c" || true; done
  rm -rf "$work"
}
trap cleanup EXIT

# Breaks Claude Code's copy of Matt Pocock's skills until the run ends.
disable_matt_skills() {
  local plugin
  plugin=$(claude plugin list --json | js 'd.filter((p) => p.id.startsWith("mattpocock-skills@") && p.enabled).map((p) => p.id)')
  [ -n "$plugin" ] || { echo "mattpocock-skills isn't installed and enabled in Claude Code." >&2; exit 1; }
  claude plugin disable "$plugin" >/dev/null
  cleanups+=("claude plugin enable $(printf %q "$plugin") >/dev/null && echo $(printf %q "Re-enabled $plugin")")
  echo "Disabled $plugin"
}

# Puts a second tdd skill where OpenCode also loads skills from, until the run
# ends, and expects the coordinator to name both copies.
copy_tdd() {
  local copy=$HOME/.claude/skills/tdd tdd warnings root
  [ ! -e "$copy" ] || { echo "$copy already exists. Move it away first." >&2; exit 1; }
  tdd=$(opencode debug skill 2>/dev/null | js 'd.filter((s) => s.name === "tdd").map((s) => s.location)' | head -n 1)
  [ -n "$tdd" ] || { echo "OpenCode lists no tdd skill." >&2; exit 1; }
  mkdir -p "$copy"
  cp "$tdd" "$copy/SKILL.md"
  cleanups+=("rm -rf $(printf %q "$copy") && echo $(printf %q "Deleted $copy")")
  warnings=$(opencode debug skill --print-logs --log-level WARN 2>&1 >/dev/null || true)
  grep -q 'duplicate skill name.*name=tdd' <<<"$warnings" \
    || { echo "OpenCode doesn't report $copy as a duplicate tdd." >&2; exit 1; }
  echo "Copied tdd to $copy"

  # The original sits in <root>/skills/tdd, such as ~/.agents/skills/tdd.
  tdd=${tdd//\\//}
  root=$(basename "$(dirname "$(dirname "$(dirname "$tdd")")")")
  said+=("${root//./\\.}[\\/]+skills[\\/]+tdd")
}

# What each run resets, starts and checks. `tickets` is the merge order a loop
# run must reach; `stopped` runs must stop before their first ticket instead.
# `said` patterns must match what the coordinator wrote, `ran` patterns the
# commands it ran. `prepare` breaks what the run tests, after the reset.
reset_args=() coordinator=claude skill=ship-tickets skill_args=auto prepare=''
tickets=(1 3 2 4) stopped=false in_orca=true unset_shell=false
said=('merged') ran=('run-create')
case $run in
  3.2) coordinator=opencode ran+=('--agent claude') ;;
  3.3)
    reset_args=(--workers 'implement `claude`, PR `opencode`, fix `opencode`')
    ran+=('--agent claude' '--agent opencode')
    ;;
  3.4)
    $windows || { echo "Run 3.4 needs Windows: OpenCode runs pwsh only there." >&2; exit 1; }
    coordinator=opencode unset_shell=true skill_args='auto 3 2' tickets=(3 2)
    # pwsh finds orca.exe before orca.cmd, so a bare `orca` there runs orca.exe.
    ran+=('--agent claude' 'Get-Command orca' "@'")
    ;;
  no-shipping-md) reset_args=(--no-shipping-md) stopped=true said=('setup-ship-tickets') ran=() ;;
  no-matt-skills) prepare=disable_matt_skills stopped=true said=('mattpocock-skills') ran=() ;;
  two-tdd)
    reset_args=(--workers '`opencode` (all roles)') prepare=copy_tdd stopped=true
    said=('\.claude[\/]+skills[\/]+tdd') ran=()
    ;;
  blocked)
    skill_args='auto 2' stopped=true ran=()
    said=('#3[^.]*(block|hold|open)|(block|hold)[^.]*#3')
    ;;
  setup-noop)
    skill=setup-ship-tickets skill_args='' stopped=true ran=()
    said=('up to date|up-to-date|no change|nothing to change')
    ;;
  outside-orca)
    skill=setup-ship-tickets skill_args='' stopped=true in_orca=false ran=()
    said=('ORCA_TERMINAL_HANDLE[^=]*(not|isn.t|unset|missing)')
    ;;
  *) usage ;;
esac
if [ -n "$coordinator_override" ]; then
  case $coordinator_override in claude | opencode) ;; *) usage ;; esac
  [ "$run" != 3.4 ] || { echo "Run 3.4 is OpenCode only." >&2; exit 1; }
  coordinator=$coordinator_override
fi

repo_json=$(orca_repo "$repo")
[ "$repo_json" != null ] || { echo "$repo isn't added to Orca. Clone it and run: orca repo add --path <clone>" >&2; exit 1; }
repo_id=$(echo "$repo_json" | js 'd.id')
clone=$(echo "$repo_json" | js 'd.path.replace(/\\/g, "/")')

echo "== Run $run: $coordinator coordinator, /$skill${skill_args:+ $skill_args}"
# Drop the reset's closing advice: this script follows it below.
bash "$here/sandbox.sh" reset "$repo" ${reset_args[@]+"${reset_args[@]}"} | sed '/^Done/,$d'

echo "Removing the sandbox's Orca worktrees"
for id in $(orca_worktrees "$repo_id"); do
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

[ -z "$prepare" ] || $prepare

# Forces one PR red, so a fix worker runs: once the first ticket's PR is open,
# push a commit that drops its CHANGELOG.md line. The implement worker's code
# review usually adds that line, so CI rarely goes red by itself. The reset
# closed every older PR, so the first open one that closes the ticket is new.
break_changelog() {
  local n=$1 found pr branch
  while :; do
    [ ! -e "$status" ] || return 0
    found=$(gh pr list --repo "$repo" --state open \
      --json number,headRefName,closingIssuesReferences \
      --jq "map(select(.closingIssuesReferences | any(.number == $n))) | .[0] // empty | \"\(.number) \(.headRefName)\"" \
      2>/dev/null || true)
    [ -z "$found" ] || break
    sleep 5
  done
  read -r pr branch <<<"$found"
  git clone --quiet --branch "$branch" "https://github.com/$repo.git" "$work/red" \
    || { echo "[run.sh] couldn't clone $branch to drop its CHANGELOG.md line"; return 0; }
  (
    cd "$work/red"
    git show "$(git merge-base HEAD origin/main):CHANGELOG.md" > CHANGELOG.md
    if git diff --quiet; then
      echo "[run.sh] PR #$pr adds no CHANGELOG.md line, so its changelog check goes red by itself"
    elif git commit --quiet -am "Drop the CHANGELOG.md line to test the fix worker" && git push --quiet origin HEAD; then
      echo "[run.sh] dropped the CHANGELOG.md line from PR #$pr"
    else
      echo "[run.sh] couldn't push to PR #$pr, so its changelog check may stay green"
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
    command=(claude -p "/$skill${skill_args:+ $skill_args}" --dangerously-skip-permissions --output-format stream-json --verbose) ;;
  opencode)
    command=(opencode run --command "$skill" --auto --format json)
    # The arguments are words without spaces, so splitting them is safe.
    [ -z "$skill_args" ] || command+=($skill_args)
    ;;
esac

runner=$work/runner.sh
{
  echo 'export MSYS_NO_PATHCONV=1'
  $unset_shell && echo 'unset SHELL'
  $in_orca || echo 'for v in $(env | grep -o "^ORCA_[A-Z_]*"); do unset "$v"; done'
  echo "cd $(printf %q "$clone") || exit 1"
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
  # Loop runs take many minutes. Wait a minute at a time, for up to 3 hours,
  # and give up on a coordinator whose output stops for 30 minutes: its
  # longest quiet stretch is one 15-minute wait for a worker or for CI.
  size=-1 quiet=0
  for _ in $(seq 180); do
    [ ! -e "$status" ] || break
    exited=$(orca terminal wait --terminal "$handle" --for exit --timeout-ms 60000 --json 2>/dev/null \
      | js 'd.result?.wait?.satisfied === true' 2>/dev/null || true)
    [ "$exited" != true ] || break
    now=$(wc -c < "$log" 2>/dev/null || echo 0)
    if [ "$now" = "$size" ]; then quiet=$((quiet + 1)); else size=$now quiet=0; fi
    if [ "$quiet" -ge 30 ]; then
      orca terminal close --terminal "$handle" --json >/dev/null 2>&1 || true
      echo "FAIL  the coordinator wrote nothing for 30 minutes, so this script closed its terminal. Output: $log" >&2
      exit 1
    fi
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
