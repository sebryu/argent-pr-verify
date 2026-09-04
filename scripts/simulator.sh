#!/usr/bin/env bash
# Manage dedicated iOS simulators for before/after verification runs so the runs never
# collide with each other or with simulators other sessions are using.
#
# Usage:
#   scripts/simulator.sh ensure <name> [device-type] [runtime]   -> prints UDID (creates + boots if needed)
#   scripts/simulator.sh delete <name>                           -> shuts down + deletes every simulator with that name
#   scripts/simulator.sh quiet-keyboard <udid>                   -> disables autocorrect/prediction (stable typing)
set -euo pipefail

cmd="${1:-}"; shift || true

latest_ios_runtime() {
  xcrun simctl list runtimes ios -j | jq -r '.runtimes | map(select(.isAvailable)) | last | .identifier'
}

udid_for_name() {
  xcrun simctl list devices -j | jq -r --arg n "$1" '.devices | to_entries[] | .value[] | select(.name == $n and .isAvailable) | .udid' | head -1
}

case "$cmd" in
  ensure)
    name="${1:?name}"; devtype="${2:-iPhone 17}"; runtime="${3:-$(latest_ios_runtime)}"
    udid=$(udid_for_name "$name")
    if [ -z "$udid" ]; then
      udid=$(xcrun simctl create "$name" "$devtype" "$runtime")
      echo "created simulator name=$name udid=$udid runtime=$runtime" >&2
    fi
    state=$(xcrun simctl list devices -j | jq -r --arg u "$udid" '.devices[][] | select(.udid == $u) | .state')
    if [ "$state" != "Booted" ]; then
      xcrun simctl boot "$udid" >&2 || true
    fi
    xcrun simctl bootstatus "$udid" -b >&2
    echo "$udid"
    ;;
  delete)
    name="${1:?name}"
    for udid in $(xcrun simctl list devices -j | jq -r --arg n "$name" '.devices[][] | select(.name == $n) | .udid'); do
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      xcrun simctl delete "$udid"
      echo "deleted simulator name=$name udid=$udid" >&2
    done
    ;;
  quiet-keyboard)
    udid="${1:?udid}"
    for key in KeyboardPrediction KeyboardAutocorrection KeyboardCheckSpelling KeyboardAutocapitalization KeyboardPeriodShortcut KeyboardCapsLock KeyboardContinuousPathEnabled; do
      xcrun simctl spawn "$udid" defaults write "Apple Global Domain" "$key" -bool false
      xcrun simctl spawn "$udid" defaults write com.apple.Preferences "$key" -bool false
    done
    xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
    ;;
  *) sed -n '2,9p' "$0" >&2; exit 2 ;;
esac
