# Argent CLI cheat sheet (verified against argent 0.23.0, iOS simulator)

Every command below was run for real. `$UDID` is the simulator UDID from `list-devices`.
Use the CLI (`argent run <tool>`) when MCP tools are not available; the MCP tools have
the same names and arguments.

## Targeting the tool-server

Resolution order: `ARGENT_TOOLS_URL` env var → `~/.argent/link.json` (`argent link`) →
auto-spawned local server (`~/.argent/tool-server-*.json`). With `ARGENT_TOOLS_URL` set and
nothing listening you get `TypeError: fetch failed`; there is no fallback. CI pattern:

```bash
argent server start --no-auth --port 3001 &   # see .github/actions/argent-server
export ARGENT_TOOLS_URL=http://127.0.0.1:3001
argent run list-devices
```

`argent mcp` follows the same resolution order, so set `ARGENT_TOOLS_URL` in the MCP
server `env` on CI. `argent server start` refuses to start a second server when one is
already registered (it asks for `--force`, which kills the existing one) — locally, reuse
the running server instead.

## Devices and apps

```bash
argent run list-devices --json                                   # {devices:[{platform,udid,name,state,runtime,runtimeKind}], avds:[...]}
argent run launch-app  --udid $UDID --bundleId com.example.app   # {"launched":true}
argent run restart-app --udid $UDID --bundleId com.example.app   # {"restarted":true}
argent run reinstall-app --udid $UDID --appPath /path/App.app    # installs (replaces) the bundle
argent run open-url    --udid $UDID --url "myapp://screen"       # {"opened":true}
argent run await-screen-idle --udid $UDID --timeoutMs 8000       # {"settled":true|false,"waitedMs":…}; false is not fatal
```

## Looking at the screen

```bash
argent run screenshot --udid $UDID --out step-01.png                                   # 0.25 scale by default (302x656)
argent run screenshot --udid $UDID --scale 1.0 --includeImageInContext false --out full.png   # device-native PNG, still written to --out
argent run describe   --udid $UDID                                                     # {description, source, hint?}
```

`describe` prints one element per line, e.g.
`AXButton "General" id="com.apple.settings.general"  (0.040, 0.435, 0.920, 0.059)`.
The four numbers are **normalized** `(x, y, w, h)` in 0..1 — the same space gesture tools
use. Tap centre = `x + w/2`, `y + h/2`. Re-run `describe` after every scroll or navigation;
stale coordinates land on the wrong element. Hit-testing is exact, not fuzzy.

## Interacting

```bash
argent run gesture-tap   --udid $UDID --x 0.5 --y 0.46                              # {"tapped":true}
argent run gesture-swipe --udid $UDID --fromX 0.5 --fromY 0.7 --toX 0.5 --toY 0.3 --durationMs 400
argent run gesture-custom --udid $UDID --args '{"udid":"'$UDID'","events":[...]}'   # long-press etc. (see `argent tools describe gesture-custom`)
argent run keyboard      --udid $UDID --text "hello"
argent run button        --udid $UDID --button home
argent run await-ui-element --udid $UDID --condition text --selector-json '{"text":"About"}' --expectedText "About"   # {"success":true,"elapsed":517}
argent run await-ui-element --udid $UDID --condition visible --selector-json '{"text":"Settings"}' --timeoutMs 10000
argent run run-sequence  --udid $UDID --steps-json '[{"tool":"gesture-tap","args":{"x":0.5,"y":0.46}},{"tool":"await-ui-element","args":{"condition":"text","selector":{"text":"About"},"expectedText":"About"}}]'
```

Object/array fields need `--<field>-json`; inside `--steps-json` nested objects are plain
JSON. `--args '<json>'` (or `--args -` for stdin) passes the whole payload at once.

## Screen recording

```bash
argent run screen-recording-start --udid $UDID --timeLimitSeconds 180 --json
# {"status":"recording","timeLimitSeconds":180,"outputFile":"/var/folders/.../tmp.mp4"}  <- temp path, not the final file
… drive the repro; every tool result carries a NOTE while recording …
argent run screen-recording-stop --udid $UDID --json
# {"video":"~/.argent/recordings/screen-recording-<udid>-<ts>.mp4","durationMs":6433,"wallClockMs":10593,"trimmedMs":4160}
```

- The final file is the `video` path from **stop**. It lands in `<project>/.argent/recordings/`
  when the cwd is inside a project (has `.git`, `package.json` or `.argent`), otherwise in
  `~/.argent/recordings/`. Copy it to the evidence directory right away.
- Static stretches are trimmed by default; pass `--trimStatic false` for wall-clock timing.
- Touches are drawn into the video by default (`--showTouches false` to disable).
- Never leave a recording running: stop it in every exit path (also on failure).
- `ffprobe -show_entries format=duration -of csv=p=0 <file>` verifies the mp4.

## Visual diff

```bash
argent run screenshot-diff --udid $UDID --baselinePath full.png --captureCurrent --outputDir ./diff
# {"pixel_mismatch":"9.32%","regions":[{x,y,w,h}...],"diffPath":"…","contextDiffPath":"…"}
```

## Simulator hygiene

- Create dedicated simulators for verification runs (`scripts/simulator.sh ensure <name>`),
  never reuse ones other sessions may be driving.
- A simulator booted with `xcrun simctl boot` works fine; `describe` adds a hint that some
  system dialogs may be missing from the tree.
