---
name: roblox-ui
description: >
  Building Roblox UI — engine primitives (GuiObjects, UDim2, AnchorPoint, layouts,
  inputs, containers) plus the Fusion 0.3 reactive framework. Use when writing,
  reviewing, or debugging UI components, sizing/positioning, layout structures,
  input handling, render order, or component lifecycle. UI layer only — engine
  semantics live in roblox-dev; language rules live in luau-expert;
  Rojo/Wally workflow lives in roblox-toolchain.
---

# Roblox UI

How Roblox UI works at the engine level + how to build it with **Fusion 0.3**.

Sources: [create.roblox.com/docs/ui](https://create.roblox.com/docs/ui) (engine primitives), [elttob.uk/Fusion/0.3](https://elttob.uk/Fusion/0.3) (Fusion docs), [github.com/dphfox/Fusion](https://github.com/dphfox/Fusion) (source).

For deep dives see:

- [`references/roblox-ui-primitives.md`](references/roblox-ui-primitives.md) — full GuiObject / layout / input reference
- [`references/design-guidelines.md`](references/design-guidelines.md) — framework-agnostic UX, spacing/type/color scales, states, motion, accessibility
- [`references/fusion-instances.md`](references/fusion-instances.md) — `New` / `Hydrate` / `[Children]` / `[OnEvent]` / `[OnChange]` / `[Out]` / `[Attribute]` / `[Child]` reference
- [`references/fusion-state.md`](references/fusion-state.md) — `Value`, `Computed`, `Observer`, `peek`, `use`, animation primitives

---

## Integration Policy

This skill describes preferred patterns; it does **not** authorize rewriting existing UI. Apply rules to new components and to changes the user explicitly asks for. **Match the project's chosen UI framework.** If the codebase uses Roact, don't migrate to Fusion unprompted. If existing components mix offset and scale, follow that mix. If there's already a theme module, use it — don't create a parallel one. Design Guidelines are recommendations, not enforcement.

Full rules: [`../../shared/integration-policy.md`](../../shared/integration-policy.md).

---

## Roblox UI Engine — Mental Model

Every Roblox UI is a tree of `GuiObject`s parented under a UI **container**. The container determines where it renders; the GuiObjects determine what shows up.

### Containers (where UI renders)

| Container | Where it shows | Lives under |
|---|---|---|
| **`ScreenGui`** | Flat 2D overlay on the player's screen | `Players[X].PlayerGui` (replicated from `StarterGui` per-character) |
| **`SurfaceGui`** | On a face of a `BasePart` in the 3D world (like a billboard) | A `BasePart`, or `StarterGui` with `Adornee` set |
| **`BillboardGui`** | Floating in 3D, always faces camera, optional `MaxDistance` | A `BasePart` / `Attachment`, or `StarterGui` with `Adornee` |

`ScreenGui` properties worth knowing:

- **`DisplayOrder`** — int ordering between sibling `ScreenGui`s (higher = on top).
- **`IgnoreGuiInset`** — when `false` (default), the topbar's reserved area shifts the visible region. Set `true` for full-screen overlays (loading screens, modal dialogs).
- **`ResetOnSpawn`** — if `true`, the GUI is destroyed and recloned from `StarterGui` every respawn. Set `false` for persistent state (HUDs, currency displays).
- **`ZIndexBehavior`** — `Sibling` (default; ZIndex only orders within same parent) vs `Global` (ZIndex orders across the whole tree). Almost always leave `Sibling`.

`SurfaceGui` extras:

- **`Face`** — which face of the part it shows on.
- **`SizingMode`** — `FixedSize` (use `CanvasSize` directly) vs `PixelsPerStud`.
- **`AlwaysOnTop`** — render even through occluders.

`BillboardGui` extras:

- **`Size`** here is in **studs** (UDim) not pixels — distance-scaled.
- **`MaxDistance`** culls the GUI past that range.
- **`StudsOffset` / `StudsOffsetWorldSpace`** — position in 3D relative to the adornee.

### `GuiObject` core properties

Every GuiObject (`Frame`, `TextLabel`, `ImageButton`, etc.) shares:

- **`Size: UDim2`** — `{ScaleX, OffsetX}, {ScaleY, OffsetY}`. Scale is fraction of parent; Offset is pixels. Both add.
- **`Position: UDim2`** — same shape; offset of the AnchorPoint inside the parent.
- **`AnchorPoint: Vector2`** — `(0..1, 0..1)`. Origin of position + scaling. Default `(0,0)` = top-left. `(0.5, 0.5)` = centered (use with `Position = UDim2.fromScale(0.5, 0.5)` to center in parent).
- **`AbsoluteSize: Vector2`** — read-only, computed in pixels at the current frame.
- **`AbsolutePosition: Vector2`** — read-only, computed in pixels at the current frame.
- **`AutomaticSize: Enum.AutomaticSize`** — `None` / `X` / `Y` / `XY`. Sizes the object to fit its content. Pairs with `Size` set to `(0,0,0,0)` along the auto axis.
- **`ClipsDescendants: boolean`** — clip children to this object's bounds.
- **`Visible: boolean`** — show/hide. Hidden objects don't receive input.
- **`Active: boolean`** — must be `true` for `MouseButton1Down`-style events on plain Frames; buttons (`TextButton`/`ImageButton`) are always active.
- **`ZIndex: number`** — render order within siblings (higher = front).
- **`LayoutOrder: number`** — sort order inside a layout structure (`UIListLayout`, etc.).
- **`Selectable: boolean`** — gamepad selection eligibility.

### `UDim2` cheatsheet

```luau
UDim2.new(sx, ox, sy, oy)                -- explicit
UDim2.fromOffset(px, py)                 -- pure pixel: (0, px, 0, py)
UDim2.fromScale(sx, sy)                  -- pure scale: (sx, 0, sy, 0)
UDim2.new(0.5, 0, 0.5, 0)                -- center if AnchorPoint is (0.5, 0.5)
UDim2.new(1, -20, 1, -20)                -- fill parent minus 10px margin on each side
```

**Rule:** mix scale + offset deliberately. Pure scale = layout fluid with screen size. Pure offset = pixel-perfect, breaks on phones. Most production UI uses scale for outer containers and offset for inner content.

### Layout structures (parent-controlled positioning)

Drop one of these as a child to take over the layout of its siblings. The siblings' `Position` is ignored; `Size` may be too depending on the layout.

| Class | What it does |
|---|---|
| **`UIListLayout`** | Stacks children along an axis (`FillDirection = Vertical/Horizontal`). Honors `LayoutOrder`, `Padding`, `HorizontalAlignment` / `VerticalAlignment`, `SortOrder`. |
| **`UIGridLayout`** | Grid with `CellSize` + `CellPadding`. |
| **`UIPageLayout`** | One child visible at a time; `:JumpTo(child)` / `:Next()` / `:Previous()`. Common for tabs / wizards. |
| **`UITableLayout`** | Rows of equal height; columns of equal width per row. Less common than `UIGridLayout`. |

```luau
-- UIListLayout — vertical stack with 8px gap, sorted by LayoutOrder
local container = Instance.new("Frame")
local layout = Instance.new("UIListLayout", container)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
```

### Modifiers & constraints (single-instance tweaks)

Drop one as a child of the GuiObject it modifies:

| Class | Effect |
|---|---|
| **`UICorner`** | Rounded corners. `CornerRadius: UDim`. |
| **`UIPadding`** | Inset for children (top/bottom/left/right `UDim`). Doesn't change own size; affects child layout. |
| **`UIStroke`** | Outline. `Thickness`, `Color`, `Transparency`, `ApplyStrokeMode = Border / Contextual`, `StrokeSizingMode`. Replaces the old border properties. **Set `StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize`** so thickness scales with parent size — keeps strokes proportional across screen sizes. Default `FixedSize` keeps a constant pixel thickness regardless of UI scale. |
| **`UIScale`** | Multiplier on the GuiObject's effective size + descendants. Useful for global zoom. |
| **`UIAspectRatioConstraint`** | Lock width/height ratio. `AspectRatio`, `AspectType = ScaleWithParentSize / FitWithinMaxSize`, `DominantAxis`. |
| **`UISizeConstraint`** | Min/max pixel size. |
| **`UITextSizeConstraint`** | Min/max text size for `TextScaled` text. |
| **`UIGradient`** | Linear gradient; tints by `Color: ColorSequence` + `Transparency: NumberSequence` + `Rotation`. Affects descendants. |
| **`UIFlexItem`** | Per-child flex weights inside a flex-enabled `UIListLayout`. |

### Common GuiObjects

- **`Frame`** — plain rectangle. `BackgroundColor3`, `BackgroundTransparency`, `BorderSizePixel = 0` (modern UI sets this to 0 always).
- **`ScrollingFrame`** — clipped frame with scroll. Set `CanvasSize: UDim2` (or `AutomaticCanvasSize = X/Y/XY` to fit content automatically). `ScrollBarImageColor3` + `ScrollBarThickness` style the bar.
- **`CanvasGroup`** — group children for compositing (alpha-blends as one layer; enables full-group transparency without per-child fade).
- **`TextLabel` / `TextButton` / `TextBox`** — text. Properties: `Text`, `Font` (legacy) or `FontFace: Font` (modern), `TextSize`, `TextColor3`, `TextWrapped`, `TextScaled` (autosizes to fit; pair with `UITextSizeConstraint`), `RichText` (parses `<b>`, `<i>`, `<font color="...">`, etc.), `TextXAlignment` / `TextYAlignment`, `LineHeight`.
- **`TextBox`** extras: `PlaceholderText`, `PlaceholderColor3`, `ClearTextOnFocus`, `MultiLine`, `:CaptureFocus()` / `:ReleaseFocus()`. Events: `Focused`, `FocusLost(enterPressed, inputThatCausedFocusLoss)`.
- **`ImageLabel` / `ImageButton`** — `Image: Content`, `ImageColor3`, `ImageTransparency`, `ScaleType` (`Stretch` / `Tile` / `Slice` / `Fit` / `Crop`), `SliceCenter: Rect` (9-slice), `TileSize: UDim2` (for tile mode).
- **`ViewportFrame`** — render a 3D scene inside a UI element. Has its own `Camera`, `WorldModel`. Use for item previews, character cards.
- **`VideoFrame`** — play `rbxasset://` videos. Limited use case; prefer in-world video on parts.

### Inputs

For buttons (`TextButton` / `ImageButton`):

```luau
button.Activated:Connect(function(inputObject, numClicks)
    -- Fires for: left mouse click, touch tap, gamepad A, Enter when focused.
end)
```

`Activated` is the right default — it abstracts mouse/touch/gamepad. Use only when you need lower-level events:

- `MouseButton1Down` / `MouseButton1Up` / `MouseButton2Down` / etc. — mouse-specific.
- `TouchTap` / `TouchPan` / `TouchPinch` — touch-specific.

For arbitrary GuiObjects (set `Active = true` first):

- `InputBegan(input)` / `InputChanged(input)` / `InputEnded(input)` — receives `InputObject` with `UserInputType` (Mouse / Touch / Gamepad / Keyboard) and `KeyCode` / `Position` / `Delta`.

For global input (camera, hotkeys, etc.) **don't** put listeners on a GuiObject — use:

- **`UserInputService`** — global signals: `InputBegan`, `InputChanged`, `InputEnded`, `JumpRequest`, plus gamepad helpers. Always provides a `gameProcessed: boolean` second arg — if `true`, the engine already consumed the input (e.g. user typed in a TextBox, clicked a button). Skip when `gameProcessed` is true unless you have a reason.
- **`ContextActionService`** — bind named actions to multiple inputs at once with priorities and runtime rebinding. Better for rebindable hotkeys.

### Render order

- **Between `ScreenGui`s:** `DisplayOrder` (higher = front).
- **Within a `ScreenGui` (siblings):** `ZIndex` (higher = front). Default behavior is `Sibling` — only orders within same parent.
- **Inside a layout:** `LayoutOrder` (lower = first in the layout direction).

`ScreenGui.ZIndexBehavior = Global` makes ZIndex order across the whole tree — almost never desired; usually a sign of a workaround for incorrect parenting.

### Topbar inset & safe areas

Roblox reserves an area at the top of the screen for the chat / leaderboard / menu button. By default, every `ScreenGui` is offset to start *below* this area.

- **`ScreenGui.IgnoreGuiInset = true`** to fill the entire screen (loading screens, modal full-screen UIs, splash screens).
- For mid-UI placement, `GuiService:GetGuiInset()` returns `(topLeft: Vector2, bottomRight: Vector2)` describing the reserved insets — useful when manually positioning.
- iOS notch / Android camera cutout are part of the inset on those platforms.

### Caveats & "hacks" worth knowing

- **`AbsoluteSize` / `AbsolutePosition` are 1-frame stale on creation.** A freshly-parented Frame reports `(0, 0)` until the first layout pass. Wait `RunService.Heartbeat` once before measuring, or use the `:GetPropertyChangedSignal("AbsoluteSize")` to react.
- **`AutomaticSize` cycles.** If a parent has `AutomaticSize = X` and a child is `Size = UDim2.fromScale(1, 0)`, you've created a cycle (parent measures children, child wants 100% of parent). Behavior is implementation-defined; avoid.
- **Centering shorthand:** `AnchorPoint = Vector2.new(0.5, 0.5)` + `Position = UDim2.fromScale(0.5, 0.5)`. Any other approach is fighting the system.
- **Aspect-locked containers:** `UIAspectRatioConstraint` on a Frame whose `Size` is pure scale, e.g. `UDim2.fromScale(0.8, 1)` + `AspectRatio = 16/9`. Container fills 80% of width but height becomes 80%-width / aspect.
- **Perfect square inside any parent:** `Size = UDim2.fromScale(1, 1)` + `UIAspectRatioConstraint` with `AspectRatio = 1`, `AspectType = FitWithinMaxSize`, `DominantAxis = Width`. The frame fills its parent on the smaller axis and stays square — works for any parent shape (wide, tall, dynamically resized).
- **Pixel-perfect on phones:** rely on `Offset` + `UISizeConstraint`. Pure scale UIs render at unpredictable sizes on small screens.
- **`TextScaled` + `UITextSizeConstraint`** clamps the auto-fit text size between min/max — without the constraint, very small parent heights produce 1px text.
- **Fake shadows:** `UIStroke` with low transparency offset visually, or stack `ImageLabel`s with `ScaleType = Slice` and a 9-slice shadow PNG.
- **Rounded button with image:** `ImageButton` + `UICorner` + `ClipsDescendants`, or use `ScaleType = Slice` on a 9-sliced rounded asset — `UICorner` is the modern path.
- **Modal dialogs:** create a full-screen `Frame` with `BackgroundTransparency = 0.5` and a high `ZIndex`. Set `Active = true` so it intercepts clicks. Set `Modal = true` on the contained TextBox / button for gamepad / keyboard navigation lock.
- **Dragging:** `UserInputService` is more reliable than `InputBegan/Changed/Ended` chains because you don't lose tracking when the cursor leaves the source GuiObject. Track delta via `input.Delta` (mouse) or `input.Position` (touch).
- **Selection groups (gamepad nav):** `GuiService.SelectedObject` and `NextSelectionUp/Down/Left/Right` on each GuiObject configure the focus graph. Set `Selectable = true` on every focusable item.
- **Hide cursor in custom UI flows:** `UserInputService.MouseIconEnabled = false`. Restore on cleanup.
- **Measuring text:** `TextService:GetTextSize(text, size, font, frameSize) -> Vector2`. Useful before sizing a parent. Prefer `AutomaticSize` if you can.
- **Modern font: `FontFace`** is a `Font` datatype (`Font.new(family, weight, style)`). The legacy `Font: Enum.Font` still works but the family enum is frozen. Prefer `FontFace` for new code.

Full primitive reference: [`references/roblox-ui-primitives.md`](references/roblox-ui-primitives.md).

---

## Design Guidelines

Framework-agnostic. Applies to Fusion, Vide, React Lua, or raw `Instance.new`. Aesthetic target: **neutral clean product** (think Discord / Notion / modern game launchers — works in most contexts without committing to one art style). **Optimize for UX and consistency, not novelty.**

### Principles

- **Hierarchy beats decoration.** Size, weight, and contrast carry meaning. A button that's the same size and color as the disabled label next to it is a UX bug.
- **Consistency beats cleverness.** Same action → same visual treatment everywhere. Same spacing rhythm everywhere. Pick a scale and stick to it.
- **Feedback for every action.** No silent UI. Click → state change. Loading → spinner / skeleton. Error → message. Empty → guidance.
- **One focal point per screen.** Primary action visible. Everything else recedes. If two things compete equally, neither wins.
- **Respect the platform.** Mobile = touch targets. Console = gamepad nav graph. Desktop = hover affordances. Test on the inputs your players use.
- **Performance is UX.** A laggy UI feels broken regardless of how it looks. Avoid `RunService.Heartbeat` re-renders, large rgb gradients on every frame, deep instance trees that re-replicate.

### Spacing scale

Pick one base unit and multiply. The agent default:

```
4  8  12  16  24  32  48  64
```

In scale terms (relative to a parent's smaller axis, ~720–1080 dp): `0.005, 0.01, 0.015, 0.02, 0.03, 0.04, 0.06, 0.08`. Use `UIPadding` + `UIListLayout.Padding` for spacing — never magic offsets between elements.

**Rule:** every `UIPadding` value, every layout gap, every margin should be a step on this scale. If you find yourself typing `UDim.new(0.017, 0)` you've left the scale.

### Type scale

```
12  14  16  18  24  32  48
```

Roles:

| Size | Use |
|---|---|
| 12 | Captions, metadata, footnotes |
| 14 | Body small, secondary labels |
| 16 | Body, button text (default) |
| 18 | Emphasized body, card titles |
| 24 | Section headings |
| 32 | Page titles |
| 48 | Display / hero only |

One font family for the whole UI. Two max (body + display). Use `FontFace = Font.fromName(...)` and reuse the same `Font` across the project. Always pair `TextScaled = true` with `UITextSizeConstraint { MaxTextSize = N }` from this scale.

### Color

Semantic roles, not raw colors:

- **`Surface`** — base background.
- **`SurfaceElevated`** — cards, modals (one shade lighter than Surface on dark UIs).
- **`Primary`** — main brand action.
- **`OnPrimary`** — text/icon on Primary.
- **`Text`** — primary text.
- **`TextMuted`** — secondary text.
- **`Border`** — dividers, strokes.
- **`Success` / `Warning` / `Danger`** — semantic feedback.

Centralize in one module/table. Never inline `Color3.fromRGB(0, 120, 255)` at call sites — refer to `theme.Primary`.

**Contrast:** WCAG AA = 4.5:1 for body text, 3:1 for large text (18+). Test palettes; many "pretty" combinations fail.

**Don't:**
- Rainbow gradients on UI surfaces.
- Color as the only signal (red error needs an icon + label; colorblind players exist).
- Pure black `Color3.new(0, 0, 0)` text on pure white — too harsh; use `(0.1, 0.1, 0.12)` ish.

### Hierarchy & layout

- **Group related content.** `UIListLayout` + spacing scale. Whitespace is the cheapest way to communicate "these belong together" / "these don't".
- **One H1 per screen.** Page title at the top, distinct size + weight from anything else.
- **Buttons follow a rank**: Primary (filled, brand color) → Secondary (outline, neutral) → Tertiary (text only). Never two primaries side by side.
- **Align everything.** Use `UIListLayout` / `UIGridLayout` rather than per-child positions. Misaligned text/edges read as sloppy.

### State coverage (every interactive element)

Every button / input / selectable needs:

| State | Visual cue |
|---|---|
| **Default** | Base style |
| **Hover** (mouse) | Slight tint shift or border highlight |
| **Pressed** | Darker / inset look |
| **Focused** (gamepad / keyboard) | `UIStroke` highlight, never just color |
| **Disabled** | Reduced contrast, no hover; `Active = false` |
| **Loading** | Spinner / skeleton; lock further input |
| **Error** | Inline message + icon |

Don't ship a button without at least Default + Hover + Pressed + Disabled.

### Motion

- **Timing**: 150–250ms for most transitions. <100ms feels instant (good for hover); >300ms feels sluggish.
- **Easing**: `Quad / Sine Out` for entry. `Quad / Sine In` for exit. Linear only for indeterminate spinners.
- **Spring** for interactive feedback (hover, drag, snap-back). **Tween** for fixed-duration transitions (page change, fade in/out).
- **Always animate** state changes that affect layout. Snap = jarring; tween = continuity.
- **Never animate** for decoration alone. Motion should communicate cause→effect.
- **Respect reduced-motion**: if the platform exposes it, honor it.

### Touch targets & input

- **Min 44×44 px** for touch targets (Apple HIG / Material). Use `UISizeConstraint { MinSize = Vector2.new(44, 44) }` even when the button is scale-sized.
- **Hover affordance** for desktop. Hand cursor (`MouseCursor` on `ImageLabel/Button`) for clickables.
- **Gamepad selection graph** explicit (`NextSelectionUp/Down/Left/Right`). `GuiService.SelectedObject` set on screen open.
- **Keyboard support**: TextBoxes accept Enter to submit, Escape to cancel where applicable.

### Responsive

- **Scale-first sizing.** Pure-pixel UIs break on phones.
- **`UIAspectRatioConstraint`** on key panels so they don't squash.
- **`UISizeConstraint`** for min/max pixel bounds — UI shouldn't shrink below readable.
- **Test the extremes**: the smallest phone screen (320–375 dp wide, portrait) and the largest desktop (3840 dp wide).
- **Don't rely on viewport-side detection** for layout switches; use the same UI everywhere with proper constraints. Detect input *type* (`UserInputService.TouchEnabled`, `GamepadEnabled`) for behavior, not for layout.

### Empty / loading / error states

For every surface that loads async data:

- **Empty** — useful guidance ("No friends online — invite someone"). Not a blank rectangle.
- **Loading** — spinner or skeleton (placeholder shapes). Lock input on submit-style flows.
- **Error** — inline message, retry affordance. Never just disappear.

### Accessibility

- **Contrast**: WCAG AA minimums.
- **Min text size**: 12pt floor. 14pt for body.
- **Don't rely on color alone**: pair with icon, label, or pattern.
- **Focus indicators visible**: `UIStroke` on focused element.
- **Gamepad-navigable**: every interactive element reachable via the selection graph.
- **No flashing >3 Hz** (seizure risk).

### Anti-Patterns (Design)

| ❌ | ✅ |
|---|---|
| Magic-number spacing (`UDim.new(0.017, 0)`) | Step from the spacing scale |
| Inline colors at call sites | Theme module / table |
| Same-size siblings forming a wall of text | Hierarchy via size/weight/color |
| Two primary buttons side-by-side | One primary + one secondary |
| Drop-shadow under every card | Reserve elevation for things that pop forward |
| Border radii: 4px / 8px / 12px / 6px on different elements | Pick 2 radii max (e.g. `UDim.new(0.1, 0)` for buttons, `UDim.new(0.04, 0)` for cards) |
| `BorderSizePixel = 1` | Always 0; use `UIStroke` if you need an edge |
| Silent disabled state (button just doesn't do anything) | Visibly muted + `Active = false` + `AutoButtonColor = false` |
| Snap state changes (instant color flip) | Tween / Spring the transition |
| Pure scale on a phone-sized device | Combine scale with `UISizeConstraint` minimums |
| Color-only error (red border, no message) | Icon + label + color |
| Empty state showing nothing | Guidance + CTA |
| Three different fonts | One body + one display max |
| Comic-sans-tier font choice for prod UI | Modern sans (BuilderSans / Inter / SF / Roboto family) |
| Per-element animation timing | Centralized motion tokens (e.g. `MOTION_FAST = 0.15`) |
| Per-frame `RunService.Heartbeat` UI rebuilds | State-driven; let the framework batch |
| Hover-only affordance for clickables | Visible enough that you don't need to hover to find it |
| Ignoring topbar inset | Set `IgnoreGuiInset` deliberately based on intent |

Full coverage with code examples in [`references/design-guidelines.md`](references/design-guidelines.md).

---

## Don't Mix Frameworks

Fusion, Vide, and React Lua have **incompatible reactive models**. Pick one for a project. Wrapping one in another breaks lifecycle assumptions and creates leaks. If you must interop (e.g. Roact-Fusion bridge), read the bridge's docs first; don't roll your own.

| Library | Mental model |
|---|---|
| **Fusion** | Reactive declarative; scope-based lifecycle; state objects + computeds |
| **Vide** | Lightweight reactive; sources + effects; functional-only API |
| **React Lua** | React-style components; hooks; element tree |

---

# Fusion 0.3

Reactive declarative UI with explicit scope-based lifecycle.

## Principles

- **Every object lives in a scope.** Scopes are arrays that hold cleanup tasks. `Fusion.doCleanup(scope)` runs them in reverse order. No scope = leak.
- **State objects, not variables.** `scope:Value(initial)` is the unit of mutable state. Read with `peek(stateObj)`. Write with `stateObj:set(new)`.
- **Computed = pure derivation.** `scope:Computed(function(use, scope) ... end)` re-runs when any `use(stateObj)` changes. The calculation must be immediate (no yields).
- **Instances are described, not constructed.** `scope:New "TextLabel" { ... }` declares the instance with its props and children inline; Fusion handles creation, defaults, hydration, cleanup.
- **One framework per project.** Don't mix with Vide or React Lua.

---

## Scopes

A scope is an array of cleanup tasks. Things added to a scope are destroyed when the scope is cleaned up.

```luau
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local scoped = Fusion.scoped
local doCleanup = Fusion.doCleanup

local scope = scoped(Fusion)         -- scope with all Fusion methods bound
local health = scope:Value(100)
local name = scope:Value("Player")

-- ...later
scope:doCleanup()                    -- destroys everything in reverse order
```

`scoped(Fusion)` returns a scope with every Fusion function attached as a method, callable with the scope itself as the first arg via `:Method(...)` syntax. Equivalent forms:

```luau
local v = Fusion.Value(scope, 5)     -- function form
local v = scope:Value(5)             -- method form (preferred)
```

### Scope hierarchy

- **`scope:innerScope()`** — child scope auto-cleaned when parent is cleaned. Use for short-lived UI (dropdowns, modals).
- **`scope:deriveScope()`** — sibling scope with the same methods but no auto-clean link. Use sparingly; prefer `innerScope`.

```luau
local uiScope = scoped(Fusion)

uiScope:insert(
    dropdownOpened:Connect(function()
        local dropdownScope = uiScope:innerScope()    -- auto-cleaned with uiScope
        -- build dropdown using dropdownScope...
        dropdownScope:insert(
            dropdownClosed:Connect(function() dropdownScope:doCleanup() end)
        )
    end)
)
```

`scope:insert(task1, task2, ...)` adds tasks (Connections, Instances, callbacks) to a scope and returns them.

### What `doCleanup` accepts

- Functions to run.
- Roblox `Instance`s (calls `:Destroy()`).
- `RBXScriptConnection`s (calls `:Disconnect()`).
- Tables with `:destroy()` / `:Destroy()` / `:disconnect()` / `:Disconnect()`.
- Other scopes (nested cleanup).

---

## State Objects

### `Value`

```luau
local health = scope:Value(100)
print(Fusion.peek(health))   -- 100
health:set(75)
print(Fusion.peek(health))   -- 75
```

`peek(stateObj)` reads current value. Doesn't subscribe to changes.

### `Computed`

Derived state. The callback receives `(use, scope)`. `use(stateObj)` reads **and** subscribes — the computed re-runs when any `use`'d state changes.

```luau
local coins = scope:Value(50)
local price = scope:Value(10)

local remaining = scope:Computed(function(use, scope)
    return use(coins) - use(price)
end)

print(peek(remaining))   -- 40
coins:set(25)
print(peek(remaining))   -- 15
```

**Rules:**

- Calculation must be immediate — no yielding (`task.wait`, RemoteEvents, etc.).
- `use(x)` reads + subscribes; `peek(x)` only reads.
- The second `scope` parameter is a **fresh inner scope** that's auto-cleaned each time the computed recalculates. Use it for objects whose lifetime should match the calculation:

```luau
scope:Computed(function(use, scope)
    local current = use(number)
    table.insert(scope, function() print("Cleaning up", current) end)
    return current * 2
end)
-- The cleanup runs each time `number` changes, before recalculating.
```

- **Optimization caveat:** computeds may not recalculate if nothing observes them. Don't rely on side effects inside; use `Observer` for those.

### `Observer`

Fires a callback when a state object changes.

```luau
local health = scope:Value(100)
local healthChanged = scope:Observer(health)

healthChanged:onChange(function()
    print("health is now", peek(health))
end)
```

For side effects (sound, network, logging) tied to state changes — never put side effects in `Computed`.

### `peek` and `use`

- **`peek(x)`** — global read. Doesn't subscribe.
- **`use(x)`** — only inside `Computed` callback. Reads + subscribes for re-runs.

Always name the first computed parameter `use` even when shadowing — `--!nolint LocalShadow` suppresses Luau warnings if needed.

---

## Instances — `New`

Create an instance with props inline:

```luau
local message = scope:Value("Hello!")

local label = scope:New "TextLabel" {
    Name = "Greeting",
    Parent = playerGui.ScreenGui,
    Text = message,                        -- state object → live binding
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(200, 50),
}
```

**State objects bound to props update the instance automatically** on the next frame after `:set()`. Constants are applied once.

`scope:New "X" { ... }` is sugar for `scope:New("X")({ ... })`. The two-call form is required when not using string literals + curly braces.

Fusion's `New` applies its own sane defaults (e.g. UI borders off, background transparency 1, automatic colors off) — different from `Instance.new()` defaults. See [Fusion source's `defaultProps.luau`](https://github.com/dphfox/Fusion/blob/main/src/Instances/defaultProps.luau) for the full list.

`scope:Hydrate(existingInstance) { ... }` applies the same prop logic to an instance you already own.

### Special prop keys

```luau
scope:New "TextButton" {
    Text = "Click me",

    [Children] = {
        scope:New "UICorner" { CornerRadius = UDim.new(0, 8) },
        scope:New "UIPadding" { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
    },

    [OnEvent "Activated"] = function(_, numClicks)
        print("clicked", numClicks)
    end,

    [OnChange "AbsoluteSize"] = function(newSize)
        print("resized to", newSize)
    end,

    [Out "Text"] = textState,           -- write Text property out to a state object
}
```

`Children`, `OnEvent`, `OnChange`, `Out` are imported directly from `Fusion`, not via `scope`.

```luau
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
local Out = Fusion.Out
```

**Capturing the Instance:** Fusion 0.3 has no `Ref` key. `scope:New "X" {...}` returns the Instance — assign it to a local and use it directly:

```luau
local frame = scope:New "Frame" { ... }
-- ...elsewhere:
frame.BackgroundColor3 = Color3.new()      -- direct mutation; for reactive props, use a Value bound to the prop
```

Older Fusion (0.2 and earlier) had `Ref`; 0.3 removed it.

`[Children]` accepts: a single Instance, an array of Instances (any nesting depth), or a state object containing either.

Full reference: [`references/fusion-instances.md`](references/fusion-instances.md).

---

## Components

A component is a function that takes `(scope, props)` and returns an Instance.

```luau
type UsedAs<T> = Fusion.UsedAs<T>   -- "T or a state object holding T"

local function Button(
    scope: Fusion.Scope,
    props: {
        Text: UsedAs<string>,
        OnClick: () -> ()?,
        Size: UsedAs<UDim2>?,
        LayoutOrder: UsedAs<number>?,
    }
): TextButton
    return scope:New "TextButton" {
        Size = props.Size or UDim2.fromOffset(120, 40),
        LayoutOrder = props.LayoutOrder,
        BackgroundColor3 = Color3.fromRGB(0, 120, 255),
        Text = props.Text,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,

        [Children] = scope:New "UICorner" { CornerRadius = UDim.new(0, 6) },
        [OnEvent "Activated"] = function() if props.OnClick then props.OnClick() end end,
    }
end

return Button
```

Use it via either form:

```luau
-- Function form
local btn = Button(scope, { Text = "OK", OnClick = save })

-- Method form (after registering on the scope)
local scope = scoped(Fusion, { Button = Button })
local btn = scope:Button { Text = "OK", OnClick = save }
```

`UsedAs<T>` is the right prop type for "constant or state object" — `peek()` and `use()` handle both transparently.

### Optional vs nullable props

`UsedAs<T>?` and `UsedAs<T?>` look similar but mean different things:

```luau
-- Optional with a sensible default — caller may omit; component substitutes a default.
Position: UsedAs<UDim2>?

-- Nullable — `nil` is itself a meaningful value the component reacts to
-- (e.g. cleared input, no selection). Caller must pass it; the inner T is what's optional.
Value: UsedAs<string?>
```

Rule: pick `UsedAs<T>?` when the prop has a default. Pick `UsedAs<T?>` when the absence of a value is part of the component's state model.

### Typed scopes

The `scope` parameter can carry the methods a component expects. Two patterns:

```luau
-- Public component: constrain the scope so callers see what's required.
-- typeof(Fusion) covers all built-in constructors; narrow further if you want.
local function Card(
    scope: Fusion.Scope<typeof(Fusion)>,
    props: { ... }
): Frame
    return scope:New "Frame" { ... }
end

-- Implementation-detail helpers: take a plain Fusion.Scope and derive an
-- inner scope with the helpers attached. Callers don't need to know about them.
local function Modal(scope: Fusion.Scope, props: { ... }): Frame
    local inner = scope:innerScope { Backdrop = Backdrop, FocusTrap = FocusTrap }
    return inner:New "Frame" { ... }
end
```

Rule: prefer `innerScope` for niche helpers. Keeps the public signature clean and lets callers pass any compatible scope.

### One component per file

Each component (`Button`, `Card`, `Modal`) lives in its own ModuleScript. Improves discoverability, keeps files focused, encourages reuse. Compose by registering on a parent scope:

```luau
local scope = scoped(Fusion, { Button = Button, Card = Card })
local ui = scope:Card { [Children] = scope:Button { Text = "OK" } }
```

---

## Common Mistakes

| ❌ | ✅ |
|---|---|
| Creating Fusion objects without a scope | Always `scoped(Fusion)` first |
| Using `peek()` inside a `Computed` callback | Use `use(x)` so re-runs trigger |
| Yielding inside a `Computed` callback | Computeds must be immediate; do async work elsewhere and feed a `Value` |
| Side effects in `Computed` (sounds, network) | Put them in `Observer:onChange(...)` |
| Forgetting `scope:doCleanup()` on UI tear-down | Always tie scope lifetime to a parent (root scope, `innerScope` of a parent) |
| `Instance.new("Frame")` then setting properties | `scope:New "Frame" { ... }` — gets defaults + cleanup for free |
| Children added with `child.Parent = parent` after-the-fact | Use `[Children]` in the prop table |
| Connecting events with `inst.Activated:Connect(...)` directly on a Fusion-created instance | `[OnEvent "Activated"] = handler` — gets cleaned with the scope |
| Storing a constant where the API wants `UsedAs<T>` | Pass the constant directly; Fusion handles it |
| `scope:Computed` capturing `scope` in cleanup callbacks | Use the second `scope` param — it's auto-cleaned per recalculation |
| Passing one scope to multiple unrelated UI trees | `innerScope`/`deriveScope` per logical group |
| Using `:Destroy()` on a Fusion-managed instance | `doCleanup` the scope; let Fusion tear down |
| Mixing Fusion with Vide / React Lua in the same tree | Pick one |

---

## Verification Rules

- **Fusion 0.x is pre-1.0; APIs change between minor versions.** This skill targets **0.3**. If the project pins a different version (`wally.toml`), verify the API against that version's docs before quoting.
- **`elttob.uk/Fusion/0.3` is the canonical reference for 0.3** — older Fusion docs (0.2 and earlier) used a different API (no scopes; `Computed` had a different signature). Don't mix tutorials.
- **Don't quote internal types or fields beyond the public API.** Fields prefixed with `_` aren't stable.
- **`UsedAs<T>` is the modern name for what older docs called `CanBeState<T>` or `StateOrValue<T>`.** Same idea; verify the actual exported type name in your installed Fusion.
- **For Vide / React Lua questions** — defer until those sections of this skill are written.

---

## Examples

- [`examples/fusion-counter.luau`](examples/fusion-counter.luau) — `Value` + `Computed` + `Observer` + `New`; full reactive chain.
- [`examples/fusion-button.luau`](examples/fusion-button.luau) — `Button` component with `UsedAs` props, scoped registration.
- [`examples/fusion-list.luau`](examples/fusion-list.luau) — dynamic children driven by a state object.
- [`examples/fusion-form.luau`](examples/fusion-form.luau) — `[Out "Text"]` capture + Instance-by-assignment for programmatic focus; submit handler.
- [`examples/fusion-animation.luau`](examples/fusion-animation.luau) — `Tween` + `Spring`: hover scale (Spring), color/transparency transitions (Tween), drop-shadow fade.

