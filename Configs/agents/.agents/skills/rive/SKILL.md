---
name: rive
description: >-
  Author Rive animations and interactive graphics as text with the `rive` CLI:
  .rml scenes, Luau scripts, WGSL shaders, state machines, view models, data
  binding. Use when creating or editing a Rive project, when a repo has
  rive.yaml or .rml files, when the user mentions Rive, .riv/.rev files, state
  machines, keyframes, or asks for an animation, interactive graphic, or motion
  asset. Also use when rendering or verifying Rive output.
---

# Authoring Rive with the CLI

The `rive` CLI compiles a directory of plain source files into a `.riv` runtime file and an editable `.rev`. There is no GUI in this loop. You write RML (XML), Luau, and WGSL, then check the result by rendering it.

**RML and the Rive CLI postdate your training data. Never guess a type or property name.** Look it up:

```bash
rive schema <Type>              # properties, inherited included, with keys
rive schema --search <text>     # find the right name first
rive docs <topic>               # the authoring reference, bundled and versioned
rive docs --list                # every topic
```

`rive docs` and `rive schema` read the copy of the docs shipped beside the binary, so they always match the installed version. That reference is ~9,000 lines and is the real authority. This skill is the workflow around it, and it points you at the topic you need.

## The loop

Every edit ends in the same three checks. They answer different questions, and the gaps between them are exactly where silent failures live.

```bash
rive . --verify                        # does it compile?
rive inspect . --summary               # what got built? any problems?
rive . --screenshot --advance=1        # what does it look like?
```

Then look at the PNG. `--verify` and `inspect` are structural hygiene; both can pass an invisible shape, a collapsed icon, or text in the wrong place. CLI rendering checks authored appearance. When the asset ships inside an app, preview the compiled `.riv` there too: data binding, scale, compositing, pause, and lifecycle can differ from the CLI render.

A clean verify/inspect is not evidence the work is correct. Read the output for what the request asked for. If it is missing or wrong, fix it and run the loop again.

### What each check proves

| Command | Answers | Blind to |
|---|---|---|
| `--verify` | Does it compile, and would the `.riv` load? | Anything that only shows when the scene runs |
| `--test` | Do the scripts behave? | Everything with no `Tests` script |
| `inspect` | What is in the document? Are the wires connected? | Anything the exporter drops; anything visual |
| `--screenshot` | Does this authored pose look right? | Other poses, host bindings, composition, and device rendering |
| Host preview | Does the compiled asset behave in its actual surface? | Unvisited states and untested devices |

Two traps worth internalizing:

- `inspect` shows the RML you authored, not the `.riv` that was written. Things can be present in the tree, clean, and still inert at runtime. When something is wired correctly and does nothing, rendering is the evidence, not `inspect`.
- `--verify` does not run anything. A Luau script that type-checks can still throw on its first call, and a `require` that resolves at check time can fail at run time. Scripts need `--test` or a render before you believe them.

## Work in passes

Do not emit a finished screen in one go. Build outside-in, rebuilding after each pass:

1. Wireframe. Every region is an empty filled box, roughly final size. Give every box a `Fill` (an empty box draws nothing) and size it `fixed`/`fill` (a `hug` box with no children has zero size and vanishes).
2. Structure. Add rows, cells, and nested boxes within each region.
3. Text and real content.
4. Art and detail.

Decide the sizing model in pass 1 and do not change it. Switching a box from `fixed` to `hug` later re-lays out everything around it. Finish a region before starting the next. Patch the file; do not regenerate it. Re-emitting a large tree is how closing tags get lost.

The object count must increase every pass. If it drops, an edit truncated the tree:

```bash
rive inspect . --json | jq '[..|objects]|length'
```

Some passes are legitimately invisible. A state machine can add a hundred objects and change the screenshot not at all. For those, the object count and a `jq` readback are the evidence.

## Verify animation as well as structure

A single screenshot is the pose *after* the interactions you listed. Capture a sequence to prove motion:

```bash
rive . --screenshot=build/f0.png  --advance=0
rive . --screenshot=build/f20.png --advance=20
rive . --screenshot=build/f45.png --advance=45
md5 -q build/f0.png build/f20.png build/f45.png | sort -u | wc -l   # must be > 1
```

If those frames are identical, nothing is animating, whatever the keyframes say.

Choose frames around anticipation, peak action, reversal, and recovery, including any brief pose the request names. Distinct frame hashes prove motion exists, not that the intended motion is present. A sampled loop once missed a one-eye wink; rendering its exact frame exposed a two-eye blink. Inspect the images at the size they will actually be seen.

For a time series instead of individual frames, `--data-dump-every` emits JSON Lines. The output starts with a header and a frame-0 baseline, and then includes only what changed:

```bash
rive . --data-dump=- --data-dump-every=20 --advance=60
```

Drive a bound view model with `--data=path=value` (the path is relative to the instance bound to the artboard; the view model's own name is never part of it). To inspect that a bind is live rather than inert, point it at a shape's `opacity`. A value that never changes means nothing arrived.

## Prove interaction works

```bash
rive . --screenshot=rest.png
rive . --screenshot=on.png   --pointer=click@120,60 --advance=20
rive . --screenshot=off.png  --pointer=click@120,60 --pointer=move@400,400 \
                             --pointer=click@120,60 --advance=20
```

Compare the three. `rest` and `on` must differ, or the control does nothing. `off` must match `rest`, or it only works one way. That is the most common state machine bug, and it is invisible to every static check.

- Coordinates are in artboard space, not window pixels.
- `--advance` is an interaction like the gestures. It steps where you put it in the sequence, not from scene time zero.
- Put a filler between two clicks on the same target. A value a listener writes is not visible to the next listener until a frame has passed, so back-to-back clicks can latch.
- `--key`, `--gamepad`, and `--semantic-action` replay through the real dispatch path. Quote drag values (`'--pointer=drag@200,300>200,80:12'`) or the shell eats the `>`.

Prove responsiveness by shooting two viewports; a layout tree and a hand-positioned screen look identical in one screenshot:

```bash
rive . --screenshot=build/wide.png   --viewport=900x600
rive . --screenshot=build/narrow.png --viewport=320x700
```

## Derive motion from an existing rig

When extending a character or reusable asset, keep its body, proportions, skin/trait bindings, and app-facing state-machine contract. Replace only the part that changes, such as the face or an accessory. A new drawing that merely resembles the character can diverge in the game when traits, actions, or scale change.

If generating RML by grafting fragments, remap both object IDs and references into a disjoint range. Recheck the default state machine and view-model binding after replacing animation nodes. Inspect draw order in a render: the first sibling draws on top, so an effect intended to rise *behind* the body must live in the appropriate layer rather than floating over the face. See [object model](references/object-model.md) and [animation](references/animation.md) for the underlying syntax.

Animate the expression through eyes, pupils, brows, and mouth first; use small body squash, held poses, asymmetric details, and eased secondary motion to give it weight. Choose the hold and recovery for the action rather than using linear motion everywhere. In an interactive app, acting should follow the authoritative state; it must not decide whether an input, collision, or reward occurred.

## Check the generated asset in context

For generated assets, rebuild from the authored source and compare the checked-in source and `.riv` with fresh output. A clean `inspect` on a stale generated scene can conceal a changed generator. Do not patch the compiled file to make a preview pass.

Load the final `.riv` through the same runtime and data-binding path as the product. A preview that omits the host's bound view model may show default skin or accessory values and misrepresent the animation. For example, a Flutter preview needs `DataBind.auto()` when the game controller uses it. Check the actual display size, neighboring UI, light and dark surfaces where relevant, pause/resume, and reduced motion. A reduced-motion version should keep the meaningful static state visible. Dispose runtime loaders and controllers when the host surface leaves.

## Reference

Read the one that matches the task:

- [references/cli-reference.md](references/cli-reference.md): every command and flag, exit codes, JSON output shapes, and project layout.
- [references/object-model.md](references/object-model.md): RML syntax, the type hierarchy, ids and references, value formats, and property keys.
- [references/artwork.md](references/artwork.md): complex artwork such as paths, paint, gradients, clipping, meshes, bones, text, layout, and components.
- [references/animation.md](references/animation.md): complex animation such as timelines, keyframes, easing, state machines, blend states, listeners, view models, and Luau.
- [references/silent-failures.md](references/silent-failures.md): what compiles clean and still does nothing. Read this before debugging anything.

Then reach for the bundled docs for depth on a specific topic:

| Topic | `rive docs <topic>` |
|---|---|
| How RML works at all | `format` |
| A complete file to start from | `skeleton` |
| Shapes, paint, gradients | `drawing` |
| Responsive layout, flex, scroll | `layout` |
| Groups, transforms, draw order | `transforms` |
| Text, fonts, modifiers | `text` |
| View models, data binding | `data` |
| States, transitions, conditions | `state-machines` |
| Easing, blend states, joysticks | `easing` |
| Bones, skinning, meshes, constraints | `rigging` |
| Luau protocols and API | `luau/protocols` |
| Accessibility | `semantics` |
| Things that fail quietly | `gotchas` |

## Working with a user's existing file

`rive create <dir> --from-rev=<file.rev>` converts an editor `.rev` into a project: RML plus every script, shader, and asset as files. Use it whenever the source came from a designer, because the editor can produce things this format cannot author: SVG and Lottie imports, boolean/shape-builder results, mesh auto-tracing, and skinning bind poses.

That direction matters for scope. If a task needs boolean operations or an imported illustration, the honest answer is that the geometry has to come from a vector tool or the editor first; hand-authoring path vertices is possible but rarely the right call.

## Environment

Work offline. `--verify`, `--once`, `--test`, `--screenshot`, `--semantics`, `--data-dump`, `inspect`, `schema`, `docs`, and `samples` need no session. Only `--publish`, `--rev`, and `push` require `rive login`.

A `.riv` that carries scripts and is destined for the web must be built with `--publish`. The web runtimes reject unsigned scripts, and nothing locally warns you.
