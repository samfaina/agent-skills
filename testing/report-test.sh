#!/usr/bin/env bash
# Tests how run.sh and verify.sh read the coordinator's output: lib.sh's
# transcript, on a Claude Code and an OpenCode event log, unlinked_prs,
# gives_command, issues_opened and comments_posted.
# No network, no Orca, no coordinator.
#
#   report-test.sh
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  local name=$1 expected=$2 got=$3
  if [ "$got" = "$expected" ]; then
    echo "ok    $name"
  else
    echo "FAIL  $name" >&2
    echo "      expected: $(printf %q "$expected")" >&2
    echo "      got:      $(printf %q "$got")" >&2
    failures=$((failures + 1))
  fi
}

# A Claude Code stream-json log: a message whose text and command come in two
# events, a two-block report, and a subagent's message after it.
cat > "$work/claude.log" <<'EOF'
{"type":"system","subtype":"init"}
{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m1","content":[{"type":"text","text":"Abrí el PR: https://github.com/o/r/pull/7"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m1","content":[{"type":"tool_use","name":"Bash","input":{"command":"gh pr checks 7 --watch"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"ok"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m2","content":[{"type":"text","text":"**#1 quedó mergeado:**"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m2","content":[{"type":"text","text":"[PR #7](https://github.com/o/r/pull/7)"}]}}
{"type":"assistant","parent_tool_use_id":"tu_1","message":{"id":"s1","content":[{"type":"text","text":"subagente"}]}}
{"type":"result","subtype":"success","result":"[PR #7](https://github.com/o/r/pull/7)"}
EOF

check "Claude Code: report is the last message, all its text blocks, never a subagent's" \
  "$(printf '%s\n%s' '**#1 quedó mergeado:**' '[PR #7](https://github.com/o/r/pull/7)')" \
  "$(transcript report < "$work/claude.log")"

# An `opencode run --format json` log: each step is a message of its own, with
# a message id on its parts, and ends with step_finish. The last step stops.
cat > "$work/opencode.log" <<'EOF'
{"type":"step_start","sessionID":"ses","part":{"messageID":"m1","type":"step-start"}}
{"type":"text","sessionID":"ses","part":{"messageID":"m1","type":"text","text":"Abrí el PR: https://github.com/o/r/pull/7"}}
{"type":"tool_use","sessionID":"ses","part":{"messageID":"m1","type":"tool","state":{"input":{"command":"gh pr checks 7 --watch"}}}}
{"type":"step_finish","sessionID":"ses","part":{"messageID":"m1","type":"step-finish","reason":"tool-calls"}}
{"type":"step_start","sessionID":"ses","part":{"messageID":"m2","type":"step-start"}}
{"type":"text","sessionID":"ses","part":{"messageID":"m2","type":"text","text":"**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)"}}
{"type":"step_finish","sessionID":"ses","part":{"messageID":"m2","type":"step-finish","reason":"stop"}}
EOF

check "OpenCode: report is the last step's text" \
  '**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)' \
  "$(transcript report < "$work/opencode.log")"

check "Claude Code: said is every message, a subagent's too" \
  "$(printf '%s\n' 'Abrí el PR: https://github.com/o/r/pull/7' '**#1 quedó mergeado:**' '[PR #7](https://github.com/o/r/pull/7)' subagente)" \
  "$(transcript said < "$work/claude.log")"
check "Claude Code: ran is the commands, with the tool" \
  'Bash: gh pr checks 7 --watch' \
  "$(transcript ran < "$work/claude.log")"
check "OpenCode: said is every step's text" \
  "$(printf '%s\n' 'Abrí el PR: https://github.com/o/r/pull/7' '**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)')" \
  "$(transcript said < "$work/opencode.log")"
check "OpenCode: ran is the commands" \
  'gh pr checks 7 --watch' \
  "$(transcript ran < "$work/opencode.log")"

# OpenCode gives each step its own message id. Should two steps ever share
# one, the step_start between them still ends the first message.
sed 's/"m2"/"m1"/' "$work/opencode.log" > "$work/shared-id.log"
check "OpenCode: a step_start ends the message, whatever its id" \
  '**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)' \
  "$(transcript report < "$work/shared-id.log")"

# The report a loop run ends with must link each PR it merged.
printf '%s\n' '**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)' \
  '**#3 quedó mergeado:** [PR #72](https://github.com/o/r/pull/72)' > "$work/report.txt"
check "unlinked_prs: nothing when every PR is linked" '' "$(unlinked_prs "$work/report.txt" 7 72)"
check "unlinked_prs: names the one PR missing" '9' "$(unlinked_prs "$work/report.txt" 7 9 72)"
echo 'https://github.com/o/r/pull/72' > "$work/72.txt"
check "unlinked_prs: a link to /pull/72 doesn't link #7" '7' "$(unlinked_prs "$work/72.txt" 7 72)"

# A coordinator that linked the PR when it opened it, but not in its report.
head -n 4 "$work/claude.log" > "$work/unreported.log"
echo '{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m2","content":[{"type":"text","text":"#1 quedó mergeado."}]}}' >> "$work/unreported.log"
transcript report < "$work/unreported.log" > "$work/unreported.txt"
check "unlinked_prs: a link in an earlier message doesn't count" '7' "$(unlinked_prs "$work/unreported.txt" 7)"

# A report that gives the user a cleanup the harness refused.
printf '%s\n' '**#1 quedó mergeado:** [PR #7](https://github.com/o/r/pull/7)' \
  'Ejecuta `git push origin --delete samfaina/1-add-slugify.v2`.' > "$work/refused.txt"
gives() { if gives_command "$@"; then echo yes; else echo no; fi; }
check "gives_command: the exact command, in backticks" yes \
  "$(gives "$work/refused.txt" 'git push origin --delete samfaina/1-add-slugify.v2')"
check "gives_command: no for a command the report doesn't give" no \
  "$(gives "$work/report.txt" 'git push origin --delete samfaina/1-add-slugify.v2')"
check "gives_command: a longer branch name isn't this branch" no \
  "$(gives "$work/refused.txt" 'git push origin --delete samfaina/1-add-slugify')"
check "gives_command: a dot in the branch matches only a dot" no \
  "$(gives "$work/refused.txt" 'git push origin --delete samfaina/1-add-slugifyxv2')"
# Git forbids a branch name ending in a dot, so a period after it ends a sentence.
echo 'Run git push origin --delete 1-add-slugify.' > "$work/sentence.txt"
check "gives_command: a sentence's period isn't part of the branch" yes \
  "$(gives "$work/sentence.txt" 'git push origin --delete 1-add-slugify')"

# A loop run opens no issue: the coordinator only offers follow-ups, and an
# unattended run has no one to accept them. The sandbox's tickets don't count,
# though the first reset after `create` opens them after the run's start.
cat > "$work/issues.json" <<'EOF'
[
  {"number": 6, "createdAt": "2026-11-17T10:05:00Z"},
  {"number": 5, "createdAt": "2026-11-16T09:00:00Z"},
  {"number": 3, "createdAt": "2026-11-17T10:01:00Z"},
  {"number": 1, "createdAt": "2026-11-17T10:00:00Z"}
]
EOF
check "issues_opened: the issues created since the run started, tickets aside" '6' \
  "$(issues_opened 2026-11-17T10:00:00Z 1 2 3 4 < "$work/issues.json")"
check "issues_opened: nothing when only the tickets are new" '' \
  "$(issues_opened 2026-11-17T10:10:00Z 1 2 3 4 < "$work/issues.json")"

# Nor does it comment on an issue: folding a follow-up into one needs an
# answer too. The issue comments API lists a PR's comments as well, under
# /pull/, and pages come as an array of arrays with --slurp.
cat > "$work/comments.json" <<'EOF'
[
  [
    {"issue_url": "https://api.github.com/repos/o/r/issues/5", "html_url": "https://github.com/o/r/issues/5#issuecomment-1", "created_at": "2026-11-17T10:05:00Z", "body": "## What happened"},
    {"issue_url": "https://api.github.com/repos/o/r/issues/7", "html_url": "https://github.com/o/r/pull/7#issuecomment-2", "created_at": "2026-11-17T10:06:00Z", "body": "Fixed."}
  ],
  [
    {"issue_url": "https://api.github.com/repos/o/r/issues/2", "html_url": "https://github.com/o/r/issues/2#issuecomment-3", "created_at": "2026-11-16T09:00:00Z", "body": "Old."},
    {"issue_url": "https://api.github.com/repos/o/r/issues/1", "html_url": "https://github.com/o/r/issues/1#issuecomment-4", "created_at": "2026-11-17T10:07:00Z", "body": "## Where"}
  ]
]
EOF
check "comments_posted: the issues commented on since the run started, PRs aside" "$(printf '5\n1')" \
  "$(comments_posted 2026-11-17T10:00:00Z < "$work/comments.json")"
check "comments_posted: nothing when every comment is older" '' \
  "$(comments_posted 2026-11-17T10:10:00Z < "$work/comments.json")"
# The loop closes a ticket its merge left open with "Shipped in #<pr>".
cat > "$work/shipped.json" <<'EOF'
[
  {"issue_url": "https://api.github.com/repos/o/r/issues/3", "html_url": "https://github.com/o/r/issues/3#issuecomment-5", "created_at": "2026-11-17T10:08:00Z", "body": "Shipped in #9"},
  {"issue_url": "https://api.github.com/repos/o/r/issues/4", "html_url": "https://github.com/o/r/issues/4#issuecomment-6", "created_at": "2026-11-17T10:09:00Z", "body": "Shipped in #9, and folded:\n\n## What happened"}
]
EOF
check "comments_posted: a ticket closed as shipped doesn't count" '4' \
  "$(comments_posted 2026-11-17T10:00:00Z < "$work/shipped.json")"

[ "$failures" = 0 ] || { echo "$failures failed" >&2; exit 1; }
echo "PASS"
