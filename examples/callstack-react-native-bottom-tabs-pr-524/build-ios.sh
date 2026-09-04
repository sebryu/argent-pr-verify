#!/usr/bin/env bash
#
# Build react-native-bottom-tabs' apps/example for the iOS Simulator (Release, native arch).
#
# Usage: build-ios.sh <repo-root>
#   <repo-root>  absolute path to a checkout of callstack/react-native-bottom-tabs
#                with JS deps not yet installed (a fresh `git clone` is fine).
#
# On success, prints ONLY the absolute path to the built .app as the last line of
# stdout. Everything else (progress, tool output, warnings) goes to stderr.
#
# Known environment gotcha this script works around: on Xcode 26.x, Apple Clang
# fails to compile the `fmt` pod (11.0.2, a transitive React Native dependency)
# with "call to consteval function ... is not a constant expression" in
# fmt/format-inl.h. This is a toolchain/fmt-version regression, unrelated to
# react-native-bottom-tabs. GitHub's macos runners also ship Xcode 26.6, so this
# hits CI too, not just local builds. Worked around by stripping the FMT_STRING()
# compile-time-format-check macro wrapper from the vendored (gitignored) Pods
# copy of fmt/format-inl.h after every `pod install` — this never touches
# repository source, only the CocoaPods-managed dependency copy that pod install
# regenerates from scratch each time.
#
# Second gotcha this script avoids: react-native's Codegen artifacts
# (apps/example/ios/build/generated/ios/**) are generated once, synchronously,
# as part of `pod install` (see node_modules/react-native/scripts/cocoapods/
# codegen_utils.rb, use_react_native_codegen_discovery!) -- NOT as an Xcode
# build script phase. If xcodebuild's -derivedDataPath is allowed to overlap
# with that `build/` directory (e.g. -derivedDataPath ios/build), then cleaning
# derived data before a build (rm -rf ios/build) also deletes the codegen
# artifacts, and the first xcodebuild invocation then races/fails looking for
# them ("Build input file cannot be found"). Using a derivedDataPath outside
# apps/example/ios/build (this script uses apps/example/ios/DerivedData)
# avoids the collision entirely: a single xcodebuild invocation succeeds.

set -euo pipefail

log() { printf '%s\n' "$*" >&2; }

if [[ $# -ne 1 ]]; then
  log "Usage: $0 <repo-root>"
  exit 2
fi

REPO_ROOT="$(cd "$1" && pwd)"
EXAMPLE_DIR="$REPO_ROOT/apps/example"
IOS_DIR="$EXAMPLE_DIR/ios"
DERIVED_DATA_DIR="$IOS_DIR/DerivedData"
FMT_HEADER="$IOS_DIR/Pods/fmt/include/fmt/format-inl.h"

if [[ ! -d "$EXAMPLE_DIR" ]]; then
  log "error: $EXAMPLE_DIR not found -- is $REPO_ROOT a react-native-bottom-tabs checkout?"
  exit 1
fi

log "==> [1/6] yarn install (repo root: $REPO_ROOT)"
( cd "$REPO_ROOT" && yarn install ) >&2

log "==> [2/6] yarn build (turbo build of lib packages)"
( cd "$REPO_ROOT" && yarn build ) >&2

log "==> [3/6] yarn build:ios (Metro JS bundle for apps/example)"
( cd "$EXAMPLE_DIR" && yarn build:ios ) >&2

log "==> [4/6] pod install (also generates Codegen artifacts synchronously)"
( cd "$EXAMPLE_DIR" && RCT_NEW_ARCH_ENABLED=1 NO_FLIPPER=1 pod install --project-directory=ios ) >&2

log "==> [5/6] workaround: strip FMT_STRING() consteval-check wrapper from vendored fmt (Xcode 26.x / fmt 11.0.2 compat)"
if [[ ! -f "$FMT_HEADER" ]]; then
  log "error: expected vendored fmt header not found at $FMT_HEADER (fmt version bump? pod install failed silently?)"
  exit 1
fi
chmod u+w "$FMT_HEADER"
sed -i '' -E 's/FMT_STRING\(("([^"]|\\.)*")\)/\1/g' "$FMT_HEADER"
remaining=$(grep -c "FMT_STRING" "$FMT_HEADER" || true)
if [[ "$remaining" -ne 0 ]]; then
  log "error: expected 0 FMT_STRING occurrences left in $FMT_HEADER, found $remaining"
  exit 1
fi
log "    confirmed: 0 FMT_STRING occurrences remain in $FMT_HEADER"

log "==> [6/6] xcodebuild (Release, iphonesimulator, native arch, separate DerivedData path)"
ARCH="$(uname -m)"
rm -rf "$DERIVED_DATA_DIR"
(
  cd "$IOS_DIR" && xcodebuild \
    -workspace ReactNativeBottomTabsExample.xcworkspace \
    -scheme ReactTestApp \
    -configuration Release \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS="$ARCH" \
    ONLY_ACTIVE_ARCH=YES
) >&2

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release-iphonesimulator/ReactTestApp.app"
if [[ ! -d "$APP_PATH" ]]; then
  log "error: build reported success but $APP_PATH does not exist"
  exit 1
fi

log "==> done"
echo "$APP_PATH"
