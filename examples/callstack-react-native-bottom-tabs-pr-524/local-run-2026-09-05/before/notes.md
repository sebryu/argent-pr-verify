# before state — callstack/react-native-bottom-tabs PR #524

- sha: `6797d321ad66f45bee3c6e64720ae983166661ef`
- Build: `bash examples/callstack-react-native-bottom-tabs-pr-524/build-ios.sh <src>` succeeded
  on the first attempt (~15 min wall clock incl. yarn install/build; full stderr log at
  `before/build.log`). App path:
  `apps/example/ios/DerivedData/Build/Products/Release-iphonesimulator/ReactTestApp.app`.
- Installed and launched on simulator `PRVerify-Before` (`1F8B79AD-A60A-4932-8A23-F6B9EB461835`),
  bundle id `bottomtabs.example`.
- The "Tab Bar Hidden" row was visible on the home list without needing to scroll
  (frame y=0.544 in the initial `describe`).
- Repro followed exactly as in the brief:
  1. Tapped "Tab Bar Hidden" → screen with "Article" text, "Hide Tab Bar" button, and a
     native tab bar (Article / Albums / Contacts) at the bottom.
  2. Baseline screenshot taken (`step-02.png`).
  3. Tapped "Hide Tab Bar" → button label changed to "Show Tab Bar" confirming the tap
     landed and JS state toggled.
  4. Decisive moment: waited for screen idle (549ms), then `describe` and a full-resolution
     screenshot (`decisive.png`, `decisive-describe.txt`).
- **Decisive observation**: the native tab bar was still present. `describe` lists
  `AXGroup "Tab Bar" (0.000, 0.905, 1.000, 0.095)` containing buttons "Article", "Albums",
  "Contacts" — all at normalized y ≈ 0.905 (> 0.85 threshold from the brief). The
  screenshot visually confirms the tab bar pill with all three items at the bottom, while
  the button above reads "Show Tab Bar". This is an exact match for the brief's
  `bug_present` criteria.
- Control step: tapped "Show Tab Bar" → button reverted to "Hide Tab Bar", tab bar
  remained visible throughout (expected in both states, does not affect the verdict).
- Recording: `before/recording.mp4` (7.13s after trimming static stretches), verified
  with `ffprobe`.

**Verdict: bug_present** (confidence 0.98) — the `tabBarHidden` prop had no effect on this
build; the native tab bar remained on screen after toggling it, exactly as reported in
issue #521.

Note: Argent reported an available update to v0.24.0 during this run. No update was
applied, per instructions to never update without explicit user consent.
