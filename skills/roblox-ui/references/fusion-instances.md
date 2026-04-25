# Fusion 0.3 — Instances Reference

Source: [elttob.uk/Fusion/0.3/tutorials/roblox](https://elttob.uk/Fusion/0.3/tutorials/roblox/) (`new-instances`, `parenting`, `events`, `change-events`, `outputs`, `hydration`).

---

## `New`

Creates an Instance, applies Fusion's defaults, then applies your prop table.

```luau
local label = scope:New "TextLabel" {
    Name = "Greeting",
    Parent = playerGui.ScreenGui,
    Text = "Hello",
    Size = UDim2.fromOffset(200, 50),
}
```

**Two call forms:**

```luau
scope:New("Part")({ Color = Color3.new(1, 0, 0), Parent = workspace })
scope:New "Part" { Color = Color3.new(1, 0, 0), Parent = workspace }   -- string + braces only
```

The Instance is added to the scope's cleanup list — `doCleanup(scope)` destroys it automatically.

**Defaults differ from `Instance.new()`** — Fusion turns off auto-coloring, removes default text, sets `BackgroundTransparency = 1` for many UI classes. See `defaultProps.luau` in the Fusion source for the full table.

---

## `Hydrate`

Same prop logic as `New`, but applied to an existing Instance you already own (e.g. an Instance from Studio, or one returned from `Clone`).

```luau
local existing = workspace.Part
scope:Hydrate(existing) {
    Color = scope:Computed(function(use, _) return use(themeColor) end),
    [OnEvent "Touched"] = onTouched,
}
```

`Hydrate` does not destroy the Instance on cleanup — only the bindings/connections it created.

---

## Property values

Three flavors:

| Pass... | Behavior |
|---|---|
| Constant | Set once when the Instance is created. |
| State object | Bound — updates the property on the next frame after `:set()`. |
| Function returning state | Same as state object. |

```luau
local color = scope:Value(Color3.new(1, 0, 0))

scope:New "Part" {
    Anchored = true,                      -- constant
    Color = color,                        -- state binding
    Size = scope:Computed(function(use, _)
        return Vector3.one * (1 + use(scale))
    end),
}
```

State-bound updates are batched per frame. Setting a state object multiple times within one frame results in a single property write.

---

## Special prop keys

Imported directly from Fusion (not via `scope`):

```luau
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
local Out = Fusion.Out
local Attribute = Fusion.Attribute
local AttributeChange = Fusion.AttributeChange
local AttributeOut = Fusion.AttributeOut
local Child = Fusion.Child
```

**Note:** Fusion 0.3 removed `Ref`. To capture the created Instance, just assign the `scope:New` result to a local — `New` returns the Instance.

### `[Children]`

Parent zero or more Instances.

```luau
scope:New "Frame" {
    [Children] = {
        scope:New "UICorner" { CornerRadius = UDim.new(0, 8) },
        scope:New "TextLabel" { Text = "Title" },
    },
}
```

Accepts:

- A single Instance.
- An array of Instances (any nesting depth — Fusion flattens).
- A state object containing an Instance, an array, or `nil`.
- A computed — recalculates when dependencies change; old children are destroyed via the Computed's inner scope.

```luau
scope:New "Frame" {
    [Children] = scope:Computed(function(use, scope)
        if not use(isVisible) then return nil end
        return scope:New "TextLabel" { Text = "Visible!" }
    end),
}
```

### `[OnEvent "Name"]`

Connect a handler to a Roblox event. The connection is tied to the scope.

```luau
scope:New "TextButton" {
    [OnEvent "Activated"] = function(inputObject, numClicks)
        print("clicked", numClicks)
    end,
    [OnEvent "MouseEnter"] = onHover,
}
```

The handler receives the same args the underlying RBXScriptSignal would.

### `[OnChange "Property"]`

Fires when a property changes (Roblox-side, not Fusion-side). Receives the new value.

```luau
scope:New "Frame" {
    [OnChange "AbsoluteSize"] = function(newSize)
        print("resized to", newSize)
    end,
}
```

### `[Out "Property"]`

Pipes a property value out to a state object. Two-way binding, sort of — the state object reflects whatever the Instance reports.

```luau
local typed = scope:Value("")

scope:New "TextBox" {
    PlaceholderText = "Type...",
    [Out "Text"] = typed,
}

scope:Observer(typed):onChange(function()
    print("user typed:", peek(typed))
end)
```

`Out` reads from the Instance into the state — useful for input fields where the user mutates the property directly.

### Capturing the Instance (no `Ref` in 0.3)

Fusion 0.3 dropped `[Ref]`. Just save the `New` return value:

```luau
local frame: Frame = scope:New "Frame" {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
}

-- Use directly:
print(frame.AbsoluteSize)
frame.BackgroundColor3 = Color3.new(1, 0, 0)   -- imperative one-shot
```

For reactive prop changes, bind a `Value` to the prop instead of mutating the Instance:

```luau
local color = scope:Value(Color3.fromRGB(40, 40, 40))
local frame = scope:New "Frame" { BackgroundColor3 = color }
color:set(Color3.new(1, 0, 0))   -- next-frame update; reactive
```

If you need to pass the Instance into a child component or callback, pass the local you already have. Avoid sticking it inside a `Value` unless the *identity* itself changes over time (rare).

### `[Attribute "Name"]` / `[AttributeChange "Name"]` / `[AttributeOut "Name"]`

Same idea as the `OnChange` / `Out` family but operates on Roblox attributes (set via `:SetAttribute(name, value)`).

```luau
scope:New "Folder" {
    [Attribute "Score"] = scoreState,           -- bind a state object to the attribute
    [AttributeChange "Score"] = function(new) ... end,
    [AttributeOut "Score"] = scoreOut,          -- pipe attribute value out to a state object
}
```

### `[Child "Name"]`

Hydrate a named child of the Instance being created. Useful when working with prefabs or models cloned into a parent.

```luau
scope:Hydrate(template) {
    [Child "TitleLabel"] = {
        Text = "Hello",
    },
    [Child "SubmitButton"] = {
        [OnEvent "Activated"] = onSubmit,
    },
}
```

---

## Children — dynamic forms

State object holding children:

```luau
local activeFrame = scope:Value(nil)
scope:New "ScreenGui" {
    [Children] = activeFrame,
}
activeFrame:set(scope:New "Frame" { ... })   -- swaps the contents
```

Computed children re-render on dependency change:

```luau
scope:New "Frame" {
    [Children] = scope:Computed(function(use, scope)
        local result = {}
        for i, item in use(items) do
            result[i] = scope:New "TextLabel" { Text = item.name, LayoutOrder = i }
        end
        return result
    end),
}
```

For large lists with stable identity, use `ForValues` / `ForKeys` / `ForPairs` (covered in [tutorials/tables](https://elttob.uk/Fusion/0.3/tutorials/tables/)).

---

## Common pitfalls

- **Setting `Parent` after `New`** — works, but you lose Fusion's batching. Prefer `Parent = ...` in the prop table.
- **`[OnEvent]` on an event that doesn't exist** — Fusion errors at hydration. Verify the event name on the class.
- **Storing the result of `New` and never adding to a scope** — leak. `New` always uses `scope`; if you bypass it, manage cleanup yourself.
- **Mutating a state object inside a `[Children]` computed** — feedback loop, undefined behavior. Read with `use`, write elsewhere.
- **Expecting property writes to be synchronous** — they're applied on the next frame after `:set()`. Test with `task.wait()` between set and read.
- **Using `Ref` for control flow** — refs are escape hatches; reach for `Computed` first.
