#!/usr/bin/env bash
# Checks a finished release test run in the sandbox from GitHub and Orca state.
#
#   verify.sh <owner/repo> [options] [tickets…]
#   verify.sh <owner/repo> [options] --stopped
#
# Tickets are the issue numbers the run shipped, in the order they must merge
# (default: 1 3 2 4). --stopped checks a run that had to stop before its first
# ticket: no worktree and no PR. Options:
#
#   --since <time>      the run started at this UTC time (default: the last
#                       force-push to main, which is the last reset)
#   --log <file>        a file of the coordinator's output, for the --expect
#                       options after it (repeatable)
#   --expect <regex>    the last --log file matches this extended regex,
#                       case-insensitive (repeatable)
#
# Exits non-zero on the first failed check and names it.
set -eEuo pipefail

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

usage() {
  echo "usage: verify.sh <owner/repo> [--since <time>] [--log <file> [--expect <regex>]…]… [tickets…]" >&2
  echo "       verify.sh <owner/repo> [--since <time>] [--log <file> [--expect <regex>]…]… --stopped" >&2
  exit 1
}

[ $# -ge 1 ] || usage
repo=$1
shift

since='' log='' stopped=false
expect_logs=() expects=() tickets=()
while [ $# -gt 0 ]; do
  case $1 in
    --since) [ $# -ge 2 ] || usage; since=$2; shift 2 ;;
    --log) [ $# -ge 2 ] || usage; log=$2; shift 2 ;;
    --expect) [ $# -ge 2 ] && [ -n "$log" ] || usage; expect_logs+=("$log"); expects+=("$2"); shift 2 ;;
    --stopped) stopped=true; shift ;;
    [0-9]*) tickets+=("$1"); shift ;;
    *) usage ;;
  esac
done
[ ${#tickets[@]} -gt 0 ] || tickets=(1 3 2 4)

ok() { echo "ok    $*"; }
fail() {
  echo "FAIL  $*" >&2
  exit 1
}
# A gh, orca or node call that fails ends the run too, named like a check.
trap 'echo "FAIL  command failed: $BASH_COMMAND" >&2' ERR

# The run's start, and main's tip at that moment: the chain of merge commits
# starts there.
if [ -z "$since" ]; then
  since=$(gh api "repos/$repo/activity?ref=refs/heads/main&activity_type=force_push&per_page=1" \
    --jq '.[0].timestamp // empty')
  [ -n "$since" ] || fail "no force-push to main: reset the sandbox before the run"
fi
base=$(gh api "repos/$repo/activity?ref=refs/heads/main&per_page=100" \
  --jq "[.[] | select(.timestamp <= \"$since\")][0].after // empty")
[ -n "$base" ] || fail "can't tell where main stood at $since"
echo "Run since $since, main at ${base:0:7}"

check_log() {
  local i file regex
  for i in ${expects[@]+"${!expects[@]}"}; do
    file=${expect_logs[$i]} regex=${expects[$i]}
    [ -s "$file" ] || fail "coordinator output: $file is missing or empty"
    grep -Eiq -- "$regex" "$file" || fail "coordinator output: nothing matches /$regex/ in $file"
    ok "coordinator output matches /$regex/ ($(basename "$file"))"
  done
}

check_orca() {
  local repo_json repo_id left runs workers
  repo_json=$(orca_repo "$repo")
  [ "$repo_json" != null ] || fail "Orca: $repo isn't added to Orca as a repo"
  repo_id=$(echo "$repo_json" | js 'd.id')

  left=$(orca_worktrees "$repo_id")
  [ -z "$left" ] || fail "Orca: worktrees left for the sandbox: $(echo "$left" | tr '\n' ' ')"
  ok "Orca: no worktree left for the sandbox"

  # Only the Runs this run created: an earlier run's leftovers aren't its fault.
  runs=$(orca orchestration run-list --limit 50 --json | js \
    'd.result.runs.filter((r) => r.created_at >= a[1]).map((r) => r.id).join(" ")' "$since")
  workers=$(orca orchestration worker-list --terminal-state reclaimable --limit 100 --json | js \
    'd.result.workers.filter((w) => a[2].split(" ").includes(w.runId) && (w.resource?.worktreeId ?? "").startsWith(a[1] + "::")).map((w) => w.dispatchId)' \
    "$repo_id" "$runs")
  [ -z "$workers" ] || fail "Orca: reclaimable workers left in the sandbox: $(echo "$workers" | tr '\n' ' ')"
  ok "Orca: no reclaimable worker in the sandbox"
}

# The run's PRs, filtered here: the index behind --search lags new PRs.
prs_json=$(gh pr list --repo "$repo" --state all --limit 100 \
  --json number,title,body,state,createdAt,mergedAt,mergeCommit,headRefName,closingIssuesReferences \
  | js 'JSON.stringify(d.filter((p) => p.createdAt >= a[1]))' "$since")

if $stopped; then
  check_log
  count=$(echo "$prs_json" | js 'd.length')
  [ "$count" = 0 ] || fail "no PR: the run opened $count PR(s): $(echo "$prs_json" | js 'd.map((p) => "#" + p.number).join(" ")')"
  ok "no PR opened"
  check_orca
  echo "PASS  the run stopped before its first ticket"
  exit 0
fi

# Each ticket's merged PR, in merge order.
prs=()
for n in "${tickets[@]}"; do
  pr=$(echo "$prs_json" | js \
    'd.filter((p) => p.state === "MERGED" && p.closingIssuesReferences.some((i) => i.number === +a[1])).map((p) => p.number)' \
    "$n")
  [ -n "$pr" ] || fail "#$n: no merged PR closes it"
  [ "$(echo "$pr" | wc -l)" -eq 1 ] || fail "#$n: several merged PRs close it: $(echo "$pr" | tr '\n' ' ')"
  prs+=("$pr")
done

order=$(echo "$prs_json" | js \
  'd.filter((p) => p.state === "MERGED").sort((x, y) => x.mergedAt.localeCompare(y.mergedAt)).flatMap((p) => p.closingIssuesReferences.map((i) => i.number)).filter((n) => a.slice(1).includes(String(n)))' \
  "${tickets[@]}" | tr '\n' ' ')
order=${order% }
expected="#${tickets[*]}" got="#$order"
[ "$order" = "${tickets[*]}" ] || fail "merge order: expected ${expected// / #}, got ${got// / #}"
ok "merge order: ${expected// / #}"

parent=$base
for i in "${!tickets[@]}"; do
  n=${tickets[$i]} pr=${prs[$i]}
  pr_json=$(echo "$prs_json" | js 'JSON.stringify(d.find((p) => p.number === +a[1]))' "$pr")

  merge=$(echo "$pr_json" | js 'd.mergeCommit.oid')
  parents=$(gh api "repos/$repo/commits/$merge" --jq '[.parents[].sha] | join(" ")')
  [ "$parents" = "$parent" ] \
    || fail "#$n: PR #$pr isn't one squash commit on top of the previous merge (${merge:0:7} has parents ${parents:-none}, expected ${parent:0:7})"
  ok "#$n: PR #$pr squash-merged as ${merge:0:7}"
  parent=$merge

  issue_title=$(gh issue view "$n" --repo "$repo" --json title --jq .title)
  pr_title=$(echo "$pr_json" | js 'd.title')
  [ "$pr_title" = "$issue_title" ] || fail "#$n: PR #$pr title is \"$pr_title\", the issue's is \"$issue_title\""
  ok "#$n: PR title is the issue title"

  echo "$pr_json" | js 'new RegExp(`Closes #${a[1]}$`).test(d.body.trimEnd())' "$n" | grep -q true \
    || fail "#$n: PR #$pr body doesn't end with \"Closes #$n\""
  ok "#$n: PR body ends with Closes #$n"

  echo "$pr_json" | js '/summary/i.test(d.body) && /testing/i.test(d.body)' | grep -q true \
    || fail "#$n: PR #$pr body lacks a Summary or a Testing section"
  ok "#$n: PR body has Summary and Testing"

  state=$(gh issue view "$n" --repo "$repo" --json state --jq .state)
  [ "$state" = CLOSED ] || fail "#$n: the issue is $state"
  ok "#$n: issue closed"

  branch=$(echo "$pr_json" | js 'd.headRefName')
  [[ "$branch" =~ (^|/)$n- ]] || fail "#$n: branch $branch doesn't follow Branch naming (<n>-<title>)"
  ok "#$n: branch $branch follows Branch naming"
  left=$(gh api "repos/$repo/git/matching-refs/heads/$branch" --jq "map(select(.ref == \"refs/heads/$branch\")) | length")
  [ "$left" = 0 ] || fail "#$n: remote branch $branch still exists"
  ok "#$n: remote branch $branch deleted"
done

# A PR whose changelog check went red on an earlier commit and green on its head.
red_then_green=''
for pr in "${prs[@]}"; do
  commits=$(gh pr view "$pr" --repo "$repo" --json commits --jq '.commits[].oid')
  head=$(echo "$commits" | tail -n 1)
  red=false
  for sha in $commits; do
    conclusions=$(gh api "repos/$repo/commits/$sha/check-runs" \
      --jq '[.check_runs[] | select(.name == "changelog") | .conclusion] | join(" ")')
    if [ "$sha" = "$head" ]; then
      $red && [[ " $conclusions " == *" success "* ]] && red_then_green=$pr
    elif [[ " $conclusions " == *" failure "* ]]; then
      red=true
    fi
  done
  [ -z "$red_then_green" ] || break
done
[ -n "$red_then_green" ] || fail "no PR's changelog check failed and then passed: the fix worker for CI never ran"
ok "PR #$red_then_green: changelog check failed, then passed"

check_orca
check_log
echo "PASS  ${expected// / #} shipped"
