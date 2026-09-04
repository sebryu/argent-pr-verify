# Target chosen for the demo

**callstack/react-native-bottom-tabs PR #524** — "tabBarHidden prop silently overwritten"
(fixes issue #521). One-line library fix, the PR ships its own example screen, and the
difference is static and unambiguous: after tapping "Hide Tab Bar" the native tab bar either
stays (bug) or disappears (fixed). Release build, no Metro. Pre-checked locally on
2026-09-05: bug reproduced at the base commit.

Runner-up: software-mansion/react-native-gesture-handler PR #4065 (Clickable crash on child
removal, fixes #4062). Rejected for CI because the crash is an `RCTAssert` that Release
builds compile out, and the Expo example's Debug build hard-codes a Metro bundle URL, so
CI would have to run Metro. Its repro patch is kept under `.pr-verify/candidates/` locally.

Other pre-checked candidates and why not: Shopify/flash-list #2114 (good, but ~16 min CI
builds and needs the same repro-patch approach), react-native-paper #4897 (ripple animation
is transient, hard to judge from a screenshot), gesture-handler #3964, reanimated #10389,
react-navigation #13133 (a one-frame flash), react-native-screens #3825 (subtle edge effect).
