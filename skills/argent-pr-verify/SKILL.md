---
name: argent-pr-verify
description: Verify that a pull request really fixes the issue it references. Reproduces the bug on an iOS simulator with Argent at the PR's base commit (before) and at its head (after), records a screen video plus step screenshots for both states, and writes a before/after report with a verdict. Use when asked to verify a PR fix, check whether a PR resolves an issue, or produce before/after evidence for a PR. Orchestrator mode runs two parallel state agents; single-state mode is what CI runs.
---

# argent-pr-verify

Two agents, two commits, one question per agent: **is the bug from the brief visible on
this build?** The orchestrator turns the two answers into a verdict.

| before (base commit) | after (head commit) | verdict |
|---|---|---|
| bug_present | bug_absent | ✅ FIX VERIFIED |
| bug_present | bug_present | ❌ NOT FIXED |
| bug_absent | any | ⚠️ BUG NOT REPRODUCED BEFORE |
| inconclusive | any | ⚠️ INCONCLUSIVE |

Paths below are relative to the skill repository root (the directory that contains
`scripts/` and `skills/`). Resolve it once: the skill file lives in
`<root>/skills/argent-pr-verify/SKILL.md`, or `~/.claude/skills/argent-pr-verify` is a
symlink into it. Call it `$ROOT`.

## Invocation

```
/argent-pr-verify <pr-url> [--issue <n|url>]... [--app-dir <dir-in-repo>] [--repro-patch <file>] [--out <dir>] [--keep-simulators]
/argent-pr-verify --state before|after --brief <brief.md> --sha <sha> --udid <UDID> --bundle-id <id> [--app-path <App.app>] [--src <checkout>] --out <dir>
```

The first form is **orchestrator mode** (local). The second is **single-state mode**: one
agent, one build, one state — used by CI, where the workflow already built and installed
the app. Default `--out` is `.pr-verify/<repo-owner>-<repo-name>-pr-<n>` in the cwd.

## Orchestrator mode

### 1. Resolve the PR

```bash
mkdir -p "$OUT" && "$ROOT/scripts/resolve-pr.sh" "$PR_URL" [--issue N]... > "$OUT/pr.json"
```

`pr.json` carries `before` (base SHA), `after` (merge commit, or head when unmerged),
`files`, the PR body and every linked issue with its comments. If `issues` is empty, ask
the user for the issue or derive the bug from the PR description, and say so in the brief.

### 2. Write the verification brief

Copy `references/brief-template.md` to `$OUT/brief.md` and fill every section. The brief
is the single source of truth for both state agents, so it must be executable by an agent
that has never seen the PR: concrete screen names, tap targets by visible text, and the
one observable difference that separates bug-present from bug-absent.

Choosing the repro:
- **Prefer an existing example screen** in the repo's example app at the base commit.
- Otherwise build a **repro patch** that touches the example app only (a new screen plus
  its navigation entry). If the PR itself adds such a screen, use exactly that:
  `git diff <before> <after> -- <example-dir> > $OUT/repro.patch`. Never include library
  source in the patch; the two states must differ only by the PR's fix.
- Record the **build recipe** (JS install, pods, xcodebuild command, scheme, `.app` path,
  bundle id) in the brief. Read the repo's iOS CI workflow first; it usually has it. Use
  Release simulator builds so no Metro is needed and both states behave identically.

### 3. Prepare the two checkouts

```bash
"$ROOT/scripts/prepare-worktrees.sh" "https://github.com/<repo>.git" "$(jq -r .before $OUT/pr.json)" "$(jq -r .after $OUT/pr.json)" "$OUT" [--patch $OUT/repro.patch]
```

This produces `$OUT/before/src` and `$OUT/after/src` (one clone, two worktrees) and applies
the patch to both. When a commit already contains the patch (the after state, if the patch
was cut from the PR itself) it is skipped; any other conflict fails loudly. Pass
`--pr <n>` so PR heads that live in forks can be fetched.

### 4. Dedicated simulators

```bash
UDID_BEFORE=$("$ROOT/scripts/simulator.sh" ensure PRVerify-Before)
UDID_AFTER=$("$ROOT/scripts/simulator.sh" ensure PRVerify-After)
```

Never reuse simulators other sessions may be driving. Two devices let both agents run at
the same time; Argent records each device independently.

### 5. Run the two state agents in parallel

Spawn two subagents in the same message so they run concurrently. **Use model
`sonnet`** for both (local verification runs always use Claude Sonnet). Give each the
prompt from `references/state-agent-prompt.md` with the placeholders filled in
(`STATE`, `SHA`, `SRC`, `UDID`, `OUT`, `BRIEF`, `ROOT`). They must not share a simulator,
a Metro port, or an output directory. Wait for both; do not interpret their transcripts,
only their `report.json`.

### 6. Compose the report

```bash
"$ROOT/scripts/compose-report.sh" "$OUT" --pr-json "$OUT/pr.json" --no-fail
```

Show the user `$OUT/REPORT.md`, the two recording paths, and the verdict. If a state is
`inconclusive`, quote its `summary` — that is the blocker to fix, not a verdict about the
PR. Unless `--keep-simulators` was given, delete the two simulators with
`scripts/simulator.sh delete <name>`.

## Single-state mode (what a state agent does)

This is the procedure every state agent follows, in orchestrator mode and on CI. Read
`references/argent-cli-cheatsheet.md` for the exact tool syntax; MCP tools (`mcp__argent__*`)
and `argent run <tool>` take the same arguments.

1. **Prepare evidence dir** `$OUT/$STATE/`; note `startedAt`.
2. **Get the app on the device.** With `--app-path`, `xcrun simctl install $UDID <App.app>`.
   Without it, build from `--src` following the brief's build recipe, then install.
   Two failed build attempts → verdict `inconclusive`, summary = the build error, stop.
3. **Launch** with `launch-app` (bundle id from the brief), then `await-screen-idle`.
   Take `step-00.png`.
4. **Start recording**: `screen-recording-start` with `timeLimitSeconds` about 2× the
   expected duration (300 is a safe default). From now on every exit path must call
   `screen-recording-stop`.
5. **Follow the brief's repro steps in order.** For each step: `describe` → act on the
   element by its visible text or id (compute the tap centre from the normalized frame) →
   `await-ui-element` on what the brief says should appear → `screenshot` to
   `$OUT/$STATE/step-NN.png` → write one sentence of what you observed. Re-run `describe`
   after every scroll or navigation. If a tap misses twice, re-describe and try once more,
   then mark the step blocked.
6. **Observe the decisive moment** exactly as the brief defines it. Capture it with a
   full-resolution screenshot (`scale 1.0`) and, when the difference is spatial, a
   `describe` dump saved to `$OUT/$STATE/decisive-describe.txt` so the verdict is backed by
   element frames, not only pixels.
7. **Stop recording** and copy the returned `video` file to `$OUT/$STATE/recording.mp4`.
8. **Write `report.json`** (schema in `references/report-schema.md`) and `notes.md`.
   The verdict is about the bug's visibility only: `bug_present`, `bug_absent`, or
   `inconclusive` with the reason. Do not say "pass" or "fail"; do not compare with the
   other state; do not soften a clear observation.

Rules of evidence: screenshots must come from the device (never edited), every reported
step needs a screenshot, and `recording.mp4` must exist and play (`ffprobe`) or the
report must say why not.

## CI notes

- The workflow installs Argent and starts `argent server start --no-auth --port 3001`;
  set `ARGENT_TOOLS_URL=http://127.0.0.1:3001` for both the MCP server and `argent run`.
- Haiku is the CI model. Keep the brief short and literal; it does the thinking up front.
- The state agent is invoked as
  `claude -p "/argent-pr-verify --state before --brief … --udid … --bundle-id … --app-path … --sha … --out …"`
  with the argent MCP server passed via `--mcp-config` and `--allowedTools "Skill,Read,Write,Edit,Bash,Glob,Grep,mcp__argent"`.
  See `.github/workflows/verify-pr.yml`.
- `compose-report.sh` exits non-zero unless the verdict is FIX VERIFIED, which is what
  makes the workflow red or green.

## Gotchas

- `describe` frames and gesture coordinates are normalized 0..1, not pixels.
- Default screenshot scale is 0.25; use `scale 1.0` for the decisive screenshot.
- The recording's final path is the `video` field returned by **stop**; the `outputFile`
  from start is a temp file.
- A Release build has no Metro, so `debugger-*` tools are unavailable; use `describe`.
- Don't run two `argent server start` locally; the CLI reuses the running server.
