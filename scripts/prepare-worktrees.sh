#!/usr/bin/env bash
# Create <out>/before/src and <out>/after/src checkouts of a repository at two commits
# (one clone, two worktrees) and optionally apply the same repro patch to both.
#
# Usage: scripts/prepare-worktrees.sh <repo-url> <before-sha> <after-sha> <out-dir> [--patch <file>] [--pr <number>]
# --pr also fetches refs/pull/<number>/head, needed when the PR head lives in a fork.
set -euo pipefail

REPO_URL="${1:?repo url}"; BEFORE="${2:?before sha}"; AFTER="${3:?after sha}"; OUT="${4:?out dir}"; shift 4
PATCH=""; PR_NUMBER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --patch) PATCH="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --pr) PR_NUMBER="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
BASE_CLONE="$OUT/repo.git"

if [ ! -d "$BASE_CLONE" ]; then
  echo "cloning repo=$REPO_URL into=$BASE_CLONE" >&2
  git clone --quiet --no-checkout "$REPO_URL" "$BASE_CLONE"
fi
git -C "$BASE_CLONE" fetch --quiet origin "$BEFORE" "$AFTER" 2>/dev/null || git -C "$BASE_CLONE" fetch --quiet origin
if [ -n "$PR_NUMBER" ]; then
  git -C "$BASE_CLONE" fetch --quiet origin "refs/pull/$PR_NUMBER/head" 2>/dev/null || true
fi
for sha in "$BEFORE" "$AFTER"; do
  git -C "$BASE_CLONE" cat-file -e "$sha^{commit}" 2>/dev/null || { echo "error: commit $sha not found after fetch (pass --pr <n> for fork heads)" >&2; exit 1; }
done

for pair in "before:$BEFORE" "after:$AFTER"; do
  state="${pair%%:*}"; sha="${pair#*:}"; dir="$OUT/$state/src"
  if [ -d "$dir" ]; then
    echo "worktree exists state=$state dir=$dir (leaving as is)" >&2
    continue
  fi
  mkdir -p "$OUT/$state"
  git -C "$BASE_CLONE" worktree add --quiet --detach "$dir" "$sha"
  echo "worktree state=$state sha=$sha dir=$dir" >&2
  if [ -n "$PATCH" ]; then
    if git -C "$dir" apply --check "$PATCH" 2>/dev/null; then
      git -C "$dir" apply "$PATCH"
      echo "patch applied state=$state patch=$PATCH" >&2
    elif git -C "$dir" apply --check --reverse "$PATCH" 2>/dev/null; then
      # The PR itself contains the repro (typical for the after state).
      echo "patch already present state=$state (skipped)" >&2
    else
      echo "error: repro patch does not apply cleanly to state=$state sha=$sha" >&2
      exit 1
    fi
  fi
done

jq -n --arg before "$BEFORE" --arg after "$AFTER" --arg patch "${PATCH:-}" --arg out "$OUT" \
  '{before:{sha:$before, src:($out+"/before/src")}, after:{sha:$after, src:($out+"/after/src")}, patch:$patch}'
