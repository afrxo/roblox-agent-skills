# Roblox UI Primitives — Reference

Source: [create.roblox.com/docs/ui](https://create.roblox.com/docs/ui).

Engine-level UI knowledge. Framework-agnostic; applies whether you build with Fusion, Vide, React Lua, or hand-written `Instance.new`.

---

## Containers

### `ScreenGui`

The on-screen 2D container. Lives under `Players[X].PlayerGui`.

| Property | Notes |
|---|---|
| `DisplayOrder: number` | Sort order between sibling ScreenGuis. Higher = front. |
| `IgnoreGuiInset: boolean` | If `true`, fills the entire screen including the topbar reserved area. |
| `ResetOnSpawn: boolean` | If `true`, the GUI is destroyed and re-cloned from `StarterGui` on every respawn. |
| `Enabled: boolean` | Master visibility. |
| `ZIndexBehavior: Enum.ZIndexBehavior` | `Sibling` (default, scoped per-parent) vs `Global` (whole-tree ZIndex). Stick with `Sibling`. |
| `ScreenInsets: Enum.ScreenInsets` | `None`, `DeviceSafeInsets`, `CoreUISafeInsets` — controls how the GUI respects platform safe areas. |
| `ClipToDeviceSafeArea: boolean` | Clips the GUI inside the device safe area (iOS notch, Android cutout). |

### `SurfaceGui`

UI rendered onto a face of a `BasePart`.

| Property | Notes |
|---|---|
| `Adornee: Instance?` | The part to render on (or set the SurfaceGui's parent to a part). |
| `Face: Enum.NormalId` | Which face. |
| `SizingMode: Enum.SurfaceGuiSizingMode` | `FixedSize` (use `CanvasSize` directly) or `PixelsPerStud`. |
| `CanvasSize: Vector2` | Resolution of the canvas in pixels. |
| `PixelsPerStud: number` | When in `PixelsPerStud` mode, how many pixels per stud. |
| `AlwaysOnTop: boolean` | Render even through occluders. |
| `LightInfluence: number` | `0` = unlit, `1` = full lighting. |

### `BillboardGui`

UI floating in 3D, always faces camera.

| Property | Notes |
|---|---|
| `Adornee: Instance?` | The part / attachment it follows. |
| `Size: UDim2` | Width/height in studs (Scale) or pixels (Offset). Stud-scaled by camera distance. |
| `MaxDistance: number` | Cull the GUI beyond this range (0 = no limit). |
| `StudsOffset: Vector3` | Offset relative to adornee, in camera space. |
| `StudsOffsetWorldSpace: Vector3` | Offset relative to adornee, in world space. |
| `LightInfluence: number` | Same as SurfaceGui. |
| `AlwaysOnTop: boolean` | Render through occluders. |

---

## `GuiObject` — Shared Properties

Every GuiObject (`Frame`, `TextLabel`, `ImageButton`, etc.) inherits these.

### Position / size

- **`Size: UDim2`** — `{(ScaleX, OffsetX), (ScaleY, OffsetY)}`. Scale is fraction of parent's `AbsoluteSize`; Offset is pixels. Final size in pixels = `parentAbsoluteSize * Scale + Offset` per axis.
- **`Position: UDim2`** — same shape. The position of the AnchorPoint inside the parent.
- **`AnchorPoint: Vector2`** — `(0..1, 0..1)`. Origin of position + scaling. `(0,0)` = top-left, `(0.5, 0.5)` = center, `(1, 1)` = bottom-right.
- **`AbsoluteSize: Vector2`** — read-only pixel size after scale/offset/constraints.
- **`AbsolutePosition: Vector2`** — read-only pixel position (top-left corner) after layout.
- **`AbsoluteRotation: number`** — read-only rotation in degrees (sums Rotation up the parent chain).
- **`Rotation: number`** — degrees. Rotates around AnchorPoint.

### `AutomaticSize`

```luau
frame.AutomaticSize = Enum.AutomaticSize.Y    -- height fits content; width still controlled by Size
frame.Size = UDim2.new(1, 0, 0, 0)            -- width = 100% of parent, height = auto
```

Values: `None` / `X` / `Y` / `XY`. Used heavily with `UIPadding`, `UIListLayout`. Watch for cycles (parent + child both auto on the same axis).

### Other shared

- **`ZIndex: number`** — render order within siblings. Higher = front.
- **`LayoutOrder: number`** — order inside a layout structure (`UIListLayout`, etc.). Lower = first.
- **`ClipsDescendants: boolean`** — clip children to this object's rect.
- **`Visible: boolean`** — show/hide. Hidden objects don't process input.
- **`Active: boolean`** — required for input events on plain Frames. Buttons are always active.
- **`Selectable: boolean`** — gamepad/controller can select.
- **`SelectionImageObject: GuiObject?`** — custom selection highlight.
- **`Interactable: boolean`** — when `false`, the object visually disables (greys out by default).

---

## Layout Structures

Drop one as a child of a `Frame` / `ScrollingFrame` / similar to control sibling layout.

### `UIListLayout`

```luau
local layout = Instance.new("UIListLayout", parent)
layout.FillDirection = Enum.FillDirection.Vertical    -- or Horizontal
layout.SortOrder = Enum.SortOrder.LayoutOrder         -- or Name
layout.Padding = UDim.new(0, 8)                        -- gap between items
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Wraps = false                                    -- new flex behavior
```

Modern flex-style layout supports `Wraps`, `HorizontalFlex`, `VerticalFlex`. Use `UIFlexItem` on children to weight individual items.

### `UIGridLayout`

```luau
layout.CellSize = UDim2.fromOffset(120, 80)
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
```

### `UIPageLayout`

```luau
layout.Animated = true
layout.EasingDirection = Enum.EasingDirection.Out
layout.EasingStyle = Enum.EasingStyle.Sine
layout.TweenTime = 0.5
layout:JumpTo(targetChild)
layout:Next() ; layout:Previous()
```

For tabs, wizards, carousels.

### `UITableLayout`

Rows of equal height; columns of equal width per row. Less common; use grid or list for most cases.

---

## Modifiers & Constraints

Drop one as a child of a `GuiObject`.

- **`UICorner`** — `CornerRadius: UDim`. Use `UDim.new(0, 8)` for 8px corners; `UDim.new(0.5, 0)` for fully circular (with square parent).
- **`UIPadding`** — `PaddingTop/Bottom/Left/Right: UDim`. Inset for descendants.
- **`UIStroke`** — outline. `Thickness`, `Color`, `Transparency`, `LineJoinMode = Round/Bevel/Miter`, `ApplyStrokeMode = Border/Contextual`, `StrokeSizingMode = FixedSize/ScaledSize`. Replaces legacy `BorderSizePixel`. **Default for new strokes:** `StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize` so thickness scales relative to the parent's size — strokes stay proportional across phone, tablet, and desktop. `FixedSize` keeps a constant pixel thickness regardless of UI scaling.

  ```luau
  local stroke = Instance.new("UIStroke")
  stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
  stroke.Thickness = 2
  stroke.Color = Color3.new(1, 1, 1)
  stroke.Parent = button
  ```
- **`UIScale`** — `Scale: number` multiplier on the whole subtree.
- **`UIAspectRatioConstraint`** — `AspectRatio`, `AspectType = ScaleWithParentSize/FitWithinMaxSize`, `DominantAxis = Width/Height`.
- **`UISizeConstraint`** — `MinSize: Vector2` / `MaxSize: Vector2` in pixels.
- **`UITextSizeConstraint`** — `MinTextSize` / `MaxTextSize`. Pair with `TextScaled = true`.
- **`UIGradient`** — `Color: ColorSequence`, `Transparency: NumberSequence`, `Rotation`, `Offset`. Affects descendants.
- **`UIFlexItem`** — per-child weighting inside a flex-enabled `UIListLayout`. `FlexMode`, `GrowRatio`, `ShrinkRatio`, `ItemLineAlignment`.
- **`UIDragDetector`** — built-in dragging support without manual InputBegan/Changed plumbing.

---

## Common GuiObjects

### `Frame`

Plain rectangle.

```luau
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0          -- always 0 in modern UI; use UIStroke if you want a border
```

### `ScrollingFrame`

```luau
sf.CanvasSize = UDim2.new(0, 0, 0, 1200)            -- explicit canvas height
sf.AutomaticCanvasSize = Enum.AutomaticSize.Y        -- or auto-size to content
sf.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
sf.ScrollBarThickness = 6
sf.ScrollingDirection = Enum.ScrollingDirection.Y    -- X / Y / XY
sf.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
```

Children with a `UIListLayout` + `AutomaticCanvasSize` is the typical recipe for a scrollable list.

### `CanvasGroup`

Compositing group. Children render into an offscreen buffer, then drawn together. Enables full-group transparency and effects without per-child fade-in. Use sparingly — there's a memory cost.

### `TextLabel` / `TextButton` / `TextBox`

```luau
label.Text = "Hello"
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 18
label.TextWrapped = true
label.TextScaled = false                           -- when true, ignore TextSize and fill
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Center
label.RichText = true                              -- parse <b>, <i>, <font>, etc.
label.LineHeight = 1.0
label.MaxVisibleGraphemes = -1                     -- -1 = no limit; useful for typewriter effects
label.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)
-- legacy: label.Font = Enum.Font.GothamBold
```

`TextBox` extras:

- `PlaceholderText`, `PlaceholderColor3`
- `ClearTextOnFocus: boolean`
- `MultiLine: boolean`
- `TextEditable: boolean`
- `:CaptureFocus()` / `:ReleaseFocus(submitted: boolean?)`
- Events: `Focused`, `FocusLost(enterPressed: boolean, inputThatCausedFocusLoss: InputObject)`
- Mobile: `TextBox.ShowNativeInput` controls whether the OS keyboard shows.

### `ImageLabel` / `ImageButton`

```luau
img.Image = "rbxassetid://1234567890"
img.ImageColor3 = Color3.new(1, 1, 1)
img.ImageTransparency = 0
img.ScaleType = Enum.ScaleType.Slice
img.SliceCenter = Rect.new(8, 8, 24, 24)           -- 9-slice center rect (in source pixels)
img.SliceScale = 1
img.TileSize = UDim2.fromOffset(16, 16)            -- when ScaleType = Tile
img.ResampleMode = Enum.ResamplerMode.Pixelated    -- crisp pixel art
```

### `ViewportFrame`

3D content rendered into a UI rect.

```luau
viewport.CurrentCamera = camera
viewport.WorldModel = worldModel    -- a WorldModel instance with the rendered scene
viewport.Ambient = Color3.new(0.5, 0.5, 0.5)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -1, -1)
```

Use for inventory previews, character cards, item displays. Light comes from `LightColor`/`LightDirection` only — no in-scene lights, no shadows.

### `VideoFrame`

Plays Roblox-hosted videos. Limited; consider in-world video on a part instead for most use cases.

---

## Inputs

### Buttons

```luau
button.Activated:Connect(function(input: InputObject, numClicks: number)
    -- Fires for: mouse left click, touch tap, gamepad A press, Enter when focused.
end)

button.MouseEnter:Connect(function(x, y) end)
button.MouseLeave:Connect(function(x, y) end)
button.MouseMoved:Connect(function(x, y) end)
```

`Activated` is the platform-agnostic default. Reach for lower-level signals only when you need them.

### Frames + `Active`

For input on plain Frames, set `Active = true` first:

```luau
frame.Active = true
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- ...
    elseif input.UserInputType == Enum.UserInputType.Touch then
        -- ...
    end
end)
frame.InputChanged:Connect(function(input) end)
frame.InputEnded:Connect(function(input) end)
```

`InputObject` fields:
- `UserInputType: Enum.UserInputType` — `MouseButton1`/`MouseButton2`/`Touch`/`Gamepad1`/`Keyboard`/etc.
- `UserInputState: Enum.UserInputState` — `Begin`/`Change`/`End`/`Cancel`.
- `KeyCode: Enum.KeyCode` — for keyboard / gamepad.
- `Position: Vector3` — `(x, y, scrollDelta)` for mouse; `(x, y, 0)` for touch.
- `Delta: Vector3` — change in position since last update.

### Gamepad navigation

```luau
local GuiService = game:GetService("GuiService")

GuiService.SelectedObject = startButton    -- focus this on gamepad-active

-- Configure the focus graph:
button1.NextSelectionDown = button2
button2.NextSelectionUp = button1
button2.NextSelectionDown = button3
-- Plus NextSelectionLeft / NextSelectionRight for grids.

button1.Selectable = true
button2.Selectable = true
```

`GuiService.GuiNavigationEnabled` toggles the global system. `Modal = true` on a GuiObject locks gamepad selection inside its subtree.

---

## Render Order

Within a single `ScreenGui`:

- **`ZIndex`** orders siblings (higher = front).
- **`ZIndexBehavior = Sibling`** (default) means ZIndex only matters within the same parent. A child with ZIndex 100 is still drawn behind a sibling of its parent with ZIndex 1.
- **`ZIndexBehavior = Global`** flattens the entire ScreenGui's ZIndex into one ordering. Almost always undesirable.

Between `ScreenGui`s:

- **`DisplayOrder`** (higher = front).

Inside layouts:

- **`LayoutOrder`** (lower = first in the layout direction).

---

## Topbar & Safe Areas

- **Topbar inset** (chat, leaderboard, menu button) reserved by Roblox at the top of the screen.
- `ScreenGui.IgnoreGuiInset = true` to draw under the topbar (full-screen overlays).
- `GuiService:GetGuiInset()` returns `(topLeft: Vector2, bottomRight: Vector2)` describing reserved insets in pixels.
- iOS notch / Android cutout handled via `ScreenInsets = DeviceSafeInsets` (default modern setting).

---

## Caveats & "Hacks"

### `AbsoluteSize` / `AbsolutePosition` are 1-frame stale

Freshly-created Frames report `(0, 0)` until the first layout pass. To measure on creation:

```luau
RunService.Heartbeat:Wait()
local size = frame.AbsoluteSize    -- now populated
```

Or react to `:GetPropertyChangedSignal("AbsoluteSize")`.

### Centering

```luau
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
```

Any other approach is fighting the system.

### Aspect-locked container

```luau
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.8, 1)         -- 80% width of parent
local arc = Instance.new("UIAspectRatioConstraint", frame)
arc.AspectRatio = 16/9
arc.AspectType = Enum.AspectType.ScaleWithParentSize
arc.DominantAxis = Enum.DominantAxis.Width   -- height = width / 16 * 9
```

### Perfect square inside any parent

```luau
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
local arc = Instance.new("UIAspectRatioConstraint", frame)
arc.AspectRatio = 1
arc.AspectType = Enum.AspectType.FitWithinMaxSize
arc.DominantAxis = Enum.DominantAxis.Width
```

The frame requests 100% of both axes; `FitWithinMaxSize` shrinks it to fit while keeping the 1:1 ratio. Result: the largest centered square that fits inside the parent, regardless of parent shape (wide, tall, or resized at runtime).

Pair `AnchorPoint = Vector2.new(0.5, 0.5)` + `Position = UDim2.fromScale(0.5, 0.5)` to center the square inside the parent's longer axis.

### Pixel-perfect on phones

Pure `Scale` UIs render at unpredictable sizes on small screens. Use `UDim2.fromOffset` + `UISizeConstraint` for elements where pixel size matters (icons, buttons).

### `TextScaled` traps

- Pair with `UITextSizeConstraint` to clamp min/max — without it, very small parents produce 1px text.
- `TextScaled = true` ignores `TextSize`.
- For multi-line text with `TextScaled`, scaling depends on the longest word fitting on one line.

### Fake shadows

- `UIStroke` with offset transparency for a soft outline.
- Stack `ImageLabel` with a sliced shadow PNG (`ScaleType = Slice`, `SliceCenter` set) for soft drop shadows.
- `CanvasGroup` + sub-frames with blur/transparency — heavier, rarely needed.

### Modal dialogs

```luau
modal.Size = UDim2.fromScale(1, 1)
modal.BackgroundTransparency = 0.5
modal.BackgroundColor3 = Color3.new(0, 0, 0)
modal.Active = true                  -- block clicks behind
modal.ZIndex = 100
modal:WaitForChild("ConfirmButton").Modal = true   -- gamepad lock
```

### Dragging

`UserInputService` is more reliable than per-GuiObject `InputBegan/Changed/Ended` — the cursor can leave the source object during drag without losing tracking.

```luau
local dragging = false
local startInput, startPos
button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        startInput = input
        startPos = button.Position
    end
end)
button.InputEnded:Connect(function(input)
    if input == startInput then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startInput.Position
        button.Position = startPos + UDim2.fromOffset(delta.X, delta.Y)
    end
end)
```

For modern code, use `UIDragDetector` instead — built in, handles edge cases.

### Hide cursor

```luau
UserInputService.MouseIconEnabled = false
-- Restore on cleanup.
```

### Measuring text without rendering

```luau
local TextService = game:GetService("TextService")
local size = TextService:GetTextSize(text, textSize, font, frameSize)   -- Vector2
```

Returns the pixel size the text would occupy. Use `frameSize.X = math.huge` to measure single-line width; cap to wrap.

### Fonts: `FontFace` over `Font`

```luau
label.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
-- legacy: label.Font = Enum.Font.GothamBold
```

`Font.new(family, weight, style)` lets you load any family, including custom fonts uploaded as Roblox assets. `Font: Enum.Font` is frozen — no new built-in families being added.

### Avoid

- `BorderSizePixel > 0` on modern UI — use `UIStroke`.
- Setting `Position` after parenting under a `UIListLayout` — ignored.
- Manual ZIndex juggling instead of correcting parent hierarchy.
- Per-frame `AbsoluteSize` polling — use `:GetPropertyChangedSignal("AbsoluteSize")`.
- `task.wait()` to "let UI settle" — listen to actual property changes instead.
