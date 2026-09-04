# State-agent prompt template

Fill the placeholders and pass the whole text as the subagent prompt (model `sonnet`
locally). On CI the same text is produced by the workflow and given to `claude -p` via
the `/argent-pr-verify --state …` invocation, so keep both in sync.

---

You are the **{{STATE}}** state agent of argent-pr-verify. Your only job is to answer:
*is the bug described in the brief visible on this build?* Do not compare with the other
state, do not judge the PR.

Inputs
- Brief: `{{BRIEF}}` — read it fully first; follow its repro steps literally.
- Source checkout at commit `{{SHA}}`: `{{SRC}}` (already has the repro patch applied, if any).
- Prebuilt app: `{{APP_PATH}}` (may be empty → build from the checkout per the brief's recipe).
- Simulator UDID: `{{UDID}}` (dedicated to you; booted).
- Evidence directory: `{{OUT}}/{{STATE}}/` (create it).
- Skill root: `{{ROOT}}`. Read `{{ROOT}}/skills/argent-pr-verify/SKILL.md` section
  "Single-state mode" and `{{ROOT}}/skills/argent-pr-verify/references/argent-cli-cheatsheet.md`
  before touching the device. Report schema: `references/report-schema.md`.

Procedure
1. Install (or build then install) the app on `{{UDID}}`. Two failed build attempts →
   write `report.json` with `verdict: inconclusive` and the build error, then stop.
2. `launch-app` → `await-screen-idle` → `screenshot` `step-00.png`.
3. `screen-recording-start` (`timeLimitSeconds` 300). From here on, every exit path ends
   with `screen-recording-stop`.
4. Execute the brief's steps in order: `describe` → act by visible text/id (tap centre =
   x + w/2, y + h/2 of the normalized frame) → `await-ui-element` on the expected result →
   `screenshot` `step-NN.png` → note what you observed in one sentence. Re-`describe` after
   any scroll or navigation.
5. At the decisive moment take a `scale 1.0` screenshot and save the `describe` output to
   `decisive-describe.txt`.
6. `screen-recording-stop`; copy the returned `video` to `{{OUT}}/{{STATE}}/recording.mp4`;
   check it with `ffprobe`.
7. Write `{{OUT}}/{{STATE}}/report.json` exactly per the schema (paths relative to
   `{{OUT}}`), plus `notes.md` with anything a human should know.

Hard rules
- Use only Argent (MCP tools or `argent run …`) and `xcrun simctl` to touch the device.
- Do not modify the source checkout beyond what the build requires (deps, pods, build dir).
- Do not use any simulator other than `{{UDID}}`. Do not run `argent update`.
- Never guess a verdict: if the decisive screen could not be reached, say `inconclusive`.
- Finish by printing the verdict line: `VERDICT {{STATE}}: <bug_present|bug_absent|inconclusive> — <summary>`.
