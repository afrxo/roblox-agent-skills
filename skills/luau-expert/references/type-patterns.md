# Advanced Luau Type Patterns

## Table of Contents

1. Branded / Nominal Types
2. Recursive Types
3. Read-Only Tables
4. Overloaded Functions
5. Cyclic Module Dependencies
6. Type Narrowing Patterns
7. Sealed vs Unsealed Table Behaviour
8. Generic Type Packs in Aliases

---

## 1. Branded / Nominal Types

Luau is structural — two tables with the same shape are interchangeable. Use a phantom brand field to create distinct nominal types:

```luau
--!strict

type UserId = number & { __brand: "UserId" }
type ItemId = number & { __brand: "ItemId" }

local function makeUserId(n: number): UserId
    return n :: UserId
end

local function makeItemId(n: number): ItemId
    return n :: ItemId
end

local function giveItem(uid: UserId, iid: ItemId): ()
    -- ...
end

giveItem(makeUserId(1), makeItemId(9))  -- ✅
-- giveItem(makeItemId(9), makeUserId(1))  -- ❌ type error
```

The `__brand` field never exists at runtime — it's a phantom type that only the type checker sees.

---

## 2. Recursive Types

```luau
--!strict

type TreeNode<T> = {
    value: T,
    children: { TreeNode<T> },
}

local function sumTree(node: TreeNode<number>): number
    local total = node.value
    for _, child in node.children do
        total += sumTree(child)
    end
    return total
end

-- JSON-like value type
type JsonValue =
    | nil
    | boolean
    | number
    | string
    | { [string]: JsonValue }
    | { JsonValue }
```

---

## 3. Read-Only Tables (via type functions)

The type function library enables a `readonly` utility:

```luau
type function readonly(t)
    if not t:is("table") then error("readonly expects a table type") end
    local result = types.newtable()
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, prop.read)
        end
    end
    return result
end

type Config = { host: string, port: number }
type FrozenConfig = readonly<Config>
-- FrozenConfig is read-only: properties can be read but not written

-- At runtime, use table.freeze for enforcement:
const cfg = table.freeze({ host = "localhost", port = 8080 }) :: FrozenConfig
```

---

## 4. Overloaded Functions

Use intersection types to express overloaded function signatures:

```luau
--!strict

type Overloaded =
    ((x: number) -> string) &
    ((x: string) -> number)

-- Implementation must cast through any since Luau doesn't support
-- user-defined overloaded function bodies yet:
local process: Overloaded = function(x: any): any
    if type(x) == "number" then
        return tostring(x)
    else
        return tonumber(x) or 0
    end
end

local s: string = process(42)    -- ✅
local n: number = process("42")  -- ✅
```

Note: Luau does not yet support user-defined overloaded function bodies natively. Some built-in functions have overloaded types.

---

## 5. Cyclic Module Dependencies

When two modules depend on each other, break the cycle with `any`:

```luau
-- A.luau
--!strict

-- Break cycle: import B as any
local B = require("./B") :: any

export type A = { name: string }

local M = {}

function M.doA(): ()
    B.doB()  -- works at runtime, but not type-safe across the cycle
end

return M
```

Document the cast so future readers understand it's intentional, not laziness.

---

## 6. Type Narrowing Patterns

```luau
--!strict

-- Narrowing with type()
local function processValue(v: string | number | boolean): string
    if type(v) == "string" then
        return v:upper()        -- v: string
    elseif type(v) == "number" then
        return tostring(v * 2)  -- v: number
    else
        return if v then "yes" else "no"  -- v: boolean
    end
end

-- Narrowing with equality (singleton types)
type Status = "idle" | "running" | "done"

local function describe(s: Status): string
    if s == "idle" then
        return "Not started"
    elseif s == "running" then
        return "In progress"
    else
        -- s: "done" — exhausted all options
        return "Finished"
    end
end

-- Narrowing with assert
local function requireValue<T>(v: T?): T
    assert(v ~= nil, "value is required")
    return v   -- narrowed: T (not T?)
end

-- Narrowing optionals
local function getLength(s: string?): number
    if not s then return 0 end
    return #s   -- s: string here
end

-- Composed refinements
local function process(x: (string | number)?, y: boolean): string
    if x ~= nil and type(x) == "string" and y then
        return x:upper()  -- x: string, y: true
    end
    return ""
end
```

---

## 7. Sealed vs Unsealed Table Behaviour

```luau
--!strict

-- UNSEALED: table literal — can add new fields
local point = { x = 1 }
point.y = 2    -- ✅ y is added to the inferred type
-- Once point leaves its creation scope, it becomes sealed

-- SEALED: explicit annotation or function return — cannot add new fields
local point2: { x: number } = { x = 1 }
-- point2.y = 2  -- ❌ not in the sealed type

-- Width subtyping: sealed tables accept supertypes at assignment
type HasName = { name: string }
type Person = { name: string, age: number }

local function printName(v: HasName): ()
    print(v.name)
end

local p: Person = { name = "Ana", age = 30 }
printName(p)  -- ✅ Person satisfies HasName (width subtyping)

-- UNSEALED is exact: missing properties are treated as nil-valued optionals
-- SEALED is inexact: may have extra properties not mentioned in the type
```

---

## 8. Generic Type Packs in Aliases

```luau
--!strict

-- Type alias with a generic type pack parameter
type Fn<Args..., Ret> = (Args...) -> Ret

-- Variadic pack (...T) vs generic pack (U...)
-- ...T = many values all of type T
-- U... = zero or more values of possibly different types

-- Example: wrap function type
type Wrapped<T...> = () -> (T...)

-- Instantiate with explicit type pack
type DoubleReturn = Wrapped<number, string>
-- DoubleReturn = () -> (number, string)

-- Trailing variadic without parentheses
type ArrFn<T> = ({T}) -> ...T
```
