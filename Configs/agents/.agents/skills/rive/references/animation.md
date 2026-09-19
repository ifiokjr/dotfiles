# Complex animation

How to make things move in text: timelines, state machines, view models, and scripts.

## Timelines

```xml
<LinearAnimation duration="120" loopValue="loop" fps="60" name="Spin" id="0:6">
    <KeyedObject objectId="0:14">
        <KeyedProperty propertyKey="15">
            <KeyFrameDouble value="0" interpolationType="linear"/>
            <KeyFrameDouble value="6.2831855" frame="120" interpolationType="linear"/>
        </KeyedProperty>
    </KeyedObject>
</LinearAnimation>
```

- `duration` is in frames; `fps` defaults to 60, so two seconds is `duration="120"`.
- `loopValue` is `oneShot` (the default), `loop`, or `pingPong`. An animation with no `loopValue` runs once and holds its final frame, so a continuous spin needs it written explicitly.
- `KeyedObject.objectId` is one of the few references you write explicitly: the animation lives beside the objects it animates, not inside them.
- `KeyedProperty.propertyKey` is a number, never a name.

### Keyframe types must match the property

| Property type | Keyframe element |
|---|---|
| `double` | `KeyFrameDouble` |
| `Color` | `KeyFrameColor` |
| `bool` | `KeyFrameBool` |
| `uint` (including enums) | `KeyFrameUint` |
| `int` | `KeyFrameInt` |
| `String` | `KeyFrameString` |
| `Id` | `KeyFrameId` |
| `callback` | `KeyFrameCallback` (frame only, no value) |

A mismatch builds clean, inspects clean, and never writes the value. The property holds still while the timeline runs. Check with `rive schema <Type>`: the type it prints determines the keyframe element.

Reference and boolean keyframes only make sense as `hold`.

```xml
<!-- fade a fill: SolidColor.colorValue is key 37 -->
<KeyedProperty propertyKey="37">
    <KeyFrameColor value="FF57A5E0" frame="0" interpolationType="linear"/>
    <KeyFrameColor value="FFE0573C" frame="60" interpolationType="linear"/>
</KeyedProperty>

<!-- swap which child of a Solo shows: activeComponentId is key 296 -->
<KeyedProperty propertyKey="296">
    <KeyFrameId value="0:61" frame="0" interpolationType="hold"/>
    <KeyFrameId value="0:62" frame="30" interpolationType="hold"/>
</KeyedProperty>
```

### Easing

`interpolationType` is `hold` (the default), `linear`, `cubic`, `cubicValue`, `elastic`, or `scripted`.

Each segment is governed by the keyframe at its start. The `interpolationType` on the last keyframe is never read, because there is no segment after it.

```xml
<KeyedProperty propertyKey="15">
    <KeyFrameDouble value="0" frame="0" interpolationType="cubic">
        <CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>
    </KeyFrameDouble>
    <KeyFrameDouble value="6.2831855" frame="120" interpolationType="linear"/>
</KeyedProperty>
```

`cubic` and `elastic` need their interpolator nested as a child. A `cubic` keyframe with no child eases nothing, silently.

- `cubic` shapes time, normalized 0–1, exactly like CSS `cubic-bezier()`.
- `cubicValue` shapes the value. Its `y1`/`y2` are in the property's own units, which is what the graph editor's curve mode produces. Use it for an overshoot that does not change the timing.

```xml
<CubicValueInterpolator x1="0.42" y1="250" x2="0.58" y2="-50"/>
```

`ElasticInterpolator` takes `easingValue` (`easeOut` default), `amplitude` (overshoot as a fraction of the change), and `period` (oscillation length as a fraction of the segment).

Standard curves, for reference: `ease` is `0.25 0.1 0.25 1`, `ease-in` is `0.42 0 1 1`, `ease-out` is `0 0 0.58 1`, and `ease-in-out` is `0.42 0 0.58 1`.

Loop seam: `loop` jumps from the last frame back to the first instantly. A symmetric third key or `pingPong` avoids the visible snap.

## State machines

Four levels, each mandatory:

```
StateMachine
└─ StateMachineLayer
   ├─ AnyState      (required)
   ├─ ExitState     (required)
   ├─ EntryState    (required)
   └─ AnimationState / BlendState*
```

Every layer needs all three of `AnyState`, `ExitState`, and `EntryState`, even when unused. A layer missing one does not import.

```xml
<StateMachine name="State Machine 1" id="0:7">
    <StateMachineLayer name="Layer 1" id="0:8">
        <AnyState x="200" y="-120"/>
        <ExitState x="400" y="-120"/>
        <EntryState>
            <StateTransition stateToId="0:12"/>
        </EntryState>
        <AnimationState x="200" animationId="0:6" id="0:12"/>
    </StateMachineLayer>
</StateMachine>
```

`x`/`y` on states are editor canvas positions, not scene coordinates.

States carry no `name`, and writing one is a build error. They take `stateName`/`stateCaption`, which are editor labels.

`AnimationState` takes `speed` (negative plays backwards) and flags written as their own attributes:

```xml
<AnimationState animationId="0:20" speed="0.5" reset="true" id="0:12"/>
```

### Transitions

A transition is a child of the state it leaves; `stateToId` is the destination. (`rive schema StateTransition` describes `stateToId` backwards.)

```xml
<AnimationState animationId="0:20" id="0:12">
    <StateTransition stateToId="0:13" duration="150"/>
</AnimationState>
```

`duration` is in milliseconds, unlike animation timing which is in frames. Flags: `disabled`, `enableExitTime`, `exitTimeIsPercetange`, `durationIsPercentage`, `pauseOnExit`, `enableEarlyExit`.

`exitTimeIsPercetange` is misspelled in the format itself. The correct spelling is not accepted, so write the typo.

```xml
<StateTransition stateToId="0:13"
                 enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
```

`randomWeight` biases selection when the source state is `random="true"`.

A transition with no exit is the single most common state machine bug: the control works exactly once. It is invisible to every static check. See the three-screenshot comparison in the main skill.

### Conditions

All conditions on a transition must pass. The current form compares a bound view model property against a literal, with two comparators nested as children in order (left, then right):

```xml
<StateTransition stateToId="0:13" duration="150">
    <TransitionViewModelCondition opValue="equal">
        <TransitionPropertyViewModelComparator>
            <BindablePropertyBoolean>
                <DataBindContext sourcePathIds="0:40-0:45" propertyKey="634"/>
            </BindablePropertyBoolean>
        </TransitionPropertyViewModelComparator>
        <TransitionValueBooleanComparator value="true"/>
    </TransitionViewModelCondition>
</StateTransition>
```

`opValue` is `equal`, `notEqual`, `lessThan`, `lessThanOrEqual`, `greaterThan`, or `greaterThanOrEqual`.

The bindable element must match the literal comparator, and the property key must match the bindable's type:

| Bindable | `propertyKey` | Literal comparator |
|---|---|---|
| `BindablePropertyNumber` | 636 | `TransitionValueNumberComparator` |
| `BindablePropertyInteger` | 686 | `TransitionValueNumberComparator` |
| `BindablePropertyBoolean` | 634 | `TransitionValueBooleanComparator` |
| `BindablePropertyString` | 635 | `TransitionValueStringComparator` |
| `BindablePropertyColor` | 638 | `TransitionValueColorComparator` |
| `BindablePropertyEnum` | 637 | `TransitionValueEnumComparator` |
| `BindablePropertyTrigger` | 686 | `TransitionValueTriggerComparator` |

`TransitionValueIdComparator` is a base class. Authoring it produces a condition that never resolves.

The deprecated input-based form still loads and is simpler for self-contained machines:

```xml
<StateMachineBool name="hovered" id="0:40"/>
...
<TransitionBoolCondition inputId="0:40" opValue="equal"/>
```

A boolean condition has no value to compare against. `TransitionBoolCondition` tests the input against `true`: `equal` fires when it is true, `notEqual` when it is false.

### Layers

Layers run simultaneously, each holding its own current state. That is how you avoid a combinatorial explosion: three buttons on three layers need three states each, rather than a state per combination.

If two layers animate the same property, the later layer wins. The rule of thumb is one layer per thing that can be in a state on its own.

A layer with no inputs, no listeners, and no conditions runs its animation forever. That is the whole recipe for a spinner or a pulsing dot.

### Blend states

A blend state mixes between poses along an axis. The current form takes a bindable as its axis. It has no `inputId`; nesting the `BindableProperty` is the wiring:

```xml
<BlendState1DViewModel id="0:70">
    <BindablePropertyNumber>
        <DataBindContext sourcePathIds="0:40-0:45" propertyKey="636"/>
    </BindablePropertyNumber>
    <BlendAnimation1D animationId="0:71" value="0"/>
    <BlendAnimation1D animationId="0:72" value="50"/>
    <BlendAnimation1D animationId="0:73" value="100"/>
</BlendState1DViewModel>
```

Three traps, all unreported:

- Weights run 0–100, not 0–1.
- `BlendAnimation1D` children must be in ascending `value` order. The runtime binary-searches and does not check, so out-of-order entries blend the wrong pair.
- Key every blended property in every pose. Anything missing holds its authored value and the blend looks broken.

`BlendStateDirect` gives each animation its own input. `BlendAnimationDirect.blendSource` is a bare uint defaulting to `0`: `0` the `inputId`, `1` its own `mixValue`, `2` a nested `BindableProperty`.

### Listeners

Listeners live on the `StateMachine`, not in a layer, and every listener needs a `targetId`. A listener without one resolves to nothing and never fires.

`StateMachineListenerSingle` carries the trigger type directly, which is the common case:

```xml
<StateMachineListenerSingle targetId="0:10" listenerTypeValue="enter" name="In" id="0:50">
    <ListenerViewModelChange>
        <BindablePropertyBoolean propertyValue="true">
            <DataBindContext sourcePathIds="0:40-0:45" propertyKey="634" direction="true"/>
        </BindablePropertyBoolean>
    </ListenerViewModelChange>
</StateMachineListenerSingle>
```

`listenerTypeValue` is one of `enter`, `exit`, `down`, `up`, `move`, `click`, `drag`, `dragStart`, `dragEnd`, `event`, `focus`, `blur`, `keyboard`, `gamepad`, `viewModel`, `semanticAction`, `textInput`, `componentProvided`.

`StateMachineListener` carries only a `targetId`; each trigger nests as a `ListenerInputType*` child with its own `listenerTypeValue`. The nesting is the link. A `KeyboardInput` outside its `ListenerInputTypeKeyboard` never fires, and an input type with no filters matches everything.

Actions are `ListenerAction` subclasses: `ListenerBoolChange` (`false|true|toggle`), `ListenerNumberChange`, `ListenerTriggerChange`, `ListenerViewModelChange`, `ListenerAlignTarget`, `ListenerFireEvent`, and the focus actions.

Dragging:

```xml
<StateMachineListenerSingle targetId="0:30" listenerTypeValue="drag" name="Drag Knob" id="0:50">
    <ListenerAlignTarget targetId="0:30" preserveOffset="true"/>
</StateMachineListenerSingle>
```

The listener's `targetId` is what you grab; the action's is what moves. `preserveOffset="true"` is almost always what you want. Position resolves in the target's parent space.

Keyboard filters: `keyPhase` is a bitmask (`1` down, `2` repeat, `4` up) and `0`, the default, matches nothing. `modifiers` is `1 shift, 2 ctrl, 4 alt, 8 meta` and is matched exactly, not as a subset.

Every listener under the pointer fires. Drawing something on top does not block it unless that thing is explicitly opaque (`isTargetOpaque`), and a fully transparent fill is still hit-testable. Two listeners writing the same property will fight, which is the usual reason a control works in one spot and appears dead in another.

The button pattern is one hold-key animation per state. You do not author the in-between: during a transition the runtime mixes the two states' values from 0 to 1 over `duration`, so two hold keys plus `duration="120"` is a 120 ms cross-fade.

### Nested artboards

```xml
<NestedArtboard artboardId="0:30" x="300" y="100" name="Spinner">
    <NestedSimpleAnimation animationId="0:35" isPlaying="true" speed="2" name="Play"/>
</NestedArtboard>

<NestedArtboard artboardId="0:30" x="100" y="100" name="Dial">
    <NestedRemapAnimation animationId="0:35" name="Scrub">
        <DataBindContext sourcePathIds="0:60-0:62" propertyKey="202"/>
    </NestedRemapAnimation>
</NestedArtboard>
```

- `time` on `NestedRemapAnimation` is a fraction of the duration, not seconds. The runtime multiplies it by the animation's length.
- `NestedSimpleAnimation.isPlaying` defaults to `false`.
- Both are only valid as a direct child of a `NestedArtboard`; anywhere else they are dropped silently.
- Driving a nested machine uses `NestedStateMachine` with `NestedBool`/`NestedNumber`/`NestedTrigger`. The value goes on `nestedValue`, not `value`.

A nested artboard inherits its parent's data context rather than binding its own instance. A view-model-driven machine that works at root does nothing once placed as a component. For nestable machines, drive them with `StateMachine*` inputs instead.

## View models and data binding

The root-level objects:

```xml
<ViewModel defaultInstanceId="0:41" name="Battery" id="0:40">
    <ViewModelPropertyNumber name="level" id="0:45"/>
    <ViewModelPropertyBoolean name="isCharging" id="0:46"/>

    <ViewModelInstance exports="true" name="Default" id="0:41">
        <ViewModelInstanceNumber propertyValue="72" viewModelPropertyId="0:45"/>
        <ViewModelInstanceBoolean propertyValue="false" viewModelPropertyId="0:46"/>
    </ViewModelInstance>
</ViewModel>
```

Three links, all required: the artboard names the view model with `viewModelId`; the view model names its default with `defaultInstanceId`; each instance value names its property with `viewModelPropertyId`.

`ViewModelInstance.exports` defaults to `false`, and an unexported instance is never written for the runtime at all. Set it explicitly.

Each property type has a matching instance element: `Number`, `String`, `Boolean`, `Color`, `Trigger`, `ViewModel` (nested), `List`, `Enum`, `Artboard`, `AssetImage`.

Naming is checked by the editor but not by the CLI. A leading digit is invalid, a Luau keyword is invalid, and the conventions are PascalCase for view models and camelCase for properties. `charge_state` builds clean and surfaces later as a Problem in the designer's editor.

### Binding

```xml
<TextValueRun styleId="0:21" text="placeholder" name="Run">
    <DataBindContext sourcePathIds="0:40-0:45" propertyKey="268"/>
</TextValueRun>
```

- `sourcePathIds` is a dash-separated absolute path starting at a view model id and walking property ids. Relative paths are not supported.
- `propertyKey` is the key on the target, meaning the property being written. `268` is `TextValueRun.text`.
- `direction="true"` makes the bind write (target → source). `twoWay="true"` for both.
- `sourceToTargetRunsFirst="true"` fixes a two-way bind overriding `--data`.
- A dangling path compiles, loads, runs, and does nothing. `problems` catches it as `unresolved-bind-path`, but it never checks whether the artboard is bound to the view model the path names.

Bind the property that exists on the target: `width` lives on a `Rectangle`, not on the enclosing `Shape`. If `rive schema <Type>` does not list the property, the bind is dead.

`nameBased="true"` changes `sourcePathIds` to a single index into a `ManifestAsset` name table, which is what the editor writes for relative binds. Nothing in this toolchain generates a manifest, so a hand-written `nameBased="true"` builds clean and is inert. `problems` also gives a meaningless verdict in both directions because it walks the path as ids regardless.

`DataConverter*` elements transform a value inline: `DataConverterRangeMapper`, `DataConverterInterpolator`, `DataConverterToString`, `DataConverterRounder`, and about fifteen more.

## Luau scripts

A `.luau` file joins the file by returning a protocol. Dropping it in the project directory is the whole registration step.

| Protocol | Returned as | Attached with |
|---|---|---|
| `Layout<T>` | `function(context: Context): Layout<T>` | `ScriptedLayout` |
| `Node<T>` | `function(): Node<T>` | `ScriptedDrawable` |
| `PathEffect<T>` | `function(): PathEffect<T>` | `ScriptedPathEffect` |
| `Converter<T, I, O>` | `function(): Converter<T, I, O>` | `ScriptedDataConverter` |
| `ListenerAction<T>` | `function(): ListenerAction<T>` | `ScriptedListenerAction` |
| `TransitionCondition<T>` | `function(): TransitionCondition<T>` | `ScriptedTransitionCondition` |
| `Interpolator<T>` | none | `ScriptedInterpolator` |
| `Tests` | `function(): Tests` (double wrapper) | none |

```xml
<ScriptedLayout scriptAssetId="0:80" name="Spin" id="0:12">
    <ScriptInputNumber propertyValue="3" name="speed"/>
    <ScriptInputViewModelProperty dataBindPathIds="0:40-0:45" name="settings"/>
</ScriptedLayout>
```

A missing `scriptAssetId` link does nothing. `ScriptedListenerAction` and `ScriptedTransitionCondition` take no `name`, and adding one fails the build because they are not `Component`s.

### Lifecycle

```luau
type Hello = { paint: Paint, path: Path, size: Vector, elapsed: number }

function init(self: Hello, context: Context): boolean return true end
function resize(self: Hello, size: Vector, scale: number) self.size = size end
function advance(self: Hello, seconds: number): boolean
    self.elapsed += seconds
    return true
end
function draw(self: Hello, renderer: Renderer)
    renderer:drawPath(self.path, self.paint)
end

return function(context: Context): Layout<Hello>
    return {
        paint = Paint.with({ color = Color.rgb(255, 100, 50) }),
        path = Path.new(),
        size = Vector.xy(0, 0),
        elapsed = 0,
        init = init, resize = resize, advance = advance, draw = draw,
    }
end
```

- `init(self, context) -> boolean` is called once when the node is created.
- `advance(self, seconds) -> boolean` runs per-frame. Returning `true` means "I changed, draw me again".
- `draw(self, renderer)` renders the node. The former `drawCanvas` callback was removed, so move its body into `draw`.
- `update(self)` is called when an input value changes.
- Pointer and gamepad hooks: `pointerDown`, `pointerMove`, `pointerUp`, `pointerExit`, `gamepadConnected`, `gamepadEvent`, `gamepadDisconnected`.
- `Layout<T>` adds `measure(self) -> Vector` and `resize(self, size, scale)`.

A misspelled hook is silently ignored. The protocol table is matched by key name and unknown keys are dropped without complaint. Every hook is optional, so the type checker cannot help.

`init` runs twice on a `ScriptedLayout`, and `context:viewModel()` is `nil` on the first call. Guard for it, or fields stay nil and the scene never moves:

```luau
function init(self: Track, context: Context): boolean
    local vm = context:viewModel()
    if vm == nil then
        return true
    end
    self.cardX = vm:getNumber('cardX')
    return true
end
```

### Language constraints

- Strict mode, and type errors are build errors. Annotate every function parameter. An unannotated one infers as `unknown`, and every arithmetic expression downstream becomes an error.
- Available: `math`, `table`, `string`, `os`, `utf8`, `buffer`, `bit32`, plus the base library.
- No `io`, no `coroutine`, no `debug`. A script cannot touch the filesystem or yield.
- There is no text API. Scripts cannot draw strings.
- `print` writes to the build log.

### Rendering

`Renderer` gives you `drawPath(path, paint)`, `drawImage(...)`, `drawImageMesh(...)`, `clipPath(path)`, `save()`, `restore()`, `transform(mat2d)`, and `modulateOpacity(opacity)`.

`Path` has `moveTo`, `lineTo`, `quadTo`, `cubicTo`, `close`, `reset`, `add`, `contours`, and `measure()` for a `PathMeasure` (`length`, `positionAndTangent`, `warp`, `extract`).

Do not mutate or reset a `Path` in the same frame after drawing it. Wait until the next frame. A `Paint` is safe to mutate after drawing.

Paths a script builds use the clockwise fill rule, so when several contours go into one path, winding direction decides fill versus hole. A contour wound the other way is subtracted, which is how a script cuts holes.

`Paint.with({ color = ..., style = 'stroke'|'fill', thickness = ..., join = ..., cap = ..., gradient = ... })`. `Gradient.linear(from, to, stops)` and `Gradient.radial(from, radius, stops)` build gradients procedurally.

### Reading the data model

`Context` exposes `viewModel()`, `rootViewModel()`, `globalViewModel(name)`, `image(name)`, `blob(name)`, `audio(name)`, `shader(name)`, and `canvas(desc)` / `gpuCanvas(desc)`.

An instance gives `getNumber`, `getString`, `getBoolean`, `getColor`, `getList`, `getViewModel`, `getEnum`, `getTrigger`, and `instance(name)`. Property values support `:addListener(cb)` and `:removeListener()`.

### Tests

```luau
return function(): Tests
    return function(test: Tester)
        test.group('clamp', function()
            test.case('clamps high', function(expect)
                expect(mathutil.clamp(10, 0, 5)).is(5)
            end)
        end)
    end
end
```

The double wrapper is required. A bare `function setup(test: Tester)` reports "no Tests scripts found" and the file is skipped. Matchers are `is`, `lessThan`, `lessThanOrEqual`, `greaterThan`, `greaterThanOrEqual`, negatable as `.never.is(y)`. Run with `rive . --test`; failures exit 6.

### Modules

Any `.luau` file returning a value is importable by name with `require('name')`.

Modules are registered in the order their `ScriptAsset`s appear in the document, and `require` only finds one already registered, so a module must be declared above every script that imports it. This type-checks clean and fails only at run time.

Mark a plain module with `isModule="true"`. `folderPath` namespaces it (`require('widgets/button')`).

### Shaders

`.wgsl` files compile and are registered under their name (filename minus extension, namespaced by folder). No RML property points at a shader. A script fetches it by string:

```luau
local shader = context:shader('wave')
```

That lookup is unvalidated: a typo returns `nil`. `rive.yaml`'s `shaderOutputs` selects publish backends from `msl`, `glsl`, `wgsl`, `hlsl`, `spirv`.

## The rule for choosing

If you could draw it in a design tool, build it in RML. A state machine, a layout, and a text run have no script equivalent, so a scripted UI gives up layout, text, and editability to gain nothing.

Script when the content is genuinely computed per frame: particles, procedural geometry, custom physics, a game loop. The reference corpus's most complex files (particle emitters, a snake game, a slot machine) are all scripted, and all of them sit inside markup that holds the layout and text.

There is no general spring or physics solver. What exists: `ElasticInterpolator` on keyframes and transitions, `DataConverterInterpolator` to ease a bound value over time, and `ElasticScrollPhysics` for scroll momentum (`friction` defaults to 8.0; `elasticFactor` is an exponent, not a fraction). Everything else is per-frame math in a script.

## Depth

| Topic | `rive docs <topic>` |
|---|---|
| States, transitions, conditions | `state-machines` |
| Easing curves, blend states, joysticks | `easing` |
| View models, data binding, enums, custom properties | `data` |
| Luau protocols and API | `luau/protocols` |
| Accessibility and semantic listeners | `semantics` |
| Keyboard focus and traversal | `focus` |
| Breakpoints in VS Code | `debugging` |
