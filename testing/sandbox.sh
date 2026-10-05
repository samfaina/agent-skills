#!/usr/bin/env bash
# Creates and resets the sandbox repo for TESTING.md.
#
#   sandbox.sh create <owner/repo>
#   sandbox.sh reset <owner/repo> [--workers '<Workers value>'] [--no-shipping-md]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

usage() {
  echo "usage: sandbox.sh create <owner/repo>" >&2
  echo "       sandbox.sh reset <owner/repo> [--workers '<Workers value>'] [--no-shipping-md]" >&2
  exit 1
}

[ $# -ge 2 ] || usage
command=$1
repo=$2
shift 2

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

reset() {
  local workers='' no_shipping_md=false
  while [ $# -gt 0 ]; do
    case $1 in
      --workers) [ $# -ge 2 ] || usage; workers=$2; shift 2 ;;
      --no-shipping-md) no_shipping_md=true; shift ;;
      *) usage ;;
    esac
  done

  echo "Closing open PRs"
  for pr in $(gh pr list --repo "$repo" --state open --json number --jq '.[].number'); do
    gh pr close "$pr" --repo "$repo" --comment "Closed by sandbox reset." >/dev/null 2>&1
    echo "  closed #$pr"
  done

  echo "Resetting main to the baseline tag"
  rm -rf "$work/reset"
  git clone --quiet "https://github.com/$repo.git" "$work/reset"
  (
    cd "$work/reset"
    git checkout --quiet -B main baseline
    if [ -n "$workers" ]; then
      W=$workers awk '/^- \*\*Workers:\*\*/ { print "- **Workers:** " ENVIRON["W"]; next } { print }' \
        docs/agents/shipping.md > "$work/shipping.md"
      mv "$work/shipping.md" docs/agents/shipping.md
      git commit --quiet -am "Set Workers for this test run"
      echo "  Workers: $workers"
    fi
    if $no_shipping_md; then
      git rm --quiet docs/agents/shipping.md
      git commit --quiet -m "Remove shipping.md for a setup test run"
      echo "  removed docs/agents/shipping.md"
    fi
    git push --quiet --force origin main

    echo "Deleting branches other than main"
    for branch in $(gh api "repos/$repo/branches" --paginate --jq '.[].name'); do
      if [ "$branch" != main ]; then
        git push --quiet origin --delete "$branch"
        echo "  deleted $branch"
      fi
    done
  )

  echo "Creating the ready-for-agent label"
  gh label create ready-for-agent --repo "$repo" --force --color 0e8a16 \
    --description "Fully specified, ready for an AFK agent" >/dev/null

  echo "Resetting tickets"
  for file in $(ls "$here"/tickets/*.md | sort -V); do
    local n title
    n=$(basename "$file" .md)
    title=$(head -n 1 "$file" | tr -d '\r' | sed 's/^# //')
    tail -n +3 "$file" | tr -d '\r' > "$work/body.md"

    if gh issue view "$n" --repo "$repo" --json number >/dev/null 2>&1; then
      gh issue edit "$n" --repo "$repo" --title "$title" --body-file "$work/body.md" >/dev/null
      if [ "$(gh issue view "$n" --repo "$repo" --json state --jq .state)" = CLOSED ]; then
        gh issue reopen "$n" --repo "$repo" >/dev/null 2>&1
      fi
      for id in $(gh api "repos/$repo/issues/$n/comments" --paginate --jq '.[].id'); do
        gh api --method DELETE "repos/$repo/issues/comments/$id" >/dev/null
      done
    else
      local url
      url=$(gh issue create --repo "$repo" --title "$title" --body-file "$work/body.md")
      if [ "${url##*/}" != "$n" ]; then
        echo "Created $url, but tickets/$n.md expects issue #$n." >&2
        exit 1
      fi
    fi

    for label in $(gh issue view "$n" --repo "$repo" --json labels --jq '.labels[].name'); do
      if [ "$label" != ready-for-agent ]; then
        gh issue edit "$n" --repo "$repo" --remove-label "$label" >/dev/null
      fi
    done
    gh issue edit "$n" --repo "$repo" --add-label ready-for-agent >/dev/null
    echo "  #$n $title"
  done

  cat <<'MSG'

Done. Before the next run:
- remove the Orca worktrees the last run left: orca worktree list, then orca worktree rm --worktree <id>
- reset your clone: git fetch origin --prune && git checkout main && git reset --hard origin/main
MSG
}

create() {
  [ $# -eq 0 ] || usage

  echo "Creating $repo"
  cp -r "$here/sandbox" "$work/create"
  (
    cd "$work/create"
    git init --quiet -b main
    git add -A
    git commit --quiet -m "Set up the ship-tickets sandbox"
    git tag baseline
    gh repo create "$repo" --private --source . --push >/dev/null
    git push --quiet origin baseline
  )
  gh api --method PATCH "repos/$repo" \
    -F allow_merge_commit=false -F allow_rebase_merge=false -F allow_squash_merge=true \
    -F delete_branch_on_merge=false >/dev/null
  echo "  squash merges only, branches kept after merge"

  reset
}

case $command in
  create) create "$@" ;;
  reset) reset "$@" ;;
  *) usage ;;
esac
