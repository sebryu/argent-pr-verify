# report.json — written by each state agent (before / after)

One file per state at `<out-dir>/<state>/report.json`. Keep it small and machine-readable;
the human-readable narrative goes in `<out-dir>/<state>/notes.md`.

```json
{
  "state": "before",                       // "before" | "after"
  "sha": "0d25288c…",                      // commit the app under test was built from
  "app": { "bundleId": "com.example.app", "udid": "SIMULATOR-UDID" },
  "verdict": "bug_present",                // "bug_present" | "bug_absent" | "inconclusive"
  "confidence": 0.9,                       // 0..1, how sure the agent is about the verdict
  "summary": "Drawer opened at the old speed after the prop changed.",
  "steps": [
    {
      "n": 1,
      "action": "Open the ReanimatedDrawerLayout example",
      "observed": "Example screen rendered with the drawer closed",
      "screenshot": "before/step-01.png"
    }
  ],
  "evidence": {
    "recording": "before/recording.mp4",   // path relative to <out-dir>
    "screenshots": ["before/step-01.png", "before/step-02.png"],
    "extra": []                            // logs, component trees, diffs…
  },
  "startedAt": "2026-09-05T10:00:00Z",
  "finishedAt": "2026-09-05T10:04:12Z"
}
```

Rules:
- `verdict` answers one question only: *is the bug from the brief visible in this state?*
  It is never "pass/fail" — the orchestrator decides pass/fail by combining both states.
- Use `inconclusive` (with the reason in `summary`) when the app could not be built,
  installed, or navigated to the repro screen. Never guess.
- Every path is relative to `<out-dir>` so the report survives being uploaded as a CI artifact.
