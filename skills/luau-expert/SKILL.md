---
name: luau-expert
description: >
  Modern, strictly-typed Luau. Use whenever writing, reviewing, or fixing Luau code
  (ModuleScripts, ServerScripts, LocalScripts) — language layer only, not Roblox APIs.
  Covers strict mode, type system, idioms, asserts, modules, and anti-patterns.
---

# Luau Language

Write modern, strictly-typed Luau. Source: [luau.org](https://luau.org).

For deep dives see:

- [`references/type-system.md`](references/type-system.md) — primitives, casts, aliases, tables, unions, generics, refinements, type functions
- [`references/typed-class-recipe.md`](references/typed-class-recipe.md) — full setmetatable+`__index` class pattern

Further reading: [`references/type-functions-api.md`](references/type-functions-api.md) (analysis-time `types` library), [`references/type-patterns.md`](references/type-patterns.md) (branded/recursive types, overloads, read-only tables).

---

## Integration Policy

This skill describes preferred patterns; it does **not** authorize rewriting existing code. Apply rules to new code and code the user explicitly asks to refactor. Match the codebase's existing style (casing, indentation, quote style, module shape) before applying skill defaults. Don't weaken stricter files; don't introduce tooling the project doesn't already use; surface conflicts once and default to the existing pattern.

Full rules: [`../../shared/integration-policy.md`](../../shared/integration-policy.md).

---

## Principles

- **Strictly typed.** New files use `--!strict`. Migrate legacy code; never weaken a file that was strict.
- **Bugs caught at analysis time beat runtime asserts.** A typed parameter is worth more than `assert(typeof(x) == "number")`.
- **Simple over clever.** Small functions, obvious intent.
- **Prefer immutability.** Mutating shared state under yields breaks everything; with React-style libraries it's non-negotiable.
- **Type public APIs fully; skip trivial locals.** Annotate anything other modules can call. Don't annotate `local n = item.attack(p)` — inference handles it.

---

## Mode Header

```luau
--!strict      -- default for new files; flags anything that *might* fail at runtime
--!nonstrict   -- legacy migration; infers any when type unknown
--!nocheck     -- generated/third-party only
```

Project-wide: `.luaurc` with `{ "languageMode": "strict" }`.

---

## Modern Syntax

```luau
-- String interpolation (not string.format / not concat)
print(`Player {name} scored {score} points`)

-- if-then-else expression (not `a and b or c`)
local label = if score >= 100 then "Winner" else "Try again"

-- Generalized iteration (not pairs/ipairs)
for k, v in t do ... end

-- Compound assignments
count += 1
path ..= "/suffix"

-- Continue
for _, item in items do
    if not item.active then continue end
    process(item)
end

-- Floor division
local q = 7 // 2

-- Const bindings (binding immutable; value still mutable)
const MAX_PLAYERS = 16

-- Number separators
local big = 1_000_000

-- Function attributes
@native
local function hotPath(x: number): number
    return x * x + x
end
```

`ipairs` only when you specifically need stop-at-first-nil semantics on a sparse array.

---

## Idioms

### Early Return / Continue

Guard clauses over pyramids — when the function logically can't keep going, return early.

```luau
local function dealDamage(humanoid: Humanoid, damage: number)
    if damage <= 0 then return end
    humanoid.Health -= damage
end
```

### Explicit `nil` Checks

Most "truthy" checks really mean "not nil". Write what you mean:

```luau
if x.Parent ~= nil then ...   -- ✅
if x.Parent then ...          -- ❌ ambiguous
```

Two exceptions where truthy is fine: `if`-expressions (`if x then a else b` reads better than the inverted form) and `or` defaults.

### `or` for Defaults; Never `x and y or z`

```luau
soundClone.Volume = volume or 0.5

-- Never simulate ternary with and/or — silently wrong when middle value is falsy
local goldAmount = if gamemode == "arena" then nil else 100   -- ✅
-- local goldAmount = gamemode == "arena" and nil or 100      -- ❌ returns 100 even on arena
```

### Don't Hide Builtins

```luau
local insert = table.insert    -- ❌
table.insert(items, sword)     -- ✅
```

### No Call-Sugar

```luau
call("string")    -- ✅
call({ ... })     -- ✅
call "string"     -- ❌
call { ... }      -- ❌ (StyLua reformats)
```

### `Async` Suffix on Yielding Functions

```luau
local function fetchPlayerDataAsync(userId: number): PlayerData
    -- yields here
end
```

React (and similar render libraries) does not expect yields — a re-render that hits a yielding call silently corrupts component state. Naming yielding functions makes it visible at the call site.

### `pcall` Method-Shorthand

```luau
pcall(part.Destroy, part)                       -- ❌ reads as nonsense
pcall(function() part:Destroy() end)            -- ✅
pcall(saveMoney, player, 100)                   -- ✅ function-shorthand reads naturally
```

---

## Requires

- **No dynamic requires.** `require(Modules.X)` keeps types; `require(child)` in a loop erases them.
- **One alphabetical block.** No sectioning by package vs local. Use Luau LSP auto-require + StyLua `sort_requires` (covered in `roblox-tooling`).

---

## Type System (essentials)

```luau
-- Optional
type Maybe<T> = T?              -- T | nil

-- Tagged union (preferred for results)
type Result<T> = { ok: true, value: T } | { ok: false, err: string }

-- Indexed maps where misses are expected
local playerPoints: { [Player]: number? } = {}    -- ✅ checker forces nil-handling
-- { [Player]: number }                            -- ❌ hides bugs on missing keys

-- Optional argument typing — ? at outer position
local function f(default: (boolean | () -> boolean)?) end    -- ✅
-- local function f(default: boolean? | () -> boolean) end   -- ❌
```

`unknown` for untrusted input; narrow before use. `any` for nothing — always reach for `unknown` first.

Full tour in [`references/type-system.md`](references/type-system.md).

### `nil` ≠ Nothing

```luau
local function returnsNothing() end          -- zero values
local function returnsNil() return nil end   -- one value: nil

print(returnsNothing())   -- (blank)
print(returnsNil())       -- nil
```

Keep return shape consistent across branches. If a function returns `T?`, the no-value branch must `return nil`, not bare `return`.

### String Enums + `exhaustiveMatch`

The only enum form to use:

```luau
type Color = "red" | "green" | "blue"

local function exhaustiveMatch(value: never): never
    error(`Unknown value in exhaustive match: {value}`)
end

local function setColor(color: Color)
    if color == "red" then ...
    elseif color == "green" then ...
    elseif color == "blue" then ...
    else exhaustiveMatch(color)   -- type error if a branch is missed
    end
end
```

No `makeEnum({...})` libraries, no `Color = { red = "red" :: Color }` wrappers. They give nothing string unions don't.

See [`examples/exhaustive-match.luau`](examples/exhaustive-match.luau).

---

## Asserts

- **Always pass an error message.** Bare `assert(cond)` produces useless `assertion failed!`.
- **Constant messages only.** `assert` evaluates its message every call. For formatting use `if not cond then error(\`...\`) end`.
- **Don't `assert(typeof(x) == ...)` to patch types.** If your code is strictly typed, that line never trips except via untyped callers — fix the upstream type instead.
- **At trust boundaries** (RemoteEvents, JSON, plugin input) type the input as `unknown` and narrow:

```luau
HurtMe.OnServerEvent:Connect(function(player, damage: unknown)
    if typeof(damage) ~= "number" or damage < 0 then return end
    -- damage: number from here
    dealDamage(player, damage)
end)
```

Typing the parameter as `number` makes the runtime check look statically valid even when an exploiter sends a string. `unknown` forces the check.

See [`examples/remote-validation.luau`](examples/remote-validation.luau).

---

## Modules

```luau
--!strict
local OtherModule = require("./OtherModule")

export type Config = { timeout: number, retries: number }

const DEFAULT_CONFIG: Config = { timeout = 30, retries = 3 }

local MyModule = {}

function MyModule.connect(cfg: Config?): ()
    local c = cfg or DEFAULT_CONFIG
    -- ...
end

return table.freeze(MyModule)
```

- **Always assign and `return` a named local.** No `return function() ... end` — breaks Ctrl-Shift-F across web/`rg`.
- **One file per utility.** No `TableUtil` mega-modules; `flatten.luau`, `reverse.luau` separately. Luau LSP auto-requires bare names. Project-structure rationale lives in `roblox-systems`.
- **`table.freeze`** the returned module table to catch accidental mutations.
- **Cyclic deps:** cast the imported module to `any` to break the cycle — and document why.

### Shallow Copy, Not Deep

For immutable updates, clone only the path you're touching:

```luau
items = table.clone(items)
items[1] = table.clone(items[1])
items[1].durability -= 10
```

Deep copy is always wasted work under immutability — unrelated subtrees keep their identity, which is exactly what `==` checks across renders want.

See [`examples/module-pattern.luau`](examples/module-pattern.luau).

---

## OOP — Default to Free Functions

Plain data + free functions over classes. Metatables fight the type checker, hurt grep, and surprise readers.

```luau
type Slide = { length: number }
type Video = { slides: { Slide } }

-- videoLength.luau
local function videoLength(video: Video): number
    local total = 0
    for _, slide in video.slides do
        total += slide.length
    end
    return total
end

return videoLength
```

Aside from `__index` and `__tostring` (and `__mode` for the rare weak table), **avoid every metamethod.** No `__call`, no `__add`, no operator overloads — they don't autocomplete and they fight inference.

When a class is genuinely warranted, see [`references/typed-class-recipe.md`](references/typed-class-recipe.md).

---

## Verification Rules

- **Don't assume Lua APIs exist in Luau.** Several were removed or relocated:
  - `setfenv` / `getfenv` — removed.
  - `unpack` (global) — moved to `table.unpack`.
  - `loadstring` — removed; use `loadstring`-equivalent only via `loadstring` if explicitly enabled, otherwise unavailable.
  - `bit32` — present, but consider native bitwise operators where possible.
  - `goto` / labels — not in Luau.
- **Don't invent syntax.** If you're unsure whether a feature (e.g. `const`, `@native`, type functions, default generics) exists or is stable, check [luau.org](https://luau.org) before using it. State the uncertainty in your reply rather than guessing.
- **Stable concepts beat brittle signatures.** If you can express the rule as "use the type system to prevent the bug" rather than "this exact stdlib function takes these exact arguments", do that — Luau's stdlib evolves; the typing principles don't.
- **Roblox APIs are out of scope here.** For `RemoteEvent`, `DataStore`, `Instance`, services, etc., defer to the `roblox-dev` skill. This skill covers the language only.

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|---|---|
| `pairs(t)` / `ipairs(t)` | `for k, v in t do` |
| `string.format(...)` | `` `interpolated {value}` `` |
| `a and b or c` | `if a then b else c` |
| `if x.Parent then` | `if x.Parent ~= nil then` |
| `local insert = table.insert` | Inline `table.insert` |
| `call "x"` / `call { ... }` | `call("x")` / `call({ ... })` |
| Reassignable constants | `const MAX = 100` |
| Globals | `local` / `const` |
| `any` | `unknown` + narrowing |
| Trivial local annotations | Let inference work |
| Untyped public function | Annotate params + return |
| `assert(typeof(x) == "T")` to patch types | Fix the upstream type |
| `assert(cond)` no message / formatted message | Constant message; `if … then error(…)` for formatted |
| `pcall(part.Destroy, part)` | `pcall(function() part:Destroy() end)` |
| `{ [K]: V }` when keys may be missing | `{ [K]: V? }` |
| Bare `return` from a `T?` function | Explicit `return nil` |
| `for _, m in c:GetChildren() do require(m)` | Static `require(c.X)` |
| Sectioned require blocks | One alphabetical block |
| Yielding fn missing `Async` suffix | Suffix `Async` |
| `makeEnum({"red","green"})` | `type Color = "red" \| "green"` + `exhaustiveMatch` |
| `__call` / `__add` / operator metamethods | Plain functions |
| Anonymous module return | `local foo = ...; return foo` |
| `TableUtil` mega-modules | One function per file |
| Deep copy for immutable update | Clone only the touched path |
| `math.floor(a / b)` | `a // b` |
| Mutating module table | `table.freeze` the return |
| Pyramid nesting | Early returns + `continue` |

---

## Examples

- [`examples/good.luau`](examples/good.luau) — idiomatic Luau ModuleScript using every recommended pattern.
- [`examples/bad.luau`](examples/bad.luau) — same logic with every anti-pattern. For contrast only.
- [`examples/exhaustive-match.luau`](examples/exhaustive-match.luau) — string enums + `exhaustiveMatch` helper.
- [`examples/remote-validation.luau`](examples/remote-validation.luau) — `unknown` + narrowing at a RemoteEvent boundary.
- [`examples/module-pattern.luau`](examples/module-pattern.luau) — clean module skeleton.
