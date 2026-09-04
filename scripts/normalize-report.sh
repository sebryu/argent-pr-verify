#!/usr/bin/env bash
# Fill in report.json fields a state agent may have omitted so compose-report.sh always has
# what it needs. Never changes an existing verdict.
#
# Usage: scripts/normalize-report.sh <report.json> <state> <sha> [recording-relative-path]
set -euo pipefail
F="${1:?report.json}"; STATE="${2:?state}"; SHA="${3:?sha}"; REC="${4:-$STATE/recording.mp4}"
[ -f "$F" ] || { echo "error: $F missing" >&2; exit 1; }
tmp=$(mktemp)
jq --arg state "$STATE" --arg sha "$SHA" --arg rec "$REC" '
  .state //= $state
  | .sha //= $sha
  | .verdict //= "inconclusive"
  | .confidence //= 0.5
  | .summary //= (.notes // "no summary")
  | .steps //= ([(.observations // [])[]] | to_entries | map({n: (.key + 1), action: .value, observed: ""}))
  | .evidence //= {}
  | .evidence.recording = $rec
  | .evidence.screenshots //= []
  | .evidence.extra //= []
' "$F" > "$tmp" && mv "$tmp" "$F"
jq -c '{state,sha:.sha[:10],verdict,confidence,steps:(.steps|length),recording:.evidence.recording}' "$F" >&2
