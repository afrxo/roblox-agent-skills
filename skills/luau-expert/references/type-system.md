# Luau Type System Reference

Deep dive on Luau's type system. SKILL.md keeps the rules; this file holds the explanations.

---

## Structural Typing

Luau is **structurally typed**: compatibility comes from shape, not name or origin. Two tables with the same fields are interchangeable.

## Primitive Types

```luau
local count: number = 0
local name: string = "Luau"
local active: boolean = true
local nothing: nil = nil
local co: thread = coroutine.create(function() end)
```

Ten VM primitives: `nil`, `string`, `number`, `boolean`, `table`, `function`, `thread`, `userdata`, `vector`, `buffer`. `table` and `function` use dedicated type syntax (not the bare word). `vector` is not representable by name at all.

## Special Types: `unknown`, `never`, `any`

```luau
-- unknown: top type — union of all types. Forces narrowing before use.
local val: unknown = getSomething()
if type(val) == "number" then
    local n = val * 2  -- ✅ narrowed
end
-- val + 1  -- ❌ can't use unknown directly

-- never: bottom type — no value inhabits it. Appears at unreachable code paths.

-- any: opt-out from the type system. Avoid.
```

Prefer `unknown` over `any`. `unknown` forces proof of type before use; `any` silently bypasses every check.

## Type Annotations

```luau
-- Variable
local x: number = 5

-- Function parameters and return
local function add(a: number, b: number): number
    return a + b
end

-- Multiple return values — wrap in parentheses
local function divmod(a: number, b: number): (number, number)
    return a // b, a % b
end

-- Optional parameter (T? = T | nil)
local function greet(name: string, title: string?): string
    return if title then `{title} {name}` else name
end

-- Function type with named args (names are documentation only, not semantic)
local fn: (x: number, y: number) -> boolean
```

## Type Casts (`::`)

```luau
local names = {} :: { string }
table.insert(names, "Aria")    -- ✅
-- table.insert(names, 42)     -- ❌

-- Casts are checked: one operand must be a subtype of the other, or any
-- Unsafe casts between unrelated types are rejected
```

When casting a multi-return, only the first value is kept.

## Type Aliases

```luau
type UserId = number
type Config = {
    maxPlayers: number,
    roundDuration: number,
}

-- typeof doesn't evaluate at runtime
type MyVec = typeof(Vector2.new(0, 0))
```

## Exported Types

```luau
-- MyModule.luau
export type Result<T> = { ok: true, value: T } | { ok: false, err: string }

-- Another file
local MyModule = require("./MyModule")
local r: MyModule.Result<number> = { ok = true, value = 42 }
```

Types are file-local by default. `export type` makes them importable.

---

## Table Types

Three states in the type checker:

**Unsealed** — created via table literal, accepts new properties:

```luau
local t = { x = 1 }   -- unsealed: { x: number }
t.y = 2               -- ✅ y added to inferred type
-- Seals when leaving the scope where it was created
```

**Sealed** — explicitly annotated or returned from a function:

```luau
local t: { x: number } = { x = 1 }
-- t.y = 2   -- ❌ property 'y' not found in sealed table
```

Sealed tables support **width subtyping**: a table with more fields satisfies a type that expects fewer.

**Array shorthand:**

```luau
local names: { string } = {}           -- { [number]: string }
local matrix: { { number } } = {}
```

**Indexer (non-number keys or mixed):**

```luau
type Cache = { [string]: number, size: number }
```

---

## Unions

```luau
type StringOrNumber = string | number
type MaybeString = string?   -- shorthand for string | nil
```

Two or more function types in a union cannot be called directly.

### Tagged Unions (Discriminated Unions)

```luau
type Result<T, E> =
    { type: "ok",  value: T }
  | { type: "err", error: E }

local function handle<T>(r: Result<T, string>): T?
    if r.type == "ok" then
        return r.value     -- narrowed
    else
        warn(r.error)
        return nil
    end
end
```

The checker narrows on the discriminant field automatically.

## Intersections

```luau
type Named = { name: string }
type Aged  = { age: number }
type Person = Named & Aged   -- must have both fields

-- Overloaded function types
type Stringify = ((number) -> string) & ((boolean) -> string)
```

Cannot intersect incompatible primitives — `string & number` is impossible.

---

## Generics

```luau
-- Generic type alias
type Pair<T> = { first: T, second: T }
local p: Pair<number> = { first = 1, second = 2 }

-- Generic function
local function reverse<T>(a: { T }): { T }
    local result: { T } = {}
    for i = #a, 1, -1 do
        result[#result + 1] = a[i]
    end
    return result
end

local nums = reverse({ 1, 2, 3 })    -- { number }
local strs = reverse({ "a", "b" })   -- { string }
```

`table.insert` has type `<T>({T}, T) -> ()` — the standard library uses generics throughout.

Functions do **not** support default generic parameters.

### Variadic Types and Type Packs

```luau
-- Variadic parameter
local function sum(...: number): number
    local total = 0
    for _, v in {...} do total += v end
    return total
end

-- In type annotations
type VarFn = (...number) -> number

-- Generic type packs:
-- ...T  = variadic pack, many values of the same type T
-- U...  = generic pack, zero or more values of possibly different types
```

Type packs can also be generic type alias parameters and instantiated explicitly.

---

## Type Refinements

The checker narrows types automatically inside conditionals.

**Truthy test:**

```luau
local s: string? = maybeGet()
if s then
    s:upper()  -- s: string
end
```

**`type()` guard:**

```luau
local val: string | number = getValue()
if type(val) == "number" then
    local doubled = val * 2
else
    local upper = val:upper()
end
```

**Equality / singleton:**

```luau
type Dir = "north" | "south" | "east" | "west"
local dir: Dir = getDir()
if dir == "north" then
    -- dir: "north" exactly
end
```

Refinements compose with `and`, `or`, `not`. `~=` also refines.

**`assert` refines the same way:**

```luau
local child = parent:FindFirstChild("Handle")
assert(child, "Handle missing")
-- child: non-nil from here on
```

---

## Type Functions

Type functions run at **analysis time** only — they operate on types, not runtime values, via the `types` built-in library.

```luau
type function keyof(t)
    local components = {}
    for key in t:properties() do
        table.insert(components, key)
    end
    return types.unionof(table.unpack(components))
end

type PersonKeys = keyof<{ name: string, age: number }>
-- PersonKeys = "name" | "age"
```

Sandboxed environment: standard Luau globals (`assert`, `error`, `print`, `next`, `pairs`, `ipairs`, `select`, `unpack`, `tonumber`, `tostring`, `type`, `typeof`, `getmetatable`, `setmetatable`, `rawget`, `rawset`, `rawlen`, `raweq`) plus `math`, `table`, `string`, `bit32`, `utf8`, `buffer`.

See [`type-functions-api.md`](type-functions-api.md) for the full `types` library reference.
