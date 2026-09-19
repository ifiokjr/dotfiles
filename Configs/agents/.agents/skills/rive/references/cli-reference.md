# Rive CLI reference

Verified against **rive 1.0.3**. `rive --help` is authoritative for the installed version; this file adds the behavior that the help text does not spell out.

## Commands

```bash
rive create [dir]                  # scaffold a project (dir must be empty or new)
rive create [dir] --from-rev=<f>   # convert an editor .rev into a project
rive <dir>                         # watch: preview window, rebuilds on save
rive docs [topic]                  # authoring reference, bundled with the binary
rive schema <Type>                 # properties of a type, inherited included
rive samples                       # copy a runnable example project
rive inspect [dir]                 # resolved scene as JSON
rive push [dir]                    # build and push the .rev to a bound Rive file
rive doctor [project-dir]          # environment check
rive lsp [project-dir]             # language server over stdio
rive login | logout | whoami
rive --version
```

There is no `build`, `export`, `render`, or `watch` subcommand. Those are flags on `rive <dir>`; a bare invocation is the watcher.

`rive create` writes `rive.yaml`, `scene.rml`, `AGENTS.md`, `CLAUDE.md` (which is just `@AGENTS.md`), and a `.gitignore` containing `build/`. It nests into an existing directory rather than erroring, so confirm the target is empty.

## Build modes on `rive <dir>`

Mutually exclusive.

| Flag | Behavior |
|---|---|
| `--verify` | Compile RML, Luau, and WGSL; write nothing. Exit 1 on errors |
| `--once` | Write an unsigned `.riv` to `build/<name>.riv` |
| `--publish` | Write a signed `.riv`. Needs `rive login` |
| `--test` | Run `Tests` scripts headlessly. Exit 6 on failures |
| `--screenshot[=<path>]` | Build, render one frame headless, write a PNG |
| `--semantics[=<path>]` | Write the accessibility tree as JSON |
| `--data-dump[=<path>]` | Write bound view model values as JSON (`-` for stdout) |
| `--bench=<frames>` | Time frames headless; report advance/render stats |

`screenshot` defaults to `build/<name>.png`; `semantics` to `build/<name>.semantics.json`; `data-dump` to `build/<name>.data.json`. The screenshot path resolves against the current directory, not the project directory, and a missing directory fails with only `screenshot failed: <path>`. Create it first.

## Modifiers

| Flag | Behavior |
|---|---|
| `--init` | Write `rive.yaml` if missing, then continue |
| `--rev=<path>` | Also write an editor `.rev`. Needs `rive login`; with `--once`/`--publish` |
| `--artboard=<name>` | Artboard shown on launch |
| `--viewport=<WxH>` | Layout size; the capture size in headless modes |
| `--fit=<mode>` | `fill`, `contain`, `cover`, `fit-width`, `fit-height`, `none`, `scale-down`, `layout` (default) |
| `--serve[=port]` | Push builds to connected players (default 9640) |
| `--headless-serve` | Serve with no local window |
| `--debug[=port]` | Script debugger for VS Code (default 9641, loopback only) |
| `--optimize` | Compile scripts at Luau O2 instead of O1 |
| `--immediate` | Render on the main thread |
| `--quiet` | No terminal log, compiler errors included |
| `--define=<NAME[=n]>` | AssemblyScript build constant; repeatable |
| `--format=json` / `--json` | Machine-readable envelope with `--once`/`--verify`/`--publish`/`--test` |

`--viewport` is not a fit. An artboard that lays itself out reflows into it, and that is what makes it the responsiveness check. A fixed-size artboard renders at its authored size anchored top-left, so a small viewport crops it. That is the flag working, not a layout bug. Every `--fit` mode except `layout` leaves the artboard at its authored size and scales into the window instead.

## Driving the scene

These need `--screenshot`, `--semantics`, or `--data-dump`; without one they are usage errors. They share one ordered queue, replayed in the order written.

| Flag | Behavior |
|---|---|
| `--advance=<N\|Ns\|Nms>` | Step the scene at this point in the sequence. Bare N = frames at 60fps. Repeatable |
| `--pointer=<kind@x,y>` | `down`, `up`, `move`, `click`; `drag@x1,y1>x2,y2[:steps]` |
| `--key=<key[:phase][+mods]>` | `down`, `repeat`, `up`, or `press` (the default) |
| `--gamepad=<event>` | `connect`, `disconnect`, `button@name:down\|up\|0..1`, `axis@name:<-1..1>` |
| `--semantic-action=<type@label>` | Fire `tap`, `increase`, `decrease` on that accessibility label |
| `--data=<path=value>` | Set a bound view model property before the scene runs; repeatable |
| `--data-dump-filter=<paths>` | Comma-separated property paths, globs allowed (`battery/*,score`) |
| `--data-dump-every=<N\|Ns\|Nms>` | Sample every N frames as JSON Lines instead of one snapshot |

Details that change results:

- A capture with no `--advance` is the pose before anything advanced. Start previews at `--advance=1`.
- `--advance` steps where you put it, not from scene time zero. One before a click runs an intro first.
- `click` is a move, a press, and a release with a frame between each.
- Quote drag values. The `>` is a shell redirect otherwise: the flag gets truncated and a file named `200,80:12` appears in the working directory.
- The drag step count is the velocity. A capture is deterministic, so fling distance is reproducible and a fling that lands identically at every step count is not carrying momentum.
- Gamepad names are W3C (`south`, `dpadLeft`, `leftX`). A bare index is W3C 0-based, but a Luau `gamepadEvent` reads the same slot as `changeIndex` plus 1. Prefer names.
- `--data` paths are relative to the instance bound to the artboard and never include the view model's own name. A flat view model takes the bare property (`--data=level=100`).
- Keys reach only what holds focus, and a headless run starts with nothing focused unless the file establishes it. `--key` says so rather than silently matching nothing.
- Every listener whose target contains the point fires. Drawing over something does not block it unless the thing on top is `isTargetOpaque`, and a fully transparent fill is still hit-testable.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | OK |
| 1 | Build errors, or a failure with no more specific code |
| 2 | Usage: bad flag value, unknown flag, two build modes at once, an interaction with no capture mode |
| 3 | Not logged in |
| 6 | Test cases failed (the build itself was fine) |
| 7 | A service could not be reached. Safe to retry |

An unrecognized flag is a hard exit-2 error, so a green exit does mean your flags landed. But `--artboard` with an unknown name silently falls back to the first artboard and exits 0.

## JSON output

`--format=json` (alias `--json`) with `--once`/`--verify`/`--publish`/`--test` writes one envelope on stdout, logs on stderr:

```json
{"success": true, "command": "verify", "data": {"riv": null, "bytes": 0, "buildMs": 12.9, "problems": []}, "errors": [], "warnings": []}
```

`data.problems[]` entries carry `{severity, kind, code, script, line, column, message}` and `severity` is one of `error`, `warning`, `hint`.

`line` and `column` are zero-based in JSON, one-based in the terminal log and in `rive inspect`. Add 1 before showing a human.

`rive inspect . --json` is JSON-native, as are `--data-dump`, `--semantics`, `rive schema --json`, and `rive doctor --format=json`. `--summary` gives problems plus object counts per type per artboard.

## Inspecting the built document

```bash
rive inspect . --summary                                # problems + counts by type
rive inspect . --json                                   # full resolved tree
rive inspect . --artboard=<name>                         # one artboard
rive inspect . --json | jq '[..|objects]|length'         # object count (must rise per pass)
rive inspect . --json | jq '.problems'                   # problems
rive inspect . --json | jq -c '[..|objects|select(.type?=="LayoutComponent" and .styleId==null)]|length'
```

The last one asserts every layout box still has its style linked. Anything other than `0` means a box was added without its `LayoutComponentStyle` and will not lay out as written.

Nodes carry a `line` field pointing back at the source, and enums are decoded alongside their integer:

```json
{"type":"KeyedProperty","line":38,"propertyKey":18,"children":[
  {"type":"KeyFrameDouble","line":39,"value":1,"frame":0,
   "interpolationType":2,"enums":{"interpolationType":"cubic"},
   "children":[{"type":"CubicEaseInterpolator","line":40,"x1":0.42,"y1":0,"x2":0.58,"y2":1}]}]}
```

That makes keyframe readback a direct assertion: pull the `KeyedProperty` for a property key, then check the frames and values. `interpolationType` reads back as an integer with the name under `.enums`. `interpolatorId` is never emitted. `computed*` values are `0` until something lays the scene out.

`List<Id>` properties (such as a bind's `sourcePathIds`) are omitted from the tree, so a bind's path is not visible in `inspect`. `problems` is the only readback for those.

The `problems` kinds actually checked include `syntax`, `unresolved-bind-path`, `bind-target-missing-property`, `incompatible-bind-types`, `missing-reference`, `no-default-state-machine`, `no-artboards`, `derived-property-authored`, `incomparable-condition`, `duplicate-script-name`, `paint-without-shape-paint`, `scroll-without-physics`, `draw-target-not-child-of-rules`, `artboards-overlap`, `states-overlap`, `listener-converter-on-write`, `artboard-without-style`. A required reference being present is checked; whether it resolves is not.

## Logs

`rive.yaml` can opt into files that are easy to script around:

```yaml
name: myproject
logs:
  file: build/rive.log        # append-only, interleaved problems/print/system
  problems: build/problems.log # rewritten per build, with a generation header
```

`problems.log` is the one to read when scripting: it opens with a header like `# rive generation 4 | 1 errors, 0 warnings | FAILED`, then one line per problem.

## Preview-window commands

With the watcher running, type into its terminal: `s|screenshot [path]`, `p|pause`, `a|artboard [name]`, `f|fit [mode]`, `z|size`, `d|data [path]`, `rev [path]`, `?|help`.

The window opens at the artboard's size and follows it until you drag it. `z` resumes following. The default fit is `layout`, so dragging the window is a real reflow rather than a zoom, which is what makes the window a responsive check.

## Environment

| Variable | Effect |
|---|---|
| `RIVE_NO_TUI` | Any value but `0` disables pickers; they print lists instead |
| `TERM` | Unset, empty, or `dumb` disables pickers |
| `NO_COLOR` | Disable color |
| `RIVE_HOME` | Defaults to `~/.rive` |
| `XDG_CONFIG_HOME` | Relocates stored credentials on macOS and Linux |
| `RIVE_DOCS_DIR`, `RIVE_SAMPLES_DIR` | Override the bundled docs and samples |
| `RIVE_API_BASE` | API host; also isolates the stored login |

Pickers draw on stderr, so `rive samples > log` still prompts. Set `RIVE_NO_TUI=1` in scripts and CI.

Credentials live in `~/.config/rive/app.rive.cli/` on macOS and Linux, and in Windows Credential Manager. A process with a different `HOME` reports `Not logged in` even on a signed-in machine.

## Project layout

```
myproject/
  rive.yaml      project config
  scene.rml      the scene: artboard, timelines, state machines
  AGENTS.md      agent instructions (written by `rive create`)
  CLAUDE.md      imports AGENTS.md
  .gitignore     build/
  build/         generated: <name>.riv, <name>.png, logs
```

`rive.yaml` requires only `name`. Other keys: `main` (default artboard by name), `debugLevel`, `optimizationLevel` (`none|medium|max`), `shaderOutputs`, `artboard` (`width`/`height`/`background`), `artboards` (per-artboard overrides), `exclude`, `excludeFromRev`, `revFlavor` (`editable|library`), `push`, `window` (macOS), `output.dir` (default `build`), `logs`. Unknown keys are ignored without warning.

A project may hold any number of `.rml` files in any folders; they compile as one document, which is how a scene splits across files. Also accepted: `.luau` scripts, `.wgsl` shaders, `.png`/`.jpg`/`.jpeg`/`.webp` images, and fonts. Anything else becomes a blob asset. `rive.yaml`, `.riv`, `.rev`, and `.log` are skipped.

## Samples

`rive samples --path` prints the directory; ten runnable projects ship with the binary:

| Shows | Sample |
|---|---|
| The smallest RML document: one artboard, one shape | `rml_triangle` |
| The smallest layout script: draw a moving shape each frame | `hello_rive` |
| RML driven by view model data, with a script input | `rml_vm_input` |
| The same scene split across files | `rml_split` |
| Pointer to view model to data bind | `pointer_reactive` |
| Editable text fields via the TextInput component | `text_input` |
| A keyboard menu with no script at all | `keyboard_menu` |
| Luau unit tests, run with `--test` | `tests_demo` |
| Keyboard, text and gamepad events in a script | `input_demo` |
| An app shell under the macOS traffic lights | `integrated_titlebar` |

Copy one out as a starting point. `keyboard_menu`, `pointer_reactive`, `text_input`, and `rml_split` are the richest RML exemplars.

## Publishing

- `--once` writes an unsigned `.riv`; any runtime can load it locally.
- `--publish` writes a signed one through the Rive compile service. Needs `rive login`.
- A file carrying scripts that is destined for the web must be published with `--publish`. The CDN and web runtimes reject unsigned scripts, and nothing locally warns you.
- Publish caps at 100 scripts and 10 MB, and fails closed.
- `--rev` writes the editable document for the Rive Editor.
- `rive push` syncs the project to a Rive file and records `push: {projectId, fileId}` in `rive.yaml`.
