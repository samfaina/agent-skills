#!/usr/bin/env bash
# Checks that every block a reader can copy from the docs holds at most one
# slash command. Claude Code takes one command per message: pasting two runs
# the first with the second as part of its argument, so
# `/plugin marketplace add` fails with "is not a valid GitHub owner/repo
# shorthand". Covers the fenced blocks in README.md and docs/, and the copy
# buttons' <code> blocks on the landing page. No network.
#
#   docs-test.sh
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
cd "$root"

files=(README.md $(git ls-files 'docs/*.md'))

awk '
  FNR == 1 { inblock = 0 }
  function close_block() {
    if (count > 1) { printf "FAIL  %s:%d: %d slash commands in one copyable block\n", FILENAME, start, count; bad++ }
    inblock = 0
  }
  /^```/ {
    if (inblock) close_block(); else { inblock = 1; start = FNR; count = 0 }
    next
  }
  /class="install"><code>/ {
    inblock = 2; start = FNR; count = 0
    sub(/.*class="install"><code>/, "")
  }
  inblock {
    line = $0
    ended = (inblock == 2 && line ~ /<\/code>/)
    sub(/<\/code>.*/, "", line)
    if (line ~ /^\//) count++
    if (ended) close_block()
  }
  END { exit bad > 0 }
' "${files[@]}" >&2
status=$?

if [ $status -eq 0 ]; then
  echo "ok    one slash command per copyable block"
fi
exit $status
