-- Anti-pattern showcase. Same logic as good.luau, written with every legacy idiom
-- the Luau skill warns against. For contrast only — do not produce code like this.

-- ❌ no mode header at all — file silently falls back to project default; declare a mode explicitly

MAX_STACK = 99  -- ❌ global, reassignable

Inventory = {}  -- ❌ global module table

-- ❌ untyped params, untyped return, no generics
function find(list, pred)
    for i, v in ipairs(list) do  -- ❌ ipairs unnecessary
        if pred(v) then
            return v
        end
    end
    return nil
end

-- ❌ no parameter or return types; result shape implicit
function Inventory.add(items, incoming)
    if incoming.qty <= 0 then
        -- ❌ string concatenation instead of interpolation
        return { ok = false, err = "qty must be > 0 (got " .. tostring(incoming.qty) .. ")" }
    end

    local existing = find(items, function(it) return it.id == incoming.id end)

    if existing then
        local total = existing.qty + incoming.qty
        if total > MAX_STACK then
            -- ❌ string.format instead of backtick interpolation
            return { ok = false, err = string.format("%s would exceed MAX_STACK (%d)", incoming.id, MAX_STACK) }
        end
        existing.qty = existing.qty + incoming.qty  -- ❌ no compound assignment
    else
        table.insert(items, { id = incoming.id, name = incoming.name, qty = incoming.qty })
    end

    return { ok = true, value = items }
end

function Inventory.remove(items, id, qty)
    for i, it in pairs(items) do  -- ❌ pairs unnecessary
        -- ❌ no `continue`; uses negated nested block instead
        if it.id == id then
            if it.qty < qty then
                return { ok = false, err = "not enough " .. id }
            end
            it.qty = it.qty - qty  -- ❌ no compound assignment
            if it.qty == 0 then
                table.remove(items, i)
            end
            return { ok = true, value = it.qty }
        end
    end

    return { ok = false, err = id .. " not in inventory" }
end

function Inventory.summary(items)
    local total = 0
    for _, it in pairs(items) do
        total = total + it.qty
    end
    -- ❌ unsafe `and ... or ...` ternary; breaks if middle value is false/nil
    local label = total == 0 and "empty" or (#items .. " stacks, " .. total .. " items")
    return "Inventory: " .. label
end

-- ❌ returns module table without freezing — callers can mutate it
return Inventory
