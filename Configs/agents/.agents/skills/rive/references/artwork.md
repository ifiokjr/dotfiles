# Complex artwork

How to build visually rich work in text, and where the ceiling is. The organizing rule:

> **If you could draw it in a design tool, build it in RML. If it only exists because something is being computed each frame, script it.**

Scripting a UI costs you layout, text (impossible from a script), state machines, listeners, and editability. Reach for a script for procedural geometry, particles, and per-frame math.

## Vector geometry

Everything visible is a `Shape`: a container holding geometry and paint.

```xml
<Shape x="200" y="150" name="Box" id="0:14">
    <Rectangle width="120" height="80" cornerRadiusTL="12" cornerRadiusTR="12" name="Path"/>
    <Fill name="Fill">
        <SolidColor colorValue="FF57A5E0" name="Color"/>
    </Fill>
</Shape>
```

Parametric paths cover most icon and UI work: `Rectangle` (`cornerRadiusTL/TR/BL/BR`, or `linkCornerRadius`), `Ellipse` (a circle is equal width and height), `Triangle`, `Polygon` (`points`, `cornerRadius`), `Star` (`innerRadius`).

### Custom paths (vector networks)

`PointsPath` **is** the vector network — there is no separate network type. Vertices are in the shape's local space, **in order**, and the four kinds differ only in how they curve:

| Vertex | Properties |
|---|---|
| `StraightVertex` | `x`, `y`, `radius` (corner rounding) |
| `CubicMirroredVertex` | `x`, `y`, `rotation`, `distance` — smooth symmetric handles |
| `CubicDetachedVertex` | `x`, `y`, `inRotation`, `inDistance`, `outRotation`, `outDistance` |
| `CubicAsymmetricVertex` | `x`, `y`, `rotation`, `inDistance`, `outDistance` |

```xml
<Shape x="100" y="100" name="Arrow" id="0:20">
    <PointsPath isClosed="true" name="Path">
        <StraightVertex x="0" y="-40" radius="4"/>
        <StraightVertex x="30" y="20"/>
        <CubicMirroredVertex x="0" y="0" rotation="0" distance="12"/>
        <StraightVertex x="-30" y="20"/>
    </PointsPath>
    <Fill name="Fill"><SolidColor colorValue="FFE0E0E0" name="Color"/></Fill>
</Shape>
```

Closing the path: set **`isClosed="true"`**. An open `PointsPath` with a `Fill` renders the fill across an implied straight line between the last and first vertex. `isClockwise` is separate and does not close anything.

`StraightVertex.radius` is clamped to half the shorter adjacent segment and reduced further on tight angles, so heavy rounding on a small shape degrades rather than breaking.

### Compound shapes and holes

A `Shape` can hold **several geometry children**, which combine into one filled path. That is how holes and compound shapes are made, and the fill rule decides which regions become holes:

- `nonZero` — +1 for clockwise contours, −1 for counter-clockwise; filled where the total is not 0. (The default.)
- `evenOdd` — filled where the crossing count is even.
- `clockwise` — Rive-specific. Enables manual subtraction of paths, and is **required for vector feathering**.

```xml
<Fill fillRule="evenOdd" name="Fill"><SolidColor colorValue="FF57A5E0" name="Color"/></Fill>
```

Boolean operations have **no RML element**. The editor's Shape Builder (`Shift+M`) merges and subtracts regions interactively and produces ordinary paths, so geometry requiring real booleans should come from a vector tool or the editor first. Hand-authoring path vertices is possible but rarely the right call for complex illustrations.

## Paint

Fills and strokes both take a paint child. A shape can carry **unlimited fills and strokes**, and paint order inside a shape is last-declared-on-top.

```xml
<!-- Gradient: startX/startY/endX/endY are local points, no percentage form -->
<Fill name="Fill">
    <LinearGradient startX="0" startY="-60" endX="0" endY="60" name="Gradient">
        <GradientStop colorValue="FFFFE066" position="0"/>
        <GradientStop colorValue="FFCC3311" position="1"/>
    </LinearGradient>
</Fill>
```

`RadialGradient` takes `startX`/`startY` plus `endX`/`endY` for the radius. Because gradient coordinates are **local points rather than percentages, they do not track a resized layout box** — a gradient on a flexible box will not reach its new edges.

### Glow without a blur

There is no blur. Vector feathering is the soft-edge feature, but **`Feather` inside a `Fill` currently renders nothing** — the paint disappears entirely at every strength, with a clean build and an empty `problems`. Feather works on strokes:

```xml
<Stroke thickness="5" name="Glow">
    <SolidColor colorValue="FF3FE0C8" name="Color"/>
    <Feather strength="7" name="Feather"/>
</Stroke>
```

For a **soft filled glow, use a `RadialGradient` whose outer stop has alpha `00`** — exactly the technique used for the badge below.

### Blend modes

Every drawable has `blendModeValue`, neither animatable nor bindable. Named values are accepted: `srcOver`, `screen`, `overlay`, `darken`, `lighten`, `colorDodge`, `colorBurn`, `hardLight`, `softLight`, `difference`, `exclusion`, `multiply`, `hue`, `saturation`, `color`, `luminosity`.

`Fill` and `Stroke` also carry their own `blendModeValue`, whose default `inherit` means "take it from the shape".

To change compositing over time, key opacity or swap between two shapes with a `Solo` — you cannot key the blend mode itself.

### Trim and dash

Both nest inside the `Stroke` they affect:

```xml
<Stroke thickness="4" name="Stroke">
    <SolidColor colorValue="FFFFFFFF" name="Color"/>
    <DashPath name="Dashes">
        <Dash length="20" name="On"/>
        <Dash length="10" name="Off"/>
    </DashPath>
</Stroke>
```

```xml
<GroupEffect name="Reveal" id="0:80">
    <TrimPath start="0" end="0.4" name="Trim"/>
</GroupEffect>
```

`GroupEffect` shares one effect stack across many paints; each paint nests a `TargetEffect` naming it. Keying the group's `TrimPath` reveals N strokes together. `TargetEffect` is only valid inside a `Fill` or `Stroke`.

`TrimPath` `modeValue` is `sequential` or `synchronized` — there is no `0`.

## Clipping

`ClippingShape` nests inside the shape being clipped and names the clipper by id. **Both shapes resolve in their own coordinate space**, which is the usual bug — a mask at the origin will clip a shape positioned elsewhere to nothing.

```xml
<Shape x="200" y="120" name="Badge" id="0:10">
    <Ellipse width="120" height="120" name="Path"/>
    <Fill name="Core"><SolidColor colorValue="FFFFC64A" name="C"/></Fill>
    <ClippingShape sourceId="0:20" name="Clip"/>
</Shape>

<Shape x="200" y="120" name="ClipMask" id="0:20">
    <Ellipse width="90" height="90" name="P"/>
</Shape>
```

The mask shape has **no fill and no stroke**, so it masks without drawing — a shape with no paints still contributes its geometry.

There is **no `isVisible` property**, and `hidden="true"` will not do it either: `Component.flags` (`hidden`, `locked`, `guide`, `opaque`) is **editor state and is not read at runtime**. A shape with no paint is how you get an invisible mask.

Inverse clipping is a compound path (rectangle minus a hole) with the fill rule set to `evenOdd`.

## Layout, and when to group

Layout is **two objects**: a `LayoutComponent` holding the tree and size, plus a `LayoutComponentStyle` holding every flex property, linked by `styleId`. Forgetting that link while nesting the style is the most common layout mistake — every value is right and nothing applies.

```xml
<LayoutComponent width="390" height="180" styleId="0:2" name="Header" id="0:1">
    <LayoutComponentStyle layoutWidthScaleType="fill" layoutHeightScaleType="fixed"
                          flexDirectionValue="row"
                          gapHorizontal="12" gapHorizontalUnitsValue="points"
                          paddingLeft="16" paddingLeftUnitsValue="points"
                          layoutAlignmentType="spaceBetweenCenter"
                          name="Header Style" id="0:2"/>
    <Fill name="Fill"><SolidColor colorValue="FF1E2430" name="C"/></Fill>
</LayoutComponent>
```

Key values: `flexDirectionValue` (`column|columnReverse|row|rowReverse`), `flexWrapValue` (`noWrap|wrap|wrapReverse`), `layoutTypeValue` (`flex|grid|stack`), `positionTypeValue` (`static|relative|absolute`), `displayValue` (`flex|none`), `overflowValue` (`visible|hidden|scroll`), and `layoutAlignmentType` (nine positions plus `spaceBetweenStart|spaceBetweenCenter|spaceBetweenEnd`).

**Scale types** — `layoutWidthScaleType` and `layoutHeightScaleType`:

| Value | Meaning |
|---|---|
| `fixed` | Use the `width`/`height` on the component |
| `fill` | Take the space the parent offers — a **weight**, not a percentage |
| `hug` | Shrink to fit the children |

Two traps:

- **`undefined` units silently drop the value.** Each dimensional property takes a companion `*UnitsValue` accepting `defined|points|percent|auto`. Omitting the attribute is safe — it defaults to `points`, and the value applies. Writing `unitsValue="undefined"` (which an export or a generator can emit) means **the value is ignored**, not defaulted: `paddingLeft="16" paddingLeftUnitsValue="undefined"` lays out with no padding at all, and nothing reports it.

```xml
<!-- applied: 20 points of left padding -->
<LayoutComponentStyle paddingLeft="20" name="S" id="0:11"/>

<!-- silently dropped: no padding -->
<LayoutComponentStyle paddingLeft="20" paddingLeftUnitsValue="undefined" name="S" id="0:11"/>
```

- `width`/`height` on a `LayoutComponent` are its own size, while `fractionalWidth`/`fractionalHeight` (the flex weight) live on the **`LayoutComponent` or `LayoutParticipant`, not on the style**.
- `fill` on the cross axis of a `wrap` container collapses to zero. `flexGrow` exists in the schema but the layout engines never read it.

**A `LayoutComponent` is itself a drawable**, so it takes `Fill`, `Stroke`, and `cornerRadius*`. Use it for panels and buttons rather than a `Shape` + `Rectangle`, because a `Rectangle` has its own fixed width the layout engine will not touch.

**Wrap composite art in a `Node`.** A group — a plain `Node` or a `Solo` — is invisible to layout: everything inside keeps its size and its `x`/`y` exactly as drawn. Without it, children get resized to fit the container and collapse into a blob.

```xml
<Node name="Icon" id="0:40">
    <Shape x="0" y="0">...</Shape>
    <Shape x="10" y="0">...</Shape>
</Node>
```

`Solo` renders exactly one child, chosen by `activeComponentId` (propertyKey **296**, needs `KeyFrameId`). That is cheaper than animating opacities and is the idiomatic way to build icon sets, character variants, and frame-by-frame effects.

## Images and meshes

```xml
<Image x="100" y="100" assetId="0:60" name="Logo"/>
<ImageAsset file="logo.png" name="logo" id="0:60"/>
```

An `Image` has **no width or height** — it takes its size from the asset. `x`/`y` plus `originX`/`originY` (default `0.5, 0.5`) place it.

**Meshes** deform a raster by moving vertices. The editor auto-traces a contour from the image's alpha; **RML cannot** — you author the vertex list yourself.

```xml
<Image x="150" y="150" assetId="0:60" name="Arm" id="0:20">
    <Mesh triangleIndexBytes="AAECAAID" name="Mesh" id="0:21">
        <ContourMeshVertex x="-100" y="-100" u="0" v="0" name="V0"/>
        ...
    </Mesh>
</Image>
```

`x`/`y` are the vertex position in the image's local space; `u`/`v` are where it samples the texture, normalized 0–1. `triangleIndexBytes` is the triangle list — three vertex indices per triangle, varuint-encoded then base64'd. The four vertices above with `AAECAAID` are `0,1,2` and `0,2,3`, the two triangles of a quad.

Two failures build clean: a `Mesh` that is not a child of an `Image` is silently ignored, and a missing `triangleIndexBytes` or an index past the vertex count **takes the whole file down at load**. `inspect` never shows `Bytes` properties.

For 9-slice scaling, `NSlicer` nests inside the `Image` and holds `AxisX`/`AxisY` cuts (`offset`, `normalized`). `NSlicer` has no properties of its own, so `rive schema NSlicer` looks empty — everything is on the axis children.

## Bones and rigging

```xml
<RootBone x="0" y="0" length="76" rotation="-1.5707964" name="Body" id="0:40">
    <Bone length="18" rotation="0" name="Neck" id="0:41">
        <Bone length="24" rotation="0" name="Head" id="0:42"/>
    </Bone>
</RootBone>
```

`RootBone` is the only bone with `x`/`y`; every other is positioned by `length` and `rotation` relative to its parent. A `RootBone` may be nested inside another `Bone`, which is legal and useful for a limb on a swinging boom.

Bones control elements three ways: a child of a bone is transformed by it, vector vertices can be bound to bones, and mesh vertices can be skinned.

**Skinning nests inside the `PointsPath` or `Mesh` it deforms**, and nothing else:

```xml
<PointsPath name="Path" id="0:51">
    <StraightVertex x="0" y="-10"><Weight values="255" indices="1"/></StraightVertex>
    <StraightVertex x="80" y="-10"><Weight values="255" indices="2"/></StraightVertex>
    <Skin tx="0" ty="0" name="Skin">
        <Tendon boneId="0:40" tx="0" ty="0" name="Upper"/>
        <Tendon boneId="0:41" tx="76" ty="0" name="Fore"/>
    </Skin>
</PointsPath>
```

- **`Tendon`** names a bone and records the bind pose. Its matrix components read as `Mat2D(xx, xy, yx, yy, tx, ty)`.
- **`Weight.indices` is 1-based** (`tendonIndex + 1`), packed one byte per slot; `values` are influences out of 255. Tendons 0 and 1 at half each is `indices="513" values="32896"`.
- **Four bones per vertex is the runtime limit**, not a convention.

**Skinning is genuinely painful to author by hand, and a wrong bind pose renders mirrored or collapsed with no error and empty `problems`.** If the geometry came from a designer, take the skinned path or mesh from a `.rev` via `rive create --from-rev` rather than writing it.

### Constraints

Constraints nest inside the thing they constrain and target with `targetId`. `strength` (0–1) enables partial application.

| Constraint | Ties | Notes |
|---|---|---|
| `TranslationConstraint` / `RotationConstraint` / `ScaleConstraint` | one axis each | Work with no target, constraining against the parent |
| `TransformConstraint` | all three | |
| `DistanceConstraint` | stays at a distance | `modeValue` accepts **no symbolic names**: `0` closer/gate (default), `1` further, `2` exact |
| `IKConstraint` | bends a bone chain | `parentBoneCount="1"` is a two-bone solve (elbow/knee); `0` is a one-bone solve — Rive's look-at |
| `FollowPathConstraint` | rides a path | Key `distance` to animate along a curve |
| `ScrollConstraint` | scrolling | Two nested layout boxes; the constraint reads its own parent as content and its grandparent as the viewport |

**`IKConstraint` must sit on a `Bone`.** On any other target the whole file fails to import and the error names no object.

## Text

Text is **three objects** with three links, each of which fails silently:

```xml
<Text x="200" y="200" name="Title" id="0:30">
    <TextStylePaint fontSize="28" fontAssetId="0:40" name="Body" id="0:31">
        <Fill name="Fill"><SolidColor colorValue="FFFFFFFF" name="C"/></Fill>
    </TextStylePaint>
    <TextValueRun styleId="0:31" text="Hello" name="Run"/>
</Text>

<FontAsset file="Inter.ttf" name="Inter" id="0:40"/>
```

The style needs a `Fill` with a colour; the run needs `styleId`; the style needs `fontAssetId`. Miss any one and the text renders as nothing, with no error and nothing in `problems`.

**You must supply a font file.** Rive ships none and there is no system-font fallback — a missing font is a hard stop, not a styling problem.

Multiple `TextValueRun`s in one `Text` flow as a single paragraph, in document order, which is how rich text works.

Useful `Text` properties: `alignValue` (`left|right|center`), `sizingValue` (`autoWidth|autoHeight|fixed`), `overflowValue` (`visible|hidden|clipped|ellipsis|fit|fitFontSize`), `width`/`height`, `wrapValue`, `verticalAlignValue`, `originValue` (`top|baseline`).

**`TextStyleBackground`** paints a highlighter box behind runs, sized to the glyphs and unioned across them — the only box that tracks reflowing text. It takes `cornerRadius` and its own paint.

**Variable fonts** render at their default instance unless told otherwise, and that default is often not what you want (Montserrat's is Thin). `TextStyleAxis.tag` is the four-character OpenType axis tag packed big-endian: `wght` is `2003265652`, `wdth` is `2003072104`.

**OpenType features** work the same way: `smcp` is `1936548720`, `liga` is `1818847073`, `tnum` is `1953396077`. `TextStyleFeature.featureValue` is animatable. A wrong tag integer is indistinguishable from a font lacking the feature — only a visible A/B proves it works.

**Text modifiers** animate per glyph, word, or line:

```xml
<TextModifierGroup modifyOpacity="true" modifyTranslation="true" invertOpacity="true"
                   opacity="0" y="20" name="Fade In" id="0:40">
    <TextModifierRange modifyFrom="0" modifyTo="0.3" name="Sweep" id="0:41"/>
</TextModifierGroup>
```

**Every value on the group is inert unless the matching `modify*` flag is set** — `rotation="0.5"` without `modifyRotation="true"` is a complete no-op. Use `invertOpacity` whenever opacity is what you animate, because the default multiplies (`opacity="0"` makes every glyph invisible instead of fading in). Ranges default to a **zero-width falloff**, so glyphs pop rather than fade.

**Scripts cannot draw text at all** — there is no text API and `Font` is an opaque handle. Any text in a scripted node has to be markup.

## Putting it together

A card with a gradient background, a clipped badge with a soft radial glow, and text:

```xml
<Artboard defaultStateMachineId="0:50" styleId="0:5" width="400" height="240" name="Card" id="0:2">
    <LayoutComponentStyle name="Card Style" id="0:5"/>

    <Fill name="Background">
        <LinearGradient startX="0" startY="-120" endX="0" endY="120" name="G">
            <GradientStop colorValue="FF1E2430" position="0"/>
            <GradientStop colorValue="FF3A2A4A" position="1"/>
        </LinearGradient>
    </Fill>

    <Shape x="200" y="120" name="Badge" id="0:10">
        <Ellipse width="120" height="120" name="Path"/>
        <Fill name="Glow">
            <RadialGradient startX="0" startY="0" endX="0" endY="60" name="R">
                <GradientStop colorValue="80FFB020" position="0"/>
                <GradientStop colorValue="00FFB020" position="1"/>
            </RadialGradient>
        </Fill>
        <Fill name="Core"><SolidColor colorValue="FFFFC64A" name="C"/></Fill>
        <ClippingShape sourceId="0:20" name="Clip"/>
    </Shape>

    <!-- the mask is at the SAME position as the badge, or it clips it away -->
    <Shape x="200" y="120" name="ClipMask" id="0:20">
        <Ellipse width="90" height="90" name="P"/>
    </Shape>

    <Text x="200" y="200" name="Title" id="0:30">
        <TextStylePaint fontSize="28" fontAssetId="0:40" name="Body" id="0:31">
            <Fill name="Fill"><SolidColor colorValue="FFFFFFFF" name="C"/></Fill>
        </TextStylePaint>
        <TextValueRun styleId="0:31" text="Hello" name="Run"/>
    </Text>
</Artboard>
```

Note the glow uses a `RadialGradient` fading to alpha `00` rather than a `Feather`, and the mask matches the badge's position. Both of those are corrections to mistakes that rendered invisibly while every static check passed.

## Depth

| Topic | `rive docs <topic>` |
|---|---|
| Shapes, paint, gradients, images | `drawing` |
| Responsive layout, flex, grid, scroll | `layout` |
| Groups, transforms, opacity, draw order | `transforms` |
| Constraints, bones, skinning, image meshes, Solo, tags | `rigging` |
| Text, fonts, modifiers | `text` |
| Images, fonts, audio, shaders, blobs | `assets` |
