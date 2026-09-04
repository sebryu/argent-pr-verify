# argent-pr-verify

A Claude Code skill that answers one question about a pull request: **does it actually fix
the issue it says it fixes?** It reproduces the bug on an iOS simulator with
[Argent](https://github.com/software-mansion/argent) at the PR's base commit and at its
head, records both runs, and writes a before/after report with a verdict.

```
/argent-pr-verify https://github.com/owner/repo/pull/123
```

Locally two Sonnet subagents run in parallel on two dedicated simulators. On GitHub Actions
the same skill runs in single-state mode on a `macos-26` runner with Claude Haiku, one job
per state, and the workflow publishes the recordings as artifacts.

## Layout

| Path | What |
|---|---|
| `skills/argent-pr-verify/SKILL.md` | the skill (orchestrator + single-state procedure) |
| `skills/argent-pr-verify/references/` | brief template, state-agent prompt, report schema, verified Argent CLI cheat sheet |
| `scripts/resolve-pr.sh` | PR URL → `pr.json` (SHAs, files, linked issues) |
| `scripts/prepare-worktrees.sh` | before/after worktrees, optional repro patch |
| `scripts/simulator.sh` | dedicated simulators (ensure / delete / quiet-keyboard) |
| `scripts/compose-report.sh` | two `report.json` → `REPORT.md` + verdict |
| `.github/workflows/verify-pr.yml` | reusable workflow (`workflow_call` + `workflow_dispatch`) |
| `.github/actions/argent-server` | install Argent + start the tool-server (from react-native-gesture-handler) |
| `examples/<target>/` | per-target `brief.md`, `build-ios.sh`, optional `repro.patch` |

## Install the skill

```bash
ln -s "$PWD/skills/argent-pr-verify" ~/.claude/skills/argent-pr-verify
```

Requirements: Claude Code, `gh` (authenticated), `argent` (`npx @swmansion/argent init`),
Xcode with an iOS simulator runtime, `jq`, `ffmpeg`.

## Run it in CI

The workflow needs a `CLAUDE_CODE_OAUTH_TOKEN` secret (from `claude setup-token`). Call it
from any repository that has the secret:

```yaml
jobs:
  verify:
    uses: sebryu/argent-pr-verify/.github/workflows/verify-pr.yml@main
    with:
      pr_url: https://github.com/owner/repo/pull/123
      example_dir: examples/owner-repo-pr-123
    secrets: inherit
```

`example_dir` points at a directory in this repo with the brief and the build script for
that target (see `examples/`). The `report` job writes the verdict to the job summary and
fails unless the verdict is **FIX VERIFIED**.
