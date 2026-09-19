# The Rive object model and RML

RML (Rive Markup Language) is an XML projection of the object model. The rule that explains the whole format:

> **Every element is a core type, every attribute is one of its properties, and nesting stands in for the references those objects hold to each other.**

The names are the ones the Editor uses, so there is no separate RML object model to learn. `rive schema <Type>` lists the properties of any type; `rive schema --list` prints all of them.

## Document structure

```xml
<Rive version="1" kind="fragment">
    <Artboard defaultStateMachineId="0:7" styleId="0:5" width="500" height="500" name="Artboard" id="0:2">
        <!-- scene content -->
    </Artboard>

    <!-- assets, view models, converters and enums are ROOT elements -->
    <FontAsset file="Inter.ttf" name="Inter" id="0:40"/>
    <ViewModel name="Settings" id="0:50">...</ViewModel>
</Rive>
```

- `Rive` is the only top-level element and must come first.
- `version` is the RML format version, currently `1`.
- `kind` is `fragment` for a project file you write, `bundle` for a self-contained editor export. A fragment never declares `<Backboard>` or `<MarkupFragment>`; in a fragment those settings live in `rive.yaml`.
- A document is a forest under one wrapper, not a single tree: a flat sequence of root elements.
- Artboards hold scene content. Assets, view models, converters, and enums are direct children of `<Rive>` and never nested inside an artboard.
- A project may split across many `.rml` files in any folders; they compile as one document. Files compile in path order, which is the artboard order in the `.riv`.

## Ids and references

Ids are two numbers separated by a colon (`0:12`, `14:11981`).

- One namespace across the whole document, not one per type. A `StateMachineLayer` and a `DataConverterGroupItem` cannot both be `0:91`; duplicates are a build failure.
- Leading zeros are malformed (`04:23` is not `4:23`). `0:0` is reserved for the editor's dangling marker.
- Elements only need an `id` when another element references them. Ids are assigned for the rest at build time.
- References are attributes ending in `Id`: `styleId`, `scriptAssetId`, `fontAssetId`, `objectId`, `stateToId`.

Nesting fills reference properties automatically. The referent is the *nearest matching ancestor*, not necessarily the immediate parent:

```xml
<LinearAnimation name="Spin" id="0:6">
    <KeyedObject objectId="0:10">        <!-- objectId points at the Shape -->
        <KeyedProperty propertyKey="15">  <!-- rotation -->
            <KeyFrameDouble value="0" interpolationType="linear"/>
            <KeyFrameDouble value="6.2831855" frame="120" interpolationType="linear"/>
        </KeyedProperty>
    </KeyedObject>
</LinearAnimation>
```

Some relationships are inverted: the parent names its child, and the child is what is being pointed at. `BindableProperty`, `KeyFrameInterpolator`, and `TargetEffect` all work this way:

```xml
<StateTransition stateToId="0:13">
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

A few things are linked by nesting alone, with no id at all: `LayoutParticipant` inside a `Shape`/`Text`/`Image`, `Mesh` inside the `Image` it deforms, and `Skin` inside that `Mesh` or a `PointsPath`.

## Value formats

| Type | Written as |
|---|---|
| Color | ARGB hex, no `#`: `colorValue="FFFF5A3C"` |
| Boolean | `"true"` / `"false"` |
| Enum | Prefer the name: `layoutWidthScaleType="fill"`. Integers work but skip validation |
| Rotation | Radians. A full turn is `6.2831855` |
| Animation timing | Frames, at the animation's `fps` (default 60) |
| Transition duration | Milliseconds |
| Fractional index | A fraction as a string: `childOrder="3/4"` (`"1"` is malformed, so write `"1/1"`) |

Enums are the one place a typo is caught for you. An unrecognized name is an error listing the accepted values, so prefer symbolic names over integers:

```
Fill attribute blendModeValue expects an integer or one of: inherit, srcOver, screen, ...
```

Colors are the opposite: `colorValue` accepts anything and gives whatever it cannot parse an alpha of zero, so a bad color draws nothing and reports nothing.

## Type hierarchy

Everything visible sits in a tree, and its position on screen is the product of its own transform and every transform above it.

```
Component                        (abstract)
├─ ContainerComponent            (abstract)
├─ TransformComponent            (abstract)  rotation, scaleX, scaleY
│  └─ WorldTransformComponent    (abstract)  + opacity
```

The shared transform set on every positioned object is `x`, `y`, `rotation`, `scaleX`, `scaleY`, and `opacity`. All six are animatable and bindable, and they are most of what a Rive file animates.

| Type | What it is |
|---|---|
| `Artboard` | One scene: a size and an origin. The unit a runtime displays. It is itself a `LayoutComponent`, so it carries a style like any other layout box |
| `Node` | Draws nothing; holds a transform its children inherit. This is the editor's *group* |
| `Shape` | A container holding geometry and paint |
| `Rectangle`, `Ellipse`, `Triangle`, `Polygon`, `Star` | Parametric paths |
| `PointsPath` | A custom path, Rive's vector network |
| `Image` | A raster, sized by its asset |
| `Text` | Container plus style plus runs |
| `LayoutComponent` | A drawable flex/grid box |
| `NestedArtboard` | Another artboard placed inside this one |
| `Solo` | Shows exactly one child, selected by `activeComponentId` |
| `RootBone` / `Bone` | A skeleton |
| `Mesh` | A deformable triangulation over an image or path |

There is no `Scene` element. "Scene" is prose for an artboard's content.

Abstract types cannot be authored. Writing one is a build error: `Component`, `ContainerComponent`, `Drawable`, `ShapePaint`, `Constraint`, `LayerState`, `Animation`, `BlendState`, `KeyFrame`, `BindableProperty`, `ViewModelProperty`, `ViewModelInstanceValue`, and others.

## Draw order

The first sibling draws on top, front-to-back, the reverse of HTML and SVG. To bring something forward, move it earlier among its parent's children. If a shape you added is invisible, suspect this first.

Paint order inside a single shape is the opposite: paint children paint last-declared-on-top. That is what makes a glow work: feathered paint first, crisp paint after.

`DrawRules` + `DrawTarget` override sibling order, but the target must be nested inside its rules or the rule silently does nothing:

```xml
<DrawRules drawTargetId="0:31" name="Rules" id="0:30">
    <DrawTarget drawableId="0:20" placementValue="before" name="Above card" id="0:31"/>
</DrawRules>
```

## Key property keys

Keyframes and binds address properties by numeric key, never by name. `rive schema <Type>` prints the key for every property.

| Property | Key | Type |
|---|---|---|
| `x` / `y` | 13 / 14 | double |
| `rotation` | 15 | double |
| `scaleX` / `scaleY` | 16 / 17 | double |
| `opacity` | 18 | double |
| `ParametricPath.width` / `.height` | 20 / 21 | double |
| `ParametricPath.originX` / `.originY` | 123 / 124 | double |
| `Rectangle.cornerRadiusTL` | 31 | double |
| `SolidColor.colorValue` | 37 | Color |
| `GradientStop.colorValue` / `.position` | 38 / 39 | Color / double |
| `Stroke.thickness` | 47 | double |
| `LinearAnimation.fps` / `duration` / `loopValue` | 56 / 57 / 59 | uint |
| `Polygon.points` / `cornerRadius` | 125 / 126 | uint / double |
| `Star.innerRadius` | 127 | double |
| `Solo.activeComponentId` | 296 | Id |
| `LayoutComponent.width` / `.height` | 7 / 8 | double |
| `Image.assetId` | 206 | Id |
| `TextValueRun.text` | 268 | String |
| `TextStyle.fontSize` | 274 | double |
| `TextStyle.fontAssetId` | 279 | Id |
| `BindablePropertyBoolean.propertyValue` | 634 | bool |
| `BindablePropertyString.propertyValue` | 635 | String |
| `BindablePropertyNumber.propertyValue` | 636 | double |
| `BindablePropertyEnum.propertyValue` | 637 | Id |
| `BindablePropertyColor.propertyValue` | 638 | Color |
| `BindablePropertyInteger.propertyValue` | 686 | uint |
| `BindablePropertyTrigger.propertyValue` | 686 | uint |
| `BindablePropertyAsset` / `Artboard` / `ViewModel` | 823 | Id |
| `BindablePropertyList.propertyValue` | 835 | Id |
| `ArtboardComponentList.listSource` | 800 | Id |
| `ViewModelInstanceNumber.propertyValue` | 575 | double |
| `ViewModelInstanceString.propertyValue` | 561 | String |
| `ViewModelInstanceBoolean.propertyValue` | 593 | bool |
| `ViewModelInstanceColor.propertyValue` | 555 | Color |

Note that keys are not unique across types: `BindablePropertyInteger` and `BindablePropertyTrigger` share `686`, and `BindablePropertyAsset`, `Artboard`, and `ViewModel` all share `823`. The element name is the discriminator.

`rive schema --animatable` filters to keyable properties; `--bindable` to data-bindable ones.

## Assets

Assets are root elements. `file=` is an authoring attribute that tells the compiler which file to embed, so `rive schema` never lists it.

```xml
<ImageAsset file="logo.png" name="logo" id="0:60"/>
<FontAsset file="Inter.ttf" name="Inter" id="0:30"/>
<AudioAsset file="click.wav" name="click" id="0:70"/>
<ScriptAsset file="main.luau" name="main" id="0:80"/>
<BlobAsset file="levels.json" name="levels" id="0:81"/>
```

SVG and Lottie are editor-only: `SVGAsset` and `LottieAsset` are stripped on export, and the conversion from those formats to real Rive objects does not exist in this toolchain. Convert upstream.

## Components

To make a scene nestable, all four steps are required and none is validated:

```xml
<!-- 1. the artboard, 2. marked as a component -->
<Artboard isComponent="true" width="80" height="40" name="Switch" id="0:30"> ... </Artboard>

<!-- 3. its entry in the assets panel -->
<ComponentAsset artboardId="0:30" name="Switch"/>

<!-- 4. place it -->
<Artboard width="600" height="400" name="Screen" id="0:1">
    <NestedArtboard artboardId="0:30" x="120" y="200" name="Left"/>
</Artboard>
```

A half-done pair builds and inspects clean while being malformed.

## Skeleton

A minimal complete file to start from:

```xml
<Rive version="1" kind="fragment">
    <Artboard defaultStateMachineId="0:7" styleId="0:5" width="500" height="500" name="Artboard" id="0:2">
        <LayoutComponentStyle name="Artboard Style" id="0:5"/>

        <Fill name="Background">
            <SolidColor colorValue="FF282828" name="Color"/>
        </Fill>

        <Shape x="200" y="150" name="Box" id="0:14">
            <Rectangle width="120" height="80" name="Path"/>
            <Fill name="Fill">
                <SolidColor colorValue="FF57A5E0" name="Color"/>
            </Fill>
        </Shape>

        <LinearAnimation duration="60" loopValue="loop" name="Animation 1" id="0:6"/>
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
    </Artboard>
</Rive>
```

`rive docs skeleton` prints this. Every artboard needs a `defaultStateMachineId` and a `LayoutComponentStyle`. Without a state machine, data binds are never applied and pointer input is never routed, though animations still play, so the file does not look dead.

## Where to go deeper

`rive docs <topic>`:

- `format`: the RML format, including both nesting-reference tables and the full property list
- `skeleton`: a complete file to start from
- `transforms`: groups, transforms, opacity, draw order
- `drawing`: shapes, paint, gradients, images
- `assets`: images, fonts, audio, shaders, blobs
- `layout`: responsive layout
- `data`: view models, data binding, enums, custom properties
- `gotchas`: things that fail quietly, ordered by cost
- `README`: the `problems` taxonomy and what each check does not cover
