#!/usr/bin/env bash
# Tests skills/setup-ship-tickets/merge-hook.sh with a fake gh: no network, no
# GitHub, no Claude Code. Each case pipes a PreToolUse payload to the hook and
# checks its permission decision and the gh commands it ran.
#
#   merge-hook-test.sh
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
hook=$here/../skills/setup-ship-tickets/merge-hook.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin" "$work/project"

# The fake gh answers from the environment and logs every call.
cat > "$work/bin/gh" <<'EOF'
#!/bin/sh
echo "$*" >> "$FAKE_GH_LOG"
case "$1 $2" in
  'repo view')
    echo "cwd=$(pwd) GH_REPO=${GH_REPO:-}" >> "$FAKE_GH_LOG"
    printf '%s\n' "$FAKE_PROJECT_URL"
    ;;
  'pr view')
    count=$(cat "$FAKE_GH_LOG.fails" 2>/dev/null || echo 0)
    if [ "$count" -lt "${FAKE_VIEW_FAILS:-0}" ]; then
      echo $((count + 1)) > "$FAKE_GH_LOG.fails"
      echo 'error connecting to api.github.com "quoted"' >&2
      exit 1
    fi
    printf '%s\n' "$FAKE_PR_VIEW"
    ;;
esac
EOF
chmod +x "$work/bin/gh"

project_url=https://github.com/o/r
own="false $project_url/pull/5"
fork="true $project_url/pull/5"
elsewhere="false https://github.com/other/repo/pull/5"

passed=0 failed=0

# Prints the decision in the hook's stdout: allow, ask or none. Anything else
# on stdout fails the case.
decision_of() {
  case $1 in
    '') echo none ;;
    *'"permissionDecision":"allow"'*) echo allow ;;
    *'"permissionDecision":"ask"'*) echo ask ;;
    *) echo "invalid: $1" ;;
  esac
}

# check <name> <tool> <expected decision> <expected gh pr view args, or -> <command>
# Set VIEW, FAILS and PROJECT_URL to change what the fake gh answers.
check() {
  local name=$1 tool=$2 want=$3 want_view=$4 command=$5 escaped payload out status got log view
  escaped=${command//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  escaped=${escaped//$'
'/\n}
  payload='{"session_id":"s","cwd":"E:\\repo","permission_mode":"auto","hook_event_name":"PreToolUse","tool_name":"'$tool'","tool_input":{"command":"'$escaped'","description":"a \"command\":\"gh pr merge 9 --squash\" in a description"},"tool_use_id":"t"}'
  log=$work/gh.log
  rm -f "$log" "$log.fails"
  : > "$log"
  out=$(printf '%s' "$payload" | (
    cd "$work/project"
    PATH="$work/bin:$PATH" FAKE_GH_LOG="$log" FAKE_PR_VIEW="${VIEW-$own}" \
      FAKE_VIEW_FAILS="${FAILS:-0}" FAKE_PROJECT_URL="${PROJECT_URL-$project_url}" \
      CLAUDE_PROJECT_DIR="$work/project" sh "$hook"
  ))
  status=$?
  got=$(decision_of "$out")
  if grep -q '^pr view' "$log"; then
    view=$(grep '^pr view' "$log" | head -n 1 | sed 's/^pr view *//; s/ *--json .*//')
  else
    view=-
  fi
  if [ "$status" = 0 ] && [ "$got" = "$want" ] && [ "$view" = "$want_view" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n  command: %s\n  want: %s, view [%s]\n  got: %s, view [%s], exit %s\n' \
      "$name" "$command" "$want" "$want_view" "$got" "$view" "$status"
  fi
}

# check_reason <name> <text the reason must hold> <command>: the output is valid
# for Claude Code and tells the user why.
check_reason() {
  local name=$1 text=$2 command=$3 out payload
  payload='{"tool_name":"Bash","tool_input":{"command":"'$command'"}}'
  rm -f "$work/gh.log" "$work/gh.log.fails"
  out=$(printf '%s' "$payload" | (
    cd "$work/project"
    PATH="$work/bin:$PATH" FAKE_GH_LOG="$work/gh.log" FAKE_PR_VIEW="${VIEW-$own}" \
      FAKE_VIEW_FAILS="${FAILS:-0}" FAKE_PROJECT_URL="$project_url" \
      CLAUDE_PROJECT_DIR="$work/project" sh "$hook"
  ))
  if printf '%s' "$out" | node -e '
    let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
      const o = JSON.parse(s).hookSpecificOutput;
      if (o.hookEventName !== "PreToolUse" || !o.permissionDecisionReason.includes(process.argv[1])) process.exit(1);
    });' "$text"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n  want a reason holding: %s\n  got: %s\n' "$name" "$text" "$out"
  fi
}

# Own PR, every selector, both tools.
check 'own, number' Bash allow 5 'gh pr merge 5 --squash'
check 'own, number, PowerShell' PowerShell allow 5 'gh pr merge 5 --squash'
check 'own, url' Bash allow "$project_url/pull/5" "gh pr merge $project_url/pull/5 --squash"
check 'own, url, PowerShell' PowerShell allow "$project_url/pull/5" "gh pr merge $project_url/pull/5 --squash"
check 'own, branch' Bash allow 'feature/x-1.2' 'gh pr merge feature/x-1.2 --squash'
check 'own, owner:branch' Bash allow 'o:feature' 'gh pr merge o:feature --squash'
check 'own, no selector' Bash allow '' 'gh pr merge --squash'
check 'own, no selector, PowerShell' PowerShell allow '' 'gh pr merge --squash'
check 'own, -R' Bash allow '5 --repo o/r' 'gh pr merge 5 -R o/r --squash'
check 'own, --repo' Bash allow '5 --repo o/r' 'gh pr merge 5 --repo o/r --squash'
check 'own, --repo=' Bash allow '5 --repo o/r' 'gh pr merge 5 --repo=o/r --squash'
check 'own, -R, no selector' Bash allow '--repo o/r' 'gh pr merge -R o/r --squash'
check 'own, method first' Bash allow 5 'gh pr merge --squash 5'
check 'own, merge method' Bash allow 5 'gh pr merge 5 --merge'
check 'own, rebase method' Bash allow 5 'gh pr merge 5 --rebase'
PROJECT_URL=$project_url/ VIEW=$own check 'project url mismatch asks' Bash ask 5 'gh pr merge 5 --squash'

# External PR, every selector, both tools.
VIEW=$fork check 'fork, number' Bash ask 5 'gh pr merge 5 --squash'
VIEW=$fork check 'fork, number, PowerShell' PowerShell ask 5 'gh pr merge 5 --squash'
VIEW=$fork check 'fork, url' Bash ask "$project_url/pull/5" "gh pr merge $project_url/pull/5 --squash"
VIEW=$fork check 'fork, branch' Bash ask feature 'gh pr merge feature --squash'
VIEW=$fork check 'fork, no selector' Bash ask '' 'gh pr merge --squash'
VIEW=$fork check 'fork, -R' Bash ask '5 --repo o/r' 'gh pr merge 5 -R o/r --squash'
VIEW=$elsewhere check 'another repo, -R' Bash ask '5 --repo other/repo' 'gh pr merge 5 -R other/repo --squash'
VIEW=$elsewhere check 'another repo, url' Bash ask 'https://github.com/other/repo/pull/5' 'gh pr merge https://github.com/other/repo/pull/5 --squash'
VIEW=$elsewhere check 'another repo, PowerShell' PowerShell ask 5 'gh pr merge 5 --squash'

# gh fails: one retry, then ask.
FAILS=1 check 'gh fails once, own' Bash allow 5 'gh pr merge 5 --squash'
FAILS=1 VIEW=$fork check 'gh fails once, fork' Bash ask 5 'gh pr merge 5 --squash'
FAILS=2 check 'gh fails twice' Bash ask 5 'gh pr merge 5 --squash'
FAILS=2 check 'gh fails twice, PowerShell' PowerShell ask 5 'gh pr merge 5 --squash'
VIEW='garbage' check 'gh answers garbage' Bash ask 5 'gh pr merge 5 --squash'
VIEW='' check 'gh answers nothing' Bash ask 5 'gh pr merge 5 --squash'
PROJECT_URL='' check 'project repo unknown' Bash ask 5 'gh pr merge 5 --squash'

# Not the plain command: ask, without looking the PR up.
check '--admin before' Bash ask - 'gh pr merge 5 --admin --squash'
check '--admin after' Bash ask - 'gh pr merge 5 --squash --admin'
check '--admin, PowerShell' PowerShell ask - 'gh pr merge 5 --admin --squash'
check '--auto' Bash ask - 'gh pr merge 5 --auto --squash'
check '--delete-branch' Bash ask - 'gh pr merge 5 --squash --delete-branch'
check 'short flag' Bash ask - 'gh pr merge 5 -s'
check 'no method' Bash ask - 'gh pr merge 5'
check 'two methods' Bash ask - 'gh pr merge 5 --squash --merge'
check 'two selectors' Bash ask - 'gh pr merge 5 6 --squash'
check '-R without a value' Bash ask - 'gh pr merge 5 --squash -R'
check 'empty --repo=' Bash ask - 'gh pr merge 5 --repo= --squash'
check 'semicolon' Bash ask - 'gh pr merge 5 --squash; echo done'
check 'and chain' Bash ask - 'gh pr merge 5 --squash && echo done'
check 'chain first' Bash ask - 'echo hi && gh pr merge 5 --squash'
check 'pipe' Bash ask - 'gh pr merge 5 --squash | cat'
check 'PowerShell chain' PowerShell ask - 'gh pr merge 5 --squash; echo done'
check 'wrapper' Bash ask - 'timeout 30 gh pr merge 5 --squash'
check 'env prefix' Bash ask - 'GH_REPO=other/repo gh pr merge 5 --squash'
check 'cd first' Bash ask - 'cd docs && gh pr merge 5 --squash'
check 'substitution' Bash ask - 'gh pr merge $(echo 5) --squash'
check 'backticks' Bash ask - 'gh pr merge `echo 5` --squash'
check 'variable' Bash ask - 'gh pr merge $PR --squash'
check 'comment hides the arguments' Bash ask - 'gh pr merge #67 --squash'
check 'quoted selector' Bash ask - 'gh pr merge "5" --squash'
check 'newline' Bash ask - $'gh pr merge 5 --squash\necho done'
check 'glob' Bash ask - 'gh pr merge 5* --squash'
check 'gh.exe' PowerShell ask - 'gh.exe pr merge 5 --squash'
check 'call operator' PowerShell ask - '& gh pr merge 5 --squash'

# Only mentions the command: no decision.
check 'other command' Bash none - 'echo hello'
check 'other gh command' Bash none - 'gh pr view 5 --json mergeable'
check 'double-quoted mention' Bash none - 'echo "gh pr merge 5 --squash"'
check 'single-quoted mention' Bash none - "git commit -m 'gh pr merge is safer now'"
check 'mention, PowerShell' PowerShell none - 'echo "gh pr merge 5 --squash"'
check 'similar word' Bash none - 'mygh pr merge 5 --squash'
check 'similar command' Bash none - 'gh pr merged 5 --squash'

# Reasons reach the user, as valid JSON whatever gh printed.
VIEW=$fork check_reason 'reason names the PR' "$project_url/pull/5" 'gh pr merge 5 --squash'
VIEW=$elsewhere check_reason 'reason names the other repo' 'https://github.com/other/repo/pull/5' 'gh pr merge 5 --squash'
FAILS=2 check_reason 'reason holds the gh error' 'error connecting' 'gh pr merge 5 --squash'
check_reason 'reason says it is not plain' 'gh pr merge' 'gh pr merge 5 --admin --squash'

# GH_REPO in the session must not decide which repo the hook belongs to.
rm -f "$work/gh.log"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 5 --squash"}}' | (
  cd "$work/project"
  PATH="$work/bin:$PATH" FAKE_GH_LOG="$work/gh.log" FAKE_PR_VIEW="$own" FAKE_PROJECT_URL="$project_url" \
    GH_REPO=other/repo CLAUDE_PROJECT_DIR="$work" sh "$hook" >/dev/null
)
case "$(grep '^cwd=' "$work/gh.log")" in
  "cwd=$(cd "$work" && pwd) GH_REPO=") passed=$((passed + 1)) ;;
  *)
    failed=$((failed + 1))
    printf 'FAIL the project repo comes from the project dir, without GH_REPO\n  got: %s\n' "$(grep '^cwd=' "$work/gh.log")"
    ;;
esac

# Input the hook can't read gets no decision, and never an approval.
for bad in '' 'not json' '{"tool_name":"Bash"}' '{"tool_name":"Bash","tool_input":{"command":""}}'; do
  out=$(printf '%s' "$bad" | PATH="$work/bin:$PATH" FAKE_GH_LOG="$work/gh.log" sh "$hook")
  if [ -z "$out" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'FAIL unreadable input [%s]\n  got: %s\n' "$bad" "$out"
  fi
done

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
