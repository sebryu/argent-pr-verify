#!/usr/bin/env bash
# Resolve a GitHub pull request into the JSON the argent-pr-verify skill needs:
# repo, number, title, base/head/merge SHAs, linked issue numbers and their bodies.
#
# Usage: scripts/resolve-pr.sh <pr-url-or-number> [--repo owner/name] [--issue <n-or-url>]...
set -euo pipefail

usage() { sed -n '2,6p' "$0" >&2; exit 2; }

PR_REF=""; REPO=""; EXTRA_ISSUES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --issue) EXTRA_ISSUES+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) [ -z "$PR_REF" ] && PR_REF="$1" || usage; shift ;;
  esac
done
[ -n "$PR_REF" ] || usage

if [[ "$PR_REF" =~ ^https?://github\.com/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  REPO="${BASH_REMATCH[1]}"; PR_NUMBER="${BASH_REMATCH[2]}"
elif [[ "$PR_REF" =~ ^[0-9]+$ ]] && [ -n "$REPO" ]; then
  PR_NUMBER="$PR_REF"
else
  echo "error: pass a PR URL, or a PR number together with --repo owner/name" >&2; exit 2
fi

PR_JSON=$(gh pr view "$PR_NUMBER" --repo "$REPO" \
  --json number,title,body,url,state,mergedAt,baseRefName,baseRefOid,headRefOid,mergeCommit,files)

# Linked issues: explicit --issue flags first, then "fixes/closes/resolves #N" and
# same-repo issue URLs found in the PR body.
ISSUE_NUMBERS=$(
  {
    for i in "${EXTRA_ISSUES[@]:-}"; do
      [ -z "$i" ] && continue
      if [[ "$i" =~ /issues/([0-9]+) ]]; then echo "${BASH_REMATCH[1]}"; else echo "$i"; fi
    done
    # "Fixes #12", "closes: #12, #13", "Resolves https://github.com/<repo>/issues/12"
    jq -r '.body' <<<"$PR_JSON" \
      | grep -oiE "(^|[^[:alnum:]])(fix(e[sd])?|close[sd]?|resolve[sd]?)[[:space:]:]*((https://github\.com/${REPO}/issues/|#)[0-9]+([[:space:]]*,[[:space:]]*(https://github\.com/${REPO}/issues/|#)[0-9]+)*)" \
      | grep -oE '[0-9]+' || true
    jq -r '.body' <<<"$PR_JSON" \
      | grep -oE "https://github\.com/${REPO}/issues/[0-9]+" | grep -oE '[0-9]+$' || true
  } | awk 'NF && !seen[$0]++'
)

ISSUES_JSON="[]"
for n in $ISSUE_NUMBERS; do
  one=$(gh issue view "$n" --repo "$REPO" --json number,title,body,url,labels,comments \
        --jq '{number,title,body,url,labels:[.labels[].name],comments:[.comments[] | {author:.author.login, body}]}' 2>/dev/null) || continue
  ISSUES_JSON=$(jq --argjson i "$one" '. + [$i]' <<<"$ISSUES_JSON")
done

jq -n --arg repo "$REPO" --argjson pr "$PR_JSON" --argjson issues "$ISSUES_JSON" '{
  repo: $repo,
  number: $pr.number,
  title: $pr.title,
  url: $pr.url,
  state: $pr.state,
  mergedAt: $pr.mergedAt,
  baseRef: $pr.baseRefName,
  before: $pr.baseRefOid,
  after: ($pr.mergeCommit.oid // $pr.headRefOid),
  head: $pr.headRefOid,
  files: [$pr.files[].path],
  body: $pr.body,
  issues: $issues
}'
