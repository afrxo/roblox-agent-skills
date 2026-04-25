# Design Guidelines — Reference

Framework-agnostic UI/UX guidance for Roblox. Applies whether the UI is built with Fusion, Vide, React Lua, or hand-written `Instance.new`.

**Aesthetic anchor:** neutral clean product (Discord / Notion / modern game launchers). **Optimization target:** UX + consistency, not novelty.

---

## Tokens

A "token" is a named value used everywhere instead of a literal. Centralize tokens in one module so the entire UI can be retuned without touching call sites.

### `theme.luau` template

```luau
--!strict

export type Theme = {
    -- Spacing scale (scale fractions; multiply by parent's smaller axis)
    space: {
        xs: UDim, sm: UDim, md: UDim, lg: UDim, xl: UDim, xxl: UDim, xxxl: UDim,
    },
    -- Type scale (max pixel sizes; pair with TextScaled + UITextSizeConstraint)
    text: {
        caption: number, bodySm: number, body: number, bodyLg: number,
        h3: number, h2: number, h1: number, display: number,
    },
    -- Radii (CornerRadius)
    radii: {
        button: UDim, card: UDim, pill: UDim,
    },
    -- Color palette — semantic roles
    color: {
        surface: Color3, surfaceElevated: Color3, surfaceOverlay: Color3,
        primary: Color3, onPrimary: Color3,
        secondary: Color3, onSecondary: Color3,
        text: Color3, textMuted: Color3, textOnDark: Color3,
        border: Color3, borderStrong: Color3,
        success: Color3, warning: Color3, danger: Color3, info: Color3,
    },
    -- Motion tokens
    motion: {
        fast: TweenInfo, base: TweenInfo, slow: TweenInfo,
        springSnappy: { speed: number, damping: number },
        springGentle: { speed: number, damping: number },
    },
    -- Typography
    font: { body: Font, display: Font, mono: Font },
}

local theme: Theme = {
    space = {
        xs = UDim.new(0.005, 0),  -- ~4px
        sm = UDim.new(0.01,  0),  -- ~8
        md = UDim.new(0.015, 0),  -- ~12
        lg = UDim.new(0.02,  0),  -- ~16
        xl = UDim.new(0.03,  0),  -- ~24
        xxl = UDim.new(0.04, 0),  -- ~32
        xxxl = UDim.new(0.06, 0), -- ~48
    },
    text = {
        caption = 12, bodySm = 14, body = 16, bodyLg = 18,
        h3 = 24, h2 = 32, h1 = 40, display = 56,
    },
    radii = {
        button = UDim.new(0.2, 0),     -- ~20% of smaller side
        card = UDim.new(0.04, 0),
        pill = UDim.new(0.5, 0),       -- fully rounded
    },
    color = {
        surface         = Color3.fromRGB(20, 22, 26),
        surfaceElevated = Color3.fromRGB(28, 30, 36),
        surfaceOverlay  = Color3.fromRGB(36, 38, 44),
        primary         = Color3.fromRGB(60, 130, 246),
        onPrimary       = Color3.fromRGB(255, 255, 255),
        secondary       = Color3.fromRGB(60, 60, 70),
        onSecondary     = Color3.fromRGB(230, 232, 236),
        text            = Color3.fromRGB(232, 234, 238),
        textMuted       = Color3.fromRGB(160, 164, 172),
        textOnDark      = Color3.fromRGB(255, 255, 255),
        border          = Color3.fromRGB(50, 52, 58),
        borderStrong    = Color3.fromRGB(80, 84, 92),
        success         = Color3.fromRGB(56, 176, 96),
        warning         = Color3.fromRGB(232, 168, 56),
        danger          = Color3.fromRGB(228, 84, 84),
        info            = Color3.fromRGB(72, 152, 220),
    },
    motion = {
        fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        base = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        slow = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        springSnappy = { speed = 30, damping = 1 },
        springGentle = { speed = 14, damping = 0.8 },
    },
    font = {
        body    = Font.fromName("BuilderSans", Enum.FontWeight.Regular),
        display = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
        mono    = Font.fromName("RobotoMono", Enum.FontWeight.Regular),
    },
}

return table.freeze(theme)
```

Reuse this everywhere. Never inline a color or spacing value at a call site.

---

## Spacing

### The scale

```
xs (4)  sm (8)  md (12)  lg (16)  xl (24)  xxl (32)  xxxl (48)
```

### Usage rules

- **Within a card**: `UIPadding` of `lg` to `xl`; `UIListLayout.Padding` of `sm` to `md`.
- **Between cards**: `UIListLayout.Padding` of `md` to `lg`.
- **Tight clusters** (icon + label, button + spinner): `xs` to `sm`.
- **Section breaks** (between major UI areas): `xxl` or `xxxl`.

### Anti-patterns

- Magic offsets (`UDim.new(0.017, 0)`) — use a token.
- Inconsistent gaps (`md` between two items, `lg` between the next two for no reason).
- Per-child `Position` / per-child margins instead of `UIListLayout.Padding`.

---

## Typography

### Scale & roles

| Token | Size | Use |
|---|---|---|
| `caption` | 12 | Footnotes, metadata, small labels |
| `bodySm` | 14 | Secondary text, form helper text |
| `body` | 16 | Default body text, button labels |
| `bodyLg` | 18 | Card titles, prominent body |
| `h3` | 24 | Section headings |
| `h2` | 32 | Page titles |
| `h1` | 40 | Major page titles |
| `display` | 56 | Hero / splash only |

### Rules

- **One body font + one display font**, max. Three is too many.
- **`FontFace = theme.font.body`** everywhere; never legacy `Font: Enum.Font` for new code.
- **`TextScaled = true`** + **`UITextSizeConstraint { MaxTextSize = theme.text.body }`**. Without the constraint, very small parents shrink text to 1px.
- **Line height**: default 1.0; bump to 1.2–1.4 for multi-line readable body.
- **Limit text alignment variation**: most UI is left-aligned (LTR). Center for headings + buttons; right rare.
- **`RichText`** for inline formatting (`<b>`, `<font color="...">`). Don't build colored text by stacking labels.

---

## Color

### Semantic roles, not raw values

Refer by purpose:

- `theme.color.text` — primary text on surfaces.
- `theme.color.primary` — main brand action.
- `theme.color.danger` — destructive action / error.

If you find yourself typing `Color3.fromRGB(60, 130, 246)` in a component, you've leaked a token.

### Contrast (WCAG AA)

- **Body text**: 4.5:1 against background.
- **Large text** (≥18pt or 14pt bold): 3:1.
- **UI components / focus indicators**: 3:1.

Quick mental check: light text on a dark surface needs the surface to be dark enough (≤ ~30% lightness) and the text light enough (≥ ~80% lightness).

Test palettes with a contrast checker before shipping.

### Don'ts

- Rainbow gradients on UI surfaces. Reserve gradients for backgrounds, hero areas, brand moments — not buttons or list rows.
- Pure black on pure white — too harsh. Use slightly off-black (~`(0.1, 0.1, 0.12)`) and slightly off-white.
- Color as the only signal. Errors need icon + text + color, not just red.
- Saturated brand color filling 50%+ of the screen. Use surface tones for the bulk; brand color for accents.

### Dark vs light mode

For a single mode UI, pick one and commit. For multi-mode:

- Define two palette objects (`darkTheme`, `lightTheme`) with same role keys.
- All components reference `theme.color.X` — switching themes swaps the table.
- Don't mix surface colors and text colors that assume one mode.

---

## Hierarchy

### The three signals

1. **Size** — bigger = more important.
2. **Weight / contrast** — bolder, higher-contrast = more important.
3. **Position** — top-left for LTR readers; visual center for hero focus.

Use *combinations*, not just one. A "large but low-contrast" element reads weaker than "medium high-contrast".

### Button rank

- **Primary** — filled with `theme.color.primary`, `onPrimary` text. The single most important action on the screen.
- **Secondary** — `surfaceElevated` background + `text` color, optional `UIStroke` border. Common alternative actions.
- **Tertiary** — text-only, no background. Cancel / dismiss / footer links.

**Never two primaries side by side.** If both feel essential, you have a UX problem (split into two screens, or pick the more common action).

### Layouts

- Use `UIListLayout` / `UIGridLayout` for everything that's a list or grid. Per-child `Position` is for one-offs (modals, floating toolbars).
- **Align**: things in a column should share an X edge or center. Misalignment reads as bug.
- **Group** related content with whitespace, not borders. A divider is a fallback, not a default.

---

## State coverage

Every interactive element needs visible feedback for every state it can be in.

| State | What changes |
|---|---|
| Default | Base style |
| Hover (mouse) | Background tint shift (e.g. +5% lightness) |
| Pressed | Background darken (-5%) or inset offset (1–2 px Y) |
| Focused (gamepad / keyboard) | `UIStroke` highlight in `theme.color.primary` |
| Selected | Filled with `primary` + `onPrimary` text (lists, tabs) |
| Disabled | Reduce text alpha to ~0.4; `Active = false`; `AutoButtonColor = false` |
| Loading | Replace label with spinner; ignore input |
| Error | Inline message below; red `UIStroke` |
| Success (after action) | Brief flash / checkmark animation |

### Implementation pattern (framework-agnostic)

Drive the appearance from a `state: "default" | "hover" | "pressed" | ...` value (or its framework equivalent — Fusion `Computed`, Roact state, etc.). Never branch on multiple booleans (`isHovered and isPressed and not isDisabled`) — that's a 2^N matrix begging for bugs.

```luau
type ButtonState = "default" | "hover" | "pressed" | "disabled" | "loading"

-- Map state → visual:
local function buttonStyle(state: ButtonState): { bg: Color3, ... }
    if state == "disabled" then return { bg = theme.color.secondary, alpha = 0.4 } end
    if state == "loading"  then return { bg = theme.color.primary,   alpha = 0.7 } end
    if state == "pressed"  then return { bg = theme.color.primary:Lerp(Color3.new(), 0.1) } end
    if state == "hover"    then return { bg = theme.color.primary:Lerp(Color3.new(1,1,1), 0.05) } end
    return { bg = theme.color.primary }
end
```

---

## Motion

### Tokens

```luau
theme.motion.fast  -- TweenInfo, ~120ms — hover / micro-feedback
theme.motion.base  -- ~200ms — common transitions (color, opacity, position)
theme.motion.slow  -- ~350ms — page transitions, modal enter/exit
```

```luau
theme.motion.springSnappy  -- speed=30, damping=1 — interactive feedback (hover scale)
theme.motion.springGentle  -- speed=14, damping=0.8 — drag, slide-in panels
```

### When to use which

- **Spring** — anything tracking continuous user input (drag, hover, follow). Tolerates target changes mid-flight.
- **Tween** — fixed-duration transitions (color flash, fade in/out, page swap). Restarts on source change — not for jittery sources.

### Easing

- **Out** (`Quad`, `Sine`, `Cubic`) — entry. Fast start, settle. Most common.
- **In** — exit. Slow start, fast finish. Use for things flying off-screen.
- **InOut** — looping / continuous motion (carousels).
- **Linear** — indeterminate spinners only.

### Rules

- **Animate state changes that affect layout.** Snapping a panel from off-screen to centered is jarring; tween it.
- **Don't animate everything.** Background colors that don't change rarely should not pulse. Motion is communication, not decoration.
- **Cap concurrent animations.** A list of 50 rows all tweening their colors on hover is a frame-rate disaster. Use `CanvasGroup` to fade groups, or avoid per-row hover effects.
- **Respect reduced-motion.** Some platforms expose this signal; honor it. At minimum: keep all transitions ≤ 250ms so they're tolerable.
- **Don't bounce by default.** Bouncy springs (`damping < 1`) are charming on rare interactions, exhausting on every button press.

---

## Touch & input

### Touch targets

- **Min 44×44 px** on touch surfaces. Apply `UISizeConstraint { MinSize = Vector2.new(44, 44) }` to interactive elements that are scale-sized.
- **Tap area can exceed visual area** — a 32px icon button can have a transparent 44px hit target around it.
- **Spacing between targets**: ≥ 8px gap to avoid mis-taps.

### Cursor

- **`MouseCursor`** on `ImageButton` / `TextButton` instances — set to a "pointer" asset for clickables.
- **Hide cursor** during cinematic / locked-camera sequences via `UserInputService.MouseIconEnabled = false`.

### Gamepad

- **Selection graph**: every interactive element sets `NextSelectionUp/Down/Left/Right` to its neighbors. `Selectable = true`.
- **`GuiService.SelectedObject`** set when a screen opens — which element should focus first?
- **`Modal = true`** on a button inside a modal panel locks focus to that subtree.
- **A button = primary action**. **B button = back / cancel.** Bind via `ContextActionService` for rebinding support.

### Keyboard

- **Enter** submits forms.
- **Escape** closes modals.
- **Tab** moves focus through GuiService selection graph (if implemented).

---

## Responsive

### Strategy

- **Scale-first sizing** (`UDim2.fromScale`).
- **Aspect locks** on key panels (`UIAspectRatioConstraint`) so they don't squash on ultrawide / portrait.
- **Pixel floors** for elements that must stay readable (`UISizeConstraint { MinSize = Vector2.new(120, 32) }`).
- **Flex sparingly** — `UIListLayout` flex modes for variable counts.
- **Test extremes**: 320×568 (small phone portrait), 1280×800 (laptop), 3840×2160 (4K desktop), 1920×1080 (1080p TV).

### Detect input *type*, not viewport

- `UserInputService.TouchEnabled` → mobile-style behavior (larger targets, no hover).
- `UserInputService.MouseEnabled` → hover affordances active.
- `UserInputService.GamepadEnabled` → focus indicators visible at all times.

Don't switch *layouts* by viewport size — switch *behavior* by input type. The same UI should fit every screen size; only what the player can do with it changes.

---

## Empty / loading / error states

For every async surface:

### Empty

```
"No friends online — invite someone to play"
[Invite Friends]
```

Useful guidance + clear CTA. Never a blank rectangle.

### Loading

- **Spinner** for short waits (< 2s).
- **Skeleton** (placeholder rectangles in shape of expected content) for longer waits — feels faster than a spinner.
- **Lock interaction** on submit-style flows; allow scroll on read-only.

### Error

```
[icon] Couldn't load friends.
       [Retry]
```

Inline. Specific. Actionable. Never silent failure.

### Success

For destructive / irreversible actions: brief confirmation toast or checkmark animation. For background success (autosave): subtle indicator, no interruption.

---

## Accessibility

- **Contrast**: WCAG AA minimums (above).
- **Min text size**: 12pt absolute floor; 14pt body.
- **No color-only signaling**: red error needs icon + label.
- **Focus indicators visible**: high-contrast `UIStroke`, never just a color tint.
- **Gamepad-navigable**: every interactive element reachable.
- **No flashing >3 Hz** (seizure risk).
- **Caption / subtitle support** for any video / cinematic.
- **Don't auto-play audio** without affordance to mute.

---

## Anti-patterns (extended)

| ❌ | ✅ |
|---|---|
| Magic spacing values | Token from spacing scale |
| Inline `Color3.fromRGB` at call sites | `theme.color.X` |
| Three font families | One body + one display |
| `Font = Enum.Font.X` (legacy) | `FontFace = Font.fromName(...)` |
| `BorderSizePixel = 1` | Always 0; use `UIStroke` if needed |
| Same-shape buttons of identical color (no rank) | Primary > Secondary > Tertiary visual ladder |
| Two primary buttons side-by-side | One primary + one secondary |
| Drop-shadow under everything | Reserve elevation for things that pop |
| Mixed corner radii (4, 8, 6, 12) on different cards | Pick 2 radii max, token them |
| Disabled button that just does nothing on click | Visibly muted + `Active = false` + `AutoButtonColor = false` |
| Snap state changes (instant flip) | Tween/Spring the transition |
| Pure scale without size constraints on phones | Combine scale + `UISizeConstraint` |
| Color-only error feedback | Icon + label + color |
| Empty state showing nothing | Guidance + CTA |
| Per-element animation timings | Centralized motion tokens |
| Per-frame `Heartbeat` UI updates | State-driven, batched |
| Hover-only affordance | Visible without hover |
| Ignoring topbar inset by accident | `IgnoreGuiInset` deliberate |
| Layout breakpoints by viewport size | Layout that fits all sizes; switch by input type |
| Comic-sans-grade font choices | Modern sans (BuilderSans / Inter / Roboto family) |
| Pure black on pure white | Slightly off-black on slightly off-white |
| Saturated brand fill on 50%+ of screen | Surface tones bulk; brand for accents |
| Bouncy springs on every interaction | Reserve bounce for rare moments |
| Three different border styles | Token the stroke |
| Auto-playing music + cutscene without skip | Always provide a skip / mute |
| Forgetting `MaxTextSize` clamp on `TextScaled` | Always pair with `UITextSizeConstraint` |
| Manual focus management mid-modal | `Modal = true` on inner button |
| Re-implementing native UI behaviors badly | Use `ContextActionService` / `GuiService` primitives |
