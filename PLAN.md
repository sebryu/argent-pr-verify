# argent-pr-verify — plan

Goal: a Claude Code skill that takes a pull-request URL, runs two agents in parallel
(one on the PR's base commit, one on its head), reproduces the linked issue on an
iOS simulator with Argent, records before/after evidence, and states whether the
fix is verified. Then the same skill runs on a GitHub Actions macOS runner with
Claude Haiku. Finish line: a green GHA run whose artifacts contain before/after
screen recordings for a real, already-merged fix in a popular React Native repo.

## Constraints given by the user

- Fleet of up to 8 parallel agents; plan before implementing.
- Local verification subagents: always `claude-sonnet-5`.
- CI agent: always Haiku (`claude-haiku-4-5-20251001`).
- Reference CI recipe: react-native-gesture-handler `ios.yml` → `ios-build.yml` +
  `ios-e2e.yml` + `.github/actions/argent-server` (npx `@swmansion/argent init --yes`,
  `argent server start --no-auth --port 3001`, simctl boot, simctl install).

## Facts established during research

- Argent 0.23.0 is installed locally; tool-server is running; `argent run <tool>`
  drives the simulator from the shell, `argent mcp` exposes the same tools over MCP.
- Claude Haiku works in GitHub Actions with the existing `CLAUDE_CODE_OAUTH_TOKEN`
  secret in `sebryu/claude-session-share` (smoke run 33925129183: both `claude -p`
  and `anthropics/claude-code-action@v1` succeeded). The token cannot be copied to
  another repo, so the real run is hosted there via a thin caller workflow that
  calls the reusable workflow in this repo with `secrets: inherit`.
- Target PR/issue: see `TARGET.md` (chosen after the PR hunt).

## Architecture

```
skills/argent-pr-verify/SKILL.md          the skill (orchestrator + single-state modes)
skills/argent-pr-verify/references/       brief template, subagent prompt, report schema
scripts/resolve-pr.sh                     PR → JSON (base/head/merge SHAs, linked issues)
scripts/prepare-worktrees.sh              before/after worktrees + optional repro patch
scripts/simulator.sh                      create/boot/delete dedicated simulators
scripts/compose-report.sh                 two report.json + evidence → REPORT.md
.github/workflows/verify-pr.yml           reusable (workflow_call) + workflow_dispatch
.github/actions/argent-server/action.yml  copied recipe from gesture-handler
examples/<repo>-pr-<n>/                   repro patch + brief used for the demo
```

### Skill flow (local, orchestrator mode)

1. Resolve the PR with `gh` and extract linked issues (`fixes #N`, issue URLs, or `--issue`).
2. Write a *verification brief*: bug summary, repro steps mapped to the example app,
   expected BEFORE (bug visible) and AFTER (bug gone), evidence to capture.
   If the example app has no screen exercising the bug, the brief includes a
   repro patch (new example screen only, never library code) applied to both states.
3. Prepare `.pr-verify/<pr>/before` and `/after` worktrees, apply the patch to both,
   create two dedicated simulators so both runs proceed in parallel without collisions.
4. Spawn two subagents (model sonnet) with identical instructions except state,
   worktree, simulator UDID and output dir. Each builds/installs the app, starts an
   Argent screen recording, follows the brief step by step with screenshots, stops the
   recording and writes `report.json` (`verdict: bug_present | bug_absent | inconclusive`).
5. Compose `REPORT.md`: side-by-side screenshots, recording paths, final verdict
   (`FIX VERIFIED` only when before=bug_present and after=bug_absent).

### Skill flow (CI, single-state mode)

`brief` job (ubuntu, Haiku) → `verify` matrix `[before, after]` (macos-26: build the
example app at that SHA, boot simulator, install app, start Argent, run Haiku with the
skill in single-state mode, upload evidence) → `compare` job (compose REPORT.md, write
the job summary, fail if the verdict is not FIX VERIFIED).

## Fleet

| # | Agent | Model | Task |
|---|-------|-------|------|
| R1–R2 | pr-hunt-* | sonnet | find a visibly reproducible merged PR/issue pair |
| R3 | ci-claude-research | sonnet | headless Claude Code + MCP on macos runner |
| R4 | argent-cheatsheet | sonnet | verified `argent run` command reference |
| I1 | skill-author | opus | SKILL.md + references |
| I2 | scripts-author | opus | shell scripts + report composer |
| I3 | workflow-author | opus | reusable + caller workflows, argent-server action |
| I4 | repro-author | opus | repro patch for the target (if needed), compiles locally |
| V1 | before-agent | sonnet | local run, base commit |
| V2 | after-agent | sonnet | local run, head commit |
| V3 | reviewer | sonnet | verify skill/scripts/workflow against this plan |

## Milestones

1. ✅ Target chosen (react-native-bottom-tabs#524), TARGET.md written — 2026-09-05.
2. ✅ Skill + scripts drafted; sonnet review in progress.
3. ✅ Local before/after run: FIX VERIFIED (before=bug_present, after=bug_absent);
   evidence archived in `examples/callstack-react-native-bottom-tabs-pr-524/local-run-2026-09-05/`.
4. ⏳ Workflow pushed; caller dispatched from `claude-session-share`
   (`.github/workflows/argent-pr-verify.yml`); waiting for a green run.
