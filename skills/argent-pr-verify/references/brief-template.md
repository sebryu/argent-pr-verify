# Verification brief — <repo>#<pr> · <title>

Filled in by the orchestrator. Both state agents receive this file verbatim, so every
step must be executable by an agent that has never read the PR or the issue.

## Bug

- Issue: <url> — <one-sentence bug statement in user-visible terms>
- PR: <url> — <what the fix changes, one sentence; list the library files touched>
- before = `<base sha>` (bug expected) · after = `<merge/head sha>` (fix expected)

## App under test

- Example app dir: `<path in repo>` · bundle id: `<com.example.app>` · scheme/workspace: `<Scheme>` / `<ios/App.xcworkspace>`
- Repro patch: `<none | repro.patch — adds <screen> to the example app; touches example app only>`
- Build recipe (Release, simulator, run from `<dir>`):
  ```bash
  <js install command>
  <pods command, if any>
  xcodebuild -workspace <X>.xcworkspace -scheme <S> -configuration Release -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
  # .app: <dir>/build/Build/Products/Release-iphonesimulator/<Name>.app
  ```
- Expected build time: <n> min locally · <n> min on a GitHub macos runner

## Repro steps (identical for both states)

Write each step as: action → what should appear. Use visible text or accessibility ids,
never coordinates.

1. Launch the app → home screen shows "<text>".
2. Tap "<text>" → screen "<title>" appears.
3. <action> → <what appears>.
4. **Decisive moment**: <the single observation that decides the verdict>.

## Decision rule

- `bug_present` when: <precise, observable condition — element present/absent, frame overlap, text, count>.
- `bug_absent` when: <the opposite, equally precise>.
- Evidence to capture at the decisive moment: full-resolution screenshot; `describe` dump; <any other>.
- Anything else (screen not reachable, app crash unrelated to the bug, build failure) → `inconclusive` with the reason.

## Expectations (for the report, not for the agents' judgement)

- before (`<base sha>`): bug_present — <what it looks like>
- after (`<head sha>`): bug_absent — <what it looks like>
