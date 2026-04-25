--!strict

-- Idiomatic Luau ModuleScript. Showcases strict mode, modern syntax,
-- generics, tagged unions, type refinements, const bindings, and table.freeze.

export type Item = {
    id: string,
    name: string,
    qty: number,
}

export type Result<T> =
    { ok: true, value: T }
  | { ok: false, err: string }

const MAX_STACK = 99

local Inventory = {}

-- Generic helper: find first element matching a predicate.
local function find<T>(list: { T }, pred: (T) -> boolean): T?
    for _, v in list do
        if pred(v) then
            return v
        end
    end
    return nil
end

function Inventory.add(items: { Item }, incoming: Item): Result<{ Item }>
    if incoming.qty <= 0 then
        return { ok = false, err = `qty must be > 0 (got {incoming.qty})` }
    end

    local existing = find(items, function(it: Item)
        return it.id == incoming.id
    end)

    if existing then
        local total = existing.qty + incoming.qty
        if total > MAX_STACK then
            return { ok = false, err = `{incoming.id} would exceed MAX_STACK ({MAX_STACK})` }
        end
        existing.qty = total
    else
        items[#items + 1] = { id = incoming.id, name = incoming.name, qty = incoming.qty }
    end

    return { ok = true, value = items }
end

function Inventory.remove(items: { Item }, id: string, qty: number): Result<number>
    for i, it in items do
        if it.id ~= id then continue end

        if it.qty < qty then
            return { ok = false, err = `not enough {id} (have {it.qty}, need {qty})` }
        end

        it.qty -= qty
        if it.qty == 0 then
            table.remove(items, i)
        end
        return { ok = true, value = it.qty }
    end

    return { ok = false, err = `{id} not in inventory` }
end

function Inventory.summary(items: { Item }): string
    local total = 0
    for _, it in items do
        total += it.qty
    end
    local label = if total == 0 then "empty" else `{#items} stacks, {total} items`
    return `Inventory: {label}`
end

return table.freeze(Inventory)
