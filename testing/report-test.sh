#!/usr/bin/env bash
# Tests how run.sh and verify.sh read the coordinator's output: lib.sh's
# transcript, on a Claude Code and an OpenCode event log, and unlinked_prs.
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

[ "$failures" = 0 ] || { echo "$failures failed" >&2; exit 1; }
echo "PASS"
