# Type Function Library (`types`)

Source: <https://luau.org/types-library>

The `types` library is only available inside type functions. It lets you create and transform types at analysis time.

---

## Properties (Primitive Type References)

```luau
types.any       -- the any type
types.unknown   -- the unknown type
types.never     -- the never type
types.boolean   -- the boolean type
types.number    -- the number type
types.string    -- the string type
types.thread    -- the thread type
types.buffer    -- the buffer type
```

---

## Constructor Functions

```luau
types.singleton(arg: string | boolean | nil): type
-- Returns the singleton/literal type for a string or boolean value
-- e.g. types.singleton("hello") → the type "hello"

types.negationof(arg: type): type
-- Returns an immutable negation of the given type

types.optional(arg: type): type
-- Returns arg | nil. If arg is already a union, adds nil to it.

types.unionof(first: type, second: type, ...: type): type
-- Returns an immutable union of two or more types

types.intersectionof(first: type, second: type, ...: type): type
-- Returns an immutable intersection of two or more types

types.newtable(
    props: { [type]: type | { read: type?, write: type? } }?,
    indexer: { index: type, readresult: type, writeresult: type? }?,
    metatable: type?
): type
-- Returns a fresh, mutable table type
-- Property keys must be string singleton types

types.newfunction(
    parameters: { head: {type}?, tail: type? },
    returns: { head: {type}?, tail: type? }?,
    generics: {type}?
): type
-- Returns a fresh, mutable function type

types.copy(arg: type): type
-- Returns a deep copy of the type

types.generic(name: string?, ispack: boolean?): type
-- Creates a generic type parameter named `name`
-- If ispack=true, creates a generic type pack
```

---

## `type` Instance

Every type has a `.tag` and these shared methods:

```luau
type.tag
-- "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string"
-- | "singleton" | "negation" | "union" | "intersection" | "table"
-- | "function" | "extern" | "thread" | "buffer"

type:is(tag: string): boolean
-- Returns true if self.tag == tag

-- __eq: t1 == t2 means syntactically equal (not semantically)
-- e.g. true | false ~= boolean
```

---

## Singleton Type

```luau
singletontype:value(): boolean | nil | string
-- Returns the actual value: true, false, nil, or a string
```

---

## Generic Type

```luau
generictype:name(): string?
-- Name of the generic, or nil if unnamed

generictype:ispack(): boolean
-- True if this is a generic type pack
```

---

## Table Type

```luau
tabletype:setproperty(key: type, value: type?)
-- Set read+write type for a property (key must be string singleton)
-- value=nil removes the property

tabletype:setreadproperty(key: type, value: type?)
-- Set only the read type for a property

tabletype:setwriteproperty(key: type, value: type?)
-- Set only the write type for a property

tabletype:readproperty(key: type): type?
-- Get the read type of a property

tabletype:writeproperty(key: type): type?
-- Get the write type of a property

tabletype:properties(): { [type]: { read: type?, write: type? } }
-- All properties with their read/write types

tabletype:setindexer(index: type, result: type)
-- Set the indexer (read+write same type)

tabletype:setreadindexer(index: type, result: type)
-- Set only the read indexer

tabletype:setwriteindexer(index: type, result: type)
-- Set only the write indexer

tabletype:indexer(): { index: type, readresult: type, writeresult: type }?
-- Get the full indexer

tabletype:readindexer(): { index: type, result: type }?
tabletype:writeindexer(): { index: type, result: type }?

tabletype:setmetatable(arg: type)
tabletype:metatable(): type?
```

---

## Function Type

```luau
functiontype:setparameters(head: {type}?, tail: type?)
-- head: ordered param types, tail: variadic type

functiontype:parameters(): { head: {type}?, tail: type? }

functiontype:setreturns(head: {type}?, tail: type?)
functiontype:returns(): { head: {type}?, tail: type? }

functiontype:generics(): {type}
functiontype:setgenerics(generics: {type}?)
```

---

## Negation Type

```luau
negationtype:inner(): type
-- Returns the type being negated
```

---

## Union Type

```luau
uniontype:components(): {type}
-- Returns an array of the unioned types
```

---

## Intersection Type

```luau
intersectiontype:components(): {type}
-- Returns an array of the intersected types
```

---

## Extern Type (Embedder-Provided)

```luau
externtype:properties(): { [type]: { read: type?, write: type? } }
externtype:readparent(): type?
externtype:writeparent(): type?
externtype:metatable(): type?
externtype:indexer(): { index: type, readresult: type, writeresult: type }?
externtype:readindexer(): { index: type, result: type }?
externtype:writeindexer(): { index: type, result: type }?
```

---

## Example: Custom `keyof`

```luau
type function keyof(t)
    -- t must be a table type
    if not t:is("table") then
        error("keyof expects a table type")
    end
    local keys = {}
    for key in t:properties() do
        -- key is a string singleton type
        table.insert(keys, key)
    end
    if #keys == 0 then return types.never end
    if #keys == 1 then return keys[1] end
    return types.unionof(table.unpack(keys))
end

type Keys = keyof<{ name: string, age: number, id: number }>
-- Keys = "name" | "age" | "id"
```

## Example: `readonly<T>`

```luau
type function readonly(t)
    if not t:is("table") then error("readonly expects a table") end
    local result = types.newtable(nil, nil, t:metatable())
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, prop.read)
            -- no setwriteproperty = write-only access removed
        end
    end
    return result
end

type ReadonlyConfig = readonly<{ name: string, value: number }>
```
