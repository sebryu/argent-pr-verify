# After-state verification notes — callstack/react-native-bottom-tabs PR #524

- Commit: `54283150c216ccd31566d3f07d48f70f5faac44a` (PR head / fix expected)
- Simulator: PRVerify-After (`4BC3882D-85AD-4A5B-AC82-F515553A8713`)
- Bundle id: `bottomtabs.example`

## Build

Release simulator build via `build-ios.sh`, succeeded on first attempt (`** BUILD SUCCEEDED **`
in `build.log`). App path:
`.../after/src/apps/example/ios/DerivedData/Build/Products/Release-iphonesimulator/ReactTestApp.app`.

## Repro walkthrough

1. Launched app; home list "BottomTabs Example" showed rows including "Tab Bar Hidden" (no
   scroll needed, row sat at normalized y≈0.544-0.603).
2. Tapped "Tab Bar Hidden" → screen titled "Tab Bar Hidden" appeared with "Article" text,
   a "Hide Tab Bar" button, and a native tab bar (Article / Albums / Contacts) at the bottom
   (`AXGroup "Tab Bar" (0.000, 0.905, 1.000, 0.095)`).
3. Captured baseline (`step-02.png`) — tab bar clearly present.
4. Tapped "Hide Tab Bar" → button label changed to "Show Tab Bar" (`await-ui-element`
   succeeded), confirming JS state toggled.
5. **Decisive moment**: after `await-screen-idle` (~550ms settle) and an extra ~1s wait,
   `describe` returned only:
   - `AXButton "BottomTabs Example" id="BackButton"`
   - `AXGroup "Tab Bar Hidden"` (nav title)
   - `AXStaticText "Article"`
   - `AXButton "Show Tab Bar"`

   No `Tab Bar` group, no `Albums`, no `Contacts` anywhere in the tree. The full-resolution
   screenshot (`decisive.png`) shows an empty gray area below the "Show Tab Bar" button —
   the native tab bar is completely gone. This matches the brief's `bug_absent` criteria
   exactly (no tab-bar items in describe; screenshot shows only Article + Show Tab Bar on an
   otherwise empty screen).
6. Control step: tapped "Show Tab Bar" → tab bar reappeared with Article/Albums/Contacts and
   the button label reverted to "Hide Tab Bar" (`step-04.png`), showing the underlying
   TabView still works normally when the prop isn't set.

## Verdict

`bug_absent` — confidence 0.98. The `tabBarHidden` prop is honored: the native tab bar
disappears on demand and the app behaves as PR #524 describes for the fixed state.

## Evidence

- `after/step-00.png` — home list
- `after/step-02.png` — Tab Bar Hidden screen, tab bar visible (baseline)
- `after/decisive.png` (full resolution) + `after/decisive-describe.txt` — decisive moment,
  tab bar absent
- `after/step-04.png` — tab bar restored after "Show Tab Bar" (control)
- `after/recording.mp4` — full screen recording (7.47s effective, static stretches trimmed),
  verified playable with `ffprobe`
- `after/build.log` — full build log (BUILD SUCCEEDED)
