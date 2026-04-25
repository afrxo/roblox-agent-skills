# Fusion 0.3 — State Reference

Source: [elttob.uk/Fusion/0.3/tutorials/fundamentals](https://elttob.uk/Fusion/0.3/tutorials/fundamentals/) (`scopes`, `values`, `computeds`, `observers`).

---

## `scoped` and scopes

```luau
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local scoped = Fusion.scoped
local doCleanup = Fusion.doCleanup

-- Plain array
local scope = {}

-- Scope with all Fusion methods bound (preferred)
local scope = scoped(Fusion)

-- Scope with custom methods only
local scope = scoped({ Value = Fusion.Value, Computed = Fusion.Computed })

-- Scope merging multiple method tables
local scope = scoped(Fusion, {
    Button = Button,
    Slider = Slider,
})
```

Scope methods bind the scope as the first arg of each function:

```luau
local v = scope:Value(5)              -- ≡ Fusion.Value(scope, 5)
```

### Inner / derived scopes

```luau
local outer = scoped(Fusion)

local inner = outer:innerScope()      -- auto-cleaned when `outer` is cleaned
local sibling = outer:deriveScope()   -- has same methods; not auto-cleaned

-- Add own methods on top:
local inner2 = outer:innerScope({ ExtraMethod = ExtraMethod })
```

**Default to `innerScope` over `deriveScope`** — guarantees cleanup; harder to leak.

### Cleanup

```luau
scope:doCleanup()           -- method form
Fusion.doCleanup(scope)     -- function form
```

Tasks run in reverse order of insertion. `doCleanup` accepts:

- Functions → called.
- Roblox `Instance` → `:Destroy()`.
- `RBXScriptConnection` → `:Disconnect()`.
- Tables with `:destroy()` / `:Destroy()` / `:disconnect()` / `:Disconnect()`.
- Other scopes → recursive cleanup.

### `scope:insert(...)`

Add tasks to the scope manually; returns each task so you can chain.

```luau
local conn, part = scope:insert(
    RunService.Heartbeat:Connect(update),
    Instance.new("Part", workspace)
)
```

---

## `Value`

```luau
local v = scope:Value(initial)
v:set(new)            -- write
Fusion.peek(v)        -- read (no subscription)
```

**`v:set(new)` returns `new`** — useful in expressions but use sparingly:

```luau
local total = 10 + counter:set(counter:peek() + 1)   -- works, but unclear
```

### Equality short-circuit

`v:set(new)` is a no-op (no listeners notified) when `new` equals the previous value (using `==`). Tables compare by reference, so mutating a table and `:set`-ing it again **does not** trigger updates — replace with a new table for immutable semantics.

---

## `Computed`

```luau
local result = scope:Computed(function(use, scope)
    return use(a) + use(b)
end)
```

- **First arg `use`** — reads + subscribes. The computed re-runs when any `use`'d state changes.
- **Second arg `scope`** — fresh inner scope per recalculation. Auto-cleaned before the next run.
- **Calculation must be immediate.** No `task.wait`, no remote calls, no delayed I/O.
- **Side-effect free.** Logging, sound, network — use `Observer` for those.
- **May be lazy.** Fusion may defer or skip recalculations when the result isn't observed.

### Inner scope use case

```luau
local result = scope:Computed(function(use, scope)
    local current = use(input)
    -- Anything tied to this calculation goes in `scope` so it's cleaned when
    -- the computed re-runs.
    table.insert(scope, function() print("tearing down for", current) end)
    return current * 2
end)
```

### Shadowing `scope`

Recommended convention: name the inner scope `scope` to shadow the outer one. Prevents accidentally writing to the wrong scope. Add `--!nolint LocalShadow` at file top to silence Luau's same-name-shadow warning.

---

## `Observer`

```luau
local obs = scope:Observer(stateObj)
local conn = obs:onChange(function()
    print("changed to", peek(stateObj))
end)
-- conn:disconnect() to stop listening early; otherwise tied to scope cleanup
```

For side effects gated on state changes. Multiple `:onChange` callbacks on the same `Observer` are allowed.

`Observer` watches **any** state object (`Value`, `Computed`, animation primitives) — not just `Value`.

---

## Animation primitives

For values that animate over time. Same scope-based shape; deeper coverage in [api-reference/animation](https://elttob.uk/Fusion/0.3/api-reference/animation/) on the Fusion site.

- **`scope:Tween(stateObj, tweenInfo)`** — tween toward the source's value with a `TweenInfo`.
- **`scope:Spring(stateObj, speed?, damping?)`** — spring physics; targets the source's value with configurable speed/damping.

```luau
local target = scope:Value(0)
local animated = scope:Spring(target, 20, 1)   -- speed=20, damping=1

-- Bind to an Instance prop:
scope:New "Frame" {
    Position = scope:Computed(function(use, _)
        return UDim2.fromScale(use(animated), 0)
    end),
}

target:set(0.5)   -- animated will smooth toward 0.5
```

Both `Tween` and `Spring` produce state objects you can `use(...)` and `peek(...)` like any other.

---

## Patterns

### Async source → reactive

For values that come from yielding work, write to a `Value` from outside, never inside a `Computed`:

```luau
local profile: Fusion.Value<Profile?> = scope:Value(nil)

task.spawn(function()
    local fetched = ProfileService:LoadProfileAsync(player.UserId)
    profile:set(fetched)
end)

local nameLabel = scope:Computed(function(use, _)
    local p = use(profile)
    return if p then p.Name else "Loading..."
end)
```

### Conditional UI

```luau
local isOpen = scope:Value(false)

local panel = scope:Computed(function(use, scope)
    if not use(isOpen) then return nil end
    return scope:New "Frame" { ... }   -- created on the inner scope; auto-cleaned when isOpen flips false
end)

scope:New "ScreenGui" {
    Parent = playerGui,
    [Children] = panel,                -- accepts state-object-of-Instance-or-nil
}
```

The `Computed`'s inner scope cleans up the old Frame each time `isOpen` changes — no manual `Destroy` needed.

### Lists

```luau
local items = scope:Value({ "apple", "banana", "cherry" })

local labels = scope:Computed(function(use, scope)
    local result = {}
    for i, item in use(items) do
        result[i] = scope:New "TextLabel" {
            Text = item,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 24),
        }
    end
    return result
end)

scope:New "Frame" {
    [Children] = {
        scope:New "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder },
        labels,
    },
}
```

Re-creates all child labels on any change to `items`. For large lists with stable identity, use `For` family helpers (covered in Fusion 0.3 docs under `tables`).

### `For` helpers (overview)

Fusion 0.3 provides `ForValues`, `ForKeys`, `ForPairs` for keyed/value list rendering with stable identity — children persist across mutations when their key is unchanged. See [tutorials/tables](https://elttob.uk/Fusion/0.3/tutorials/tables/) for the full API.
