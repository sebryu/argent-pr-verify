# Verification brief — callstack/react-native-bottom-tabs#524 · `tabBarHidden` prop is ignored

Both state agents receive this file verbatim. Follow the steps literally; judge only what
the decision rule says.

## Bug

- Issue: https://github.com/callstack/react-native-bottom-tabs/issues/521 — passing
  `tabBarHidden={true}` to `TabView` does nothing: the native tab bar stays on screen.
- PR: https://github.com/callstack/react-native-bottom-tabs/pull/524 — `TabView.tsx` used to
  hard-code `tabBarHidden={!!renderCustomTabBar}`, discarding the caller's prop; the fix
  forwards `tabBarHidden ?? !!renderCustomTabBar`. Library file touched:
  `packages/react-native-bottom-tabs/src/TabView.tsx`.
- before = `6797d321ad66f45bee3c6e64720ae983166661ef` (bug expected) ·
  after = `54283150c216ccd31566d3f07d48f70f5faac44a` (fix expected)

## App under test

- Example app dir: `apps/example` (react-native-test-app harness) · bundle id:
  `bottomtabs.example` · scheme/workspace: `ReactTestApp` / `ios/ReactNativeBottomTabsExample.xcworkspace`
- Repro patch: `repro.patch` — the PR's own example-app changes (adds the "Tab Bar Hidden"
  example screen and registers it). Touches `apps/example` only.
- Build recipe: `build-ios.sh <repo-root>` (Release, simulator, prints the `.app` path).
  It includes a workaround for an `fmt` pod that does not compile with Xcode 26.6 and
  runs `xcodebuild` twice because the first pass races React Native codegen.
- Expected build time: ~7 min locally · ~10 min on a GitHub macos-26 runner

## Repro steps (identical for both states)

1. Launch `bottomtabs.example` → the home list titled "BottomTabs Example" shows rows such
   as "Three Tabs", "Four Tabs", "Lazy Tabs", "Tab Bar Hidden".
2. Tap the row "Tab Bar Hidden" (scroll the list down if it is not visible; re-`describe`
   after scrolling) → a screen titled "Tab Bar Hidden" appears with the text "Article", a
   button "Hide Tab Bar", and a native tab bar at the bottom with the items "Article",
   "Albums", "Contacts".
3. Take the baseline screenshot (`step-02.png`) showing the tab bar present.
4. Tap the button "Hide Tab Bar" → the button label changes to "Show Tab Bar" (this proves
   the tap landed and JS state toggled; it happens in both states).
5. **Decisive moment**: wait ~1 s (`await-screen-idle`), then `describe` and take a
   full-resolution screenshot. Look at the bottom ~15 % of the screen.
6. Tap "Show Tab Bar" → the tab bar is visible again in both states (control step; record
   what you see but it does not affect the verdict).

## Decision rule

- `bug_present` when, at the decisive moment, the native tab bar is still on screen: the
  screenshot shows the tab bar pill with "Article", "Albums", "Contacts" at the bottom
  and/or `describe` lists tab-bar items with those labels in the bottom part of the screen
  (normalized y > 0.85) while the button reads "Show Tab Bar".
- `bug_absent` when, at the decisive moment, the tab bar is gone: no tab-bar items
  "Albums" / "Contacts" anywhere in `describe`, and the screenshot shows only "Article" and
  the "Show Tab Bar" button on an otherwise empty screen.
- Evidence to capture at the decisive moment: full-resolution screenshot, `describe` dump
  saved as `decisive-describe.txt`.
- If the "Tab Bar Hidden" row cannot be found, the button label does not change after the
  tap (tap missed twice), or the app crashes → `inconclusive` with the reason.

## Expectations (for the report, not for the agents' judgement)

- before (`6797d321`): bug_present — tab bar stays visible after tapping "Hide Tab Bar".
- after (`54283150`): bug_absent — tab bar disappears after tapping "Hide Tab Bar".
